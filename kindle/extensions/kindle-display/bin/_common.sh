# Common helpers. Sourced by the other scripts.
# Caller must set HERE to its own dir before sourcing.

. "$HERE/../config.sh"

mkdir -p "$TILE_DIR" 2>/dev/null

log() {
  # Single-line timestamped log entry. Tag is $1, message is the rest.
  TAG="$1"
  shift
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$TAG] $*" >> "$LOG_FILE"
}
