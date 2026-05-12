# Kuray Infinite Fusion Full Current Tester Build - 2026-05-12

This release upgrades the older public `2026-04-22-no-csf` base install into the current experimental full tester build from this workspace.

## What this build includes

- Current local script/content changes reflected in this repo
- `custom_species_framework` with creator assets and imported species data
- modded multiplayer client/server files
- `travel_expansion_framework`, `player_identity_bedroom`, `counterfeit_shinies`, `autoplay_bot`, and the rest of the packaged mod stack
- `Libs/` and `ExpansionLinks/` from the current install

## What stays out

- personal save data
- Discord/account link files
- local cache, bot runtime state, and creator/importer debug logs
- `ExpansionLibrary/` external game archives

## Warnings

- This is an experimental merged tester build, not a stable upstream release.
- Saves live in `%APPDATA%\kurayinfinitefusion`, not inside the install folder.
- Back up saves before testing this build.

## Install flow

1. Download `PIF-player-build-20260512-full-current-WebSetup.exe`.
2. Run `Install / Repair` for a fresh setup.
3. Use `Update Only` only when you already have an existing Kuray Infinite Fusion install in that folder.

## How the installer works

- The web installer keeps the one-click flow.
- Fresh installs still download the older `2026-04-22-no-csf` base package first.
- The installer then applies the embedded `2026-05-12` full-current overlay on top.
- Existing installs can skip the base download and apply just the embedded full-current overlay.

## Credits

- The installed build writes `PACKAGED_MOD_CREDITS.txt` into the game folder with the included mod authors and imported-species credit notes.
- Imported Mongratis species credits currently include work by Princess-Phoenix and KajiAtsui, with pack maintenance by Plouton, as required by the packaged credit manifest.
- Project-wide/base-game credits remain in `PIF_Credits.txt` and the main `README.md`.

## Files in this release folder

- `PIF-player-build-20260512-full-current-WebSetup.sha256.txt`
- `PIF-player-build-20260512-full-current-update1.sha256.txt`
- `PIF-player-build-20260512-full-current-update1.manifest.txt`
- `PACKAGED_MOD_CREDITS.txt`
