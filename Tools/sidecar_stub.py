#!/usr/bin/env python3
"""KIF NeuralFusion entrypoint (run by 694_AISprites/006_AIGen_Launcher, or by a
venv python directly). It picks the RIGHT isolated environment and runs the
sidecar in it -- so the game never depends on, or disturbs, your global Python:

  * trained weights + GPU training env present -> run in .venv-train  (NEURAL)
  * otherwise                                  -> run in .venv        (compositor)
  * neither built yet                          -> self-create .venv, then run

Falls through cleanly (game uses Japeal) if Python can't set things up.
"""
import os, sys, subprocess, importlib.util

TOOLS = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.join(TOOLS, "kif_neuralfusion")
sys.path.insert(0, PKG)
LORA = os.path.join(PKG, "models", "lora")


def _have(m):
    try:
        return importlib.util.find_spec(m) is not None
    except Exception:
        return False


def _run_sidecar():
    import sidecar
    sidecar.main()


def _weights_present():
    return (os.path.isfile(os.path.join(LORA, "pytorch_lora_weights.safetensors"))
            or os.path.isfile(os.path.join(LORA, "pytorch_lora_weights.bin")))


def _is_self(py):
    try:
        return os.path.normcase(os.path.abspath(py)) == os.path.normcase(os.path.abspath(sys.executable))
    except Exception:
        return False


def _exec(py):
    args = [py, os.path.abspath(__file__)]
    try:
        os.execv(py, args)
    except Exception:
        try:
            subprocess.Popen(args)
        except Exception as e:
            print(f"[KIF NeuralFusion] could not launch venv python: {e}")
        sys.exit(0)


def main():
    if not os.path.isdir(PKG):
        print(f"[KIF NeuralFusion] package missing at {PKG}; not starting.")
        sys.exit(1)
    try:
        import bootstrap
    except Exception:
        bootstrap = None

    # loop guard
    attempts = int(os.environ.get("KIF_BOOT_ATTEMPTS", "0"))
    if attempts > 3:
        print("[KIF NeuralFusion] setup kept failing; falling back to Japeal.")
        sys.exit(1)

    # pick ideal interpreter
    target = None
    if bootstrap:
        train_py = bootstrap.venv_python(bootstrap.TRAIN_VENV)
        run_py = bootstrap.venv_python(bootstrap.RUNTIME_VENV)
        if _weights_present() and os.path.isfile(train_py):
            target = train_py            # NEURAL tier
        elif os.path.isfile(run_py):
            target = run_py              # compositor tier
    # already in the right interpreter (has the runtime deps)?
    if (target and _is_self(target)) or (target is None and _have("PIL") and _have("numpy")):
        return _run_sidecar()
    if target:
        os.environ["KIF_BOOT_ATTEMPTS"] = str(attempts + 1)
        return _exec(target)

    # nothing built yet -> create the runtime env (show a console on Windows)
    if bootstrap is None:
        if _have("PIL") and _have("numpy"):
            return _run_sidecar()
        print("[KIF NeuralFusion] bootstrap.py missing and deps absent; using Japeal.")
        sys.exit(1)
    try:
        if os.name == "nt":
            CREATE_NEW_CONSOLE = 0x00000010
            subprocess.run([sys.executable, os.path.join(PKG, "bootstrap.py"), "runtime"],
                           creationflags=CREATE_NEW_CONSOLE)
        else:
            bootstrap.ensure_runtime()
    except Exception as e:
        print(f"[KIF NeuralFusion] auto-setup failed ({e}); using Japeal.")
        sys.exit(1)
    run_py = bootstrap.venv_python(bootstrap.RUNTIME_VENV)
    if os.path.isfile(run_py):
        os.environ["KIF_BOOT_ATTEMPTS"] = str(attempts + 1)
        return _exec(run_py)
    sys.exit(1)


if __name__ == "__main__":
    main()
