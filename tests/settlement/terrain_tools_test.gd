extends SceneTree
const Editor = preload("res://scripts/settlement/terrain_editor.gd")
class TerrainSession extends "res://scripts/settlement/settlement.gd":
	var test_pointer := Vector2.ZERO
	func _viewport_mouse() -> Vector2: return test_pointer

var failure_messages: Array[String] = []
var check_count := 0
func check_result(passed_check: bool, check_message: String) -> void:
	check_count += 1
	if not passed_check: failure_messages.append(check_message)
func _initialize() -> void: call_deferred("run_checks")

func run_checks() -> void:
	root.size = Vector2i(1440, 900)
	var game_session := TerrainSession.new()
	game_session.launch_to_menu = false
	root.add_child(game_session)
	game_session.capture = true
	game_session.set_process(false)
	game_session.rig.focus = Vector3(4, 0, 0)
	game_session.rig.zoom = 14
	game_session.rig.update_camera()
	game_session.hud.build_panel.hide()
	for frame_index in 3: await physics_frame
	check_result(game_session.hud.buttons.exit.get_global_rect().end.x <= game_session.hud.root.size.x, "New terrain controls keep Save and Exit inside the window")
	var target_cell := Vector3i(4, 0, 0)
	var target_point: Vector3 = game_session.model.navigation.surface_point(target_cell)
	game_session.test_pointer = game_session.rig.camera.unproject_position(target_point)
	game_session.hud.buttons.terrain_dig.pressed.emit()
	check_result(game_session.tool == "terrain_dig" and game_session.hud.buttons.terrain_dig.button_pressed, "Dig toolbar selects the active tool")
	check_result(not game_session.hud.build_panel.visible, "Terrain tools close the construction list")
	check_result(game_session.hud.buttons.terrain_dig.focus_mode == Control.FOCUS_ALL, "Terrain buttons support keyboard focus")
	check_result(game_session.placement_at(game_session.test_pointer).get("cell") == target_cell, "Pointer targets the exposed one-metre cell")
	game_session._update_hover()
	check_result(game_session.hover_valid and game_session.preview.visible, "Dig preview is visible")
	check_result(game_session.preview.position == Vector3(4, -1, 0), "Dig previews the cube below the surface")
	check_result(game_session.hud.placement_strokes.size() == 12, "Preview outlines all twelve cube edges")
	check_result(game_session.preview.get_child(0).mesh.size == Vector3.ONE, "Preview cube is exactly 1×1×1")
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	game_session._unhandled_input(click_event)
	check_result(game_session.model.surface_at(4, 0).y == -1, "Actual dig click removes one metre")
	for frame_index in 2: await physics_frame
	game_session.test_pointer = game_session.rig.camera.unproject_position(Vector3(4, 0, 0))
	game_session.hud.buttons.terrain_fill.pressed.emit()
	check_result(game_session.tool == "terrain_fill" and not game_session.hud.buttons.terrain_dig.button_pressed, "Fill replaces Dig as the selected tool")
	game_session._update_hover()
	check_result(game_session.preview.position == Vector3(4, -1, 0), "Fill previews the empty cube in the pit")
	game_session._unhandled_input(click_event)
	check_result(game_session.model.surface_at(4, 0).y == 0, "Actual fill click restores the pit")
	for frame_index in 2: await physics_frame
	game_session.test_pointer = game_session.rig.camera.unproject_position(Vector3(4, 0, 0))
	game_session._unhandled_input(click_event)
	check_result(game_session.model.surface_at(4, 0).y == 1, "Repeated fill stacks another cube")
	for frame_index in 2: await physics_frame
	game_session.test_pointer = game_session.rig.camera.unproject_position(Vector3(4, 1, 0))
	check_result(game_session.placement_at(game_session.test_pointer).get("cell") == Vector3i(4, 1, 0), "Picking follows raised terrain collision")
	var worker_data: Dictionary = game_session.model.workers[0]
	var old_position: Vector3 = worker_data.position
	var old_cell: Vector3i = worker_data.cell
	worker_data.position = Vector3(4, 1, 0)
	worker_data.cell = Vector3i(4, 1, 0)
	game_session._update_hover()
	check_result(not game_session.preview_error.is_empty() and game_session.hud.placement_color == game_session.hud.WORK_FILL, "Blocked terrain preview uses warning colour")
	game_session._unhandled_input(click_event)
	check_result(game_session.model.surface_at(4, 0).y == 1, "Blocked clicks leave terrain unchanged")
	worker_data.position = old_position
	worker_data.cell = old_cell
	game_session.model.exploration.cells.clear()
	check_result(game_session.placement_at(game_session.test_pointer).is_empty(), "Terrain tool cannot pick through fog")
	game_session.model.exploration.reveal(Vector3(4, 0, 0))
	var cancel_event := InputEventKey.new()
	cancel_event.keycode = KEY_ESCAPE
	cancel_event.pressed = true
	game_session._input(cancel_event)
	check_result(game_session.tool == "inspect" and not is_instance_valid(game_session.preview), "Escape removes the preview and exits the tool")
	game_session.hud.buttons.terrain_dig.pressed.emit()
	var right_event := InputEventMouseButton.new()
	right_event.button_index = MOUSE_BUTTON_RIGHT
	right_event.pressed = true
	game_session._unhandled_input(right_event)
	right_event.pressed = false
	game_session._unhandled_input(right_event)
	check_result(game_session.tool == "inspect", "Right click exits terrain editing")
	if OS.get_cmdline_user_args().has("--terrain-capture"):
		# In-memory fixture only: show a stepped pile, pit and active fill preview.
		game_session.fog.hide()
		game_session.world.fog_enabled = false
		for field_name in ["trees", "deposits", "water_sources", "vines"]: game_session.model.get(field_name).clear()
		for horizontal_x in range(2, 5):
			for horizontal_z in range(2, 5):
				var pile_cell := game_session.model.surface_at(horizontal_x, horizontal_z)
				Editor.apply_edit(game_session.model, pile_cell, "terrain_fill", false)
		Editor.apply_edit(game_session.model, Vector3i(3, 1, 3), "terrain_fill", false)
		for horizontal_x in range(5, 8):
			for horizontal_z in range(-2, 0):
				Editor.apply_edit(game_session.model, game_session.model.surface_at(horizontal_x, horizontal_z), "terrain_dig", false)
		game_session.world.sync(game_session.model, 0, -1)
		game_session.rig.focus = Vector3(4, 0.4, 1)
		game_session.rig.zoom = 12
		game_session.rig.update_camera()
		for frame_index in 3: await physics_frame
		game_session._set_tool("terrain_fill")
		game_session.test_pointer = game_session.rig.camera.unproject_position(Vector3(3, 2, 3))
		game_session._update_hover()
		for frame_index in 8: await process_frame
		await RenderingServer.frame_post_draw
		check_result(root.get_texture().get_image().save_png("res://artifacts/terrain-tools.png") == OK, "Terrain preview screenshot saved")
	game_session.free()
	for failure_message in failure_messages: printerr("FAIL: " + failure_message)
	if failure_messages.is_empty(): print("PASS: %d terrain toolbar, preview, picking and input checks" % check_count)
	quit(int(not failure_messages.is_empty()))
