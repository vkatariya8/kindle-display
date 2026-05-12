import hmac
import os
import hashlib
import time
from email.utils import formatdate, parsedate_to_datetime
from pathlib import Path

from flask import Flask, abort, jsonify, redirect, render_template, request, send_file, url_for

from render.image import render_photo
from render.text import render_quote
from render.unsplash import fetch_photo
from render.smart_bg import render_quote_on_background

SERVER_DIR = Path(__file__).resolve().parent
# TILES_DIR is configurable so Railway can point it at a persistent volume.
# In production we mount /data as the volume; locally we fall back to ./tiles.
TILES_DIR = Path(os.environ.get("TILES_DIR", SERVER_DIR / "tiles"))
SOURCE_PATH = TILES_DIR / "current_source"
RENDERED_PATH = TILES_DIR / "current.png"
DRAFT_PATH = TILES_DIR / "draft.png"

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


def _token_ok(token: str) -> bool:
    if UPLOAD_TOKEN is None:
        return True
    return hmac.compare_digest(token, UPLOAD_TOKEN)


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


# ---------------------------------------------------------------------------
# Web UI routes (obscure-URL auth)
# ---------------------------------------------------------------------------

@app.get("/u/<token>/")
def upload_form(token: str):
    if not _token_ok(token):
        abort(404)
    preview_ts = request.args.get("t", "")
    current_exists = RENDERED_PATH.exists()
    current_mtime = int(RENDERED_PATH.stat().st_mtime) if current_exists else 0
    return render_template(
        "upload.html",
        token=token,
        preview_ts=preview_ts,
        current_exists=current_exists,
        current_mtime=current_mtime,
    )


@app.post("/u/<token>/draft")
def draft(token: str):
    if not _token_ok(token):
        abort(404)

    TILES_DIR.mkdir(parents=True, exist_ok=True)

    text = request.form.get("text", "").strip()
    f = request.files.get("file")

    if f and f.filename:
        # Image upload takes precedence.
        ext = Path(f.filename).suffix.lower()
        if ext not in ALLOWED_EXTS:
            abort(415, f"unsupported extension {ext}")
        src = SOURCE_PATH.with_suffix(ext)
        for old in TILES_DIR.glob("current_source.*"):
            if old != src:
                old.unlink()
        f.save(src)
        render_photo(src, DRAFT_PATH)
    elif text:
        smart_bg = request.form.get("smart_bg") == "on"
        if smart_bg:
            bg = fetch_photo(text)
            if bg:
                render_quote_on_background(text, bg, DRAFT_PATH)
            else:
                # Unsplash missing key / no results — fall back to plain text.
                render_quote(text, DRAFT_PATH)
        else:
            render_quote(text, DRAFT_PATH)
        # Save source for later inspection.
        for old in TILES_DIR.glob("current_source.*"):
            old.unlink()
        src = SOURCE_PATH.with_suffix(".txt")
        src.write_text(text, encoding="utf-8")
    else:
        abort(400, "supply text or an image")

    return redirect(url_for("upload_form", token=token, t=int(time.time())))


@app.get("/u/<token>/draft.png")
def draft_png(token: str):
    if not _token_ok(token):
        abort(404)
    if not DRAFT_PATH.exists():
        abort(404, "no draft yet")
    return send_file(DRAFT_PATH, mimetype="image/png")


@app.post("/u/<token>/publish")
def publish(token: str):
    if not _token_ok(token):
        abort(404)
    if not DRAFT_PATH.exists():
        abort(400, "no draft to publish")

    # Atomically move draft to current.
    tmp = RENDERED_PATH.with_suffix(".tmp")
    DRAFT_PATH.rename(tmp)
    tmp.rename(RENDERED_PATH)

    current_exists = RENDERED_PATH.exists()
    current_mtime = int(RENDERED_PATH.stat().st_mtime) if current_exists else 0
    return render_template(
        "upload.html",
        token=token,
        published=True,
        current_exists=current_exists,
        current_mtime=current_mtime,
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5050, debug=True)
