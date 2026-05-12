#!/bin/sh
HERE="$(dirname "$0")"
. "$HERE/_common.sh"

PIDFILE="$TILE_DIR/loop.pid"
WAKE_PIDFILE="$TILE_DIR/wake-listener.pid"

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  if kill -0 "$PID" 2>/dev/null; then
    # Kill the loop's child process too — sleep is what we usually catch.
    kill "$PID" 2>/dev/null
    sleep 1
    kill -9 "$PID" 2>/dev/null
    log loop "stopped PID $PID"
  else
    log loop "stale pidfile, PID $PID not running"
  fi
  rm -f "$PIDFILE"
else
  log loop "no loop running"
fi

if [ -f "$WAKE_PIDFILE" ]; then
  WPID=$(cat "$WAKE_PIDFILE")
  if kill -0 "$WPID" 2>/dev/null; then
    kill "$WPID" 2>/dev/null
    sleep 1
    kill -9 "$WPID" 2>/dev/null
    log loop "stopped wake-listener PID $WPID"
  fi
  rm -f "$WAKE_PIDFILE"
fi
