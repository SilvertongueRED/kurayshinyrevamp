#!/usr/bin/env python3
"""convert_pif_pack.py - Convert a PIF sprite pack into KIF/NPT fork numbering.

* Identity for any head/body id <= 552 and all base mons (no rename).
* Divergent ids 553-572 remapped per the species-keyed crosswalk below.
* PIF sprite takes the MAIN slot (H.B.png); an existing AFI/KIF sprite for the
  same fork fusion is demoted to the next free alt letter. Byte-identical files
  are skipped (dedup).
* Optional SPAK v2 repack into <forkhead>.pak (handled by 990_NPT/009_SpritePacks.rb).

Usage:
  python3 convert_pif_pack.py --pack PIF/CustomBattlers [--base PIF/Other/BaseSprites] \
      --out <install>/Graphics/CustomBattlers/indexed [--pak] [--only-affected] [--dry-run]
"""
import os, re, argparse, struct, hashlib, shutil
from collections import defaultdict

PIF_TO_FORK = {553:1038,554:1039,555:1040,556:553,557:581,558:554,559:555,560:556,561:557,
               562:558,563:559,564:560,565:561,566:1109,567:1110,568:687,569:688,570:689,
               571:737,572:738}
def p2f(i): return PIF_TO_FORK.get(i, i)
AFFECTED = set(range(553, 573))
FUSION = re.compile(r'^(\d+)\.(\d+)([a-z]?)\.png$')
BASE   = re.compile(r'^(\d+)([a-z]?)\.png$')

def md5(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for c in iter(lambda: f.read(1 << 16), b''):
            h.update(c)
    return h.hexdigest()

def next_letter(used):
    for i in range(26):
        c = chr(ord('a') + i)
        if c not in used:
            return c
    return 'z'

def write_spak(head_folder, pak_path):
    entries = []
    for fn in sorted(os.listdir(head_folder)):
        if not fn.endswith('.png'):
            continue
        m = FUSION.match(fn)
        if m:
            body = int(m.group(2)); altc = m.group(3)
        else:
            mb = BASE.match(fn)
            if not mb:
                continue
            body = 0; altc = mb.group(2)
        alt_index = 0 if altc == '' else (ord(altc) - ord('a') + 1)
        with open(os.path.join(head_folder, fn), 'rb') as f:
            entries.append((body, alt_index, f.read()))
    with open(pak_path, 'wb') as out:
        out.write(b'SPAK')
        out.write(struct.pack('<I', len(entries)))
        offset = 0
        for body, alt_index, data in entries:
            out.write(struct.pack('<IIII', body, alt_index, offset, len(data)))
            offset += len(data)
        for _, _, data in entries:
            out.write(data)

def process_tree(pack_dir, is_base, out_root, only_affected, dry, stats, samples):
    if not pack_dir or not os.path.isdir(pack_dir):
        return
    for fn in os.listdir(pack_dir):
        if is_base:
            m = BASE.match(fn)
            if not m:
                stats['nonsprite_skipped'] += 1; continue
            h = int(m.group(1)); alt = m.group(2)
            touches = h in AFFECTED
            target = "%d%s.png" % (p2f(h), alt)
            hf = p2f(h)
        else:
            m = FUSION.match(fn)
            if not m:
                stats['nonsprite_skipped'] += 1; continue
            h, b, alt = int(m.group(1)), int(m.group(2)), m.group(3)
            touches = (h in AFFECTED) or (b in AFFECTED)
            hf, bf = p2f(h), p2f(b)
            target = "%d.%d%s.png" % (hf, bf, alt)
        if only_affected and not touches:
            stats['identity_untouched'] += 1; continue
        stats['remapped' if touches else 'identity_copied'] += 1
        if touches and len(samples) < 20:
            samples.append((fn, target))
        if dry:
            continue
        dst_folder = os.path.join(out_root, str(hf))
        os.makedirs(dst_folder, exist_ok=True)
        src = os.path.join(pack_dir, fn)
        dst_main = os.path.join(dst_folder, target)
        if alt == '':
            if os.path.exists(dst_main):
                if md5(dst_main) == md5(src):
                    stats['dedup_skipped'] += 1; continue
                used = set()
                for fn2 in os.listdir(dst_folder):
                    mm = FUSION.match(fn2) or BASE.match(fn2)
                    if mm and mm.groups()[-1]:
                        used.add(mm.groups()[-1])
                shutil.move(dst_main, os.path.join(dst_folder, target[:-4] + next_letter(used) + '.png'))
                stats['afi_demoted_to_alt'] += 1
            shutil.copy2(src, dst_main); stats['written'] += 1
        else:
            if os.path.exists(dst_main) and md5(dst_main) == md5(src):
                stats['dedup_skipped'] += 1; continue
            shutil.copy2(src, dst_main); stats['written'] += 1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--pack', required=True)
    ap.add_argument('--base')
    ap.add_argument('--out', required=True)
    ap.add_argument('--only-affected', action='store_true')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--pak', action='store_true')
    a = ap.parse_args()
    stats = defaultdict(int); samples = []
    if not a.dry_run:
        os.makedirs(a.out, exist_ok=True)
    process_tree(a.pack, False, a.out, a.only_affected, a.dry_run, stats, samples)
    if a.base:
        process_tree(a.base, True, a.out, a.only_affected, a.dry_run, stats, samples)
    if a.pak and not a.dry_run:
        for head in os.listdir(a.out):
            hp = os.path.join(a.out, head)
            if os.path.isdir(hp):
                write_spak(hp, os.path.join(a.out, head + '.pak'))
                stats['pak_built'] += 1
    print("=== PIF -> fork conversion ===")
    for k in sorted(stats):
        print("  %s: %d" % (k, stats[k]))
    print("Sample remaps (PIF -> fork):")
    for o, t in samples:
        print("  %14s  ->  %s" % (o, t))

if __name__ == '__main__':
    main()
