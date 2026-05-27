# Kuray Infinite Fusion Full Current Tester Build

Latest refresh pushed to the existing public experimental release page on 2026-05-27.

## What this refresh is

This is the current experimental merged tester build from the live workspace behind this repo. It is a human-directed, AI-assisted KIF/PIF upgrade branch meant to help testers install the newest public-safe merged build, inspect the actual file changes on GitHub, and try the current mod stack in one place.

## Main warnings

- This is not a stable upstream release.
- It may break progression, conflict with future upstream updates, or corrupt saves.
- Saves live in `%APPDATA%\\kurayinfinitefusion`, not inside the install folder.
- `player_identity_bedroom`, current `custom_species_framework`, current travel-expansion compatibility work, modded multiplayer, and the experimental `zzz_gba_player` scaffold are included.

## What changed in the 2026-05-27 refresh

- Synced the current local gameplay/data/mod workspace into the public repo.
- Added the current `zzz_gba_player` experimental scaffold to the public package and repo.
- Added the current void-starter imported species content and TEF speech-bubble safety update.
- Refreshed the web installer, the update overlay, the portable fallback archive, and the packaged mod credits/checksum files.

## Included public content

- Current merged KIF/PIF gameplay and data changes from this workspace
- Current `custom_species_framework`
- Current `travel_expansion_framework`
- Imported void-starter species assets/data
- modded multiplayer files
- current packaged mod stack from this install
- `zzz_gba_player` scaffold with bundled public runtime files, including the curated `mGBA-0.10.5-win64` runtime and the native helper/core runtime files used by the bridge flow

## Intentionally excluded

- save files
- ROM files
- Discord/account-link files
- local cache, histories, logs, creator/importer state, and machine-specific runtime leftovers
- `Mods\\zzz_gba_player\\ROMs`
- `Mods\\zzz_gba_player\\Saves`
- `Mods\\zzz_gba_player\\mirror_runtime`
- `Mods\\zzz_gba_player\\launch.log`
- `Mods\\zzz_gba_player\\Emulator\\mGBA-0.10.5-win64\\qt.ini`
- `Mods\\zzz_gba_player\\native\\**\\bin`
- `Mods\\zzz_gba_player\\native\\**\\obj`

## Download paths

- One-click installer: `PIF-player-build-20260527-full-current-WebSetup.exe`
- Portable fallback: download all `PIF-player-build-20260527-full-current.7z.001` through `.007` assets from the same release page, then extract the `.001` file
- Update overlay archive: `PIF-player-build-20260527-full-current-update1.7z`

## Installer behavior

- `Install / Repair` is the main path for fresh installs or repairs.
- `Update Only` applies the embedded changed-file overlay without forcing the full base download when the target folder already contains the expected public install.
- The portable split archive is the fallback for testers who hit SmartScreen or antivirus friction with the installer.

## Credits

- The install writes `PACKAGED_MOD_CREDITS.txt` into the game folder and the same file is stored in this release folder.
- The packaged credits include the bundled mod authors, imported-species credits, and third-party runtime credit for the bundled mGBA runtime and GBA Player bridge/runtime files.
- The GBA Player scaffold is public-safe only: testers must add their own ROMs and saves locally after install.

## Files in this folder

- `PACKAGED_MOD_CREDITS.txt`
- `PIF-player-build-20260527-full-current-WebSetup.sha256.txt`
- `PIF-player-build-20260527-full-current-update1.sha256.txt`
- `PIF-player-build-20260527-full-current-update1.manifest.txt`
- `PIF-player-build-20260527-full-current.sha256.txt`
- `PIF-player-build-20260527-full-current.manifest.txt`
