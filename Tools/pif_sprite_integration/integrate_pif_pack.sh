#!/usr/bin/env bash
# integrate_pif_pack.sh - integrate a PIF sprite pack (monthly or Full) into one
# or more KIF-fork installs, remapping PIF dex ids to fork/NPT ids on the way in.
#
# Usage:
#   integrate_pif_pack.sh <pack.zip | pack_dir> <install_dir> [install_dir ...]
#
# A "pack_dir" must contain CustomBattlers/ (and optionally Other/BaseSprites/).
# Each install_dir is a game root (the folder containing Graphics/).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$1"; shift
WORK=""
if [[ "$SRC" == *.zip ]]; then
  WORK="$(mktemp -d)"; echo "Extracting $SRC ..."; unzip -q "$SRC" -d "$WORK"; SRC="$WORK"
fi
# locate CustomBattlers / BaseSprites within the pack
PACK_CB="$(find "$SRC" -type d -iname CustomBattlers | head -1)"
PACK_BS="$(find "$SRC" -type d -iname BaseSprites | head -1)"
[[ -z "$PACK_CB" ]] && { echo "ERROR: no CustomBattlers/ found in pack"; exit 1; }
echo "Pack CustomBattlers: $PACK_CB"
echo "Pack BaseSprites:    ${PACK_BS:-<none>}"
for INSTALL in "$@"; do
  DST="$INSTALL/Graphics/CustomBattlers/indexed"
  echo "=== Integrating into: $INSTALL ==="
  python3 "$HERE/convert_pif_pack.py" --pack "$PACK_CB" ${PACK_BS:+--base "$PACK_BS"} --out "$DST" --pak
done
[[ -n "$WORK" ]] && rm -rf "$WORK"
echo "Done."
