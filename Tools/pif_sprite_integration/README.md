# PIF Sprite Integration (KIF fork)

Makes official **Pokémon Infinite Fusion** sprite packs (monthly + Full) drop into
this fork cleanly, keeping **both** PIF and AFI/KIF art (PIF as the main sprite,
AFI as a selectable in-Pokédex alt — nothing is lost), and auto-extends as PIF
ships new months.

## The problem it solves
PIF/PIF-Hoenn renumbered dex **502–572**. The fork's NPT ids are **identical for
502–552**, then diverge at **553** (PIF spends 4 dex slots on Castform's weather
forms; the fork spends one, then ordering differs). So a raw PIF pack lands sprites
on the wrong species for ~20 ids unless they're translated.

## What ships
* `Data/Scripts/990_NPT/020_PIFRemap.rb` — in-engine canonical PIF⇄fork id map (data-only, MP-safe).
* `Data/Scripts/990_NPT/021_PIFGapSpecies.rb` — registers **Noibat (1109)** and **Noivern (1110)**, which PIF has (566/567) but the fork was missing. `NPTVersion` is intentionally **not** bumped (keeps official-server MP compatibility).
* `Tools/pif_sprite_integration/convert_pif_pack.py` — the converter/repacker.
* `Tools/pif_sprite_integration/integrate_pif_pack.sh` — one-shot wrapper for one or more installs.
* `pif_npt_map.json`, `PIF_to_NPT_crosswalk.csv` — the mapping (human + machine).

## The mapping (divergent ids only; everything else is identity)
| PIF | species | → fork | | PIF | species | → fork |
|--:|---|--:|---|--:|---|--:|
| 553 | Castform (Sunny) | 1038 | | 562 | Clamperl | 558 |
| 554 | Castform (Rainy) | 1039 | | 563 | Huntail | 559 |
| 555 | Castform (Snowy) | 1040 | | 564 | Gorebyss | 560 |
| 556 | Tropius | 553 | | 565 | Relicanth | 561 |
| 557 | Chingling | 581 | | 566 | **Noibat** | **1109** (new) |
| 558 | Chimecho | 554 | | 567 | **Noivern** | **1110** (new) |
| 559 | Spheal | 555 | | 568 | Tynamo | 687 |
| 560 | Sealeo | 556 | | 569 | Eelektrik | 688 |
| 561 | Walrein | 557 | | 570 | Eelektross | 689 |
|  |  |  | | 571 / 572 | Skrelp / Dragalge | 737 / 738 |

## Integrate a pack
```bash
# Monthly delta or the Full pack — one command per install:
Tools/pif_sprite_integration/integrate_pif_pack.sh  Sprite_Pack_125_April_2026.zip \
    "<game root>"        # e.g. the Steam install, the local copy, each Testing install
```
The converter:
* leaves 502–552 + all base ids untouched (identity),
* remaps the divergent ids per the table,
* restructures flat `H.B.png` into the fork's `CustomBattlers/indexed/<head>/` layout,
* puts the PIF sprite in the **main** slot and bumps any existing AFI sprite to the next free **alt** letter (skips byte-identical files),
* writes `<head>.pak` SPAK-v2 bundles the game already knows how to read.

Run it again next month on the new pack; it's idempotent and only touches what changed.

## Monthly cadence
* **Monthly delta:** Discord `#downloads` `Sprite_Pack_<NNN>_<Month>_<Year>.zip` (the number/name increments each month) → run the wrapper.
* **Full pack (periodic):** the Drive "Full" link → run the wrapper to pick up fixes/updates the install hasn't integrated yet.

When PIF adds **new** species in a future month, add the new `PIF id → fork id`
pair to `020_PIFRemap.rb` and `convert_pif_pack.py` (and register the species like
Noibat/Noivern in `021_*` if the fork lacks it). Everything else keeps working.

## Notes
* Multiplayer: changes are client-side/additive; `NPTVersion` unchanged ⇒ official KIFM server still matches.
* Rollback: delete `020_*`/`021_*` and restore the install's `CustomBattlers` from backup.

## Integration status (2026-06-14)
* Runtime scripts `020_PIFRemap.rb` + `021_PIFGapSpecies.rb` are installed in: repo, local full install, Testing 1, Testing 2.
* **Divergent species (the 20 ids 553-572 that differ) integrated** into the local full install + both Testing installs via `merge_divergent_heads.py`: PIF art is the main sprite for each as a fusion *head* (+ base sprite), with the existing AFI sprite preserved as a `z` alt. Verified (e.g. fork 553 base = PIF Tropius; 2,702 fusions + 320 AFI alts + 20 base per install).
* **Still to do for full parity (body-side + identity range):** run `integrate_pif_pack.sh <Full pack> "<install>"` locally to add PIF art for the divergent species as fusion *bodies* across all heads and (optionally) the identical 502-552 range. AFI already covers those correctly today, so this is additive, not a fix.
* Repo stays graphics-light (no sprites committed) — tooling only.

## UPDATE — Automatic in-game download is the default (all users)
The fork now ships `Data/Scripts/052_AddOns/PIFRemapDownload.rb`, which hooks PIF's
own on-demand sprite auto-downloader. When a missing custom sprite involves a
divergent id (553-572 / Castform forms / Noibat-Noivern), it fetches the
PIF-numbered sprite from the live repo (`CUSTOM_SPRITES_REPO_URL`) and saves it
under the correct **fork** filename — so every user automatically gets current,
correctly-numbered PIF art with zero manual steps and zero packs.

- Rides the existing **Options → "Download data"** setting, plus a new
  **Options → "PIF Sprite Auto-Fix"** toggle (On by default; turn Off to keep
  only bundled/AFI art).
- Identity ids (≤552) and fork-only species are unaffected.
- New sprites arrive automatically as you encounter fusions. (Like PIF, a *fix to
  a sprite already on disk* isn't re-fetched in-game; re-download it by deleting
  the file, or do an occasional manual Full-pack pass with `integrate_pif_pack.sh`.)

The earlier Cowork "monthly drop-folder" scheduled task has been removed — the
in-game feature replaces it. The scripts in this folder remain as **optional**
tools for bulk one-time pre-seeding or a Full-pack refresh.

### Refresh (picks up upstream fixes)
- **Options → "Refresh PIF Sprites"** re-downloads your party's Hoenn+ sprites on demand.
- The same party refresh runs **automatically ~every 2 months** (tracked in `Data/sprites/pif_last_refresh.txt`), so upstream sprite fixes propagate with no input. Both are bounded to the party (fast, rate-limit friendly); for a full bulk refresh use `integrate_pif_pack.sh` with the Full pack.
