# Deploy notes

Server runs on PythonAnywhere (free tier) at
`https://vkatariya8.pythonanywhere.com`. The Kindle pulls
`/current.png` from there every hour. The web UI lives at
`/u/<UPLOAD_TOKEN>/`.

## Push a server change

From your laptop:
```bash
git push
```

Then on PA (**Consoles → Bash**):
```bash
cd ~/kindle-display
git pull
```

What you do next depends on what changed:

| If you changed... | Then run |
|---|---|
| Python code only (no new imports) | (nothing) — go straight to Reload |
| `requirements.txt` (new or updated deps) | `.venv/bin/pip install -r requirements.txt` |
| The WSGI file or any env var | (re-edit it via the Web tab) |
| Static files / templates only | (nothing) — Reload picks them up |

Then **Web tab → Reload** (the green button). Refresh your URL to confirm.

## Common failure modes

### `ModuleNotFoundError: No module named '<x>'`

You added an import that needs a new package. The pull updated the
code but PA's virtualenv still doesn't have the lib. Fix:
```bash
cd ~/kindle-display && .venv/bin/pip install -r requirements.txt
```
Reload. If you only want to install one missing thing, `.venv/bin/pip
install <name>` works too — but installing from requirements.txt keeps
the venv in sync with the repo, which is what you want long-term.

### 502 / "Something went wrong"

Almost always an import error or a syntax error at module top level.
Check the **Web tab → Error log** for the actual traceback. The error
log is more useful than the server log for crashes — server log is for
request-handling errors after the app boots.

### Changes "don't seem to apply"

You forgot to hit Reload. PA serves the app from a forked process; new
code is only loaded when the process restarts. Reload restarts it.

## Push a Kindle-side change

Kindle changes don't go through PA. Edit `kindle/extensions/kindle-display/`
files, then either:
- Plug the Kindle in and copy the changed files into
  `/Volumes/Kindle/extensions/kindle-display/` (mirror the structure).
- Or, if you only changed scripts you've already deployed once,
  overwrite individual files.

Eject, unplug, open KUAL. New menu entries appear after KUAL refreshes
(KUAL menu → Refresh KUAL, or just relaunch).

## Rotate the upload token

If you suspect the token leaked:
1. Generate a new one: `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`
2. PA → Web tab → edit the WSGI config file → update `UPLOAD_TOKEN`.
3. Reload.
4. Update the bookmark on every device and any saved `curl` aliases.
5. The Kindle doesn't need the token (download only), so nothing to
   change on-device.
