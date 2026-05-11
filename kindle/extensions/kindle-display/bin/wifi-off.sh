#!/bin/sh
HERE="$(dirname "$0")"
. "$HERE/_common.sh"
log wifi "disable"
lipc-set-prop com.lab126.cmd wirelessEnable 0 2>>"$LOG_FILE"
