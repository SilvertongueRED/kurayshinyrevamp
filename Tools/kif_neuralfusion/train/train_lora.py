#!/usr/bin/env python3
"""Fine-tune a LoRA that turns our compositor output into human-custom-quality
Infinite-Fusion sprites. Stable Diffusion 1.5 UNet LoRA, trained on the human
customs (target/) with style+id captions. At inference the sidecar runs img2img
with our compositor sprite as the init image and this LoRA loaded, so structure
& palette come from the compositor and detail/finish come from the LoRA.

REQUIRES a CUDA GPU (~8 GB VRAM at 512 / rank 16; less with --resolution 384).
The prepared dataset is plain HuggingFace `imagefolder` (metadata.jsonl with
file_name + text), so if you prefer you can instead run diffusers' official
examples/text_to_image/train_text_to_image_lora.py --train_data_dir <dataset>
unchanged -- see README_TRAINING.md.

All output (and any crash traceback) is teed into kif_neuralfusion/logs/ by tlog.

Example:
  accelerate launch train_lora.py \
     --dataset ../dataset --output ../models/lora \
     --base-model "stable-diffusion-v1-5/stable-diffusion-v1-5" \
     --resolution 512 --rank 16 --lr 1e-4 --batch 2 --grad-accum 4 \
     --max-steps 6000 --mixed-precision fp16
"""
import os, sys, json, math, time, glob, shutil, argparse, random
from pathlib import Path

# Quiet the repeated Hugging Face noise the user saw, and keep downloads robust.
# These MUST be set before transformers / diffusers / huggingface_hub import.
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")   # the repeated symlink warning
os.environ.setdefault("HF_HUB_DISABLE_TELEMETRY", "1")
os.environ.setdefault("TRANSFORMERS_NO_ADVISORY_WARNINGS", "1")
os.environ.setdefault("HF_HUB_ENABLE_HF_TRANSFER", "0")         # don't require the optional hf_transfer pkg
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))           # package dir (tlog.py)
try:
    import tlog
except Exception:
    tlog = None

import torch
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader
from PIL import Image
import numpy as np

from accelerate import Accelerator
from accelerate.utils import set_seed
from diffusers import (AutoencoderKL, DDPMScheduler, UNet2DConditionModel,
                       StableDiffusionPipeline)
from diffusers.optimization import get_scheduler
from diffusers.training_utils import compute_snr
from diffusers.utils import convert_state_dict_to_diffusers
from transformers import CLIPTextModel, CLIPTokenizer
from peft import LoraConfig
from peft.utils import get_peft_model_state_dict


class JsonlImageData(Dataset):
    def __init__(self, root, tokenizer, resolution, jsonl="metadata.jsonl"):
        self.root = Path(root)
        self.tok = tokenizer
        self.res = resolution
        path = self.root / jsonl
        if not path.is_file():
            raise FileNotFoundError(
                f"{path} not found -- run prepare_dataset.py first (or fix --dataset).")
        self.records = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]

    def __len__(self):
        return len(self.records)

    def __getitem__(self, i):
        r = self.records[i]
        img = Image.open(self.root / r["file_name"]).convert("RGB").resize(
            (self.res, self.res), Image.NEAREST)
        x = torch.from_numpy(np.asarray(img, np.float32) / 127.5 - 1.0).permute(2, 0, 1)
        ids = self.tok(r["text"], max_length=self.tok.model_max_length, padding="max_length",
                       truncation=True, return_tensors="pt").input_ids[0]
        return {"pixel_values": x, "input_ids": ids}


def _find_latest_checkpoint(output):
    """Return (path, step) of the newest checkpoint-<N> dir under output, or (None, 0)."""
    best, best_n = None, -1
    for d in glob.glob(os.path.join(output, "checkpoint-*")):
        if not os.path.isdir(d):
            continue
        try:
            n = int(os.path.basename(d).split("-")[-1])
        except Exception:
            continue
        if n > best_n:
            best, best_n = d, n
    return (best, best_n) if best else (None, 0)


def _prune_checkpoints(output, keep):
    """Keep only the `keep` newest checkpoint-<N> dirs; delete older ones to bound disk."""
    if keep is None or keep <= 0:
        return
    dirs = []
    for d in glob.glob(os.path.join(output, "checkpoint-*")):
        if os.path.isdir(d):
            try:
                dirs.append((int(os.path.basename(d).split("-")[-1]), d))
            except Exception:
                pass
    for _n, d in sorted(dirs)[:-keep]:
        try:
            shutil.rmtree(d, ignore_errors=True)
            print(f"  [checkpoint] pruned old {os.path.basename(d)}")
        except Exception:
            pass


def _ensure_base_model(model_id, tries=6):
    """Pre-download the SD1.5 base model with resume + retry/backoff so a flaky or
    rate-limited Hugging Face connection doesn't repeatedly crash the run (the
    'repeated hugging face errors'). A local path is used as-is. After this the
    from_pretrained() calls below just read the cache."""
    if os.path.isdir(model_id):
        print(f"[train] base model is a local path: {model_id}")
        return
    try:
        from huggingface_hub import snapshot_download
    except Exception as e:
        print(f"[train] huggingface_hub unavailable ({e}); from_pretrained will fetch directly.")
        return
    # only the components we actually load (skip the giant single-file checkpoints)
    allow = ["model_index.json", "*.txt",
             "tokenizer/*", "text_encoder/*", "vae/*", "unet/*", "scheduler/*"]
    last = None
    for i in range(tries):
        try:
            path = snapshot_download(model_id, allow_patterns=allow, resume_download=True)
            print(f"[train] base model ready in cache: {path}")
            return
        except Exception as e:
            last = e
            wait = min(45, 4 * (i + 1))
            print(f"[train] HF download attempt {i+1}/{tries} failed: {e}\n"
                  f"        retrying in {wait}s (resumable)...", flush=True)
            time.sleep(wait)
    print(f"[train] WARNING: could not pre-download {model_id} after {tries} tries "
          f"({last}). Will let from_pretrained try once more; if it also fails, check "
          f"your internet / the Hugging Face status page and re-run.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--base-model", default="stable-diffusion-v1-5/stable-diffusion-v1-5")
    ap.add_argument("--resolution", type=int, default=512)
    ap.add_argument("--rank", type=int, default=16)
    ap.add_argument("--lr", type=float, default=1e-4)
    ap.add_argument("--batch", type=int, default=2)
    ap.add_argument("--grad-accum", type=int, default=4)
    ap.add_argument("--max-steps", type=int, default=6000)
    ap.add_argument("--warmup", type=int, default=200)
    ap.add_argument("--snr-gamma", type=float, default=5.0, help="0 disables SNR weighting")
    ap.add_argument("--mixed-precision", default="fp16", choices=["no", "fp16", "bf16"])
    ap.add_argument("--checkpoint-steps", type=int, default=1000)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--gradient-checkpointing", action="store_true", default=True)
    ap.add_argument("--resume", default="auto",
                    help="auto = resume from the newest checkpoint-N in --output if any; "
                         "none = always start fresh; or a path to a specific checkpoint dir")
    ap.add_argument("--keep-checkpoints", type=int, default=2,
                    help="how many recent checkpoint-N dirs to keep (older ones are pruned)")
    args = ap.parse_args()

    # ---- diagnostics: dump everything we'd want if this run fails -----------
    if tlog:
        tlog.section("args")
        print(json.dumps(vars(args), indent=2, default=str))
        tlog.dump_nvidia_smi()
        tlog.dump_versions(["torch", "torchvision", "diffusers", "transformers",
                            "accelerate", "peft", "safetensors", "numpy", "PIL"])
        tlog.dump_torch_env()

    # ---- GPU / precision guard: the #1 cause of an instant failure ----------
    if not torch.cuda.is_available():
        print("\n[WARN] ==============================================================")
        print("[WARN] No CUDA GPU is visible to torch -- this is the most common")
        print("[WARN] reason training fails right away. SD1.5 LoRA on CPU is not")
        print("[WARN] practical, and fp16/bf16 ops are unsupported on CPU (you'd")
        print("[WARN] get a 'not implemented for Half' crash).")
        print("[WARN]  -> Forcing --mixed-precision no so the run can at least start.")
        print("[WARN]  -> To really train: re-run 'Setup AI Sprites.bat' / bootstrap")
        print("[WARN]     so CUDA torch installs, confirm `nvidia-smi`, then retry.")
        print("[WARN] ==============================================================\n")
        args.mixed_precision = "no"

    set_seed(args.seed)
    acc = Accelerator(gradient_accumulation_steps=args.grad_accum,
                      mixed_precision=args.mixed_precision)
    wdtype = {"no": torch.float32, "fp16": torch.float16, "bf16": torch.bfloat16}[args.mixed_precision]
    print(f"[train] device={acc.device} mixed_precision={args.mixed_precision}")

    print(f"[train] loading base model: {args.base_model}")
    _ensure_base_model(args.base_model)
    tok = CLIPTokenizer.from_pretrained(args.base_model, subfolder="tokenizer")
    text = CLIPTextModel.from_pretrained(args.base_model, subfolder="text_encoder")
    vae = AutoencoderKL.from_pretrained(args.base_model, subfolder="vae")
    unet = UNet2DConditionModel.from_pretrained(args.base_model, subfolder="unet")
    noise_sched = DDPMScheduler.from_pretrained(args.base_model, subfolder="scheduler")

    vae.requires_grad_(False); text.requires_grad_(False); unet.requires_grad_(False)
    unet.add_adapter(LoraConfig(r=args.rank, lora_alpha=args.rank, init_lora_weights="gaussian",
                                target_modules=["to_k", "to_q", "to_v", "to_out.0"]))
    if args.gradient_checkpointing:
        unet.enable_gradient_checkpointing()

    # Keep the VAE in fp32 even under fp16 training: the SD1.5 VAE is numerically
    # unstable in fp16 and can emit NaN latents (-> NaN loss, dead run). Only the
    # frozen text encoder is cast to the working dtype.
    vae.to(acc.device, dtype=torch.float32)
    text.to(acc.device, dtype=wdtype)
    lora_params = [p for p in unet.parameters() if p.requires_grad]
    opt = torch.optim.AdamW(lora_params, lr=args.lr)

    ds = JsonlImageData(args.dataset, tok, args.resolution)
    if len(ds) == 0:
        raise RuntimeError(
            f"dataset has 0 images (empty metadata.jsonl in {args.dataset}). "
            "Run prepare_dataset.py first, or point --dataset at the built dataset.")
    if len(ds) < args.batch:
        print(f"[train] only {len(ds)} images available; lowering --batch to 1")
        args.batch = 1
    # num_workers>0 on Windows spawns subprocesses and is a frequent source of
    # cryptic crashes/hangs; keep it single-process there.
    nworkers = 0 if os.name == "nt" else 4
    dl = DataLoader(ds, batch_size=args.batch, shuffle=True, num_workers=nworkers, drop_last=True)
    lr_sched = get_scheduler("cosine", opt, num_warmup_steps=args.warmup * args.grad_accum,
                             num_training_steps=args.max_steps * args.grad_accum)
    unet, opt, dl, lr_sched = acc.prepare(unet, opt, dl, lr_sched)

    # ---- auto-resume: continue from the newest checkpoint if asked -----------
    step = 0
    resume_mode = (args.resume or "auto").strip().lower()
    resume_dir = None
    if resume_mode not in ("none", "no", "off", ""):
        if resume_mode == "auto":
            resume_dir, step = _find_latest_checkpoint(args.output)
        elif os.path.isdir(args.resume):
            resume_dir = args.resume
            try:
                step = int(os.path.basename(args.resume.rstrip("/\\")).split("-")[-1])
            except Exception:
                step = 0
        if resume_dir:
            try:
                acc.load_state(resume_dir)
                print(f"[train] RESUMING from {os.path.basename(resume_dir)} at step {step}/{args.max_steps}", flush=True)
                if step >= args.max_steps:
                    print(f"[train] checkpoint step {step} >= max-steps {args.max_steps}; "
                          "nothing to do. Increase --max-steps or delete checkpoints to retrain.")
            except Exception as e:
                print(f"[train] could not resume from {resume_dir} ({e}); starting fresh.")
                step = 0
        else:
            print("[train] no checkpoint to resume from; starting fresh.")

    print(f"[train] {len(ds)} images | steps {args.max_steps} | rank {args.rank} | "
          f"res {args.resolution} | starting at step {step}")
    done = step >= args.max_steps
    while not done:
        for batch in dl:
            with acc.accumulate(unet):
                pv = batch["pixel_values"].to(dtype=vae.dtype)          # fp32 for the VAE
                latents = vae.encode(pv).latent_dist.sample() * vae.config.scaling_factor
                latents = latents.to(dtype=wdtype)
                noise = torch.randn_like(latents)
                bsz = latents.shape[0]
                t = torch.randint(0, noise_sched.config.num_train_timesteps, (bsz,),
                                  device=latents.device).long()
                noisy = noise_sched.add_noise(latents, noise, t)
                enc = text(batch["input_ids"])[0]
                pred = unet(noisy, t, enc).sample
                target = noise if noise_sched.config.prediction_type == "epsilon" \
                    else noise_sched.get_velocity(latents, noise, t)
                if args.snr_gamma and args.snr_gamma > 0:
                    snr = compute_snr(noise_sched, t)
                    w = torch.stack([snr, args.snr_gamma * torch.ones_like(t)], 1).min(1)[0] / snr
                    loss = (F.mse_loss(pred.float(), target.float(), reduction="none").mean([1, 2, 3]) * w).mean()
                else:
                    loss = F.mse_loss(pred.float(), target.float())
                if not torch.isfinite(loss):
                    raise RuntimeError(
                        f"loss became non-finite (NaN/Inf) near step {step}. Usual causes: "
                        "fp16 instability or too-high --lr. Try --mixed-precision bf16 (if "
                        "your GPU supports it) or a lower --lr (e.g. 5e-5).")
                acc.backward(loss)
                if acc.sync_gradients:
                    acc.clip_grad_norm_(lora_params, 1.0)
                opt.step(); lr_sched.step(); opt.zero_grad()
            if acc.sync_gradients:
                step += 1
                if step % 25 == 0 and acc.is_main_process:
                    print(f"  step {step}/{args.max_steps}  loss {loss.item():.4f}", flush=True)
                if step % args.checkpoint_steps == 0:
                    ckpt = os.path.join(args.output, f"checkpoint-{step}")
                    if acc.is_main_process:
                        _save(acc, unet, ckpt)            # deployable LoRA weights
                    acc.save_state(ckpt)                  # full state for auto-resume
                    if acc.is_main_process:
                        _prune_checkpoints(args.output, args.keep_checkpoints)
                        print(f"  [checkpoint] saved + resumable checkpoint-{step}", flush=True)
                if step >= args.max_steps:
                    done = True
                    break
    if acc.is_main_process:
        _save(acc, unet, args.output)
        print(f"[train] DONE -> {args.output}  (pytorch_lora_weights.safetensors)")


def _save(acc, unet, out):
    os.makedirs(out, exist_ok=True)
    u = acc.unwrap_model(unet)
    sd = convert_state_dict_to_diffusers(get_peft_model_state_dict(u))
    StableDiffusionPipeline.save_lora_weights(out, unet_lora_layers=sd, safe_serialization=True)


if __name__ == "__main__":
    if tlog:
        tlog.open_log("train_lora")
        tlog.guarded(main, "train_lora")
    else:
        main()
