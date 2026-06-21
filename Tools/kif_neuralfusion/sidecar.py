#!/usr/bin/env python3
"""KIF NeuralFusion - on-device sidecar (serves the v1 backend contract).

  GET /health                         -> 200 "ok"          (model ready probe)
  GET /generate?head=H&body=B[&third=T][&seed=S] -> 200 image/png  (288 RGBA)
                                         third=T => triple fusion; head==body => self
                                         404 if a parent sprite is missing
                                         400 on bad params

Tiers (best available wins, transparently):
  1. NEURAL   - if trained diffusion weights + torch are present, the compositor
                output is used as the img2img init image and refined to human-
                custom quality (see neural.py / train/). GPU strongly preferred.
  2. COMPOSITOR - always available: pure pillow+numpy palette-harmonising fusion.

Dependencies for the runs-anywhere tier: pillow, numpy ONLY (stdlib HTTP server).
Bind is localhost only; generation is user-initiated in-game, never during a
battle. Every request is exception-guarded so the game never crashes on us.
"""
import os, sys, io, json, time, threading, urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compositor as COMP  # noqa: E402

HOST = os.environ.get("KIF_SIDECAR_HOST", "127.0.0.1")
PORT = int(os.environ.get("KIF_SIDECAR_PORT", "8760"))

# Optional neural refiner (soft import; absent/failed import => compositor only).
try:
    import neural as NEURAL  # noqa: E402
except Exception:
    NEURAL = None


def find_game_root():
    """Locate the KIF install root (the dir that has Graphics/BaseSprites or
    Graphics/Battlers). Walk up from this script and from CWD; env wins."""
    env = os.environ.get("KIF_GAME_ROOT")
    starts = []
    if env:
        starts.append(env)
    starts += [HERE, os.getcwd()]
    seen = set()
    for s in starts:
        d = os.path.abspath(s)
        for _ in range(6):
            if d in seen:
                break
            seen.add(d)
            if (os.path.isdir(os.path.join(d, "Graphics", "BaseSprites")) or
                    os.path.isdir(os.path.join(d, "Graphics", "Battlers"))):
                return d
            nd = os.path.dirname(d)
            if nd == d:
                break
            d = nd
    # last resort: assume <root>/Tools/kif_neuralfusion -> two up
    return os.path.abspath(os.path.join(HERE, "..", ".."))


GAME_ROOT = find_game_root()
BASE_ROOTS = [GAME_ROOT, os.getcwd()]
_neural_ready = False
if NEURAL is not None:
    try:
        _neural_ready = bool(NEURAL.available(GAME_ROOT))
    except Exception:
        _neural_ready = False

print(f"[KIF NeuralFusion] game root: {GAME_ROOT}")
print(f"[KIF NeuralFusion] tier: {'NEURAL+compositor' if _neural_ready else 'compositor'}")


def render_png(head, body, seed, third=None):
    """Return PNG bytes or None if a parent sprite can't be found. `third` set =>
    triple fusion (head, body, third); head == body => self-fusion."""
    params = COMP.load_params(os.path.join(HERE, "params.json"))
    if third is not None and str(third) != "":
        img = COMP.generate_triple(head, body, third, seed=seed, base_roots=BASE_ROOTS, params=params)
    else:
        img = COMP.generate_fusion(head, body, seed=seed, base_roots=BASE_ROOTS, params=params)
    if img is None:
        return None
    if _neural_ready:
        try:
            refined = NEURAL.refine(img, head, body, seed, GAME_ROOT, third=third)
            if refined is not None:
                img = refined
        except Exception as e:
            print(f"[KIF NeuralFusion] neural refine failed, using compositor: {e}")
    buf = io.BytesIO()
    img.convert("RGBA").save(buf, format="PNG")
    return buf.getvalue()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code, body=b"", ctype="text/plain"):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except Exception:
            pass

    def do_GET(self):
        try:
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path
            if path == "/health":
                return self._send(200, "ok")
            if path == "/generate":
                q = urllib.parse.parse_qs(parsed.query)
                head = (q.get("head") or [""])[0].strip()
                body = (q.get("body") or [""])[0].strip()
                third = (q.get("third") or [""])[0].strip()
                seed = (q.get("seed") or ["0"])[0].strip() or "0"
                if not head or not body:
                    return self._send(400, "missing head/body")
                try:
                    seed = int(seed)
                except Exception:
                    seed = abs(hash(seed)) % (10 ** 8)
                png = render_png(head, body, seed, third or None)
                if png is None:
                    miss = f"{head}, {body}" + (f" or {third}" if third else "")
                    return self._send(404, f"no base sprite for {miss}")
                return self._send(200, png, "image/png")
            return self._send(404, "not found")
        except Exception as e:
            return self._send(500, f"error: {e}")

    def log_message(self, *a):  # quiet
        pass


def main():
    srv = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"[KIF NeuralFusion] listening on http://{HOST}:{PORT}  "
          f"(/health, /generate?head=H&body=B[&third=T][&seed=S])")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()


if __name__ == "__main__":
    main()
