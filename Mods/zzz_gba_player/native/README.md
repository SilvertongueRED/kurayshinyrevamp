# Native Bridge Notes

The mod now has two native-side tracks:

1. `mirror/` - the stable v1 runtime. It launches the bundled mGBA frontend and mirrors/embeds that window into the handheld UI.
2. `corehost/` - an experimental v2 bridge. It runs a headless libretro mGBA core and feeds frames, audio, input, status, and `.srm` saves through the in-game handheld UI. It is currently opt-in because helper-process PNG frame streaming is too choppy for normal play.

The older Ruby C-extension facade still tries to load either:

- `Mods/zzz_gba_player/native/gba_player_bridge`
- `gba_player_bridge`

Expected native API:

```ruby
GBAPlayerBridge.open_rom(path, mode, config_hash)
GBAPlayerBridge.close
GBAPlayerBridge.status
```

That extension path is still reserved for a future direct `libmgba`/MKXP-Z integration. Current gameplay should go through `mirror/`; `corehost/` is only for bridge testing.

`ext/` contains a minimal C-extension ABI scaffold. It is not the finished renderer; it exists so the eventual libmgba/MKXP-Z work has a concrete method shape to fill in.
