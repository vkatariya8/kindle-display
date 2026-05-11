# Plan: web UI for tile uploads

Pick up this plan in a fresh session and execute. Repo is already wired
to PythonAnywhere; the Kindle pulls `/current.png` over HTTPS hourly via
the linkss screensaver hack. See `README.md` and `CLAUDE.md` for context.

## Context

Today, the only way to push a new tile is `curl -F file=@x.png` with an
`X-Upload-Token` header. That's fine for the author; it's hostile for a
non-technical co-user. We want a web page two people can hit from a
bookmark — type a quote or pick a photo, see what it'll look like on the
Kindle's e-ink, hit Confirm. Anything that lands as `/current.png` gets
displayed on the wall within the next refresh cycle.

Auth model is "obscure URL." The token already living in `UPLOAD_TOKEN`
becomes the URL slug. Anyone without it sees a 404.

## Decisions (confirmed with user)

| Question | Choice |
|---|---|
| Text style | Single quote: large serif, centered, generous margins |
| Devices | Both mobile and desktop, responsive |
| Flow | Preview-then-Confirm (two-step) |
| Auth | Single secret URL `/u/<UPLOAD_TOKEN>/`, no separate UI token |

## Server changes

### Routes (all in `server/app.py`)

| Method | Path | Purpose |
|---|---|---|
| GET | `/u/<token>/` | Render the form page (text textarea + file picker). |
| POST | `/u/<token>/draft` | Accept text OR image; render via existing pipeline; save as `TILES_DIR/draft.png`; redirect back to the form with preview shown. |
| GET | `/u/<token>/draft.png` | Serve the latest draft (used by the preview `<img>` tag). |
| POST | `/u/<token>/publish` | Atomically move `draft.png` → `current.png` (and copy source to `current_source.*`). Show "Sent to Kindle" confirmation. |
| (keep) `POST /upload` | unchanged — still the curl/API path with `X-Upload-Token` header. |

All `/u/<token>/...` routes use `hmac.compare_digest(token, UPLOAD_TOKEN)`
and return 404 (not 401) on mismatch — hides existence.

### Text renderer

New module: `server/render/text.py`, function `render_quote(text, dst_path)`.

- Same 600×800 canvas, mode `"L"`, white background, end with
  Floyd–Steinberg dither via the existing pipeline. Consider extracting
  the dither/save step into a helper in `server/render/__init__.py` so
  both `image.py` and `text.py` use the same finish.
- Font: ship **EB Garamond** (Open Font License, free to redistribute).
  Drop the regular and italic TTFs in `server/fonts/`. Commit them.
- Layout:
  1. Word-wrap to fit ~90% of the canvas width.
  2. Auto-size: start at ~72pt, shrink in 4pt steps until all lines fit
     vertically with ~10% top/bottom margin.
  3. Center horizontally and vertically as a block.
  4. Draw glyphs in black on white.
- Use Pillow's `ImageFont.truetype` + `ImageDraw.multiline_text` with
  `align="center"`. Wrapping done manually with `font.getlength()` per
  word so we can break correctly on whitespace.

### Image upload path

The form's image input reuses `render.image.render_photo`. The only new
work is the HTTP plumbing — `request.files.get("file")` and the same
extension whitelist as `/upload`.

## Front-end

Single Jinja2 template: `server/templates/upload.html`. Rendered from
`GET /u/<token>/`. Inline CSS, no JS framework. Aim for ~150 lines total.

### Layout (responsive, single column on mobile)

```
+------------------------------+
| Kindle wall display          |
+------------------------------+
| [textarea: "Type a quote…"]  |
| [file input: "or pick image"]|
| [Preview button]             |
+------------------------------+
| (after submit:)              |
| <img src="/u/<t>/draft.png"> |
| [Send to Kindle]  [Redo]     |
+------------------------------+
```

- Textarea and file input mutually exclusive — if a file is picked, the
  text is ignored (and vice versa). Document this in the UI copy.
- Mobile: `<input type="file" accept="image/*" capture="environment">`
  so phones default to camera; user can still browse.
- Preview image displayed at native aspect ratio (~3:4), max-width 600px.
- "Send to Kindle" posts to `/u/<token>/publish` and shows a success page
  with a "Make another" link back to the form.

### Cache busting on preview

Preview `<img>` URL needs `?t=<timestamp>` query string so the browser
doesn't show a stale draft after re-submit.

## File layout after this work

```
server/
├── app.py                  # +4 routes, +token URL guard
├── render/
│   ├── __init__.py         # (optional) shared dither/save helper
│   ├── image.py            # unchanged
│   └── text.py             # NEW — render_quote(text, dst_path)
├── fonts/
│   ├── EBGaramond-Regular.ttf   # NEW (commit)
│   └── EBGaramond-Italic.ttf    # NEW (commit, optional)
├── templates/
│   └── upload.html         # NEW
└── tiles/
    ├── current.png         # served to Kindle
    ├── current_source.*    # last source uploaded
    └── draft.png           # NEW — pre-publish preview
```

## Verification

Run locally with the dev gunicorn config from earlier:

```bash
UPLOAD_TOKEN=devsecret TILES_DIR=/tmp/kdtiles PORT=5051 \
  .venv/bin/gunicorn --chdir server --bind 127.0.0.1:5051 --workers 1 app:app
```

Then:

1. `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5051/u/wrong/` → **404**
2. `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5051/u/devsecret/` → **200**
3. Open the page in a browser; type "Hello, world." and click Preview.
   Confirm an `<img>` shows a 600×800 centered serif quote.
4. Click "Send to Kindle." `curl http://127.0.0.1:5051/current.png` should
   return the same bytes as the preview.
5. Same flow with an image upload (use `photo.png`). Confirm preview
   matches `tools/preview.py --src photo.png` byte-for-byte.
6. `curl -H "X-Upload-Token: devsecret" -F "file=@photo.png"
   http://127.0.0.1:5051/upload` still works — regression check on the
   API path.
7. Responsive sanity-check: DevTools mobile emulation, look at iPhone SE
   width (375px). Textarea and file picker stack cleanly.

## Deploy

1. Push to `main`.
2. On PythonAnywhere: `cd ~/kindle-display && git pull`
3. **Web tab → Reload.**
4. Bookmark `https://vkatariya8.pythonanywhere.com/u/<your-token>/` on
   both phones.
5. From the Kindle, KUAL → Kindle Display → "Start wall display" so the
   hourly loop picks up whatever you send.

## Out of scope (defer)

- History/versioning of past tiles
- Multiple recipients / multiple Kindles
- Scheduled future-dated posts
- Per-user accounts
- Server-side rate limiting (URL secrecy is the only mitigation in v1)
- Native font picker / font upload — EB Garamond only
