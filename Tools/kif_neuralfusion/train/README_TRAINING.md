# Training the KIF NeuralFusion LoRA (GPU)

This upgrades the sidecar from the always-on compositor to human-custom quality.
The idea: teach Stable Diffusion to refine our compositor sprite into a sprite
that looks hand-made, using the 222k human customs as ground truth. At inference
the compositor output is the img2img init image, so the model only has to add
detail/finish — not invent structure.

## 0. Hardware
CUDA GPU. ~8 GB VRAM at 512px / LoRA rank 16 (drop to `--resolution 384` or
`--rank 8` for less). Full run is a few hours on a single modern GPU; you can
stop early — checkpoints land in `../models/lora/checkpoint-*`.

## 1. Install
    pip install -r requirements_train.txt
    # install torch matching your CUDA from https://pytorch.org first
    accelerate config default

## 2. Build the dataset (composite -> human-custom pairs)
    python prepare_dataset.py \
        --corpus  "C:/.../PIFFull Sprite pack 1-125 (April 2026)/CustomBattlers" \
        --base-roots "C:/.../kurayshinyrevamp" "C:/.../PIFFull Sprite pack.../Other" \
        --out ../dataset --size 512 --limit 0 --val-split 0.02
Emits `../dataset/target/*.png` (human customs on white), `../dataset/cond/*.png`
(our compositor for the same pair), and `metadata.jsonl`
(`file_name` + `text` + `conditioning_image`). 222k pairs ~ tens of GB; use
`--limit 40000` for a strong first pass.

### Better captions (optional)
Drop a `../species.json` of `{ "25": {"name":"Pikachu","type1":"Electric"}, ... }`
and prepare_dataset.py writes name/type captions instead of id tokens.

## 3. Train
    accelerate launch train_lora.py \
        --dataset ../dataset --output ../models/lora \
        --base-model "stable-diffusion-v1-5/stable-diffusion-v1-5" \
        --resolution 512 --rank 16 --lr 1e-4 --batch 2 --grad-accum 4 \
        --max-steps 6000 --mixed-precision fp16 --snr-gamma 5.0
Output: `../models/lora/pytorch_lora_weights.safetensors`.

The dataset is standard HF `imagefolder`, so you can instead run diffusers'
official `examples/text_to_image/train_text_to_image_lora.py --train_data_dir
../dataset` unchanged.

## 4. Activate
The sidecar auto-detects `models/lora/` on next launch and switches to NEURAL
(check its console: `tier: NEURAL+compositor`). Tune `../neural.json`:
`img2img_strength` 0.4 = closer to the compositor, 0.6 = more model creativity;
`lora_scale`, `steps`, `guidance`, `prompt` as usual.

## Stronger option: ControlNet / InstructPix2Pix
prepare_dataset.py already writes the `cond/` conditioning images and a
`conditioning_image` column, so you can train diffusers' `train_controlnet.py`
(or instruct-pix2pix) on composite->custom for the most faithful refinement,
then point `neural.json` at the controlnet dir. The LoRA route above is the
simplest path and is recommended first.

## Diagnostics / logs (read this if training fails)
Every stage now writes a full log automatically — you don't have to enable
anything. Logs land in `Tools/kif_neuralfusion/logs/`:

* `latest.log` — the whole most-recent run (setup + dataset + train) in one file.
  The `Train AI Sprites (GPU).bat` clears this at the start of each run.
* `bootstrap_*.log`, `prepare_dataset_*.log`, `train_lora_*.log` — a timestamped
  copy per stage (kept as history).

Each log records the OS/Python, `nvidia-smi`, the installed package versions,
`torch.cuda.is_available()` + the GPU/VRAM, every CLI argument, and — on a
failure — the **full traceback plus targeted hints** (CUDA out-of-memory,
fp16-on-CPU, HuggingFace download problems, missing packages, locked files,
full disk). If a run dies, open `latest.log` and read the `FAILURE` section at
the bottom; if you ask for help, send that file.

Common fix the log will point at: if it shows `cuda.is_available  False` while
you do have an NVIDIA GPU, the training env got a CPU-only torch. Delete
`Tools/kif_neuralfusion/.venv-train` and re-run setup so the CUDA wheel
reinstalls (confirm `nvidia-smi` works in a normal terminal first).

## Full species coverage (--base-dir)
The PIF fusion corpus only covers a limited species range. To teach the model
EVERY pokemon (so out-of-PIF fusions render real features), the dataset step
also pulls in the game's complete BaseSprites as single-species training targets:

    --base-dir ".../Kuray Infinite Fusion/Graphics/BaseSprites" --base-limit 0

Each base sprite `<id>[letter].png` becomes a target whose conditioning image is
the compositor's own rendering of it, captioned with the same `h<id>/b<id>`
token used by fusions — so the species identity learned here transfers straight
into fusion prompts. `Train AI Sprites (GPU).bat` already wires this up (the
`BASES` variable); set `BASELIMIT` above 0 only if you want to cap it.

## Troubleshooting

### "It trained on the CPU / my GPU wasn't used" (and repeated Hugging Face errors)
This happens when the training venv ends up with a **CPU-only** PyTorch
(`torch x.y.z+cpu`, `torch.cuda.is_available() == False`) even though you have an
NVIDIA GPU. The log header shows it under `----- torch / CUDA -----`.

Fix (fast, keeps the rest of the env):

```
Tools\kif_neuralfusion\.venv-train\Scripts\python.exe -m pip install ^
  --force-reinstall --no-cache-dir torch torchvision ^
  --index-url https://download.pytorch.org/whl/cu128
```

…or just re-run **`Train AI Sprites (GPU).bat`** — it now self-heals: it always
runs `bootstrap.py train`, which detects a CPU-only torch next to an NVIDIA GPU
and reinstalls a CUDA build (trying cu130 → cu129 → cu128 → … until one actually
sees the GPU). You can also run the repair explicitly:

```
py -3 Tools\kif_neuralfusion\bootstrap.py repair-train
```

The Hugging Face noise is now quieted (symlink/telemetry warnings off) and the
SD1.5 base-model download is resumable + retried, so a flaky/rate-limited
connection no longer crashes the run.

### Triples & self-fusions
`prepare_dataset.py` now also ingests the hand-made triple sprites via
`--triple-dir` (the game's `Graphics/Battlers/special/`), pairing each
`s1.s2.s3.png` with the compositor's own triple render so the LoRA learns to turn
a rough triple into a clean one. Self-fusions (head == body) are trained from the
full base-sprite set and captioned with a `self:s<id>` token. The Train .bat wires
`--triple-dir` automatically. At generation time the sidecar accepts
`/generate?head=H&body=B&third=T` (triple) and `head==body` (self).
