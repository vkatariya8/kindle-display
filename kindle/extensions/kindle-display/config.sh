# Sourced by every script. POSIX sh; no bashisms.
# EDIT THIS FILE ONCE on yo  ur laptop before copying to the Kindle.

SERVER_URL="https://vkatariya8.pythonanywhere.com"

# Where we keep the cached PNG, PID file, and tmp scratch.
# /mnt/us survives reboots and (usually) firmware updates.
TILE_DIR="/mnt/us/kindle-display"
LOG_FILE="/mnt/us/kindle-display.log"

# NiLuJe's "linkss" screensaver hack drops custom screensavers here. We
# overwrite both default slots so the hack's random picker always lands
# on our image. If you have a different screensaver hack, change this.
SS_DIR="/mnt/us/linkss/screensavers"
SS_FILES="bg_xsmall_ss00.png bg_xsmall_ss01.png"

# The regular uploaded-image check runs hourly from 09:00 through 21:00.
# This is also the interval used for the weather window; the script aligns
# wakeups to the top of each hour so the 06:00, 07:00, and 09:00 transitions
# happen on time.
REFRESH_SECONDS=3600

# How long to wait for Wi-Fi to associate before giving up.
WIFI_TIMEOUT_SECONDS=30

# Battery percentage at or below which we show a low-battery overlay and stop refreshing.
LOWBATT_THRESHOLD=15
