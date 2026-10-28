#!/bin/sh
set -eu
PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
if [ ! -x "$GODOT_BIN" ]; then GODOT_BIN=$(command -v godot || command -v godot4); fi
for argument in "$@"; do
  if [ "$argument" = "--preview" ]; then
    exec "$GODOT_BIN" --path "$PROJECT_ROOT" --log-file /tmp/block-city-generator-preview.log --script tools/block_city/generate_building.gd -- "$@"
  fi
done
exec "$GODOT_BIN" --headless --path "$PROJECT_ROOT" --log-file /tmp/block-city-generator-export.log --script tools/block_city/generate_building.gd -- "$@"
