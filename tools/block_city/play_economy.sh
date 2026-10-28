#!/bin/sh
set -eu
LAB_TOOLS=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$LAB_TOOLS/play.sh" res://scenes/block_city/EconomyLab.tscn "$@"
