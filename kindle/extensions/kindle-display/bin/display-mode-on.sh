#!/bin/sh
# Enter dedicated wall-display mode:
#   1. Stop the Kindle framework (lab126_gui) so it stops repainting the UI
#      over our image.
#   2. Run one fetch immediately so the wall has something to show.
#   3. Start the hourly background loop.
#
# RECOVERY: hold the power button ~20 seconds to force-reboot. The framework
# starts back up on boot and KUAL works again. The hourly loop does NOT
# auto-resume — tap this entry again from KUAL to re-enter display mode.

HERE="$(dirname "$0")"
. "$HERE/_common.sh"

log mode "ENTER display mode"

# stop lab126_gui is upstart-based on Touch 5.x. Suppress errors so a
# missing/renamed service on a different firmware doesn't bail us out.
stop lab126_gui >>"$LOG_FILE" 2>&1 || log mode "stop lab126_gui returned non-zero (continuing)"

# Give the framework a moment to release the framebuffer before we paint.
sleep 2

# One immediate fetch+display so the wall isn't blank.
"$HERE/fetch-and-show.sh"

# Then start the background loop.
"$HERE/loop-start.sh"

log mode "display mode active"
