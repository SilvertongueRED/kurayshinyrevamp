#!/usr/bin/env bash
# monthly_integrate.sh <drop_folder> <install_root> [install_root ...]
# Additively integrates every *.zip / pack folder in <drop_folder> into each
# install, then moves processed zips to <drop_folder>/done/.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DROP="$1"; shift
INSTALLS=("$@")
shopt -s nullglob
mkdir -p "$DROP/done"
found=0
for item in "$DROP"/*.zip "$DROP"/*/; do
  [ -e "$item" ] || continue
  base="$(basename "$item")"
  [ "$base" = "done" ] && continue
  src="$item"; tmp=""
  if [[ "$item" == *.zip ]]; then
    tmp="$(mktemp -d)"; unzip -q "$item" -d "$tmp"; src="$tmp"
  fi
  CB="$(find "$src" -type d -iname CustomBattlers | head -1)"
  BS="$(find "$src" -type d -iname BaseSprites | head -1)"
  [ -z "$CB" ] && { echo "skip $base (no CustomBattlers)"; [ -n "$tmp" ] && rm -rf "$tmp"; continue; }
  found=1
  echo "=== integrating $base ==="
  for INST in "${INSTALLS[@]}"; do
    python3 "$HERE/add_pif_pack.py" "$CB" "${BS:--}" "$INST"
  done
  [ -n "$tmp" ] && rm -rf "$tmp"
  [[ "$item" == *.zip ]] && mv "$item" "$DROP/done/" 2>/dev/null
done
[ "$found" = 0 ] && echo "No new packs found in $DROP"
