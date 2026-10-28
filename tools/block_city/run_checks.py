#!/usr/bin/env python3
"""Focused demo checks, with a timeout and script-error detection (Godot can exit 0 on errors)."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
godot = os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4") or "/Applications/Godot.app/Contents/MacOS/Godot"
failed = False
for name in ("transformer_edit_test", "power_equipment_test", "floating_land_test", "lighting_test", "utility_test", "construction_controls_test", "land_test", "land_interaction_test", "generator_test", "neighbourhood_test", "model_test", "runtime_test", "interiors_test", "entrances_test", "elevator_test", "platforms_test", "interaction_test", "placement_plane_test", "roof_target_test", "floor_selection_test", "relocation_test", "removal_test", "cable_removal_test", "power_distribution_test", "power_interaction_test", "editor_test", "editor_interaction_test", "shape_outline_test", "navigation_test", "hall_cut_test", "debug_build_test", "economy_lab_test", "economy_lab_runtime_test", "variety_test"):
    result = subprocess.run([godot, "--headless", "--path", str(root), "--log-file", f"/tmp/block-city-{name}.log", "--script", f"tests/block_city/{name}.gd"], capture_output=True, text=True, timeout=60)
    text = result.stdout + result.stderr
    # The macOS certificate warning is unrelated to this entirely offline demo.
    bad = result.returncode != 0 or "SCRIPT ERROR" in text or "Assertion failed" in text
    print(f"{'FAIL' if bad else 'PASS'} {name}")
    print(text.strip())
    failed |= bad
sys.exit(1 if failed else 0)
