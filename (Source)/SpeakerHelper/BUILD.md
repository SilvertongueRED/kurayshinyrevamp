# kif_speaker — Controller-Speaker audio router

A tiny, self-contained Windows helper that plays a single sound file to a
**specific** audio-output device — used by KIF to push Pokemon cries and
Pokedex voice-over out of the **DualSense built-in speaker** (which Windows
exposes as an audio endpoint named "Wireless Controller" / "DualSense Wireless
Controller"). mkxp-z/RGSS can only play SE through the *default* device, so the
game shells out to this helper instead.

> The DualSense speaker is available over **USB only** (not Bluetooth).

## Command-line contract (called by Data/Scripts/691_Rumble/010_SpeakerOutput.rb)

```
kif_speaker.exe play "<device-substr>" "<file>" <volume0-100> <pitch%>
kif_speaker.exe probe "<out-file>"
```

* **play** — decode `<file>` (`.ogg` via stb_vorbis, `.wav/.mp3/.flac` via
  miniaudio) and render it to the first **playback** endpoint whose name
  contains `<device-substr>` (case-insensitive). `pitch%` 100 = normal.
  Exit 0 on success; 2 = no matching device, 4 = bad/missing file.
* **probe** — write detection results to `<out-file>` (UTF-8):
  ```
  dualsense_present=0|1
  dualsense_name=<endpoint name>
  default_name=<default render endpoint>
  default_is_headphones=0|1
  ```

It is built as a **GUI-subsystem** binary (WinMain) so spawning it never flashes
a console window.

## Build

Sources: `kif_speaker.c` + bundled single-header libs `miniaudio.h`
(© David Reid, MIT-0) and `stb_vorbis.c` (© Sean Barrett, public domain).

### With zig (no admin rights, cross-compiles from any OS)
```
pip install ziglang
python3 -m ziglang cc -target x86_64-windows-gnu -O2 \
    kif_speaker.c -o kif_speaker.exe \
    -Wl,--subsystem,windows -lole32 -loleaut32 -lshell32 -luuid -lwinmm
```

### With MinGW-w64 on Windows
```
x86_64-w64-mingw32-gcc -O2 kif_speaker.c -o kif_speaker.exe \
    -mwindows -lole32 -loleaut32 -lshell32 -luuid -lwinmm
```

Drop the resulting `kif_speaker.exe` in the game root (next to `Game.exe`).
