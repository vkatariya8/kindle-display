#!/bin/sh
# Dump the last ~30 log lines to the screen via eips so you can debug
# without plugging in. Each eips text call writes one row.

HERE="$(dirname "$0")"
. "$HERE/_common.sh"

eips -c >/dev/null 2>&1

if [ ! -f "$LOG_FILE" ]; then
  eips 1 2 "no log yet"
  exit 0
fi

eips 1 1 "kindle-display log (last 30 lines):"

row=3
tail -n 30 "$LOG_FILE" | while IFS= read -r line; do
  # eips clips long lines; that's fine — we just want the gist on-screen.
  eips 0 "$row" "$line"
  row=$((row + 1))
done
