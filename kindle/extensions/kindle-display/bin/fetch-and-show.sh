#!/bin/sh
# The loop body. It selects a tile based on the local clock:
# 06:00–06:59 a bundled motivational tile; 07:00–08:59 Bangalore weather;
# 09:00–22:59 the uploaded image. Overnight it leaves the current image alone.

HERE="$(dirname "$0")"
. "$HERE/_common.sh"

CURRENT="$TILE_DIR/current.png"
TMP="$TILE_DIR/.current.png.tmp"
WEATHER_CURRENT="$TILE_DIR/weather.png"
WEATHER_TMP="$TILE_DIR/.weather.png.tmp"
LOWBATT_STOP="$TILE_DIR/lowbatt_stop"
MOTIVATION_DIR="$HERE/../tiles"

log fetch "begin"

# Kindle time is configured locally. Strip a leading zero without relying on
# non-POSIX arithmetic so this remains compatible with BusyBox ash.
HOUR_RAW=$(date +%H 2>/dev/null)
MINUTE_RAW=$(date +%M 2>/dev/null)
HOUR=$(expr "$HOUR_RAW" + 0 2>/dev/null || echo 0)
MINUTE=$(expr "$MINUTE_RAW" + 0 2>/dev/null || echo 0)

# Sleep until the next hour boundary. After the 22:00 check we sleep through
# the night and let the 06:00 motivational window start the next day.
if [ "$HOUR" -gt 22 ] || [ "$HOUR" -lt 6 ]; then
  HOURS_TO_SIX=$(( (30 - HOUR) % 24 ))
  NEXT_WAKE_SECONDS=$(( HOURS_TO_SIX * 3600 - MINUTE * 60 ))
else
  NEXT_WAKE_SECONDS=$(( 3600 - MINUTE * 60 ))
fi
[ "$NEXT_WAKE_SECONDS" -le 0 ] && NEXT_WAKE_SECONDS=60

# Give the persistent RTC listener the actual next transition rather than a
# fixed cadence. The listener is a separate process, so use a tiny state file
# instead of relying on shell-variable inheritance.
WAKE_INTERVAL_FILE="$TILE_DIR/next-wake-seconds"
echo "$NEXT_WAKE_SECONDS" > "$WAKE_INTERVAL_FILE"
REFRESH_SECONDS="$NEXT_WAKE_SECONDS"
log fetch "time=${HOUR_RAW}:${MINUTE_RAW}, next wake in ${REFRESH_SECONDS}s"

# Check battery before doing anything expensive.
BATT=$(lipc-get-prop com.lab126.powerd battLevel 2>/dev/null || echo 100)
log fetch "battery=$BATT%"
if [ "$BATT" -le "$LOWBATT_THRESHOLD" ]; then
  log fetch "battery <= ${LOWBATT_THRESHOLD}%, entering low-battery mode"
  if "$HERE/wifi-on.sh"; then
    LOWBATT_IMG="$TILE_DIR/lowbatt.png"
    HTTP_LB=$(curl -sS -L -k \
      -o "$LOWBATT_IMG" \
      -w "%{http_code}" \
      --connect-timeout 10 \
      --max-time 60 \
      "$SERVER_URL/current-lowbatt.png" 2>>"$LOG_FILE") || HTTP_LB="000"
    log fetch "lowbatt GET -> $HTTP_LB"
    "$HERE/wifi-off.sh"
    if [ "$HTTP_LB" = "200" ] && [ -f "$LOWBATT_IMG" ]; then
      cp "$LOWBATT_IMG" "$CURRENT"
      /usr/sbin/eips -f -g "$CURRENT" >>"$LOG_FILE" 2>&1
    fi
  else
    log fetch "no wifi for lowbatt fetch, keeping current image"
  fi
  touch "$LOWBATT_STOP"
  log fetch "lowbatt_stop sentinel created, exiting"
  exit 0
fi

# publish_screensaver: copy its image into linkss's screensaver folder,
# overwriting both default slots so the hack's random picker always lands on it.
publish_screensaver() {
  DISPLAY_IMAGE="$1"
  if [ ! -f "$DISPLAY_IMAGE" ]; then
    log fetch "display image missing: $DISPLAY_IMAGE"
    return
  fi
  if [ ! -d "$SS_DIR" ]; then
    log fetch "screensaver dir $SS_DIR missing, falling back to eips"
    /usr/sbin/eips -g "$DISPLAY_IMAGE" >>"$LOG_FILE" 2>&1
    return
  fi
  for f in $SS_FILES; do
    cp "$DISPLAY_IMAGE" "$SS_DIR/$f" 2>>"$LOG_FILE"
  done
  log fetch "screensavers updated"

  state_now=$(lipc-get-prop com.lab126.powerd state 2>/dev/null)
  case "$state_now" in
    screenSaver|readyToSuspend)
      /usr/sbin/eips -f -g "$DISPLAY_IMAGE" >>"$LOG_FILE" 2>&1
      log fetch "eips repaint (state=$state_now)"
      ;;
  esac
  awake=$(lipc-get-prop com.lab126.powerd state 2>/dev/null)
  log fetch "powerd.state=$awake"
  lipc-set-prop -i com.lab126.powerd rtcWakeup "$REFRESH_SECONDS" 2>/dev/null \
    && log fetch "rtcWakeup armed for +${REFRESH_SECONDS}s (direct)"
  if [ "$awake" = "active" ]; then
    lipc-set-prop com.lab126.powerd powerButton 1 2>>"$LOG_FILE"
    log fetch "powerButton 1 sent (sleep)"
  fi
}

# 06:00–06:59: show one of seven pre-rendered local tiles. %j is POSIX and
# changes the selected tile daily without a network request.
if [ "$HOUR" -eq 6 ]; then
  DAY_OF_YEAR=$(date +%j 2>/dev/null)
  TILE_INDEX=$(expr "$DAY_OF_YEAR" % 7 + 1 2>/dev/null || echo 1)
  MOTIVATION_TILE="$MOTIVATION_DIR/motivation-${TILE_INDEX}.png"
  log fetch "morning motivation tile=$TILE_INDEX"
  publish_screensaver "$MOTIVATION_TILE"
  log fetch "done"
  exit 0
fi

# 23:00–05:59: preserve the last visible tile and do not spend battery on Wi-Fi.
# The 22:00 hourly uploaded-image check is the last network request of the day.
if [ "$HOUR" -gt 22 ] || [ "$HOUR" -lt 6 ]; then
  log fetch "overnight quiet period; keeping current display"
  log fetch "done"
  exit 0
fi

# Wi-Fi up. If it fails, redisplay whatever we have and bail — the wall keeps
# showing the last good image rather than going blank.
if ! "$HERE/wifi-on.sh"; then
  log fetch "no wifi; redisplaying cached"
  [ -f "$CURRENT" ] && /usr/sbin/eips -g "$CURRENT" >>"$LOG_FILE" 2>&1
  exit 1
fi

# During the 07:00–08:59 window, use the server-rendered Bangalore forecast.
# No JSON parsing or weather rendering happens on the Kindle.
if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 9 ]; then
  FETCHED_IMAGE="$WEATHER_CURRENT"
  TMP="$WEATHER_TMP"
  HTTP=$(curl -sS -L -k \
    -o "$TMP" \
    -w "%{http_code}" \
    --connect-timeout 10 \
    --max-time 60 \
    "$SERVER_URL/weather.png" 2>>"$LOG_FILE") || HTTP="000"
else
  FETCHED_IMAGE="$CURRENT"
  # curl -z compares the server's Last-Modified to the local file's mtime.
  # If unchanged, it returns 304 and writes nothing to $TMP. -k is necessary
  # because this Kindle's CA bundle predates the server certificate chain.
  HTTP=$(curl -sS -L -k \
    -o "$TMP" \
    -w "%{http_code}" \
    -z "$CURRENT" \
    --connect-timeout 10 \
    --max-time 60 \
    "$SERVER_URL/current.png" 2>>"$LOG_FILE") || HTTP="000"
fi

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

case "$HTTP" in
  200)
    # New image. Atomic replace so a half-downloaded file can never display.
    mv "$TMP" "$FETCHED_IMAGE"
    BYTES=$(wc -c < "$FETCHED_IMAGE" | tr -d ' ')
    log fetch "new image, $BYTES bytes"
    publish_screensaver "$FETCHED_IMAGE"
    ;;
  304)
    # Same image server-side. Re-publish anyway in case the user woke the
    # device and we want to send it back to the screensaver.
    rm -f "$TMP"
    if [ -f "$FETCHED_IMAGE" ]; then
      log fetch "304, re-publishing cached"
      publish_screensaver "$FETCHED_IMAGE"
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
