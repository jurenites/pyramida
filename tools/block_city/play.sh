#!/bin/sh
set -eu
PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
if [ ! -x "$GODOT_BIN" ]; then
  GODOT_BIN=$(command -v godot || command -v godot4)
fi
exec "$GODOT_BIN" --path "$PROJECT_ROOT/demos/block_city" --log-file /tmp/block-city-play.log "$@"
