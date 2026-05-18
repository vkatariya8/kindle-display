# CLAUDE.md

Context for Claude Code working on this repo. Read this before making changes.

## What this project is

A wall-mounted e-ink display built from a jailbroken Kindle Touch. The Kindle
fetches a pre-rendered PNG from a server every 30 minutes (configurable) and
displays it. The server does all the rendering (photos, quotes, dashboards)
and serves the current tile at a stable URL. See `README.md` for the full
architecture.

**Current status:** The project is functional end-to-end. Server is deployed on
PythonAnywhere, the Kindle fetches and displays tiles via the linkss screensaver
hack with RTC wakeup scheduling, and there's a working web UI for uploading
photos and text quotes (with optional Unsplash smart backgrounds).

## The two sides of this codebase have very different constraints

### Server side (`server/`, `tools/`)

Normal modern Python 3.11+ environment. Pillow for image work, Flask for the
HTTP layer. Use whatever standard tooling makes sense — type hints, `pytest`,
`ruff`, etc. This code runs on a laptop or a VPS, not on the Kindle.

### Kindle side (`kindle/`)

This is the part that bites. **Do not assume a normal Linux environment.**

- Shell is BusyBox `ash`, not bash. No `[[ ]]`, no arrays, no `local` in some
  builds, no process substitution, no `${var,,}`. Use POSIX sh idioms.
- Coreutils are BusyBox versions. Flags you take for granted on GNU systems
  (`grep -P`, `sed -i` with backup suffixes, `date -d`, `stat --format`) often
  don't exist or behave differently. Check before using.
- `curl` is present and supports `-z` for `If-Modified-Since`. `wget` is also
  there but less featureful.
- No Python, no Node, no anything heavy. Pure shell + the Kindle's native
  binaries (`eips`, `lipc-set-prop`, `lipc-get-prop`).
- The filesystem layout is unusual. User-writable space is under `/mnt/us/`.
  Things placed elsewhere may be wiped by firmware updates.
- The Kindle framework (`lab126_gui` and friends) will fight you for the
  screen. Either stop it, or use the documented "screensaver hack" pattern.

When generating Kindle-side code, prefer paranoia over cleverness. Log to a
file under `/mnt/us/`, check exit codes, fail loud.

## Hardware specifics

- **Device:** Kindle Touch (4th gen, 2011, model D01200)
- **Firmware:** 5.3.x (jailbroken)
- **Launcher:** KUAL installed at `/mnt/us/extensions/`
- **Screen:** 600×800 px, 16-level greyscale (4-bit), portrait native
- **Wi-Fi:** controlled via `lipc-set-prop com.lab126.cmd wirelessEnable 1/0`

If you're unsure about a Kindle-side detail, ask before generating code rather
than guessing — the MobileRead forums are the source of truth, and getting it
wrong on a jailbroken device can mean a long recovery.

## Rendering pipeline conventions

- All output PNGs are exactly **600×800**, mode `"L"` (8-bit greyscale) or
  `"1"` (1-bit), saved as PNG. The Kindle handles both.
- Dithering: Floyd–Steinberg via Pillow (`Image.convert(..., dither=Image.FLOYDSTEINBERG)`).
- Fonts live in `server/fonts/`. Default to a serif for quotes (e.g. EB
  Garamond) and a clean sans for dashboards (e.g. Inter or Source Sans).
- Tiles are stored in `server/tiles/` as the *source* (original photo, quote
  text, etc.). The rendered PNG is generated on demand and cached.
- The current tile is always available at `GET /current.png` with proper
  `Last-Modified` and `ETag` headers so the Kindle's `curl -z` works.

## HTTP contract between Kindle and server

- `GET /current.png` — returns the current rendered tile. Must support
  `If-Modified-Since` (return `304` when unchanged). Must set `Last-Modified`.
- `POST /upload` — accepts an image file with `X-Upload-Token` header. Stores
  it as the new current tile.
- `GET /health` — returns 200 with a tiny JSON body. Used for debugging from
  the Kindle.

The Kindle never parses JSON, never follows redirects it doesn't expect, and
never processes anything but the raw PNG bytes. Keep the contract minimal.

### Web UI and auth

The web UI lives at `/u/<token>/` where `<token>` is the value of
`UPLOAD_TOKEN`. Wrong tokens get a 404 (not 401) to hide the endpoint's
existence. The UI supports a draft/preview workflow: `POST /u/<token>/draft`
renders a preview, and `POST /u/<token>/publish` atomically promotes it to
`current.png`. The API endpoint (`POST /upload` with `X-Upload-Token` header)
still works independently for `curl`-based uploads.

## Environment variables

- `UPLOAD_TOKEN` — shared secret for the `/upload` API and the web UI URL slug.
  If unset, upload is open (dev only). Set via PA's WSGI config.
- `UNSPLASH_ACCESS_KEY` — Unsplash API key for the smart background feature.
  Optional; if unset, smart_bg falls back to plain text rendering.
- `TILES_DIR` — override path for tile storage. Defaults to `server/tiles/`.
  Useful when the hosting platform needs a persistent volume mount.

## Working style

- **Small, focused changes.** This is a hobby project; PRs in spirit, not in
  practice. Don't refactor things that aren't in scope for the current task.
- **Server before Kindle.** The render pipeline should be solid and previewable
  on a laptop before any of it gets shipped to the device. Use `tools/preview.py`.
- **Run things.** When you write rendering code, render a sample and inspect
  the output. When you write a shell script, at least `sh -n` it.
- **Don't add dependencies casually.** Pillow + Flask + `requests` cover most
  of what we need server-side. Resist the urge to pull in heavy frameworks.
- **Comments explain *why*, not *what*.** The "why" is often a Kindle quirk or
  a dithering choice that won't be obvious six months later.

## Deployment

Hosted on PythonAnywhere (free tier) at `https://vkatariya8.pythonanywhere.com`.
Deploy workflow: `git push` locally, then on PA's Bash console run
`cd ~/kindle-display && git pull && .venv/bin/pip install -r requirements.txt`,
then hit Reload on the Web tab. Env vars are set in PA's WSGI config file.
See `docs/deploy.md` for the full runbook and common failure modes.

## Testing

No formal test suite. Testing is manual:
- Use `tools/preview.py` for local rendering checks (photo tiles).
- Use `tools/compare.html` to visually diff source vs rendered output.
- Run server locally: `UPLOAD_TOKEN=dev python server/app.py`
- Kindle-side: check `/mnt/us/kindle-display.log` via KUAL "Show log on
  screen" or by mounting the Kindle as a USB drive.

## Out of scope (for now)

- Multi-user / multi-device support
- Tile history or versioning
- Scheduled / future-dated tile posts
- ESP32 client (planned for v3, but separate concern)
- OTA updates to the Kindle script (just SSH and re-run `install.sh`)
- Formal test suite

## Useful one-liners

```bash
# SSH to the Kindle (assuming USBNetwork is set up)
ssh root@192.168.1.x   # password is the usual jailbreak default; change it

# Manually display a PNG on the Kindle
eips -g /mnt/us/current.png

# Toggle Wi-Fi from the Kindle shell
lipc-set-prop com.lab126.cmd wirelessEnable 1
lipc-set-prop com.lab126.cmd wirelessEnable 0

# Stop the Kindle UI so it stops fighting us for the screen
# (firmware-dependent — confirm before running)
stop lab126_gui

# Local preview of a tile without deploying
python tools/preview.py --tile quote --text "..." --out preview.png
```
