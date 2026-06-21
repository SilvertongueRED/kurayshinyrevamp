#!/usr/bin/env python3
"""Optional neural refiner. The sidecar soft-imports this; if torch + diffusers
are installed AND trained LoRA weights are present, it upgrades each compositor
sprite to human-custom quality via Stable Diffusion img2img (the compositor sprite
is the init image, so structure & palette are preserved and the LoRA supplies
detail and finish). Anything missing/failing -> available() is False / refine()
returns None, and the sidecar serves the compositor sprite unchanged.

Config: neural.json (next to this file). Train weights with train/train_lora.py.
"""
import os, json, functools
from PIL import Image
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
_PIPE = None
_CFG = None


def _cfg():
    global _CFG
    if _CFG is None:
        path = os.path.join(HERE, "neural.json")
        base = {"base_model": "stable-diffusion-v1-5/stable-diffusion-v1-5",
                "lora_dir": "models/lora", "img2img_strength": 0.5, "steps": 28,
                "guidance": 7.0, "lora_scale": 0.9, "res": 512, "canvas": 288,
                "device": "auto",
                # style prefix MUST match prepare_dataset._STYLE (the LoRA trigger).
                "style_prompt": "infinite fusion pokemon battle sprite, 2d pixel art, "
                          "clean 1-pixel black outline, flat cel shading, limited palette, "
                          "crisp hard edges, no anti-aliasing, no dithering, single creature "
                          "centered on a plain white background, front three-quarter view",
                # clean-pixel-art finishing of the diffusion output (see _pixel_finish)
                "pixel_finish": True, "finish_colors": 18, "outline_luma": 50,
                "finish_outline": True, "grid_snap": 0,
                "negative_prompt": "blurry, jpeg artifacts, photo, realistic, 3d render, "
                                   "soft shading, gradient, watermark, text, signature, "
                                   "multiple creatures, extra limbs, deformed, smooth anti-aliasing"}
        try:
            base.update(json.load(open(path, encoding="utf-8")))
        except Exception:
            pass
        _CFG = base
    return _CFG


def _resolve_lora(game_root):
    c = _cfg()
    cands = [c["lora_dir"], os.path.join(HERE, c["lora_dir"])]
    if game_root:
        cands.append(os.path.join(game_root, "Tools", "kif_neuralfusion", c["lora_dir"]))
    for d in cands:
        if os.path.isdir(d) and (os.path.isfile(os.path.join(d, "pytorch_lora_weights.safetensors"))
                                 or os.path.isfile(os.path.join(d, "pytorch_lora_weights.bin"))):
            return d
    return None


@functools.lru_cache(maxsize=1)
def _torch_ok():
    try:
        import torch  # noqa
        import diffusers  # noqa
        return True
    except Exception:
        return False


def available(game_root=None):
    return bool(_cfg().get("enabled", True) and _torch_ok() and _resolve_lora(game_root))


def _load_pipe(game_root):
    global _PIPE
    if _PIPE is not None:
        return _PIPE
    import torch
    from diffusers import AutoPipelineForImage2Image
    c = _cfg()
    dev = c["device"]
    if dev == "auto":
        dev = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if dev == "cuda" else torch.float32
    pipe = AutoPipelineForImage2Image.from_pretrained(c["base_model"], torch_dtype=dtype,
                                                      safety_checker=None)
    lora = _resolve_lora(game_root)
    pipe.load_lora_weights(lora)
    try:
        names = pipe.get_active_adapters()
        if names:
            pipe.set_adapters(names, adapter_weights=[float(c["lora_scale"])] * len(names))
    except Exception:
        pass
    pipe = pipe.to(dev)
    try:
        pipe.set_progress_bar_config(disable=True)
    except Exception:
        pass
    _PIPE = pipe
    return pipe


def _build_prompt(c, head, body, third):
    """Compose the inference prompt. Mirrors the training captions so the style
    prefix acts as the LoRA trigger and the right fusion-kind token is supplied
    (2-way fusion / self-fusion / triple fusion)."""
    style = c.get("style_prompt") or c.get("prompt") or ""
    # back-compat: an old {head}/{body} template still formats fine.
    try:
        style = style.format(head=head, body=body, third=(third if third is not None else ""))
    except Exception:
        pass
    if third is not None and str(third) != "":
        desc = f"triple fusion, head:h{head} body:b{body} third:t{third}"
    elif str(head) == str(body):
        desc = f"self-fusion, single clean species sprite, self:s{head} head:h{head} body:b{body}"
    else:
        desc = f"fusion with head:h{head} body:b{body}"
    return f"{style}, {desc}" if "head:h" not in style else style


def _pixel_finish(out_rgb, alpha, c):
    """Snap the diffusion output back to clean pixel art so it matches the base &
    custom sprites: re-key transparency, drop the near-white halo, optionally snap
    to a coarser pixel grid, then quantise to a limited palette and re-draw a
    crisp 1-pixel outline -- reusing the compositor's corpus-fit finishing."""
    import compositor as COMP
    P = COMP.load_params()
    t = int(P["alpha_threshold"])
    arr = np.dstack([np.asarray(out_rgb, np.uint8), alpha]).astype(np.uint8)
    # drop near-white halo pixels inside the silhouette edge
    rgb = arr[:, :, :3].astype(np.int32)
    near_white = (rgb[:, :, 0] > 244) & (rgb[:, :, 1] > 244) & (rgb[:, :, 2] > 244)
    arr[:, :, 3][near_white] = 0
    # optional grid snap (blockier, lower-res pixels) -- off by default
    g = int(c.get("grid_snap", 0) or 0)
    if g > 1:
        h, w = arr.shape[:2]
        small = Image.fromarray(arr, "RGBA").resize((max(1, w // g), max(1, h // g)), Image.BOX)
        arr = np.asarray(small.resize((w, h), Image.NEAREST), np.uint8).copy()
    arr = COMP.clean_alpha(arr, t)
    arr = COMP.posterize(arr, int(c.get("finish_colors", P["palette"]["posterize_colors"])))
    if c.get("finish_outline", True):
        arr = COMP.add_outline(arr, int(c.get("outline_luma", P["outline"]["target_luma"])), 1)
    return arr


def refine(comp_img, head, body, seed, game_root=None, third=None):
    """comp_img: RGBA PIL from the compositor. Returns a refined RGBA PIL (canvas
    sq, transparent bg) or None on any failure. `third` set => triple fusion."""
    try:
        import torch
        c = _cfg()
        res = int(c["res"])
        rgba = comp_img.convert("RGBA").resize((res, res), Image.NEAREST)
        # init image on white (SD works in RGB)
        white = Image.new("RGBA", (res, res), (255, 255, 255, 255))
        white.alpha_composite(rgba)
        init = white.convert("RGB")
        alpha = np.asarray(rgba.split()[-1], np.uint8)  # compositor silhouette
        pipe = _load_pipe(game_root)
        dev = pipe.device.type if hasattr(pipe, "device") else "cpu"
        gen = torch.Generator(device=dev).manual_seed(int(seed) & 0x7fffffff)
        prompt = _build_prompt(c, head, body, third)
        out = pipe(prompt=prompt, negative_prompt=c["negative_prompt"], image=init,
                   strength=float(c["img2img_strength"]), num_inference_steps=int(c["steps"]),
                   guidance_scale=float(c["guidance"]), generator=gen).images[0]
        out = out.convert("RGB")
        if c.get("pixel_finish", True):
            arr = _pixel_finish(out, alpha, c)
        else:
            arr = np.dstack([np.asarray(out, np.uint8), alpha]).astype(np.uint8)
            rgb = arr[:, :, :3].astype(np.int32)
            near_white = (rgb[:, :, 0] > 244) & (rgb[:, :, 1] > 244) & (rgb[:, :, 2] > 244)
            arr[:, :, 3][near_white] = 0
        result = Image.fromarray(arr, "RGBA").resize((int(c["canvas"]), int(c["canvas"])), Image.NEAREST)
        return result
    except Exception as e:
        print(f"[KIF NeuralFusion] neural.refine error: {e}")
        return None
