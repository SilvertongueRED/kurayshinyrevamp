# GBA Player Core Host

`GBAPlayerCoreHost.exe` is an experimental v2 gameplay bridge. It runs a libretro mGBA core headlessly and writes frames, audio, status, and save RAM through the same runtime protocol used by the v1 mirror helper. It is built as a Windows subsystem app so it should not open a console window.

This backend is not the default because PNG frame streaming from a helper process is too choppy for normal play. The stable runtime path is currently the v1 `mirror/` helper. Enable this backend only when testing the next bridge architecture.

Runtime files:

- `mirror_runtime/frame.N.png` - rotating emulator frames for the in-game handheld UI. The active frame path is advertised in `status.txt` as `frame_path=...`.
- `mirror_runtime/commands.txt` - commands from Ruby (`tap`, `hold`, `down`, `up`, `pause`, `resume`, `volume`, `quit`).
- `mirror_runtime/status.txt` - bridge state (`state=ready`, `mode=core`, frame counters, etc.).
- `Saves/*.srm` - SRAM copies written by the core host, usable by the importer when the save layout is Gen 3 compatible.

Build:

```powershell
dotnet publish Mods\zzz_gba_player\native\corehost\GBAPlayerCoreHost.csproj -c Release -r win-x64 --self-contained false -o Mods\zzz_gba_player\native\corehost\publish
```

Core install:

```powershell
powershell -ExecutionPolicy Bypass -File Mods\zzz_gba_player\native\corehost\fetch_mgba_libretro.ps1
```

Ruby uses this helper only when `bridge_backend` is `native`, or when `bridge_backend` is `auto` and `native_core_enabled` is true. If the helper or `cores/mgba_libretro.dll` is missing, `auto` falls back to the older mGBA window mirror.
