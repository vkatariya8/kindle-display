#!/bin/sh
# Start a background loop that fetches every $REFRESH_SECONDS.
# Writes its PID to $TILE_DIR/loop.pid for loop-stop.sh.
# Survives this shell exiting (nohup), but does NOT survive reboot —
# rerun this entry from KUAL after a power cycle.

HERE="$(dirname "$0")"
. "$HERE/_common.sh"

PIDFILE="$TILE_DIR/loop.pid"
WAKE_PIDFILE="$TILE_DIR/wake-listener.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  log loop "already running, PID $(cat "$PIDFILE")"
  exit 0
fi

# Spawn the persistent wake-listener daemon. Cleans up any stale instance
# first so we don't end up with multiples after restarts.
if [ -f "$WAKE_PIDFILE" ] && kill -0 "$(cat "$WAKE_PIDFILE")" 2>/dev/null; then
  kill "$(cat "$WAKE_PIDFILE")" 2>/dev/null
fi
"$HERE/wake-listener.sh" >>"$LOG_FILE" 2>&1 &
echo $! > "$WAKE_PIDFILE"
log loop "wake-listener PID $(cat "$WAKE_PIDFILE")"

# We embed the fetch path with absolute reference because nohup loses cwd.
FETCH="$HERE/fetch-and-show.sh"

# Cadence is driven by the RTC wakealarm armed inside fetch-and-show.sh —
# the device suspends after each fetch and wakes itself $REFRESH_SECONDS
# later. The userspace `sleep` here is just a safety floor so we don't
# busy-loop in the (logged) case where arming the wakealarm fails.
TICK=60

# BusyBox sh doesn't ship nohup, but the trailing `&` plus stdin/out/err
# redirection is enough — the child won't get SIGHUP'd by KUAL's exit
# because KUAL launches scripts as detached children already.
sh -c "
  while true; do
    '$FETCH'
    sleep $TICK
  done
" >>"$LOG_FILE" 2>&1 &

echo $! > "$PIDFILE"
log loop "started, PID $(cat "$PIDFILE"), tick ${TICK}s, wake every ${REFRESH_SECONDS}s"
