extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Editor = preload("res://scripts/settlement/terrain_editor.gd")
const Scenery = preload("res://scripts/settlement/scenery_view.gd")
var failure_messages: Array[String] = []
var check_count := 0

func check_result(passed_check: bool, check_message: String) -> void:
	check_count += 1
	if not passed_check: failure_messages.append(check_message)

func _initialize() -> void: call_deferred("run_checks")

func run_checks() -> void:
	var world_model = Model.new()
	world_model.setup(1409)
	var surface_cell := Vector3i(4, 0, 0)
	check_result(Editor.edit_error(world_model, surface_cell, "terrain_dig").is_empty(), "Open starting sand accepts digging")
	var old_ground: Dictionary = world_model.ground.duplicate()
	check_result(Editor.apply_edit(world_model, surface_cell, "terrain_dig"), "Dig succeeds")
	var pit_cell := surface_cell + Vector3i.DOWN
	check_result(world_model.surface_at(4, 0) == pit_cell and world_model.ground.has(pit_cell) and not world_model.ground.has(surface_cell), "Dig lowers exactly one metre")
	check_result(world_model.ground.size() == old_ground.size(), "One cell changes without removing a column")
	var other_columns_unchanged := true
	for other_cell: Vector3i in old_ground:
		if other_cell != surface_cell and not world_model.ground.has(other_cell): other_columns_unchanged = false
	check_result(other_columns_unchanged, "Unedited columns stay unchanged")
	check_result(world_model.Volume.material_at(world_model, pit_cell) == "air" and world_model.Volume.material_at(world_model, pit_cell + Vector3i.DOWN) == "solid", "Pit volume matches its surface")
	check_result(world_model.navigation.surfaces.has(pit_cell) and not world_model.navigation.surfaces.has(surface_cell), "Navigation drops the removed walking floor")
	check_result(not world_model.navigation.edges.get(surface_cell + Vector3i.RIGHT, []).has(pit_cell), "Citizens cannot walk through a metre-high cliff")
	check_result(Editor.apply_edit(world_model, pit_cell, "terrain_fill"), "Fill restores the excavated metre")
	check_result(Editor.apply_edit(world_model, surface_cell, "terrain_fill"), "Fill stacks one metre above the original surface")
	check_result(world_model.Volume.material_at(world_model, surface_cell) == "solid", "Added sand has solid occupancy")
	var saved_world: Dictionary = world_model.snapshot()
	var restored_world = Model.new()
	check_result(restored_world.restore(JSON.parse_string(JSON.stringify(saved_world))), "Raised sand saves and reloads")
	check_result(restored_world.surface_edits == world_model.surface_edits, "Sparse height edits survive serialization")
	check_result(restored_world.soil_shapes.get(surface_cell + Vector3i.UP) == [1.0, 1.0, 1.0, 1.0], "Reload does not regrow soil relief over filled sand")
	check_result(Editor.apply_edit(world_model, surface_cell + Vector3i.UP, "terrain_dig"), "Stack can be removed")
	check_result(Editor.apply_edit(world_model, surface_cell, "terrain_dig"), "Excavation reaches negative heights")
	check_result(restored_world.restore(JSON.parse_string(JSON.stringify(world_model.snapshot()))), "Negative ground heights save and reload")
	check_result(restored_world.surface_at(4, 0) == pit_cell, "Reload preserves pit depth")
	check_result(not Editor.apply_edit(world_model, Vector3i(-6, 0, 2), "terrain_dig"), "Stockpile foundations cannot be undermined")
	var worker_cell: Vector3i = world_model.workers[0].cell
	check_result(not Editor.apply_edit(world_model, worker_cell, "terrain_fill"), "Citizens cannot be buried")
	check_result(not Editor.apply_edit(world_model, Vector3i(999, 0, 999), "terrain_dig"), "Unloaded ground cannot be edited")
	var limit_column := Vector2i(4, 0)
	world_model.surface_edits[limit_column] = Editor.MIN_HEIGHT
	Editor.apply_column(world_model, limit_column, Editor.MIN_HEIGHT)
	check_result(not Editor.apply_edit(world_model, Vector3i(4, Editor.MIN_HEIGHT, 0), "terrain_dig", false), "Minimum depth is enforced")
	world_model.surface_edits[limit_column] = -1
	Editor.apply_column(world_model, limit_column, -1)
	world_model.rebuild_navigation()
	# A remote edited column remains changed through unloading and dormant saves.
	var remote_chunk := Vector2i(-8, -8)
	world_model.Chunks.load_chunk(world_model, remote_chunk)
	var remote_cell := Vector3i.ZERO
	var found_remote := false
	for candidate_cell: Vector3i in world_model.Chunks.chunk_surfaces(world_model, remote_chunk):
		if Editor.edit_error(world_model, candidate_cell, "terrain_dig", false).is_empty():
			remote_cell = candidate_cell
			found_remote = true
			break
	check_result(found_remote, "Remote editable surface found")
	if found_remote:
		check_result(not Editor.apply_edit(world_model, remote_cell, "terrain_dig"), "Fog rejects hidden terrain")
		check_result(Editor.apply_edit(world_model, remote_cell, "terrain_dig", false), "Remote test edit succeeds")
		world_model.Chunks.unload_chunk(world_model, remote_chunk)
		check_result(restored_world.restore(JSON.parse_string(JSON.stringify(world_model.snapshot()))), "Dormant terrain edits save")
		restored_world.Chunks.load_chunk(restored_world, remote_chunk)
		check_result(restored_world.surface_at(remote_cell.x, remote_cell.z).y == remote_cell.y - 1, "Dormant reload replays terrain edits")
		world_model.Chunks.load_chunk(world_model, remote_chunk)
		check_result(world_model.surface_at(remote_cell.x, remote_cell.z).y == remote_cell.y - 1, "Chunk streaming never fills the pit")
	var terrain_view := Scenery.new()
	root.add_child(terrain_view)
	terrain_view.setup(world_model)
	for frame_index in 2: await physics_frame
	var ray_query := PhysicsRayQueryParameters3D.create(Vector3(4, 5, 0), Vector3(4, -4, 0))
	var collision_hit := terrain_view.get_world_3d().direct_space_state.intersect_ray(ray_query)
	check_result(not collision_hit.is_empty() and is_equal_approx(collision_hit.position.y, -1.0), "Pit collision matches the new floor")
	var edited_chunk_id: int = terrain_view.chunks[Vector2i.ZERO].get_instance_id()
	var neighbour_chunk_id: int = terrain_view.chunks[Vector2i(0, -1)].get_instance_id()
	var distant_chunk_id: int = terrain_view.chunks[Vector2i(2, 2)].get_instance_id()
	check_result(Editor.apply_edit(world_model, pit_cell, "terrain_fill"), "Live fill succeeds")
	terrain_view.sync(world_model)
	check_result(terrain_view.chunks[Vector2i.ZERO].get_instance_id() != edited_chunk_id, "Edit rebuilds affected terrain mesh")
	check_result(terrain_view.chunks[Vector2i(0, -1)].get_instance_id() != neighbour_chunk_id, "Chunk-border edit rebuilds the neighbouring exposed wall")
	check_result(terrain_view.chunks[Vector2i(2, 2)].get_instance_id() == distant_chunk_id, "Unrelated meshes stay cached")
	for frame_index in 2: await physics_frame
	collision_hit = terrain_view.get_world_3d().direct_space_state.intersect_ray(ray_query)
	check_result(not collision_hit.is_empty() and is_equal_approx(collision_hit.position.y, 0.0), "Filled collision replaces old pit collision")
	terrain_view.free()
	# Coastal saves validate modified heights without changing the land mask.
	var coast_world = Model.new()
	coast_world.setup(1409, "easy")
	check_result(Editor.apply_edit(coast_world, surface_cell, "terrain_dig"), "Coastal sand can be dug")
	check_result(restored_world.restore(JSON.parse_string(JSON.stringify(coast_world.snapshot()))), "Coastal pit saves and reloads")
	for failure_message in failure_messages: printerr("FAIL: " + failure_message)
	if failure_messages.is_empty(): print("PASS: %d terrain dig/fill, collision, navigation, save and streaming checks" % check_count)
	quit(int(not failure_messages.is_empty()))
