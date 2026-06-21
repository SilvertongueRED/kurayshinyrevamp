#!/usr/bin/env python3
"""Shared diagnostic logging for the KIF NeuralFusion training pipeline.

Stdlib only (safe to import on a bare Python, before any venv exists). Every
stage -- bootstrap / prepare_dataset / train_lora -- calls `open_log("<stage>")`
once at startup. That tees *all* stdout and stderr into a timestamped file under
`kif_neuralfusion/logs/` AND appends to `logs/latest.log`, so an entire training
run (setup + dataset + train) lands in one file you can hand over to diagnose.

`guarded(main, "<stage>")` runs the stage and, on ANY failure, writes the full
traceback plus targeted hints to the log -- the thing we were missing when
training "just failed" with nothing to look at.
"""
import os, sys, io, subprocess, datetime, traceback, atexit, importlib

PKG = os.path.dirname(os.path.abspath(__file__))   # the kif_neuralfusion/ dir
LOG_DIR = os.path.join(PKG, "logs")

_tee = None
_open_files = []


class _Tee(io.TextIOBase):
    """Write-through stream that fans out to the real console + log files."""
    def __init__(self, streams):
        self.streams = streams

    def write(self, s):
        for st in self.streams:
            try:
                st.write(s)
                st.flush()
            except Exception:
                pass
        return len(s)

    def flush(self):
        for st in self.streams:
            try:
                st.flush()
            except Exception:
                pass


def _ts():
    return datetime.datetime.now().strftime("%Y%m%d_%H%M%S")


def open_log(stage):
    """Begin teeing stdout+stderr into logs/<stage>_<ts>.log and logs/latest.log.
    Returns the per-stage log path (also printed in the banner)."""
    global _tee
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
    except Exception as e:
        print(f"[tlog] could not create log dir {LOG_DIR}: {e!r}")
        return None
    per = os.path.join(LOG_DIR, f"{stage}_{_ts()}.log")
    try:
        fper = open(per, "w", encoding="utf-8", buffering=1)
        flat = open(os.path.join(LOG_DIR, "latest.log"), "a", encoding="utf-8", buffering=1)
    except Exception as e:
        print(f"[tlog] could not open log files: {e!r}")
        return None
    _open_files.extend([fper, flat])
    _tee = _Tee([sys.stdout, fper, flat])
    sys.stdout = _tee
    sys.stderr = _tee
    atexit.register(_close)
    banner(stage, per)
    return per


def _close():
    for f in _open_files:
        try:
            f.flush()
            f.close()
        except Exception:
            pass


def banner(stage, path):
    line = "=" * 70
    print(line)
    print(f"  KIF NeuralFusion training log   stage: {stage}")
    print(f"  time: {datetime.datetime.now().isoformat(timespec='seconds')}")
    print(f"  log : {path}")
    print(line)
    dump_system()


def section(title):
    print("\n----- " + title + " " + "-" * max(0, 60 - len(title)))


def dump_system():
    import platform
    section("system")
    print(f"platform : {platform.platform()}")
    print(f"python   : {sys.version.splitlines()[0]}")
    print(f"exe      : {sys.executable}")
    print(f"cwd      : {os.getcwd()}")
    print(f"argv     : {sys.argv}")


def dump_nvidia_smi():
    section("nvidia-smi")
    try:
        out = subprocess.run(["nvidia-smi"], capture_output=True, text=True, timeout=20)
        print((out.stdout or out.stderr or "").strip() or "(no output)")
    except Exception as e:
        print(f"nvidia-smi unavailable: {e!r}  (no NVIDIA driver/GPU visible)")


def dump_versions(names):
    section("package versions")
    for n in names:
        try:
            m = importlib.import_module(n)
            print(f"  {n:14s} {getattr(m, '__version__', '?')}")
        except Exception as e:
            print(f"  {n:14s} NOT INSTALLED ({e.__class__.__name__})")


def dump_torch_env():
    """Detailed torch/CUDA report. Returns True iff a CUDA GPU is usable."""
    section("torch / CUDA")
    try:
        import torch
    except Exception as e:
        print(f"torch import FAILED: {e!r}")
        return False
    print(f"  torch              {torch.__version__}")
    print(f"  built for cuda     {getattr(torch.version, 'cuda', None)}")
    avail = False
    try:
        avail = torch.cuda.is_available()
    except Exception as e:
        print(f"  cuda.is_available() raised: {e!r}")
    print(f"  cuda.is_available  {avail}")
    if avail:
        try:
            i = torch.cuda.current_device()
            p = torch.cuda.get_device_properties(i)
            print(f"  device             {torch.cuda.get_device_name(i)}")
            print(f"  VRAM               {p.total_memory / 1024**3:.1f} GiB")
        except Exception as e:
            print(f"  device query raised: {e!r}")
    else:
        print("  device             CPU ONLY  <-- GPU is NOT visible to torch")
    return avail


_HINTS = [
    (("out of memory", "cuda oom", "alloc"),
     "CUDA out of memory: lower --resolution (e.g. 384), --batch 1, or --rank 8."),
    (("not implemented for 'half'", 'not implemented for "half"', "half"),
     "fp16 math ran on CPU: torch can't see your GPU. Re-run setup so CUDA torch "
     "installs, verify `nvidia-smi`, or pass --mixed-precision no."),
    (("connectionerror", "couldn't connect", "max retries", "huggingface", "hfhuberror",
      "newconnectionerror", "read timed out"),
     "Model download/network problem reaching HuggingFace. Check internet/proxy, or "
     "pre-download stable-diffusion-v1-5 and point --base-model at the local folder."),
    (("no module named", "modulenotfounderror"),
     "A package is missing in the venv. Re-run bootstrap.py train (or Setup AI Sprites.bat)."),
    (("permission denied", "operation not permitted", "winerror 5"),
     "File locked/permission denied. Close the game, and don't keep the dataset/output "
     "folder open in Explorer while training."),
    (("no space left", "errno 28", "disk full"),
     "Disk full. The 512px dataset is tens of GB; free space or lower --limit / --size."),
]


def guarded(fn, stage):
    """Run fn(); log a full traceback + targeted hints on failure (exit 1)."""
    try:
        fn()
        print(f"\n[OK] stage '{stage}' completed.")
    except KeyboardInterrupt:
        section("INTERRUPTED")
        print(f"stage '{stage}' was interrupted by the user (Ctrl+C).")
        sys.stdout.flush()
        sys.exit(130)
    except SystemExit:
        raise
    except BaseException as e:
        section("FAILURE")
        print(f"stage '{stage}' FAILED:\n")
        traceback.print_exc()
        blob = (repr(e) + " " + "".join(traceback.format_exception_only(type(e), e))).lower()
        hints = [h for keys, h in _HINTS if any(k in blob for k in keys)]
        if hints:
            print("\nHINTS:")
            for h in hints:
                print("  - " + h)
        print("\n[FAIL] full log saved (path shown at the top of this file).")
        sys.stdout.flush()
        sys.exit(1)
