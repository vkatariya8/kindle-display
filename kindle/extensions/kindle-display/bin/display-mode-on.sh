#!/bin/sh
# Start wall-display mode using NiLuJe's linkss screensaver hack:
#   1. Fetch and publish the current tile as the screensaver.
#   2. Start the hourly background loop (it re-publishes every $REFRESH_SECONDS).
#
# Framework stays running — touch the power button to wake the Kindle back to
# normal use. Hourly loop does NOT survive reboot; re-tap this after power
# cycles.

HERE="$(dirname "$0")"
. "$HERE/_common.sh"

log mode "start wall display"

"$HERE/fetch-and-show.sh"
"$HERE/loop-start.sh"

log mode "wall display active"
