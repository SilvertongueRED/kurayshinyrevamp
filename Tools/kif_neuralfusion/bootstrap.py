#!/usr/bin/env python3
"""KIF NeuralFusion auto-setup (stdlib only -- runs on a bare Python).

Creates ISOLATED virtual environments so the user's global Python packages are
NEVER touched (a global `pip install torch` once clobbered a CUDA build -- never
again). Two envs, both inside this folder:

  .venv        runtime: pillow + numpy  (the always-on compositor sidecar)
  .venv-train  training: CUDA torch (auto-detected) + diffusers stack (GPU LoRA)

Used by:
  * sidecar_stub.py  -> ensure_runtime() on first in-game launch (self-healing)
  * Setup .bat files -> one-click setup for end users
  * CLI:  python bootstrap.py runtime | train | both | repair-train

`repair-train` (and `train`) self-heal a training env whose torch can't see the
GPU: if an NVIDIA GPU is present but the installed torch is a CPU-only build, we
reinstall a CUDA build (the exact bug that made training run on the CPU).

All output (including pip) is teed to kif_neuralfusion/logs/ via tlog.
"""
import os, sys, re, json, subprocess, venv as _venv

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
try:
    import tlog
except Exception:
    tlog = None

RUNTIME_VENV = os.path.join(HERE, ".venv")
TRAIN_VENV = os.path.join(HERE, ".venv-train")

# PyTorch CUDA wheel indexes we know about, NEWEST FIRST. We pick the highest one
# whose CUDA version is <= the driver's, then try progressively older ones until a
# build that actually sees the GPU installs. Listing a tag that no longer exists
# on the server is harmless -- that attempt just 404s and the ladder moves on. So
# we keep a couple of forward-looking tags at the top for new drivers.
CUDA_INDEXES = [(13, 0, "cu130"), (12, 9, "cu129"), (12, 8, "cu128"),
                (12, 6, "cu126"), (12, 4, "cu124"), (12, 1, "cu121"),
                (11, 8, "cu118")]
# Known-good fallback if the driver's CUDA version can't be parsed at all but a
# GPU is clearly present. cu128 is broadly compatible with modern (>=12.8 / 13.x)
# drivers and is what this project has verified on an RTX 4090.
SAFE_CUDA_TAG = "cu128"


def log(m):
    print(f"[KIF setup] {m}", flush=True)


def venv_python(venv_dir):
    if os.name == "nt":
        return os.path.join(venv_dir, "Scripts", "python.exe")
    return os.path.join(venv_dir, "bin", "python")


def _run(cmd, **kw):
    """Run a command, streaming its output line-by-line so pip's progress is both
    visible live AND captured in the log file (subprocess writes to OS fds, which
    the tlog tee can't see -- so we pump it through print() ourselves)."""
    label = " ".join(str(c) for c in cmd[-4:]) if len(cmd) > 4 else " ".join(map(str, cmd))
    log(label)
    check = kw.pop("check", True)
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True, bufsize=1, **kw)
    for line in p.stdout:
        print(line.rstrip())
    p.wait()
    if check and p.returncode != 0:
        raise subprocess.CalledProcessError(p.returncode, cmd)
    return p


def _pip(py, args, tries=2):
    base = [py, "-m", "pip", "install", "--disable-pip-version-check", "--no-input"]
    last = None
    for i in range(tries):
        try:
            _run(base + args)
            return True
        except Exception as e:
            last = e
            log(f"pip attempt {i+1} failed: {e}")
    raise last


def make_venv(venv_dir):
    py = venv_python(venv_dir)
    if not os.path.isfile(py):
        log(f"creating environment: {venv_dir}")
        _venv.EnvBuilder(with_pip=True, upgrade_deps=False).create(venv_dir)
    try:
        _run([py, "-m", "pip", "install", "--disable-pip-version-check", "-q", "--upgrade", "pip"])
    except Exception:
        pass
    return py


def _importable(py, mods):
    code = "import importlib.util,sys;" + \
           "sys.exit(0 if all(importlib.util.find_spec(m) for m in %r) else 1)" % (list(mods),)
    try:
        return subprocess.run([py, "-c", code]).returncode == 0
    except Exception:
        return False


def ensure_runtime():
    """Runtime venv with pillow+numpy. Returns its python path (or None)."""
    py = venv_python(RUNTIME_VENV)
    if os.path.isfile(py) and _importable(py, ["PIL", "numpy"]):
        return py
    try:
        py = make_venv(RUNTIME_VENV)
        if not _importable(py, ["PIL", "numpy"]):
            _pip(py, ["pillow>=9", "numpy>=1.21"])
        log("runtime environment ready.")
        return py
    except Exception as e:
        log(f"runtime setup failed: {e}")
        return None


# --------------------------------------------------------------------------- #
#  CUDA detection
# --------------------------------------------------------------------------- #
def _nvidia_smi_text():
    try:
        res = subprocess.run(["nvidia-smi"], capture_output=True, text=True, timeout=20)
    except Exception as e:
        log(f"nvidia-smi not runnable ({e}); assuming no NVIDIA GPU")
        return None
    out = res.stdout or ""
    if res.returncode != 0 and "NVIDIA" not in out:
        return None
    return out


def _parse_driver_cuda(out):
    """Return (major, minor) of the driver's max CUDA, or None. Handles both the
    classic 'CUDA Version: 12.4' header AND the newer driver layout that prints
    'CUDA UMD Version: 13.3' (User-Mode-Driver) -- the rename to *UMD* is exactly
    what used to make us miss the version and fall back to a stale/CPU wheel."""
    if not out:
        return None
    m = re.search(r"CUDA(?:\s+UMD)?\s+Version:\s*(\d+)\.(\d+)", out)
    if m:
        return int(m.group(1)), int(m.group(2))
    return None


def gpu_present():
    out = _nvidia_smi_text()
    return bool(out and "NVIDIA" in out)


def cuda_tag_candidates():
    """Ordered list of cuXXX wheel tags to try (best first). Empty list == no
    NVIDIA GPU at all (genuine CPU-only machine). A GPU that's present but whose
    CUDA version we can't parse still yields a full candidate list -- we never
    treat 'unparsed' as 'no GPU', because that is what silently breaks training."""
    out = _nvidia_smi_text()
    if not out or "NVIDIA" not in out:
        return []
    drv = _parse_driver_cuda(out)
    if drv:
        usable = [tag for (cmaj, cmin, tag) in CUDA_INDEXES if (drv[0], drv[1]) >= (cmaj, cmin)]
        if usable:
            log(f"driver CUDA {drv[0]}.{drv[1]} -> trying wheels: {', '.join(usable)}")
            return usable
        # driver older than our oldest tag: still try the oldest as a last resort
        log(f"driver CUDA {drv[0]}.{drv[1]} is older than known wheels; trying {CUDA_INDEXES[-1][2]}")
        return [CUDA_INDEXES[-1][2]]
    # GPU present but version unparsed: try the safe tag first, then the rest.
    log("nvidia-smi present but CUDA version unparsed; trying cu128 then older "
        "(NOT CPU -- a CPU torch can't train on the GPU)")
    order = [SAFE_CUDA_TAG] + [t for (_a, _b, t) in CUDA_INDEXES if t != SAFE_CUDA_TAG]
    return order


def detect_cuda():
    """Single best cuXXX tag (or None). Kept for callers/logging; the installer
    uses cuda_tag_candidates() so it can fall back across tags."""
    c = cuda_tag_candidates()
    return c[0] if c else None


def _torch_status(py):
    """Return (version_str_or_None, cuda_available_bool) for the torch in `py`."""
    code = (
        "import json\n"
        "try:\n"
        " import torch\n"
        " print(json.dumps([str(torch.__version__), bool(torch.cuda.is_available())]))\n"
        "except Exception:\n"
        " print(json.dumps([None, False]))\n")
    try:
        r = subprocess.run([py, "-c", code], capture_output=True, text=True, timeout=180)
        line = (r.stdout or "").strip().splitlines()[-1]
        v, ok = json.loads(line)
        return (v, bool(ok))
    except Exception:
        return (None, False)


def _verify_torch_cuda(py, gpu_expected):
    """Run the installed torch and LOUDLY report whether it sees CUDA."""
    v, ok = _torch_status(py)
    log(f"torch self-check: version={v} cuda_available={ok}")
    if gpu_expected and not ok:
        log("=" * 60)
        log("WARNING: an NVIDIA GPU was detected, but the torch installed in the")
        log("training env does NOT see CUDA. Training would fall back to CPU and")
        log("be impractically slow. Likely a CPU-only wheel slipped in or there is")
        log("a driver/toolkit mismatch.")
        log("Fix: re-run with `repair-train`, or delete the .venv-train folder and")
        log("re-run setup, and confirm `nvidia-smi` works in a normal console.")
        log("=" * 60)
    elif not gpu_expected:
        log("No NVIDIA GPU detected -- this build is CPU-only. SD1.5 LoRA training "
            "is impractical on CPU; training is meant for an NVIDIA GPU.")
    return ok


def _install_cuda_torch(py, candidates):
    """Try each cuXXX index (best first), force-reinstalling torch+torchvision,
    until one installs a build that actually SEES the GPU. Returns the winning
    tag, or None if every candidate failed. NEVER installs a CPU wheel here."""
    for tag in candidates:
        log(f"installing CUDA torch from the {tag} wheel index (force-reinstall)...")
        try:
            _pip(py, ["--force-reinstall", "--no-cache-dir", "torch", "torchvision",
                      "--index-url", f"https://download.pytorch.org/whl/{tag}"])
        except Exception as e:
            log(f"  {tag} install failed ({e}); trying an older CUDA index")
            continue
        v, ok = _torch_status(py)
        if ok:
            log(f"  OK -> torch {v} sees the GPU (via {tag}).")
            return tag
        log(f"  torch {v} from {tag} still does not see the GPU; trying older index")
    return None


def ensure_training(force_cuda=None):
    """Isolated training venv: CUDA torch + diffusers stack. Returns python path.

    Self-healing: if a GPU is present but the existing torch is CPU-only (the bug
    that made training run on the CPU), the CUDA build is reinstalled in place."""
    py = make_venv(TRAIN_VENV)
    candidates = [force_cuda] if force_cuda else cuda_tag_candidates()
    has_gpu = bool(candidates)

    cur_ver, cur_ok = _torch_status(py)
    if has_gpu and cur_ok:
        log(f"training env already has a CUDA torch ({cur_ver}) that sees the GPU; keeping it.")
    elif has_gpu:
        if cur_ver:
            log(f"training env has torch {cur_ver} but it CANNOT see the GPU "
                f"(likely a CPU-only build) -- reinstalling a CUDA build.")
        won = _install_cuda_torch(py, candidates)
        if not won:
            raise RuntimeError(
                "Could not install a CUDA-enabled torch that sees your GPU, so "
                "training would be CPU-only (not viable for SD1.5). NOT installing "
                "a CPU torch. Confirm `nvidia-smi` works in a normal console, then "
                "manually run:\n"
                f'  "{py}" -m pip install --force-reinstall --no-cache-dir '
                "torch torchvision --index-url https://download.pytorch.org/whl/cu128")
    else:
        log("no NVIDIA GPU detected -- installing CPU torch (training will be slow).")
        if not cur_ver:
            _pip(py, ["torch", "torchvision"])

    log("ensuring the diffusers training stack is installed...")
    if not _importable(py, ["diffusers", "transformers", "accelerate", "peft", "safetensors"]):
        _pip(py, ["diffusers>=0.27", "transformers>=4.38", "accelerate>=0.27",
                  "peft>=0.10", "safetensors>=0.4", "numpy>=1.21", "pillow>=9"])
    else:
        log("diffusers stack already present.")
    _verify_torch_cuda(py, gpu_expected=has_gpu)
    log(f"training environment ready: {py}")
    return py


def repair_training():
    """Force a CUDA-torch reinstall into an existing .venv-train regardless of what
    is currently there (used by the 'repair-train' target / the Train .bat)."""
    if not os.path.isfile(venv_python(TRAIN_VENV)):
        return ensure_training()
    candidates = cuda_tag_candidates()
    if not candidates:
        log("no NVIDIA GPU detected; nothing to repair (CPU build).")
        return ensure_training()
    py = venv_python(TRAIN_VENV)
    log("repair-train: forcing a fresh CUDA torch into the existing training env...")
    won = _install_cuda_torch(py, candidates)
    if not won:
        raise RuntimeError(
            "repair-train could not install a CUDA torch that sees the GPU. "
            "Confirm `nvidia-smi`, then run:\n"
            f'  "{py}" -m pip install --force-reinstall --no-cache-dir torch '
            "torchvision --index-url https://download.pytorch.org/whl/cu128")
    if not _importable(py, ["diffusers", "transformers", "accelerate", "peft", "safetensors"]):
        _pip(py, ["diffusers>=0.27", "transformers>=4.38", "accelerate>=0.27",
                  "peft>=0.10", "safetensors>=0.4", "numpy>=1.21", "pillow>=9"])
    _verify_torch_cuda(py, gpu_expected=True)
    log("repair-train done.")
    return py


def _main():
    what = (sys.argv[1] if len(sys.argv) > 1 else "runtime").lower()
    if what in ("runtime", "both"):
        ensure_runtime()
    if what in ("train", "training", "both"):
        ensure_training()
    elif what in ("repair-train", "repair", "fix-train"):
        repair_training()
    elif what not in ("runtime", "both"):
        log(f"unknown target '{what}' (use: runtime | train | both | repair-train)")


def main():
    stage = "bootstrap_" + (sys.argv[1].lower() if len(sys.argv) > 1 else "runtime")
    if tlog:
        tlog.open_log(stage)
        tlog.guarded(_main, stage)
    else:
        _main()


if __name__ == "__main__":
    main()
