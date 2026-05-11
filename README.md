# kindle-display

Turning a jailbroken Kindle Touch (2010) into a wall-mounted e-ink display that
shows photos, quotes, and ambient information tiles. Refreshes once per hour.

## Architecture

```
   ┌──────────────┐   HTTPS, hourly      ┌──────────────────┐
   │   Kindle     │  ─────────────────▶  │     Server       │
   │  (dumb glass)│  ◀─────────────────  │ (does the work)  │
   └──────────────┘   600×800 PNG        └──────────────────┘
```

The Kindle is intentionally dumb. It wakes on a cron schedule, brings up Wi-Fi,
issues a conditional GET (`If-Modified-Since`), and either pipes the result into
`eips` or goes back to sleep. No rendering, no logic, no parsing.

The server does everything interesting:

- Accepts uploads (images, quotes, anything else)
- Renders them to Kindle-native PNGs (600×800, 4-bit greyscale,
  Floyd–Steinberg dithered)
- Serves the current tile at a stable URL with proper cache headers
- Eventually: rotates between tile types based on time of day, pulls from
  external sources (weather, calendar, RSS, etc.)

## Why this design

- **Battery life.** Wi-Fi off by default; a single fetch + display per hour.
  With airplane-mode toggling via `lipc-set-prop`, a Touch on this loop runs
  for weeks per charge.
- **Robustness.** The Kindle script is ~30 lines of `ash`. If the server is
  down, the Kindle just shows whatever it last fetched. If the Kindle dies, the
  server is unaffected.
- **Iteration speed.** All the interesting work (rendering, dithering,
  composition) happens server-side in Python, where iteration is fast. The
  Kindle never needs to be reflashed or even touched after initial setup.
- **Portable client.** The same server endpoint can later drive an ESP32 +
  e-ink panel, a Raspberry Pi, or a browser tab. The Kindle is just one of
  several possible "dumb glass" clients.

## Repo layout

```
kindle-display/
├── README.md              # this file
├── CLAUDE.md              # context for Claude Code sessions
├── server/                # Flask app + rendering pipeline
│   ├── app.py
│   ├── render/            # tile renderers (image, quote, dashboard, …)
│   ├── tiles/             # stored tiles
│   ├── fonts/
│   ├── requirements.txt
│   └── Dockerfile
├── kindle/                # everything that runs on the device
│   ├── kual/extensions/   # KUAL menu entry
│   ├── bin/               # fetch-and-show.sh, wifi-on.sh, wifi-off.sh
│   ├── etc/crontab.sample
│   └── install.sh
├── tools/
│   └── preview.py         # render a tile locally without deploying
└── docs/
    ├── kindle-setup.md
    └── server-deploy.md
```

## Hardware

- Kindle Touch (4th gen, 2011 — model D01200), firmware 5.3.x, jailbroken
- KUAL launcher installed
- Screen: 600×800, 16-level greyscale (4-bit)

## Status

- [ ] Server: minimal Flask app with upload + `/current.png`
- [ ] Server: image renderer (photo → dithered greyscale PNG)
- [ ] Server: quote renderer (text → typeset PNG)
- [ ] Server: conditional GET (`Last-Modified`, `ETag`)
- [ ] Local preview tool
- [ ] Kindle: `fetch-and-show.sh` with `curl -z` and `eips -g`
- [ ] Kindle: Wi-Fi toggle scripts via `lipc-set-prop`
- [ ] Kindle: KUAL menu entry to start/stop the cron loop
- [ ] Kindle: `install.sh` to deploy from laptop over SSH
- [ ] Server: tile rotation by time of day
- [ ] Server: tile library (weather, poem-of-the-day, generative art, etc.)
- [ ] Auth on the upload endpoint
- [ ] Deployment (Docker + small VPS or home server)

## Roadmap

**v0** — boring but working: photo upload, Kindle fetches and displays it
hourly. Single tile at a time.

**v1** — multiple tile types (photo, quote, simple dashboard) with a rotation
schedule. Local preview tool. Decent dithering.

**v2** — ambient tiles pulling from external sources (weather, calendar,
poem-of-the-day, today-in-history). Time-of-day rotation.

**v3** — second client: ESP32 + Waveshare panel hitting the same endpoint.

## References

- [MobileRead Kindle Developer's Corner](https://www.mobileread.com/forums/forumdisplay.php?f=150)
  — canonical reference for `eips`, `lipc`, KUAL, and firmware-specific quirks.
- [MagInkDash](https://github.com/speedyg0nz/MagInkDash) — Raspberry Pi e-ink
  dashboard. Good code to crib from for rendering and layout.
- Pillow's `Image.convert("1", dither=Image.FLOYDSTEINBERG)` and the
  `"L"` mode for 8-bit greyscale.
