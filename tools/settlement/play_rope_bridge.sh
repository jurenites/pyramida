#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
godot_bin=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
exec "$godot_bin" --path "$project_dir" --log-file /tmp/pyramida-rope-bridge.log res://scenes/settlement/RopeBridgePrototype.tscn
