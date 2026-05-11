#!/bin/sh
# The loop body. One shot: wifi on -> conditional GET -> eips -> wifi off.
# Safe to run as often as you like; uses If-Modified-Since to avoid re-downloads.

HERE="$(dirname "$0")"
. "$HERE/_common.sh"

CURRENT="$TILE_DIR/current.png"
TMP="$TILE_DIR/.current.png.tmp"

log fetch "begin"

# Wi-Fi up. If it fails, redisplay whatever we have and bail — the wall keeps
# showing the last good image rather than going blank.
if ! "$HERE/wifi-on.sh"; then
  log fetch "no wifi; redisplaying cached"
  [ -f "$CURRENT" ] && eips -g "$CURRENT" >>"$LOG_FILE" 2>&1
  exit 1
fi

# curl -z compares the SERVER's Last-Modified to the local file's mtime.
# If unchanged, server returns 304 and curl writes nothing to $TMP.
# --max-time bounds the whole transfer so a hung server can't hang our loop.
# -k: skip TLS cert verification. The Kindle Touch ships a ~2013 CA bundle
# that doesn't include modern Let's Encrypt roots, so PythonAnywhere's cert
# fails to validate. The connection is still encrypted; only identity check
# is skipped. Threat model = "someone on home wifi swaps the wallpaper" —
# acceptable for v0. Upload endpoint is still token-protected.
HTTP=$(curl -sS -L -k \
  -o "$TMP" \
  -w "%{http_code}" \
  -z "$CURRENT" \
  --connect-timeout 10 \
  --max-time 60 \
  "$SERVER_URL/current.png" 2>>"$LOG_FILE") || HTTP="000"

log fetch "GET -> $HTTP"

# publish_screensaver: copy $CURRENT into linkss's screensaver folder,
# overwriting BOTH default slots so the hack's random picker always lands
# on our image. Then nudge the device into screensaver mode so it repaints.
publish_screensaver() {
  if [ ! -d "$SS_DIR" ]; then
    log fetch "screensaver dir $SS_DIR missing, falling back to eips"
    eips -g "$CURRENT" >>"$LOG_FILE" 2>&1
    return
  fi
  for f in $SS_FILES; do
    cp "$CURRENT" "$SS_DIR/$f" 2>>"$LOG_FILE"
  done
  log fetch "screensavers updated"
  # Tell powerd to enter screensaver mode. If we're already in it, this is
  # effectively a repaint. Framework is not stopped, so power button still
  # wakes the device normally.
  lipc-set-prop com.lab126.powerd toScreenSaver 2>>"$LOG_FILE"
}

case "$HTTP" in
  200)
    # New image. Atomic replace so a half-downloaded file can never display.
    mv "$TMP" "$CURRENT"
    BYTES=$(wc -c < "$CURRENT" | tr -d ' ')
    log fetch "new image, $BYTES bytes"
    publish_screensaver
    ;;
  304)
    # Same image server-side. Re-publish anyway in case the user woke the
    # device and we want to send it back to the screensaver.
    rm -f "$TMP"
    if [ -f "$CURRENT" ]; then
      log fetch "304, re-publishing cached"
      publish_screensaver
    else
      log fetch "304 but no cached file (shouldn't happen)"
    fi
    ;;
  *)
    # Network or server problem. Leave the existing display alone.
    rm -f "$TMP"
    log fetch "unexpected status, keeping display"
    ;;
esac

"$HERE/wifi-off.sh"
log fetch "done"
