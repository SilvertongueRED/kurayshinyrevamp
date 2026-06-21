# KIF NeuralFusion — on-device fusion-sprite model

Generates Infinite-Fusion sprites for pairs that have no human custom, so the
game can prefer a clean AI sprite over the low-quality Japeal autogen. Wired to
the in-game engine (Data/Scripts/694_AISprites) via a tiny localhost contract.

## Two tiers (best available wins, automatically)

1. **Compositor** (always on, any CPU, ~12 ms/sprite, deps: pillow + numpy).
   Takes the BODY parent's silhouette, recolours it toward the HEAD parent's
   palette (the signature fusion look), caps the HEAD parent's head/features on
   top, then unifies the outline and tightens the palette. Its parameters
   (`params.json`) are FIT to the April-2026 PIF custom corpus: ~15-colour
   palette, ~luma-50 outline, body-defines-shape / head-supplies-face. `seed`
   varies recolour strength, head scale/placement, palette size & hue, so
   "Generate" makes distinct variants.

2. **Neural** (optional, GPU): a LoRA fine-tuned on the 222k human customs. The
   compositor sprite becomes the img2img **init image**, so structure & palette
   are preserved while the model adds human-custom detail and finish. Activates
   automatically once `models/lora/` holds trained weights and torch+diffusers
   are installed — see `train/README_TRAINING.md`. Tune in `neural.json`.

## Contract (served by sidecar.py on 127.0.0.1:8760)

    GET /health                          -> 200 "ok"
    GET /generate?head=H&body=B[&seed=S] -> 200 image/png (288x288 RGBA)
                                            404 if a base sprite is missing
Base sprites are read from the install: `Graphics/BaseSprites/<id>.png` then
`Graphics/Battlers/<id>/<id>.png`.

## Setup (automated, one click)

Double-click **`Tools/Setup AI Sprites.bat`**. It auto-detects Python (installs
3.12 via winget if missing), then builds an **isolated** environment
(`kif_neuralfusion/.venv`, pillow+numpy only) -- your global Python packages are
never touched. If it sees an NVIDIA GPU it offers to set up the separate GPU
training env too. Nothing else to do: the game launches the sidecar from that
venv on demand (694_AISprites/006_AIGen_Launcher), and generation is always
user-initiated (the Generate button), never during a battle.

First in-game launch self-heals too: if no venv exists yet the entrypoint
creates one automatically (a small console shows progress once).

Environments (both isolated, inside this folder):
    .venv        runtime: pillow + numpy        (always-on compositor)
    .venv-train  training: CUDA torch + diffusers (GPU LoRA; see train/)
The sidecar runs in .venv-train automatically once trained weights exist.

## Ship to players without Python (build the exe)

    pip install pyinstaller
    pyinstaller --onefile --name sidecar \
        --add-data "kif_neuralfusion/params.json:kif_neuralfusion" \
        --collect-submodules kif_neuralfusion \
        kif_neuralfusion/sidecar.py
    # copy dist/sidecar.exe -> Tools/sidecar.exe  (the launcher prefers it)

## Files
    sidecar.py        localhost server + tier routing
    compositor.py     the runs-anywhere fusion model (pillow+numpy)
    params.json       compositor parameters, fit to the corpus
    neural.py         optional GPU img2img refiner (soft-imported)
    neural.json       neural refiner config
    train/            dataset prep + LoRA training (GPU)
    ../sidecar_stub.py  entrypoint the in-game launcher runs
