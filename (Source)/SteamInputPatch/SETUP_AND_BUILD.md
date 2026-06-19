# KIF native DualSense haptics — mkxp-z Steam Input patch

This patch makes the engine talk to the **Steamworks Steam Input API** so the game can:

* **Detect the real controller type even while Steam Input is active** — including when KIF is run through Steam as a *non-Steam game*. (Plain SDL can't: Steam Input hands the game a virtual **Xbox 360** pad and hides the real DualSense, so `SDL_GameControllerGetType` reports Xbox. The Steam Input API is the supported way to see through that and read `k_ESteamInputType_PS5Controller`.)
* Drive the DualSense **two main motors + the two trigger motors** (`rumble_ex`).
* Set the **DualSense lightbar** colour.

Non-DualSense controllers keep working exactly as before: if Steam Input isn't available the Ruby side falls back to the XInput backend automatically.

> **What this does NOT do:** the Steam Input API exposes trigger *rumble* but not DualSense **adaptive-trigger resistance** (the variable-stiffness effect). That requires writing raw DualSense HID output reports (the "Direct raw-HID" option). Say the word and I can add a raw-HID resistance layer on top of this.

---

## How the pieces fit

* **C++ (this folder):** `steaminput_kif.cpp` / `.h` register a tiny Ruby module `SteamHaptics` (`available?`, `run_frame`, `controller_type`, `controller_count`, `rumble`, `rumble_ex`, `led`, `led_reset`). All 64-bit controller handles stay inside C++.
* **Ruby (already in `Data/Scripts/691_Rumble/`):** `006_RumbleNativeBridge.rb` detects `SteamHaptics`, routes rumble through it when a Steam-Input controller is present, exposes `Haptics.controller_kind` / `dualsense?`, and adds the lightbar accents. With no patched engine it silently uses XInput.

No engine `main()` / event-loop changes are needed: Steamworks is initialised lazily and `RunFrame()` is pumped once per frame from the Ruby `Haptics.tick`.

---

## Prerequisites

1. **The mkxp-z source this fork was built from.** The shipped `Game.exe` is mkxp-z (Splendide Imaginarius, 2022-2023). Build from the matching source so the resulting binary stays compatible with the game's scripts.
2. **Steamworks SDK** (https://partner.steamgames.com/downloads/list — requires a Steamworks account and agreeing to the SDK terms). You need:
   * headers: `sdk/public/steam/*.h`
   * import lib: `sdk/redistributable_bin/win64/steam_api64.lib`
   * runtime dll: `sdk/redistributable_bin/win64/steam_api64.dll`

---

## Build steps

### 1. Add the source files
Copy `steaminput_kif.cpp` and `steaminput_kif.h` into the engine's `binding-mri/` folder (next to `input-binding.cpp`).

### 2. Register the binding (`binding-mri/binding-mri.cpp`)
Add the include near the other binding includes:
```cpp
#include "steaminput_kif.h"
```
Then, inside the function that runs all the `*BindingInit()` calls (search for `inputBindingInit();`), add one line after it:
```cpp
    inputBindingInit();
    SteamHapticsBindingInit();   // <-- add this
```

### 3. Wire up the build (`meson.build`)
Add the source to the binding sources list (where `input-binding.cpp` is listed):
```meson
    'binding-mri/steaminput_kif.cpp',
```
Enable Steam Input and point at the SDK. For example:
```meson
steam_root = 'C:/path/to/steamworks_sdk'        # adjust
add_project_arguments('-DMKXPZ_STEAM_INPUT', language: ['cpp'])
global_include_dirs += include_directories(steam_root / 'public')
global_link_args   += ['-L' + steam_root / 'redistributable_bin/win64', '-lsteam_api64']
```
> Exact variable names vary by mkxp-z revision — the three things to achieve are: (a) define `MKXPZ_STEAM_INPUT`, (b) add the Steam `public/` include dir, and (c) link `steam_api64`. If you don't define `MKXPZ_STEAM_INPUT`, the engine still builds and `SteamHaptics.available?` just returns false.

### 4. Build the engine as you normally build this mkxp-z fork.

---

## Runtime setup

1. Put **`steam_api64.dll`** next to `Game.exe`.
2. Put a **`steam_appid.txt`** next to `Game.exe`:
   * Launching **through Steam** (non-Steam shortcut): Steam sets the App ID in the environment, so the file is usually optional. If detection doesn't init, add `steam_appid.txt` containing `480` (Valve's public Spacewar test app) on its own line.
   * Launching **outside Steam**: `steam_appid.txt` with `480` is required for `SteamAPI_Init()` to succeed (Steam client must be running).
3. In Steam: add KIF as a **non-Steam game**, open its **Controller** settings, and enable **Steam Input** + **PlayStation Controller Support** (a.k.a. "Use Steam Input"). This is what lets the API report the DualSense and drive its effects.

---

## Verifying

In-game: **Options -> KIF Settings -> Controller Vibration -> Test Vibration**. The message shows what was detected, e.g. *"Detected: DualSense (native) via Steam Input"*. On a DualSense you should feel the main + trigger motors and see the lightbar tint by move type in battle. On any other pad (or a stock, un-patched exe) it reads e.g. *"Detected: Xbox / XInput"* and uses the two-motor backend.

---

## Caveats / honesty

* I can't compile or hardware-test this here. The C++ uses documented Steam Input calls (`TriggerVibration`, `TriggerVibrationExtended`, `SetLEDColor`, `GetInputTypeForHandle`) with signatures verified against the Steamworks SDK, and the no-Steam stub path compiles clean — but please build + test on your machine.
* `SteamAPI_Init()` for **non-Steam games** can be finicky; if `available?` stays false, try the `steam_appid.txt`=`480` fallback and make sure Steam Input is enabled for the shortcut.
* Shipping a custom `Game.exe` + `steam_api64.dll`: expect the usual antivirus / SmartScreen "unknown publisher" friction for anyone you distribute to.
* Adaptive-trigger *resistance* is not part of this API (raw-HID add-on needed).
