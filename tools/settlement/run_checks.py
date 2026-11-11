#!/usr/bin/env python3
"""Run prototype contracts; a Godot script error can still return exit code zero."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN") or shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
SUITE = [
    "tests/settlement/geological_islands_test.gd",
    "tests/settlement/island_variation_test.gd",
    "tests/settlement/solid_islands_test.gd",
    "tests/settlement/fitted_support_test.gd",
    "tests/settlement/archipelago_test.gd",
    "tests/settlement/terraced_landscape_test.gd",
    "tests/settlement/house_selection_test.gd",
    "tests/settlement/incremental_navigation_test.gd",
    "tests/settlement/puddle_assignment_test.gd",
    "tests/settlement/sand_puddle_density_test.gd",
    "tests/settlement/support_deck_escape_test.gd",
    "tests/settlement/housing_birth_test.gd",
    "tests/settlement/rope_bridge_test.gd",
    "tests/settlement/rope_bridge_runtime_test.gd",
    "tests/settlement/rope_bridge_main_test.gd",
    "tests/settlement/rope_bridge_edit_test.gd",
    "tests/settlement/imbrex_test.gd",
    "tests/settlement/house_tiers_test.gd",
    "tests/settlement/building_layout_sandbox_test.gd",
    "tests/settlement/well_shaft_test.gd",
    "tests/settlement/stone_road_test.gd",
    "tests/settlement/roofed_workplaces_test.gd",
    "tests/settlement/reviewed_mill_shape_test.gd",
    "tests/settlement/structure_frame_test.gd",
    "tests/settlement/roof_boards_test.gd",
    "tests/settlement/roof_timber_test.gd",
    "tests/settlement/shared_house_posts_test.gd",
    "tests/settlement/house_roofs_test.gd",
    "tests/settlement/connected_buildings_test.gd",
    "tests/settlement/depot_storage_test.gd",
    "tests/settlement/roof_kit_test.gd",
    "tests/settlement/seed_placement_test.gd",
    "tests/settlement/well_preview_test.gd",
    "tests/settlement/reviewed_balance_test.gd",
    "tests/settlement/reviewed_runtime_test.gd",
    "tests/settlement/background_save_test.gd",
    "tests/settlement/journey_navigation_test.gd",
    "tests/settlement/baker_workplace_test.gd",
    "tests/settlement/room_construction_test.gd",
    "tests/settlement/room_editor_test.gd",
    "tests/settlement/terrain_edit_test.gd",
    "tests/settlement/terrain_tools_test.gd",
    "tests/settlement/assigned_gathering_test.gd",
    "tests/settlement/building_variation_test.gd",
    "tests/settlement/stump_removal_test.gd",
    "tests/settlement/nature_generator_test.gd",
    "tests/settlement/debug_build_test.gd",
    "tests/settlement/construction_cancel_test.gd",
    "tests/settlement/construction_actions_test.gd",
    "tests/settlement/construction_planning_test.gd",
    "tests/settlement/platform_tiers_test.gd",
    "tests/settlement/timber_palette_test.gd",
    "tests/settlement/timber_kit_test.gd",
    "tests/settlement/timber_continuity_test.gd",
    "tests/settlement/timber_motion_test.gd",
    "tests/settlement/timber_frame_test.gd",
    "tests/settlement/timber_construction_test.gd",
    "tests/settlement/timber_recovery_test.gd",
    "tests/settlement/shared_building_parts_test.gd",
    "tests/settlement/dedicated_storage_test.gd",
    "tests/settlement/log_length_test.gd",
    "tests/settlement/settings_expressions_test.gd",
    "tests/settlement/balance_test.gd",
    "tests/settlement/scenery_performance_test.gd",
    "tests/settlement/grass_resource_test.gd",
    "tests/settlement/warehouse_test.gd",
    "tests/settlement/population_storage_test.gd",
    "tests/settlement/soil_surface_test.gd",
    "tests/settlement/sawmill_test.gd",
    "tests/settlement/well_test.gd",
    "tests/settlement/vine_test.gd",
    "tests/settlement/planting_test.gd",
    "tests/settlement/house_join_test.gd",
    "tests/settlement/hotkeys_test.gd",
    "tests/settlement/structure_parts_test.gd",
    "tests/settlement/asset_workbench_test.gd",
    "tests/settlement/asset_links_test.gd",
    "tests/settlement/asset_variants_test.gd",
    "tests/settlement/asset_selection_test.gd",
    "tests/settlement/asset_area_selection_test.gd",
    "tests/settlement/asset_transform_test.gd",
    "tests/settlement/asset_rotation_test.gd",
    "tests/settlement/asset_multiselect_test.gd",
    "tests/settlement/asset_grouping_test.gd",
    "tests/settlement/building_appearance_test.gd",
    "tests/settlement/greece_test.gd",
    "tests/settlement/farming_test.gd",
    "tests/settlement/hay_terrain_growth_test.gd",
    "tests/settlement/hay_field_join_test.gd",
    "tests/settlement/child_play_test.gd",
    "tests/settlement/stone_pile_test.gd",
    "tests/settlement/stone_volume_test.gd",
    "tests/settlement/slab_mesh_test.gd",
    "tests/settlement/placement_outline_test.gd",
    "tests/settlement/citizen_clearance_test.gd",
    "tests/settlement/slope_navigation_test.gd",
    "tests/settlement/blueprint_life_test.gd",
    "tests/settlement/relocation_test.gd",
    "tests/settlement/deconstruction_test.gd",
    "tests/settlement/bush_growth_test.gd",
    "tests/settlement/citizen_performance_test.gd",
    "tests/settlement/placement_offset_test.gd",
    "tests/settlement/automatic_roof_test.gd",
    "tests/settlement/pile_groups_test.gd",
    "tests/settlement/object_tooltip_test.gd",
    "tests/settlement/citizen_occlusion_test.gd",
    "tests/settlement/vegetation_test.gd",
    "tests/settlement/half_grid_test.gd",
    "tests/settlement/chunk_stream_test.gd",
    "tests/settlement/chunk_visual_test.gd",
    "tests/settlement/exploration_test.gd",
    "tests/settlement/island_clouds_test.gd",
    "tests/settlement/audio_test.gd",
    "tests/settlement/legacy_features_test.gd",
    "tests/settlement/structure_picker_test.gd",
    "tests/settlement/structure_workshop_test.gd",
    "tests/settlement/economy_test.gd",
    "tests/settlement/new_game_test.gd",
    "tests/settlement/resource_visibility_test.gd",
    "tests/settlement/idle_citizen_test.gd",
    "tests/settlement/ui_scale_test.gd",
    "tests/settlement/window_resize_test.gd",
    "tests/settlement/work_progress_test.gd",
    "tests/settlement/construction_site_view_test.gd",
    "tests/settlement/camera_stability_test.gd",
    "tests/settlement/ladder_test.gd",
    "tests/settlement/editor_preview_test.gd",
    "tests/settlement/day_cycle_test.gd",
    "tests/settlement/world_generation_test.gd",
    "tests/settlement/terrain_runtime_test.gd",
    "tests/settlement/navigation_test.gd",
    "tests/settlement/worker_animation_test.gd",
    "tests/settlement/citizen_rig_test.gd",
    "tests/settlement/reference_man_test.gd",
    "tests/settlement/reference_woman_test.gd",
    "tests/settlement/reference_child_test.gd",
    "tests/settlement/tree_test.gd",
    "tests/settlement/simulation_test.gd",
    "tests/settlement/builder_order_test.gd",
    "tests/settlement/citizen_reassignment_test.gd",
    "tests/settlement/simulation_speed_test.gd",
    "tests/settlement/rendering_test.gd",
    "tests/settlement/building_placement_test.gd",
    "tests/settlement/runtime_test.gd",
    "tests/settlement/menu_test.gd",
    "tests/settlement/loading_test.gd",
    "tests/settlement/delete_save_test.gd",
    "tests/settlement/startup_test.gd",
    "tests/building_blueprint_test.gd",
    "tests/obj_asset_runtime_test.gd",
    "tests/applied_labour_test.gd",
    "tests/building_asset_gameplay_test.gd",
]


def run_check(name, command, timeout, require_marker=False):
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    except (subprocess.TimeoutExpired, OSError) as error:
        print(f"FAIL {name}: {error}", flush=True)
        if isinstance(error, subprocess.TimeoutExpired):
            for output in (error.stdout, error.stderr):
                if output:
                    print(output.decode(errors="replace") if isinstance(output, bytes) else output)
        return False
    output = result.stdout + result.stderr
    errors = [line for line in output.splitlines() if ("ERROR:" in line or "FAIL:" in line)
              and 'Condition "ret != noErr"' not in line]
    passed = result.returncode == 0 and not errors and (not require_marker or "PASS:" in output)
    print(("PASS " if passed else "FAIL ") + name, flush=True)
    if not passed:
        print(output, flush=True)
    return passed


def main():
    failed = []
    # Separate logs let independent chats run checks without clobbering diagnostics.
    with tempfile.TemporaryDirectory(prefix="pyramida-checks-") as directory:
        for test in SUITE:
            log = str(Path(directory) / (Path(test).stem + ".log"))
            command = [GODOT, "--headless", "--path", str(ROOT), "--log-file", log, "--script", test]
            if not run_check(test, command, 180 if test.endswith(("/economy_test.gd", "/construction_planning_test.gd")) else 90, require_marker=True):
                failed.append(test)
        test = "tests/test_pyrbuilding_codec.py"
        if not run_check(test, [sys.executable, "-B", test], 30):
            failed.append(test)
    print(f"{len(SUITE) + 1 - len(failed)}/{len(SUITE) + 1} suites passed", flush=True)
    return bool(failed)


if __name__ == "__main__":
    sys.exit(main())
