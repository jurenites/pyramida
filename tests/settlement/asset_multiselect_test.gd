extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
const Rotation = preload("res://scripts/settlement/asset_rotation_tool.gd")
var checks := 0
var failures: Array[String] = []
var workshop: CanvasLayer
var editor: RefCounted
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func mouse(point: Vector2, shift := false, pressed := true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.shift_pressed = shift
	event.position = point
	return event
func select_pair() -> void:
	editor.select_layer(0)
	editor.select_layer(1, true)
func run() -> void:
	workshop = Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	await process_frame
	editor = workshop.pieces
	editor.activate()
	var a := Workspace.instance("raw_stone", Vector3(-2.13, 0.4, 0), Vector3(0.2, -0.3, 0.1))
	a.scale = Vector3(1.2, 0.8, 1.1)
	a.basis = Basis(Vector3(-1, 0, 0), Vector3(0.1, 1, 0), Vector3(0, 0.2, 1))
	var b := Workspace.instance("raw_stone", Vector3(2.17, 1, 0), Vector3(0, 0.2, 0))
	var untouched := Workspace.instance("raw_stone", Vector3(0, 0, 4))
	editor.parts = [a.duplicate(true), b.duplicate(true), untouched.duplicate(true)]
	workshop._refresh()
	editor.fit()
	# Exercise the actual GUI event path, including ItemList's native processing.
	await process_frame
	for index in [0, 1]:
		var point: Vector2 = editor.layers.global_position + editor.layers.get_item_rect(index).get_center()
		root.push_input(mouse(point, index == 1))
		root.push_input(mouse(point, index == 1, false))
		await process_frame
	check(editor.selection_indices() == [0, 1], "Shift-click in the layer list selects both rows")
	check(editor.layers.get_selected_items() == PackedInt32Array([0, 1]), "Both rows retain their selection highlight")
	check(editor.parts == [a, b, untouched], "Selecting does not change source geometry")
	check(workshop.overlay.placement_edges.size() == 24, "Both selected layers have visible outlines")
	editor.select_layer(1, true)
	check(editor.selection_indices() == [0], "Shift-click toggles an existing member off")
	# Shift in the viewport must select, never delete.
	var screen: Vector2 = workshop.camera.unproject_position(Kit.bounds(b).get_center())
	workshop._view_input(mouse(screen, true))
	workshop._view_input(mouse(screen, true, false))
	check(editor.selection_indices() == [0, 1] and editor.parts.size() == 3, "Viewport Shift-click adds a part without deleting it")
	var before: Array = editor.parts.duplicate(true)
	for axis in 3:
		var history: int = workshop.undo_stack.size()
		editor.gizmo.nudge(axis, 1)
		for index in [0, 1]:
			var expected: Vector3 = before[index].at
			expected[axis] += 0.1
			check(editor.parts[index].at.is_equal_approx(expected), "Axis nudge translates every selected member by the same amount")
		check(editor.parts[2] == untouched, "Unselected part remains unchanged")
		check(editor.parts[0].rotation == a.rotation and editor.parts[0].basis == a.basis and editor.parts[0].scale == a.scale, "Translation preserves exact authored rotation, basis and scale")
		check(workshop.undo_stack.size() == history + 1, "Group move is one history step")
		workshop.undo()
		check(editor.parts == before, "Undo restores exact unsnapped source positions")
		workshop.redo()
		workshop.undo()
		select_pair()
	var centre: Vector3 = editor.selection_position()
	editor.coordinates[1].get_line_edit().text = str(centre.y + 0.12345)
	editor.coordinates[1].apply()
	check(is_equal_approx(editor.selection_position().y, centre.y + 0.12345), "Numeric group position preserves manually entered precision")
	check((editor.parts[1].at - editor.parts[0].at).is_equal_approx(b.at - a.at), "Numeric position preserves relative spacing")
	workshop.undo()
	select_pair()
	for mode in ["size", "face"]:
		editor.gizmo.set_mode(mode)
		check(editor.gizmo.mode == "move" and editor.gizmo.handles().all(func(handle): return handle.kind == "move"), "Group resizing cannot be enabled")
	check(editor.gizmo.mode_buttons[1].disabled and editor.gizmo.mode_buttons[2].disabled, "Size and Face are disabled for a group")
	for spin: SpinBox in editor.scale_spins:
		check(not spin.editable, "Numeric group scale is disabled")
		spin.value = 2
	check(editor.parts == before, "Even a programmatic scale signal cannot resize a group")
	# Inspector rotation and shortcuts must affect the same group.
	for axis in 3:
		centre = editor.selection_position()
		editor.rotation_spins[axis].value = 30
		var direction := Vector3.ZERO
		direction[axis] = 1
		check(editor.parts[0].at.is_equal_approx(centre + Basis(direction, PI / 6) * (a.at - centre)), "Numeric XYZ rotation uses the shared centre")
		workshop.undo()
		select_pair()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	workshop._input(key)
	check(editor.parts[0] != a and editor.parts[1] != b and editor.parts[2] == untouched, "Rotate shortcut transforms all selected members only")
	workshop.undo()
	select_pair()
	# Numeric rotation, including imported skew/scale and nested children.
	editor.gizmo.set_mode("angle")
	var tool = editor.gizmo.rotation_tool
	tool.choose_axis(Vector3.UP)
	tool.angle_spin.value = 90
	centre = editor.selection_position()
	tool.apply_angle()
	var turned: Array = editor.parts.duplicate(true)
	for index in [0, 1]:
		var pose := Kit.transform(before[index])
		var expected := Transform3D(Basis(Vector3.UP, PI / 2) * pose.basis, centre + Basis(Vector3.UP, PI / 2) * (pose.origin - centre))
		check(Kit.transform(turned[index]).is_equal_approx(expected), "Every member rotates rigidly about the shared centre")
		check(turned[index].get("basis") == before[index].get("basis") and turned[index].get("scale") == before[index].get("scale") and turned[index].children == before[index].children, "Rotation preserves imported basis, scale and child hierarchy")
	workshop.undo()
	check(editor.parts == before, "Group rotation undoes atomically")
	workshop.redo()
	check(editor.parts == turned, "Group rotation redoes atomically")
	var path := "/tmp/pyramida-selection-%d.pyrstructure" % Time.get_ticks_usec()
	check(workshop._save(path) and workshop._load(path), "Transformed group saves and loads")
	for index in 3: check(Kit.transform(editor.parts[index]).is_equal_approx(Kit.transform(turned[index])), "Saved transforms survive reload")
	DirAccess.remove_absolute(path)
	editor.parts = before.duplicate(true)
	select_pair()
	editor.gizmo.set_mode("angle")
	editor.fit()
	var sphere: Dictionary = tool.sphere()
	var start: Vector2 = sphere.centre + Vector2(20, 10)
	workshop._view_input(mouse(start))
	check(editor.gizmo.dragging, "Group rotation starts from the shared sphere")
	var motion := InputEventMouseMotion.new()
	motion.position = sphere.centre + Vector2(-30, 20)
	var history: Array = workshop.undo_stack.duplicate(true)
	workshop._view_input(motion)
	check(editor.parts != before, "Ring gesture rotates the selected group live")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	workshop._input(escape)
	check(editor.parts == before and workshop.undo_stack == history, "Escape restores all group transforms and history")
	check(editor.selection_indices().is_empty() and workshop.visible, "Escape clears the whole selection without closing Blueprints")
	select_pair()
	editor.gizmo.set_mode("move")
	# Direct dragging a member preserves the multi-selection.
	screen = workshop.camera.unproject_position(Kit.bounds(a).get_center())
	workshop._view_input(mouse(screen))
	check(editor.multiple_selected() and editor.dragging, "Dragging a selected member retains the group")
	motion.position = screen + Vector2(60, 0)
	workshop._view_input(motion)
	workshop._input(mouse(motion.position, false, false))
	check(editor.parts[0].at != a.at and (editor.parts[1].at - editor.parts[0].at).is_equal_approx(b.at - a.at), "Viewport dragging translates the group without changing its spacing")
	workshop.undo()
	select_pair()
	workshop._view_input(mouse(screen))
	history = workshop.undo_stack.duplicate(true)
	workshop._view_input(motion)
	workshop._input(escape)
	check(editor.parts == before and workshop.undo_stack == history, "Escape also cancels a whole-group translation")
	select_pair()
	editor.duplicate_selected()
	check(editor.parts.size() == 5 and editor.selection_indices() == [3, 4], "Duplicate copies and selects every group member")
	editor.remove_selected()
	check(editor.parts == before and editor.selection_indices().is_empty(), "Delete removes the selected copies together")
	workshop.undo()
	check(editor.parts.size() == 5, "Group deletion is undoable")
	# Mixed building/mesh selection snaps the common delta, not individual origins.
	editor.parts = [Workspace.instance("house", Vector3(0.03, 0, 0)), a.duplicate(true)]
	select_pair()
	editor.gizmo.nudge(0, 1)
	check(is_equal_approx(editor.parts[0].at.x, 1.03) and is_equal_approx(editor.parts[1].at.x, a.at.x + 1), "Mixed groups use one-metre movement while preserving authored offsets")
	# Reject an out-of-bounds group change atomically, without an empty undo step.
	var edge_parts: Array = editor.parts.duplicate(true)
	history = workshop.undo_stack.duplicate(true)
	editor.move_selection(Vector3(40, 0, 0))
	check(editor.parts == edge_parts and workshop.undo_stack == history, "Movement limits preserve the entire group and history")
	editor.enter_selected()
	check(editor.scopes.is_empty(), "A multi-selection does not accidentally enter just one component")
	workshop.free()
	if failures.is_empty(): print("PASS: %d Blueprint multi-selection checks" % checks)
	quit(int(not failures.is_empty()))
