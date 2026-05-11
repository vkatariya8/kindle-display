#!/bin/sh
# Bring the framework back so you can use the Kindle normally.
# Only useful AFTER a reboot (because when lab126_gui is stopped, KUAL
# itself is unreachable). Left here for completeness / future use.

HERE="$(dirname "$0")"
. "$HERE/_common.sh"

log mode "EXIT display mode"

"$HERE/loop-stop.sh"

start lab126_gui >>"$LOG_FILE" 2>&1 || log mode "start lab126_gui returned non-zero"

log mode "framework restart requested"
