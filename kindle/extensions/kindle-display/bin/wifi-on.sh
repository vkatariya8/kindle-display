#!/bin/sh
# Bring up Wi-Fi and wait until the wifid state machine reports CONNECTED.
# Exits 0 on success, 1 on timeout.

HERE="$(dirname "$0")"
. "$HERE/_common.sh"

log wifi "enable"
lipc-set-prop com.lab126.cmd wirelessEnable 1 2>>"$LOG_FILE"

# Poll cmState. CONNECTED is the post-association steady state on 5.3.x.
# We accept any "connected-ish" state to be defensive across firmware revs.
i=0
while [ $i -lt "$WIFI_TIMEOUT_SECONDS" ]; do
  state=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)
  case "$state" in
    CONNECTED|READY)
      log wifi "up after ${i}s (state=$state)"
      exit 0
      ;;
  esac
  sleep 1
  i=$((i + 1))
done

log wifi "TIMEOUT after ${WIFI_TIMEOUT_SECONDS}s (last state=$state)"
exit 1
