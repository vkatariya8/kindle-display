#!/bin/sh
# Start a background loop that fetches every $REFRESH_SECONDS.
# Writes its PID to $TILE_DIR/loop.pid for loop-stop.sh.
# Survives this shell exiting (nohup), but does NOT survive reboot —
# rerun this entry from KUAL after a power cycle.

HERE="$(dirname "$0")"
. "$HERE/_common.sh"

PIDFILE="$TILE_DIR/loop.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  log loop "already running, PID $(cat "$PIDFILE")"
  exit 0
fi

# We embed the fetch path with absolute reference because nohup loses cwd.
FETCH="$HERE/fetch-and-show.sh"
INTERVAL="$REFRESH_SECONDS"

# BusyBox sh doesn't ship nohup, but the trailing `&` plus stdin/out/err
# redirection is enough — the child won't get SIGHUP'd by KUAL's exit
# because KUAL launches scripts as detached children already.
sh -c "
  while true; do
    '$FETCH'
    sleep $INTERVAL
  done
" >>"$LOG_FILE" 2>&1 &

echo $! > "$PIDFILE"
log loop "started, PID $(cat "$PIDFILE"), interval ${INTERVAL}s"
