#!/usr/bin/env python3
"""KIF NeuralFusion - on-device compositor (the runs-anywhere fusion model).

Given a HEAD species sprite and a BODY species sprite, produce a clean
Infinite-Fusion-style fusion: the body's silhouette recolored toward the head's
palette, with the head's distinctive features capped on top, unified outline,
and a tight limited palette. Pure PIL + numpy, ~50 ms/sprite on CPU.

Its parameters are FIT to the human custom-sprite corpus (see params.json /
calibrate.py): tight ~15-colour palette, dark (~luma 50) outline, body-defines-
silhouette / head-supplies-features. A `seed` deterministically varies recolor
strength, head scale & placement, palette size and hue, so "generate more"
yields distinct but plausible variants.

This is the structural tier. If trained diffusion weights are present the sidecar
uses this output as the img2img init image and refines it (see sidecar.py).
"""
import os, json, math, hashlib
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CANVAS_DEFAULT = 288


# --------------------------------------------------------------------------- #
#  Parameters (fit to corpus, overridable via params.json)
# --------------------------------------------------------------------------- #
_DEFAULTS = {
    "canvas": 288,
    "alpha_threshold": 24,
    "palette": {"posterize_colors": 16, "posterize_jitter": 4},
    "outline": {"target_luma": 50, "enabled": True, "thickness": 1},
    "recolor": {"strength": 0.70, "strength_jitter": 0.08, "head_palette_k": 10,
                "hue_rotate_deg_jitter": 12},
    "head": {"max_top_fraction": 0.55, "fallback_fraction": 0.45,
             "neck_width_ratio": 0.82, "width_ratio_on_body": 1.02,
             "width_ratio_jitter": 0.12, "shoulder_fraction": 0.31,
             "shoulder_jitter": 0.04, "vertical_overlap": 0.06},
    # Triple fusion = fuse(fuse(s1,s2), s3): the s1/s2 fusion supplies the shape &
    # head, then s3 contributes its colour identity (a softer recolor) the way the
    # game's hand-made triples read as "a bit of all three".
    "triple": {"third_strength": 0.34, "third_strength_jitter": 0.06},
}


def _deep_merge(base, over):
    out = dict(base)
    for k, v in (over or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = _deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def load_params(path=None):
    path = path or os.path.join(HERE, "params.json")
    try:
        with open(path) as fh:
            raw = json.load(fh)
        raw.pop("_comment", None)
        return _deep_merge(_DEFAULTS, raw)
    except Exception:
        return dict(_DEFAULTS)


# --------------------------------------------------------------------------- #
#  Small image helpers
# --------------------------------------------------------------------------- #
def to_rgba(img_or_path):
    img = Image.open(img_or_path) if isinstance(img_or_path, str) else img_or_path
    return np.asarray(img.convert("RGBA"), dtype=np.uint8).copy()


def luma(rgb):
    rgb = rgb.astype(np.float32)
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def content_mask(a, t):
    return a[:, :, 3] > t


def bbox_of(mask):
    if not mask.any():
        return None
    ys, xs = np.where(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def row_widths(mask, l, r, t, b):
    sub = mask[t:b, l:r]
    return sub.sum(axis=1)


def seeded_rng(seed, head_id, body_id):
    key = f"{head_id}.{body_id}.{seed}".encode()
    h = int(hashlib.sha256(key).hexdigest()[:8], 16)
    return np.random.default_rng(h)


# --------------------------------------------------------------------------- #
#  Palette + recolor
# --------------------------------------------------------------------------- #
def dominant_palette(a, t, k=10):
    """Return (rgb[k',3] float, weight[k']) of the content's dominant colours,
    sorted dark->light by luma."""
    m = content_mask(a, t)
    rgb = a[:, :, :3][m]
    if len(rgb) == 0:
        return np.array([[128, 128, 128]], np.float32), np.array([1.0])
    k = int(max(2, min(k, 16)))
    col = Image.fromarray(rgb.reshape(-1, 1, 3), "RGB")
    q = col.quantize(colors=k, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE)
    idx = np.asarray(q).reshape(-1)
    pal = np.asarray(q.getpalette()[: k * 3], np.float32).reshape(-1, 3)
    counts = np.bincount(idx, minlength=len(pal)).astype(np.float32)
    keep = counts > 0
    pal, counts = pal[keep], counts[keep]
    order = np.argsort(luma(pal))
    return pal[order], counts[order] / counts.sum()


def hue_rotate(pal, deg):
    if abs(deg) < 1e-3:
        return pal
    p = Image.fromarray(pal.reshape(-1, 1, 3).astype(np.uint8), "RGB").convert("HSV")
    hsv = np.asarray(p, np.int16)
    hsv[..., 0] = (hsv[..., 0] + int(deg / 360.0 * 255)) % 256
    out = Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB")
    return np.asarray(out, np.float32).reshape(-1, 3)


def recolor_body_to_head(body_a, head_pal, t, strength):
    """Keep the BODY's luminance (shading & shape) but adopt the HEAD palette's
    colour identity, ranked by lightness. Blended toward original by `strength`.
    """
    out = body_a.copy()
    m = content_mask(body_a, t)
    if not m.any():
        return out
    brgb = body_a[:, :, :3][m].astype(np.float32)
    Lb = luma(brgb)
    lo, hi = np.percentile(Lb, 2), np.percentile(Lb, 98)
    p = np.clip((Lb - lo) / max(1.0, hi - lo), 0.0, 1.0)        # lightness rank
    # head ramp indexed by rank
    pal_l = luma(head_pal)
    pal_lo, pal_hi = pal_l.min(), pal_l.max()
    pos = p * (len(head_pal) - 1)
    i0 = np.floor(pos).astype(int)
    i1 = np.clip(i0 + 1, 0, len(head_pal) - 1)
    frac = (pos - i0)[:, None]
    target = head_pal[i0] * (1 - frac) + head_pal[i1] * frac      # head colour at rank
    # rescale target to the body pixel's own luma -> preserves shading exactly
    tl = np.clip(luma(target), 1.0, None)
    scaled = np.clip(target * (Lb / tl)[:, None], 0, 255)
    new = brgb * (1 - strength) + scaled * strength
    out[:, :, :3][m] = np.clip(new, 0, 255).astype(np.uint8)
    return out


# --------------------------------------------------------------------------- #
#  Head segmentation + placement
# --------------------------------------------------------------------------- #
def detect_head_box(a, t, P):
    """Bounding box (l,t,r,b) of a sprite's HEAD region via neck-pinch detection
    with a top-fraction fallback. Used both to crop the head parent's head and to
    decide where on the body that head should sit (covering the body's own head)."""
    m = content_mask(a, t)
    bb = bbox_of(m)
    if bb is None:
        return None
    l, tp, r, b = bb
    H = b - tp
    rw = row_widths(m, l, r, tp, b).astype(np.float32)
    if rw.max() <= 0:
        return None
    limit = int(H * P["head"]["max_top_fraction"])
    seg = rw[:limit] if limit > 2 else rw
    peak_i = int(np.argmax(seg)) if len(seg) else 0
    peak_w = seg[peak_i] if len(seg) else rw.max()
    neck = None
    thresh = peak_w * P["head"]["neck_width_ratio"]
    for i in range(peak_i + 1, len(rw)):
        if rw[i] < thresh:
            below = rw[i: min(len(rw), i + max(4, H // 12))]
            if below.size and below.max() > rw[i] * 1.12:
                neck = i
                break
    head_h = neck if neck else int(H * P["head"]["fallback_fraction"])
    head_h = max(int(H * 0.22), min(head_h, int(H * P["head"]["max_top_fraction"])))
    band = m[tp: tp + head_h, :]
    cols = np.where(band.any(axis=0))[0]
    if len(cols) == 0:
        return None
    return int(cols.min()), tp, int(cols.max()) + 1, tp + head_h


def head_crop(head_a, t, P):
    """Crop the head parent's HEAD region (RGBA array)."""
    box = detect_head_box(head_a, t, P)
    if box is None:
        return None
    hl, tp, hr, hb = box
    return head_a[tp:hb, hl:hr].copy()


def alpha_over(dst, src, x, y, t):
    """Composite RGBA src onto RGBA dst at (x,y) with straight-alpha over."""
    H, W = dst.shape[:2]
    sh, sw = src.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(W, x + sw), min(H, y + sh)
    if x0 >= x1 or y0 >= y1:
        return dst
    sx0, sy0 = x0 - x, y0 - y
    s = src[sy0: sy0 + (y1 - y0), sx0: sx0 + (x1 - x0)].astype(np.float32)
    d = dst[y0:y1, x0:x1].astype(np.float32)
    sa = (s[:, :, 3:4] / 255.0)
    da = (d[:, :, 3:4] / 255.0)
    oa = sa + da * (1 - sa)
    rgb = (s[:, :, :3] * sa + d[:, :, :3] * da * (1 - sa)) / np.clip(oa, 1e-6, None)
    dst[y0:y1, x0:x1, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    dst[y0:y1, x0:x1, 3] = np.clip(oa[:, :, 0] * 255, 0, 255).astype(np.uint8)
    return dst


def place_head_on_body(body_a, head_rgba, t, P, rng):
    """Sit the head parent's head over the body's OWN head region, sized to cover
    it. Both are in the head palette now, so they read as one creature."""
    if head_rgba is None:
        return body_a
    m = content_mask(body_a, t)
    bb = bbox_of(m)
    if bb is None:
        return body_a
    box = detect_head_box(body_a, t, P)
    if box is None:
        bl, bt, br, bbo = bb
        box = (bl, bt, br, int(bt + 0.40 * (bbo - bt)))
    bl2, bt2, br2, bb2 = box
    box_w, box_h, cx = br2 - bl2, bb2 - bt2, (bl2 + br2) // 2
    cover = P["head"]["width_ratio_on_body"] + float(rng.uniform(-1, 1)) * P["head"]["width_ratio_jitter"]
    target_w = max(10, int(box_w * cover))
    sh, sw = head_rgba.shape[:2]
    scale = target_w / max(1, sw)
    target_h = max(10, int(sh * scale))
    body_h = bb[3] - bb[1]
    if target_h > 0.62 * body_h:                       # keep head from dwarfing body
        k = (0.62 * body_h) / target_h
        target_w = max(10, int(target_w * k)); target_h = max(10, int(target_h * k))
    head_img = Image.fromarray(head_rgba, "RGBA").resize((target_w, target_h), Image.LANCZOS)
    head_rs = np.asarray(head_img, np.uint8).copy()
    overlap = int(box_h * P["head"]["vertical_overlap"])
    x = int(cx - target_w / 2)
    y = int(bb2 - target_h + overlap)         # chin aligned to body head's base
    out = body_a.copy()
    return alpha_over(out, head_rs, x, y, t)


# --------------------------------------------------------------------------- #
#  Finishing: outline unify + posterize + clean alpha
# --------------------------------------------------------------------------- #
def clean_alpha(a, t):
    a = a.copy()
    soft = a[:, :, 3] <= t
    a[soft] = 0
    a[~soft, 3] = 255
    return a


def keep_main_component(a, t):
    """Drop disconnected floating islands: keep only the alpha component connected to
    the body's main mass. This removes the worst compositor failure -- a mis-detected
    head crop pasted off the silhouette as a free-floating chunk (the 'scramble')."""
    from collections import deque
    m = a[:, :, 3] > t
    if not m.any():
        return a
    H, W = m.shape
    col_counts = m.sum(0)
    cx = int(np.argmax(col_counts))                  # densest column = body core
    rows = np.where(m[:, cx])[0]
    if len(rows):
        cy = int(rows[len(rows) // 2])               # mid of the body column
    else:
        ys, xs = np.where(m); cy, cx = int(ys.mean()), int(xs.mean())
    seen = np.zeros_like(m)
    dq = deque([(cy, cx)]); seen[cy, cx] = True
    while dq:
        y, x = dq.popleft()
        for ny, nx in ((y-1, x), (y+1, x), (y, x-1), (y, x+1)):
            if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; dq.append((ny, nx))
    drop = m & ~seen
    if drop.any():
        a = a.copy(); a[drop, 3] = 0
    return a


def add_outline(a, target_luma, thickness=1):
    m = a[:, :, 3] > 0
    if not m.any():
        return a
    ring = np.zeros_like(m)
    for _ in range(max(1, thickness)):
        up = np.zeros_like(m); up[1:, :] = m[:-1, :]
        dn = np.zeros_like(m); dn[:-1, :] = m[1:, :]
        lf = np.zeros_like(m); lf[:, 1:] = m[:, :-1]
        rt = np.zeros_like(m); rt[:, :-1] = m[:, 1:]
        dil = m | up | dn | lf | rt
        ring |= dil & ~m
        m = dil
    out = a.copy()
    # darken existing outermost interior edge toward target luma (keeps hue)
    interior_edge = np.zeros_like(ring)
    mm = a[:, :, 3] > 0
    up = np.zeros_like(mm); up[1:, :] = ~mm[:-1, :]
    dn = np.zeros_like(mm); dn[:-1, :] = ~mm[1:, :]
    lf = np.zeros_like(mm); lf[:, 1:] = ~mm[:, :-1]
    rt = np.zeros_like(mm); rt[:, :-1] = ~mm[:, 1:]
    interior_edge = mm & (up | dn | lf | rt)
    rgb = out[:, :, :3].astype(np.float32)
    L = np.clip(luma(rgb), 1.0, None)
    factor = np.clip(target_luma / L, 0.0, 1.0)[:, :, None]
    ie = interior_edge[:, :, None]
    out[:, :, :3] = np.where(ie, np.clip(rgb * factor, 0, 255), rgb).astype(np.uint8)
    return out


def posterize(a, colors):
    m = a[:, :, 3] > 0
    if not m.any():
        return a
    rgb = a[:, :, :3]
    flat = rgb[m].reshape(-1, 1, 3)
    q = Image.fromarray(flat, "RGB").quantize(colors=int(max(4, colors)),
            method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).convert("RGB")
    out = a.copy()
    out[:, :, :3][m] = np.asarray(q, np.uint8).reshape(-1, 3)
    return out


# --------------------------------------------------------------------------- #
#  Top-level
# --------------------------------------------------------------------------- #
def compose(head_a, body_a, head_id="?", body_id="?", seed=0, params=None):
    P = params or load_params()
    t = P["alpha_threshold"]
    C = P["canvas"]
    rng = seeded_rng(seed, head_id, body_id)

    # SELF-FUSION (head == body): there is nothing to graft on -- a self-fusion is
    # just the species itself, refined. Skip the recolor + head-cap and keep the
    # body sprite as-is; the finishing pass below gives it the clean, unified
    # limited-palette look so it matches the rest of the corpus.
    if str(head_id) == str(body_id):
        fused = body_a.copy()
    else:
        # 1. recolor body toward head palette (body keeps shading/shape)
        k = int(P["recolor"]["head_palette_k"])
        head_pal, _ = dominant_palette(head_a, t, k)
        hue_j = float(rng.uniform(-1, 1)) * P["recolor"]["hue_rotate_deg_jitter"]
        head_pal = hue_rotate(head_pal, hue_j)
        strength = float(np.clip(P["recolor"]["strength"]
                         + float(rng.uniform(-1, 1)) * P["recolor"]["strength_jitter"], 0.4, 0.95))
        fused = recolor_body_to_head(body_a, head_pal, t, strength)

        # 2. cap the head parent's head on top (native head colours)
        hc = head_crop(head_a, t, P)
        fused = place_head_on_body(fused, hc, t, P, rng)

    # 3. finishing
    fused = clean_alpha(fused, t)
    fused = keep_main_component(fused, t)
    pj = int(round(float(rng.uniform(-1, 1)) * P["palette"]["posterize_jitter"]))
    fused = posterize(fused, P["palette"]["posterize_colors"] + pj)
    if P["outline"]["enabled"]:
        fused = add_outline(fused, P["outline"]["target_luma"], P["outline"]["thickness"])

    # 4. fit to canvas (sprites are already 288; guard odd sizes)
    if fused.shape[0] != C or fused.shape[1] != C:
        canvas = np.zeros((C, C, 4), np.uint8)
        m = content_mask(fused, t)
        bb = bbox_of(m)
        if bb:
            l, tp, r, b = bb
            crop = fused[tp:b, l:r]
            ch, cw = crop.shape[:2]
            s = min((C - 16) / cw, (C - 16) / ch, 1.0)
            nw, nh = max(1, int(cw * s)), max(1, int(ch * s))
            crop = np.asarray(Image.fromarray(crop, "RGBA").resize((nw, nh), Image.LANCZOS))
            ox, oy = (C - nw) // 2, int(C * 0.79) - nh
            canvas = alpha_over(canvas, crop, ox, max(0, oy), t)
        fused = canvas
    return fused


def find_base_sprite(species_id, roots):
    sid = str(species_id)
    for root in roots:
        for cand in (os.path.join(root, "Graphics", "BaseSprites", f"{sid}.png"),
                     os.path.join(root, "Graphics", "Battlers", sid, f"{sid}.png"),
                     os.path.join(root, "BaseSprites", f"{sid}.png"),
                     os.path.join(root, f"{sid}.png")):
            if os.path.isfile(cand):
                return cand
    return None


def generate_fusion(head_id, body_id, seed=0, base_roots=None, params=None):
    """Return a PIL RGBA Image (CANVAS x CANVAS) or None if a parent is missing."""
    base_roots = base_roots or [os.getcwd()]
    hp = find_base_sprite(head_id, base_roots)
    bp = find_base_sprite(body_id, base_roots)
    if not hp or not bp:
        return None
    head_a, body_a = to_rgba(hp), to_rgba(bp)
    arr = compose(head_a, body_a, head_id, body_id, seed, params)
    return Image.fromarray(arr, "RGBA")


def generate_triple(s1, s2, s3, seed=0, base_roots=None, params=None):
    """Triple fusion of three species. Convention (matching Infinite Fusion's own
    triples, which are named s1.s2.s3): s1 = head, s2 = body/shape, s3 = the third
    contributor of colour identity. Returns a PIL RGBA Image or None if any of the
    three base sprites is missing."""
    base_roots = base_roots or [os.getcwd()]
    p1 = find_base_sprite(s1, base_roots)
    p2 = find_base_sprite(s2, base_roots)
    p3 = find_base_sprite(s3, base_roots)
    if not p1 or not p2 or not p3:
        return None
    P = params or load_params()
    t = P["alpha_threshold"]
    a_rgba, b_rgba, c_rgba = to_rgba(p1), to_rgba(p2), to_rgba(p3)

    # step 1: the s1(head) + s2(body) fusion provides shape and the head.
    inter = compose(a_rgba, b_rgba, s1, s2, seed, P)

    # step 2: fold in s3's colour identity at a softer strength so all three read.
    rng = seeded_rng(seed, f"{s1}.{s2}", s3)
    c_pal, _ = dominant_palette(c_rgba, t, int(P["recolor"]["head_palette_k"]))
    tj = float(rng.uniform(-1, 1)) * P["triple"]["third_strength_jitter"]
    third = float(np.clip(P["triple"]["third_strength"] + tj, 0.15, 0.6))
    blended = recolor_body_to_head(inter, c_pal, t, third)

    # step 3: re-unify the finish (clean alpha, limited palette, 1px outline).
    blended = clean_alpha(blended, t)
    blended = keep_main_component(blended, t)
    blended = posterize(blended, P["palette"]["posterize_colors"])
    if P["outline"]["enabled"]:
        blended = add_outline(blended, P["outline"]["target_luma"], P["outline"]["thickness"])
    return Image.fromarray(blended, "RGBA")


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "triple":
        s1, s2, s3 = sys.argv[2], sys.argv[3], sys.argv[4]
        seed = int(sys.argv[5]) if len(sys.argv) > 5 else 0
        roots = [sys.argv[6]] if len(sys.argv) > 6 else [os.getcwd()]
        img = generate_triple(s1, s2, s3, seed, roots)
        if img is None:
            print("missing parent sprite"); sys.exit(1)
        out = f"triple_{s1}.{s2}.{s3}_{seed}.png"
        img.save(out); print("wrote", out)
    else:
        h, b = sys.argv[1], sys.argv[2]
        seed = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        roots = [sys.argv[4]] if len(sys.argv) > 4 else [os.getcwd()]
        img = generate_fusion(h, b, seed, roots)
        if img is None:
            print("missing parent sprite"); sys.exit(1)
        out = f"fusion_{h}.{b}_{seed}.png"
        img.save(out); print("wrote", out)
