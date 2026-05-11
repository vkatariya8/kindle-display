# Kindle side

Drag-and-drop install for the Kindle Touch (5.3.x, jailbroken, KUAL).
No SSH required.

## Install

1. Edit `extensions/kindle-display/config.sh` if your server URL differs from
   the default. The token isn't needed on the Kindle (it only downloads).
2. Plug the Kindle into your laptop with the USB cable. It mounts as a drive.
3. Copy the **whole `extensions/kindle-display/` folder** into the Kindle's
   `extensions/` folder, so the on-device path becomes:

   ```
   /mnt/us/extensions/kindle-display/
   ├── config.sh
   ├── menu.json
   └── bin/
       ├── fetch-and-show.sh
       ├── loop-start.sh
       ├── loop-stop.sh
       ├── show-log.sh
       ├── wifi-on.sh
       ├── wifi-off.sh
       └── _common.sh
   ```
4. Eject the Kindle and unplug.
5. Open KUAL on the Kindle. You should see a new entry **kindle-display** with
   four items: Refresh now, Start hourly loop, Stop hourly loop, Show log.

## First-run checklist

1. Upload a tile from your laptop:
   ```bash
   curl -H "X-Upload-Token: <token>" \
        -F "file=@photo.png" \
        https://vkatariya8.pythonanywhere.com/upload
   ```
2. On the Kindle, KUAL → kindle-display → **Refresh now**. You should see the
   screen flash and your photo appear (~10–15 seconds for Wi-Fi + fetch +
   display).
3. If something looks wrong, KUAL → **Show log on screen** displays the last
   30 lines of `/mnt/us/kindle-display.log`.
4. Happy? Tap **Start hourly loop** to begin the background fetcher.

## Debugging without SSH

- Plug into laptop, open `/Volumes/Kindle/kindle-display.log` in any editor.
- The log timestamps every wifi/fetch event and records HTTP status codes.

## Known v0 limitations

- **Loop does not survive reboot.** Tap "Start hourly loop" again after any
  power cycle. Persistent-on-boot needs an upstart or rc.d entry; deferred.
- **Framework repaints.** Even with `eips -g`, the Kindle's UI may briefly
  paint over our image (clock, status bar). The hourly redraw on 304
  responses masks this. A cleaner fix is `stop lab126_gui` at boot — not in
  v0 because it's firmware-sensitive.
- **TLS.** Kindle Touch's curl is old but PythonAnywhere's certs work fine
  in testing. If you ever see `SSL connect error` in the log, we can fall
  back to a `http://` proxy or pin a specific cert bundle.

## Uninstall

Plug in, delete the `extensions/kindle-display/` folder. That's it.
The cached image at `/mnt/us/kindle-display/` and the log file at
`/mnt/us/kindle-display.log` will linger — delete those too if you care.
