# GBA Player

Managed mod for Pokemon Infinite Fusion/Kuray Infinite Fusion.

## What works in this Ruby mod

- Adds the `GBA Player` key item.
- Adds a `GBA Player` option to the standard PC terminal list.
- Opens a handheld-style ROM picker, then returns to the map with a live walkalong GBA screen embedded inside the Infinite Fusion window so the player can keep moving.
- Lists local `.gba`, `.gb`, `.gbc`, and `.zip` files from `ROMs` and any folders in `config.json`.
- Mirrors a selected ROM through the portable mGBA SDL frontend in `Mods/zzz_gba_player/Emulator`. You can replace it or set `emulator_path` in `config.json`; default launch volume is `emulator_volume_percent: 25`, the native window is embedded with `mirror_embed: true`, the GBA screen is aspect-locked with `mirror_lock_aspect: true`, and the bundled mGBA SDL keyboard bindings are repaired before launch.
- Walkalong controls are separate from Infinite Fusion movement by default: D-pad `I/J/K/L`, A/B `U/O`, L/R `Y/P`, Select/Start `G/H`, screen re-sync `F11`, stop `F12`.
- Reads compatible Gen 3 `.sav`/`.srm` files and imports copied Pokemon into Infinite Fusion PC storage.

## What is scaffolded

This experimental public build includes the bundled mGBA runtime plus the current native mirror/core helper runtime files used by the mod's public testing path.

ROMs, saves, mirror frames, launch logs, and local build-output folders are intentionally not included in the public repo/package. Place your own ROM files in `Mods/zzz_gba_player/ROMs`. Place your own save files in `Mods/zzz_gba_player/Saves`, or add extra folders in `config.json`.

Mirror and ROM launch attempts are written to `Mods/zzz_gba_player/launch.log`. Live mirror frames are written to `Mods/zzz_gba_player/mirror_runtime/frame.png`.

The mod does not launch mGBA, scan ROM folders, or search emulator folders during game startup. Those heavier checks only run after opening the GBA Player menu or starting a ROM.
