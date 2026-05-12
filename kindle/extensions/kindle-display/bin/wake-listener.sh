#!/bin/sh
# Persistent listener: watches powerd for readyToSuspend events and arms
# rtcWakeup whenever one fires. Started by loop-start.sh, stopped by
# loop-stop.sh. Single long-lived process is simpler and less racy than
# spawning one listener per fetch.
#
# powerd only accepts writes to the rtcWakeup property in the
# ReadyToSuspend lifecycle stage; the event signals exactly that moment.

HERE="$(dirname "$0")"
. "$HERE/_common.sh"

log wake "listener up, PID $$, will arm rtcWakeup=${REFRESH_SECONDS}s on each readyToSuspend"

# -m: stay alive across multiple events. Output one line per event so we
# can react each time. We ignore the actual line content; the act of
# receiving the line is the trigger.
lipc-wait-event -m com.lab126.powerd readyToSuspend 2>>"$LOG_FILE" | while IFS= read -r _; do
  if lipc-set-prop -i com.lab126.powerd rtcWakeup "$REFRESH_SECONDS" 2>>"$LOG_FILE"; then
    log wake "rtcWakeup armed for +${REFRESH_SECONDS}s"
  else
    log wake "rtcWakeup rejected (state changed between event and write?)"
  fi
done

log wake "listener exiting"
