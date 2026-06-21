# Controller Rumble & DualSense Setup

KIF has built-in controller vibration (Options → KIF Settings → **Controller Vibration**).
Xbox and other XInput pads just work. A **PlayStation DualSense / DualShock 4** needs one
small decision depending on whether you use **Steam Input**.

## TL;DR — pick the path that matches how you launch

| How you play | What you get | What you have to do |
|---|---|---|
| **Steam Input OFF** (DualSense plugged in directly, USB or Bluetooth) | Correct DualSense detection **+ rumble** | Nothing — works out of the box |
| **Steam Input ON** (KIF added as a non‑Steam game) | Full native support: **rumble + trigger motors + lightbar** | Drop **your own** `steam_api64.dll` next to `Game.exe` (one‑time) |
| **Xbox / other XInput pad** | Rumble | Nothing |

Both paths are safe and fully optional — if nothing is set up, vibration simply falls back to
the standard two‑motor XInput backend or stays a no‑op.

## Why there's a choice at all

When you run KIF through Steam as a **non‑Steam game with Steam Input enabled**, Steam hands the
game a **virtual Xbox 360 controller** and hides the real DualSense. That's by design — it's how
Steam Input does remapping — but it means the game (and SDL) only ever see "Xbox." The *only*
supported way to see the real controller type through that disguise is the **Steamworks Steam
Input API**, which needs `steam_api64.dll` present. That's the one file the Steam‑Input path asks
for.

If you **don't** use Steam Input, KIF talks to the DualSense directly over USB/Bluetooth (raw HID)
and needs no extra files at all.

## Path A — Steam Input OFF (no extra files)

1. In Steam, open KIF's **Controller** settings (or global Settings → Controller) and turn **off**
   "Steam Input" / "PlayStation Controller Support" for this game, **or** just launch `Game.exe`
   directly without Steam.
2. Plug in (or Bluetooth‑pair) your DualSense.
3. In game: Options → KIF Settings → Controller Vibration → **Test Vibration**.
   It should read **"Detected: DualSense via direct USB"** (or Bluetooth) and you'll feel the test
   pattern.

This path gives rumble and correct detection. (Trigger‑motor and lightbar effects are part of the
Steam Input path below.)

## Path B — Steam Input ON (one‑time `steam_api64.dll`)

1. Find a `steam_api64.dll` you already have: open any Steam game you own at
   `C:\Program Files (x86)\Steam\steamapps\common\<some game>\` — most contain a `steam_api64.dll`.
   It must be the **64‑bit** file (`steam_api64.dll`, not `steam_api.dll`).
2. Copy it into your KIF folder, **right next to `Game.exe`**.
3. Add KIF as a **non‑Steam game**, open its **Controller** settings, and enable **Steam Input** +
   **PlayStation Controller Support**.
4. Launch through that Steam shortcut, then Options → KIF Settings → Controller Vibration →
   **Test Vibration**. It should read **"Detected: DualSense via Steam Input,"** and you get rumble,
   the two trigger motors, and lightbar tinting (by move type / encounter).

KIF now **auto-creates** a `steam_appid.txt` (containing `480`) next to `Game.exe` the first
time the Steam Input bridge runs, so you normally don't touch it. If your KIF folder is
read-only (e.g. under `Program Files`) and detection still shows Xbox, create it yourself: a
plain text file named `steam_appid.txt` containing just `480`, next to `Game.exe`. Without a
valid App ID, `SteamAPI_Init` fails ("no appID found") and detection falls back to Xbox.

## Why we don't bundle `steam_api64.dll` for you

`steam_api64.dll` is a Steamworks SDK redistributable. Its license only covers shipping it as part
of **your own** Steam app under an AppID you own — it does **not** cover bundling it with a
non‑Steam fan game, and a copy taken from another game isn't yours to redistribute. (The test
AppID the bridge falls back to, `480`/Spacewar, is also for testing only, not shipping.) Bundling
an unknown binary would also trip antivirus/SmartScreen for everyone who installs the fork.

So the Steam Input path is **user‑supplied**: you drop in a `steam_api64.dll` you already own, for
your own use. Nothing questionable is shipped in the repo or installer.

## What the in‑game readout tells you

The **Test Vibration** button always reports what it found:

- *"Detected: DualSense via Steam Input"* — Path B working (native).
- *"Detected: DualSense via direct USB/Bluetooth"* — Path A working (raw HID).
- *"Detected: Xbox / XInput"* + *"Steam Input is active. Copy steam_api64.dll next to Game.exe…"* —
  you're on Steam Input but the DLL is missing (do Path B step 1–2), or turn Steam Input off for
  Path A.
- *"No controller detected"* — no pad is connected/seen.

**Still shows Xbox after adding `steam_api64.dll`?** Make sure you launched **through the Steam
shortcut** with Steam Input on, that `steam_appid.txt` (just `480`) sits next to `Game.exe`, and
open **`Logs/rumble_steaminput.log`** — it writes one line per launch with `ok=`, the controller
`count=`, the real `type=` (13 = DualSense, 2/3 = Xbox) and any `err=`, which pinpoints the cause.

## Notes & limits

- Trigger‑motor rumble and lightbar tinting are only available on the **Steam Input** path (they
  come from the Steam Input API). The direct path provides the two main motors.
- DualSense **adaptive‑trigger resistance** (variable stiffness) is not supported by either path.
- Non‑Windows (Linux/Mac) or no pad present → vibration is a safe no‑op.
- Advanced/optional: builders can compile the engine with the C++ Steam Input patch in
  `(Source)/SteamInputPatch/` instead of using the Ruby bridge; both expose the same in‑game
  behavior. The Ruby bridge is the no‑recompile default.
