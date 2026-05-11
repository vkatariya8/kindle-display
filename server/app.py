import hmac
import os
import hashlib
from email.utils import formatdate, parsedate_to_datetime
from pathlib import Path

from flask import Flask, abort, jsonify, request, send_file

from render.image import render_photo

SERVER_DIR = Path(__file__).resolve().parent
# TILES_DIR is configurable so Railway can point it at a persistent volume.
# In production we mount /data as the volume; locally we fall back to ./tiles.
TILES_DIR = Path(os.environ.get("TILES_DIR", SERVER_DIR / "tiles"))
SOURCE_PATH = TILES_DIR / "current_source"
RENDERED_PATH = TILES_DIR / "current.png"

# Shared-secret auth for /upload. If unset, /upload is open (dev only).
UPLOAD_TOKEN = os.environ.get("UPLOAD_TOKEN")

ALLOWED_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}

app = Flask(__name__)


def _etag(path: Path) -> str:
    h = hashlib.sha1()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return f'"{h.hexdigest()}"'


@app.post("/upload")
def upload():
    if UPLOAD_TOKEN:
        # Constant-time compare so we don't leak token length via timing.
        provided = request.headers.get("X-Upload-Token", "")
        if not hmac.compare_digest(provided, UPLOAD_TOKEN):
            abort(401, "bad or missing X-Upload-Token")
    f = request.files.get("file")
    if f is None or not f.filename:
        abort(400, "missing 'file' field")
    ext = Path(f.filename).suffix.lower()
    if ext not in ALLOWED_EXTS:
        abort(415, f"unsupported extension {ext}")

    TILES_DIR.mkdir(parents=True, exist_ok=True)
    # Keep extension on the source so Pillow can sniff format reliably.
    src = SOURCE_PATH.with_suffix(ext)
    # Clear any prior source with a different extension.
    for old in TILES_DIR.glob("current_source.*"):
        if old != src:
            old.unlink()
    f.save(src)

    render_photo(src, RENDERED_PATH)
    return jsonify(ok=True, bytes=RENDERED_PATH.stat().st_size)


@app.get("/current.png")
def current_png():
    if not RENDERED_PATH.exists():
        abort(404, "no tile rendered yet")

    mtime = RENDERED_PATH.stat().st_mtime
    last_modified = formatdate(mtime, usegmt=True)
    etag = _etag(RENDERED_PATH)

    # Conditional GET: Kindle uses curl -z, which sends If-Modified-Since.
    ims = request.headers.get("If-Modified-Since")
    inm = request.headers.get("If-None-Match")
    not_modified = False
    if inm and inm == etag:
        not_modified = True
    elif ims:
        try:
            if parsedate_to_datetime(ims).timestamp() >= int(mtime):
                not_modified = True
        except (TypeError, ValueError):
            pass

    if not_modified:
        resp = app.response_class(status=304)
        resp.headers["Last-Modified"] = last_modified
        resp.headers["ETag"] = etag
        return resp

    resp = send_file(RENDERED_PATH, mimetype="image/png", conditional=False)
    resp.headers["Last-Modified"] = last_modified
    resp.headers["ETag"] = etag
    resp.headers["Cache-Control"] = "no-cache"
    return resp


@app.get("/health")
def health():
    return jsonify(ok=True)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050, debug=True)
