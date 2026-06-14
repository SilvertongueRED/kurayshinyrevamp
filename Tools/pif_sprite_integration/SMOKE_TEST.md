# PIF Sprite Smoke Test (Testing installs)

A test helper is installed in **Testing 1 & 2 only** (`Data/Scripts/990_NPT/099_PIFTestHelper.rb`).
It turns on the debug menu and adds a one-shot test team. Do this offline. Delete the helper when done.

## 1. Get the test Pokémon (two ways)

**Easiest — flag file:**
1. Launch a Testing install, load/continue any save, and stand in the overworld.
2. In the game's root folder (the one with `Game.exe`), create an empty file named **`PIF_TEST_GIVE.txt`**.
   (e.g. in that folder: right-click → New → Text Document, rename it to exactly `PIF_TEST_GIVE.txt`).
3. Take a step. Within ~1 second you'll get this team (and the flag file disappears):
   Tropius 50, **Noibat 47**, Noivern 50, Tynamo 50, Eelektross 50, Skrelp 50, Dragalge 50, Castform 50, Chingling 50, Relicanth 50.

**Or — debug menu:** in the overworld press **F9** (or Pause → Debug) → **Pokémon** → **[Add Pokémon]** → pick any species and level. (The helper sets `$DEBUG = true`.)

## 2. What to check

**Base sprites (party / summary screen).** Each should show its real PIF art, proving the remap landed on the right fork ID:

| Species | fork ID | quick visual |
|---|---|---|
| Tropius | 553 | green leaf-winged dino w/ banana fruit |
| Chingling | 581 | tiny round bell |
| Tynamo / Eelektross | 687 / 689 | eel; Eelektross = big jawed eel |
| Skrelp / Dragalge | 737 / 738 | kelp seahorse / kelp dragon |
| Castform (Sunny/Rainy/Snowy) | 1038 / 1039 / 1040 | weather forms |
| **Noibat / Noivern** | **1109 / 1110** | purple bat → big sound dragon (brand-new to the fork) |

**Fusion sprite + AFI alt-swap.** Fuse one of these with another Pokémon (DNA Splicer), open it in the **Pokédex sprite viewer**, and cycle the alt sprites — you should see the **PIF sprite as the main** and the **AFI sprite available as an alt** (nothing lost). Plenty of new PIF-only fusions were also added (~13k), so previously-missing combos should now have art.

**Evolution.** Noibat was given at **Lv 47**. Give it one Rare Candy (debug: F9 → Items, or the bag) to reach **48** → it evolves into **Noivern**. Confirm the Noivern sprite shows.

## 3. Cleanup
Delete `Data/Scripts/990_NPT/099_PIFTestHelper.rb` from the Testing installs and any leftover `PIF_TEST_GIVE.txt` when you're finished. (The helper is testing-only and is not in the repo or the live install.)
