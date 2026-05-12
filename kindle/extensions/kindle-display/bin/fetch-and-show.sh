#!/bin/sh
# The loop body. One shot: wifi on -> conditional GET -> /usr/sbin/eips -> wifi off.
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
  [ -f "$CURRENT" ] && /usr/sbin/eips -g "$CURRENT" >>"$LOG_FILE" 2>&1
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

# RTC wake is now handled by the persistent wake-listener daemon spawned by
# loop-start.sh (see wake-listener.sh). That daemon listens for powerd's
# readyToSuspend event and arms rtcWakeup whenever it fires. Doing it per-
# fetch was racy: the listener might miss the event, and we'd accumulate
# short-lived listener processes.
#
# Here we just attempt a direct rtcWakeup write as a best-effort early arm
# (works only when powerd is already in ReadyToSuspend, which is rare from
# inside a fetch but harmless to try).

# publish_screensaver: copy $CURRENT into linkss's screensaver folder,
# overwriting BOTH default slots so the hack's random picker always lands
# on our image. Then nudge the device into screensaver mode so it repaints.
publish_screensaver() {
  if [ ! -d "$SS_DIR" ]; then
    log fetch "screensaver dir $SS_DIR missing, falling back to eips"
    /usr/sbin/eips -g "$CURRENT" >>"$LOG_FILE" 2>&1
    return
  fi
  for f in $SS_FILES; do
    cp "$CURRENT" "$SS_DIR/$f" 2>>"$LOG_FILE"
  done
  log fetch "screensavers updated"

  # If the device is already in screensaver mode, the linkss hack won't
  # repaint just because we swapped the PNG underneath it (it picks an
  # image only on entry into screensaver). Force an immediate repaint via
  # eips. Safe in screenSaver/readyToSuspend states; we skip it when active
  # so we don't fight the framework UI.
  state_now=$(lipc-get-prop com.lab126.powerd state 2>/dev/null)
  case "$state_now" in
    screenSaver|readyToSuspend)
      /usr/sbin/eips -f -g "$CURRENT" >>"$LOG_FILE" 2>&1
      log fetch "eips repaint (state=$state_now)"
      ;;
  esac
  # Sleep the device. powerButton 1 simulates a physical power-button press,
  # which is the reliable way to enter screensaver mode on Touch 5.3.x.
  # (lipc com.lab126.powerd.toScreenSaver was a no-op on this firmware.)
  # If the device is already asleep, this would WAKE it — that's why we only
  # call it when we have a fresh image worth showing.
  awake=$(lipc-get-prop com.lab126.powerd state 2>/dev/null)
  log fetch "powerd.state=$awake"

  # Best-effort early arm. The persistent wake-listener will catch any
  # readyToSuspend event afterwards regardless.
  lipc-set-prop -i com.lab126.powerd rtcWakeup "$REFRESH_SECONDS" 2>/dev/null \
    && log fetch "rtcWakeup armed for +${REFRESH_SECONDS}s (direct)"

  # powerButton 1 is a TOGGLE — it sleeps an active device, but wakes a
  # sleeping one. Only press it when the device is fully active.
  if [ "$awake" = "active" ]; then
    lipc-set-prop com.lab126.powerd powerButton 1 2>>"$LOG_FILE"
    log fetch "powerButton 1 sent (sleep)"
  fi
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
