#!/usr/bin/env python3
"""Build a paired training set from the human custom-sprite corpus.

Every custom CustomBattlers/<head>.<body>[letter].png is, by name, a fusion of
two base sprites we can locate. For each one we emit:

  target/<name>.png  - the HUMAN custom, flattened on white, resized (the goal)
  cond/<name>.png    - OUR compositor's fusion for the SAME pair (the start point)
  metadata.jsonl     - {"file_name": "target/..png", "text": <caption>,
                        "conditioning_image": "cond/..png"}

This gives a clean composite -> human-custom mapping: the strongest possible
supervision for teaching a diffusion model to refine our compositor output into
human-custom quality. The same files drive either a text->image LoRA (use cond/
as the img2img init at inference) or a ControlNet / InstructPix2Pix model (use
cond/ as the conditioning_image directly).

--base-dir ALSO adds every base sprite (<id>[letter].png) as a single-species
target (cond = the compositor's own rendering of that sprite). The PIF fusion
corpus only covers a limited species range; feeding in the game's full
BaseSprites set teaches the model EVERY species so out-of-PIF fusions render
their real features instead of guesses.

Usage:
  python prepare_dataset.py \
      --corpus  ".../PIF.../CustomBattlers" \
      --base-roots ".../kurayshinyrevamp"  ".../PIF.../Other" \
      --base-dir ".../Kuray Infinite Fusion/Graphics/BaseSprites" \
      --out ../dataset --size 512 --limit 0 --val-split 0.02
"""
import os, re, sys, json, argparse, random

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))           # the package dir (compositor.py, tlog.py)
import compositor as COMP
from PIL import Image
try:
    import tlog
except Exception:
    tlog = None

NAME_RE = re.compile(r"^(\d+)\.(\d+)([a-z]?)\.png$", re.I)
BASE_RE = re.compile(r"^(\d+)([a-z]?)\.png$", re.I)
TRIPLE_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)([a-z]?)\.png$", re.I)

# This style prefix is the model's trigger phrase: it is attached to EVERY target
# so the LoRA binds these clean-pixel-art principles to the look of the human
# customs. Keep it identical to neural.json's `prompt` prefix so inference matches
# training. The descriptors below are the IF/KIF spritework conventions: a single
# readable creature, one crisp dark outline, flat cel shading over a tight palette,
# and NO anti-aliasing / dithering / background.
_STYLE = ("infinite fusion pokemon battle sprite, 2d pixel art, clean 1-pixel black "
          "outline, flat cel shading, limited palette, crisp hard edges, no "
          "anti-aliasing, no dithering, single creature centered on a plain white "
          "background, front three-quarter view")


def load_species_meta(path):
    if path and os.path.isfile(path):
        try:
            return json.load(open(path, encoding="utf-8"))
        except Exception as e:
            print(f"[prepare] species meta load failed ({e}); using id tokens")
    return {}


def _types(*ms):
    types = []
    for m in ms:
        if m:
            for t in (m.get("type1"), m.get("type2")):
                if t and t not in types:
                    types.append(str(t).lower())
    return (", " + " ".join(f"{t} type" for t in types)) if types else ""


def caption(head, body, meta):
    h, b = str(head), str(body)
    # SELF-FUSION: head == body. The corpus has these too (e.g. 25.25); teach them
    # as "a single species, refined" with a distinct self:s<id> token so the model
    # does not try to graft a second head on.
    if h == b:
        m = meta.get(h)
        nm = (m or {}).get("name", f"species {h}")
        return f"{_STYLE}, self-fusion of {nm}, single clean species sprite{_types(m)}, " \
               f"self:s{h} head:h{h} body:b{b}"
    hm, bm = meta.get(h), meta.get(b)
    if hm or bm:
        hn = (hm or {}).get("name", f"species {h}")
        bn = (bm or {}).get("name", f"species {b}")
        return f"{_STYLE}, {hn} head fused onto {bn} body{_types(hm, bm)}, head:h{h} body:b{b}"
    return f"{_STYLE}, fusion with head:h{h} body:b{b}"


def triple_caption(s1, s2, s3, meta):
    """Caption for a three-species triple fusion (head s1, body s2, third s3)."""
    a, b, c = str(s1), str(s2), str(s3)
    ms = [meta.get(a), meta.get(b), meta.get(c)]
    if any(ms):
        names = [(ms[i] or {}).get("name", f"species {x}") for i, x in enumerate((a, b, c))]
        return f"{_STYLE}, triple fusion of {names[0]}, {names[1]} and {names[2]}" \
               f"{_types(*ms)}, head:h{a} body:b{b} third:t{c}"
    return f"{_STYLE}, triple fusion, head:h{a} body:b{b} third:t{c}"


def base_caption(num_id, meta):
    """Caption for a single (non-fused) base sprite. Uses the SAME h<id>/b<id>
    token convention so the species identity learned here transfers to fusions."""
    m = meta.get(str(num_id))
    if m:
        nm = m.get("name", f"species {num_id}")
        return f"{_STYLE}, {nm}{_types(m)}, single clean species sprite, " \
               f"self:s{num_id} head:h{num_id} body:b{num_id}"
    return f"{_STYLE}, single clean species sprite, self:s{num_id} " \
           f"head:h{num_id} body:b{num_id}"


def flatten_white(img, size):
    img = img.convert("RGBA")
    bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
    bg.alpha_composite(img)
    return bg.convert("RGB").resize((size, size), Image.NEAREST)


def _collect_base_files(base_dirs):
    """Return [(stem, numeric_id, path)] across base dirs, deduped by stem."""
    out, seen = [], set()
    for d in base_dirs:
        if not os.path.isdir(d):
            print(f"[prepare] WARNING base-dir missing: {d!r}")
            continue
        for f in sorted(os.listdir(d)):
            m = BASE_RE.match(f)
            if not m:
                continue
            stem = f[:-4]                     # e.g. "100" or "100a"
            if stem in seen:
                continue
            seen.add(stem)
            out.append((stem, m.group(1), os.path.join(d, f)))
    return out


def _collect_triple_files(triple_dirs):
    """Return [(stem, s1, s2, s3, path)] for every <s1>.<s2>.<s3>[letter].png in the
    given dirs (the game's hand-made triples in Graphics/Battlers/special/)."""
    out, seen = [], set()
    for d in triple_dirs:
        if not os.path.isdir(d):
            print(f"[prepare] WARNING triple-dir missing: {d!r}")
            continue
        for f in sorted(os.listdir(d)):
            m = TRIPLE_RE.match(f)
            if not m:
                continue
            stem = f[:-4]
            if stem in seen:
                continue
            seen.add(stem)
            out.append((stem, m.group(1), m.group(2), m.group(3), os.path.join(d, f)))
    return out


def run(args):
    meta = load_species_meta(args.species_json)
    params = COMP.load_params()
    if tlog:
        tlog.section("config")
    print(f"[prepare] corpus     : {args.corpus}")
    print(f"[prepare] base-roots : {args.base_roots}")
    print(f"[prepare] base-dir   : {args.base_dir or '(none)'}")
    print(f"[prepare] out        : {args.out}")
    print(f"[prepare] size={args.size} limit={args.limit or 'ALL'} base-limit="
          f"{args.base_limit or 'ALL'} val-split={args.val_split}")
    print(f"[prepare] species meta entries: {len(meta)}")

    if not os.path.isdir(args.corpus):
        raise FileNotFoundError(
            f"corpus dir does not exist: {args.corpus!r} -- check the CORPUS path in "
            "the .bat (it must point at the CustomBattlers folder).")
    for r in args.base_roots:
        if not os.path.isdir(r):
            print(f"[prepare] WARNING base-root missing: {r!r}")

    os.makedirs(os.path.join(args.out, "target"), exist_ok=True)
    os.makedirs(os.path.join(args.out, "cond"), exist_ok=True)

    all_files = os.listdir(args.corpus)
    files = [f for f in all_files if NAME_RE.match(f)]
    print(f"[prepare] {len(all_files)} entries in corpus, {len(files)} match <head>.<body>[x].png")
    if not files:
        raise RuntimeError("no files in the corpus matched the <head>.<body>[letter].png "
                           "naming -- is CORPUS pointing at the right folder?")
    random.seed(args.seed)
    random.shuffle(files)
    if args.limit:
        files = files[: args.limit]

    train_fh = open(os.path.join(args.out, "metadata.jsonl"), "w", encoding="utf-8")
    val_fh = open(os.path.join(args.out, "metadata_val.jsonl"), "w", encoding="utf-8")
    n_ok = n_skip = n_val = 0
    skip_missing = skip_unreadable = 0
    skip_examples = []

    def emit(rec):
        nonlocal n_val
        is_val = random.random() < args.val_split
        (val_fh if is_val else train_fh).write(json.dumps(rec) + "\n")
        n_val += int(is_val)

    # ---- 1. fusion pairs (compositor -> human custom) ----------------------
    for i, f in enumerate(files):
        m = NAME_RE.match(f)
        head, body = m.group(1), m.group(2)
        try:
            cond = COMP.generate_fusion(head, body, seed=0, base_roots=args.base_roots, params=params)
        except Exception as e:
            cond = None
            if len(skip_examples) < 12:
                skip_examples.append(f"{f}: compositor error {e!r}")
        if cond is None:
            n_skip += 1; skip_missing += 1
            if len(skip_examples) < 12:
                hp = COMP.find_base_sprite(head, args.base_roots)
                bp = COMP.find_base_sprite(body, args.base_roots)
                miss = "head" if not hp else ("body" if not bp else "?")
                skip_examples.append(f"{f}: missing base sprite ({miss}) head={head} body={body}")
            continue
        try:
            human = Image.open(os.path.join(args.corpus, f))
        except Exception as e:
            n_skip += 1; skip_unreadable += 1
            if len(skip_examples) < 12:
                skip_examples.append(f"{f}: unreadable custom ({e!r})")
            continue
        stem = f[:-4]
        tgt_rel, cnd_rel = f"target/{stem}.png", f"cond/{stem}.png"
        flatten_white(human, args.size).save(os.path.join(args.out, tgt_rel))
        flatten_white(cond, args.size).save(os.path.join(args.out, cnd_rel))
        emit({"file_name": tgt_rel, "text": caption(head, body, meta), "conditioning_image": cnd_rel})
        n_ok += 1
        if (i + 1) % 500 == 0:
            print(f"[prepare] fusions: {i+1} processed, {n_ok} written, {n_skip} skipped", flush=True)

    # ---- 2. base sprites as single-species targets (full species coverage) --
    n_base = n_base_skip = 0
    if args.base_dir:
        base_roots_for_cond = list(args.base_dir) + list(args.base_roots)
        base_files = _collect_base_files(args.base_dir)
        random.shuffle(base_files)
        if args.base_limit:
            base_files = base_files[: args.base_limit]
        print(f"[prepare] base sprites: {len(base_files)} unique <id>[x].png to add")
        for j, (stem, num_id, path) in enumerate(base_files):
            try:
                cond = COMP.generate_fusion(stem, stem, seed=0, base_roots=base_roots_for_cond, params=params)
                human = Image.open(path)
            except Exception as e:
                cond = None
                if len(skip_examples) < 24:
                    skip_examples.append(f"base {stem}: {e!r}")
            if cond is None:
                n_base_skip += 1
                continue
            tgt_rel, cnd_rel = f"target/base_{stem}.png", f"cond/base_{stem}.png"
            flatten_white(human, args.size).save(os.path.join(args.out, tgt_rel))
            flatten_white(cond, args.size).save(os.path.join(args.out, cnd_rel))
            emit({"file_name": tgt_rel, "text": base_caption(num_id, meta), "conditioning_image": cnd_rel})
            n_base += 1
            if (j + 1) % 500 == 0:
                print(f"[prepare] bases: {j+1} processed, {n_base} written", flush=True)

    # ---- 3. triple fusions (compositor triple -> hand-made special sprite) --
    n_trip = n_trip_skip = 0
    if args.triple_dir:
        triple_roots = list(args.base_roots) + list(args.base_dir or [])
        trip_files = _collect_triple_files(args.triple_dir)
        random.shuffle(trip_files)
        if args.triple_limit:
            trip_files = trip_files[: args.triple_limit]
        print(f"[prepare] triple sprites: {len(trip_files)} <s1>.<s2>.<s3>[x].png to add")
        for k, (stem, s1, s2, s3, path) in enumerate(trip_files):
            try:
                cond = COMP.generate_triple(s1, s2, s3, seed=0, base_roots=triple_roots, params=params)
                human = Image.open(path)
            except Exception as e:
                cond = None
                if len(skip_examples) < 36:
                    skip_examples.append(f"triple {stem}: {e!r}")
            if cond is None:
                n_trip_skip += 1
                continue
            tgt_rel, cnd_rel = f"target/triple_{stem}.png", f"cond/triple_{stem}.png"
            flatten_white(human, args.size).save(os.path.join(args.out, tgt_rel))
            flatten_white(cond, args.size).save(os.path.join(args.out, cnd_rel))
            emit({"file_name": tgt_rel, "text": triple_caption(s1, s2, s3, meta),
                  "conditioning_image": cnd_rel})
            n_trip += 1
            if (k + 1) % 100 == 0:
                print(f"[prepare] triples: {k+1} processed, {n_trip} written", flush=True)

    train_fh.close()
    val_fh.close()
    total = n_ok + n_base + n_trip
    print(f"[prepare] DONE: {total} pairs total = {n_ok} fusions + {n_base} base sprites "
          f"+ {n_trip} triples ({n_val} val). fusion-skipped {n_skip} (missing base="
          f"{skip_missing}, unreadable={skip_unreadable}), base-skipped {n_base_skip}, "
          f"triple-skipped {n_trip_skip} -> {args.out}")
    if skip_examples:
        if tlog:
            tlog.section("skip examples (first few)")
        print("[prepare] skip examples:")
        for s in skip_examples:
            print("   " + s)
    if total == 0:
        raise RuntimeError("0 pairs written. Most likely the base sprites can't be found "
                           "for any pair -- check --base-roots / --base-dir (they should "
                           "contain BaseSprites/<id>.png or Graphics/Battlers/<id>/<id>.png).")
    print(f"[prepare] caption samples:\n   fusion: {caption('25', '6', meta)}\n"
          f"   self:   {caption('25', '25', meta)}\n"
          f"   base:   {base_caption('25', meta)}\n"
          f"   triple: {triple_caption('144', '145', '146', meta)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True, help="CustomBattlers dir of human customs")
    ap.add_argument("--base-roots", nargs="+", required=True,
                    help="dirs containing base sprites (game root and/or pack Other/)")
    ap.add_argument("--base-dir", nargs="*", default=[],
                    help="dirs of base sprites <id>[x].png to ALSO add as single-species "
                         "targets (full species coverage beyond the fusion corpus)")
    ap.add_argument("--base-limit", type=int, default=0, help="0 = all base sprites")
    ap.add_argument("--triple-dir", nargs="*", default=[],
                    help="dirs of hand-made triple sprites <s1>.<s2>.<s3>[x].png "
                         "(Graphics/Battlers/special/) to add as triple training pairs")
    ap.add_argument("--triple-limit", type=int, default=0, help="0 = all triples")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(HERE), "dataset"))
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--limit", type=int, default=0, help="0 = all fusions")
    ap.add_argument("--val-split", type=float, default=0.02)
    ap.add_argument("--species-json", default=os.path.join(os.path.dirname(HERE), "species.json"))
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    run(args)


if __name__ == "__main__":
    if tlog:
        tlog.open_log("prepare_dataset")
        tlog.guarded(main, "prepare_dataset")
    else:
        main()
