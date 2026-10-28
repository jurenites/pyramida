extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
const Gizmo = preload("res://scripts/settlement/asset_transform_gizmo.gd")
var failures: Array[String] = []
var checks := 0
var workshop: CanvasLayer
var editor: RefCounted
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func press(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	workshop._view_input(event)
func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	workshop._view_input(event)
func release() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	# Release outside the viewport must finish the gesture too.
	event.position = Vector2(-100, -100)
	workshop._input(event)
func reset(part: Dictionary, mode: String) -> void:
	editor.parts = [part.duplicate(true)]
	editor.selected = 0
	editor.selected_layers.clear()
	editor.selecting = true
	editor.gizmo.set_mode(mode)
	workshop._refresh()
func run() -> void:
	workshop = Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	await process_frame
	editor = workshop.pieces
	editor.activate()
	var original := Workspace.instance("raw_stone", Vector3(0.2,0.3,-0.1), Vector3(0.12,0.55,0.08))
	original.scale = Vector3(1.2,0.9,0.8)
	reset(original, "move")
	editor.fit()
	check(editor.gizmo.controls.visible, "Selected object exposes top-right axis controls")
	for axis in 3:
		reset(original, "move")
		editor.gizmo.nudge_buttons[axis * 2 + 1].pressed.emit()
		var expected: Vector3 = original.at
		expected[axis] += editor.EDIT_STEP
		check(editor.parts[0].at.is_equal_approx(expected), "Positive axis button moves exactly one grid step")
		editor.gizmo.nudge_buttons[axis * 2].pressed.emit()
		check(editor.parts[0].at.is_equal_approx(original.at), "Negative axis button reverses the move")
	check(editor.gizmo.handles().size() == 3, "Move mode exposes three compact axis arrows")
	for axis in 3:
		reset(original, "move")
		var handle: Dictionary = editor.gizmo.handles()[axis]
		var centre: Vector2 = workshop.camera.unproject_position(Kit.transform(original) * Gizmo.local_bounds(original).get_center())
		check(is_equal_approx(centre.distance_to(handle.screen_end), 40), "Movement arrows stay forty UI points from the mesh centre")
		check(editor.gizmo.hit(centre).is_empty(), "Centre stays available for free dragging")
		var start_point: Vector2 = handle.screen_start.lerp(handle.screen_end, 0.7)
		press(start_point)
		check(editor.gizmo.dragging and editor.gizmo.drag_handle.axis == axis, "Arrow shaft picks its axis before the model")
		var projected: Vector2 = editor.gizmo.screen_axis
		motion(start_point + projected * 0.34)
		release()
		var expected: Vector3 = original.at + handle.direction * 0.3
		check(editor.parts[0].at.is_equal_approx(expected), "Dragging constrains movement to one axis with tenth-metre steps")
		check(editor.parts[0].rotation == original.rotation and editor.parts[0].scale == original.scale, "Arrow dragging preserves orientation and dimensions")
		workshop.undo()
		check(editor.parts[0] == original, "Arrow drag undoes as one action")
		workshop.redo()
		check(editor.parts[0].at.is_equal_approx(expected), "Arrow drag redoes")
	var old_zoom: float = workshop.camera.size
	workshop.camera.size *= 2
	for handle: Dictionary in editor.gizmo.handles():
		var centre: Vector2 = workshop.camera.unproject_position(handle.point)
		check(is_equal_approx(centre.distance_to(handle.screen_end), 40), "Zoom does not enlarge movement arrows")
	workshop.camera.size = old_zoom
	var building := Workspace.instance("house", Vector3(-2, 0, -1))
	reset(building, "move")
	var move_handle: Dictionary = editor.gizmo.handles()[1]
	press(move_handle.screen_end)
	motion(move_handle.screen_end + editor.gizmo.screen_axis * 1.3)
	release()
	check(editor.parts[0].at.is_equal_approx(building.at + Vector3.UP), "Fixed-size buildings retain metre movement steps")
	reset(building, "move")
	editor.parts.append(original.duplicate(true))
	editor.select_layer(1, true)
	move_handle = editor.gizmo.handles()[2]
	press(move_handle.screen_end)
	motion(move_handle.screen_end - editor.gizmo.screen_axis * 1.2)
	release()
	check(editor.parts[0].at.is_equal_approx(building.at - Vector3.BACK) and editor.parts[1].at.is_equal_approx(original.at - Vector3.BACK), "Mixed selections move together on the building grid without shifting relative spacing")
	workshop.undo()
	check(editor.parts == [building, original], "Multi-selection arrow drag undoes atomically")
	reset(original, "move")
	move_handle = editor.gizmo.handles()[0]
	press(move_handle.screen_end)
	motion(move_handle.screen_end - editor.gizmo.screen_axis * 0.4)
	editor.gizmo.cancel()
	check(editor.parts[0] == original, "Cancelling an arrow drag restores the original transform")
	# Manual decimals survive commits, refresh, history and serialization.
	var precise := original.duplicate(true)
	precise.at.x = 0.47
	reset(precise, "move")
	check(is_equal_approx(editor.parts[0].at.x, 0.47), "Inspector preserves untouched source values")
	var field: SpinBox = editor.coordinates[0]
	field.get_line_edit().text = "0.675123"
	field.apply()
	check(is_equal_approx(editor.parts[0].at.x, 0.675123), "Typed positions keep extra decimal places")
	workshop._refresh()
	check(field.get_line_edit().text == "0.675123", "Refresh keeps the typed decimal instead of float32 noise")
	check(is_equal_approx(Kit.decode(Kit.encode(editor.parts)).parts[0].at.x, 0.675123), "Serialization preserves typed precision")
	workshop.undo()
	check(is_equal_approx(editor.parts[0].at.x, 0.47), "Undo restores exact original source coordinates")
	workshop.redo()
	check(is_equal_approx(editor.parts[0].at.x, 0.675123), "Redo restores manually entered precision")
	# Exercise native arrow buttons, including the first step off a precise value.
	var input_layer := CanvasLayer.new()
	input_layer.layer = 1000
	root.add_child(input_layer)
	var holder := VBoxContainer.new()
	input_layer.add_child(holder)
	var spin: SpinBox = workshop._spin(holder, "", -32, 32, 0, func(_value): pass, 0.1)
	await process_frame
	await process_frame
	for sample in [[0.675123, true, 0.7], [0.675123, false, 0.6], [-0.675123, true, -0.6], [-0.675123, false, -0.7], [0.7, true, 0.8], [0.7, false, 0.6], [32.0, true, 32.0], [-32.0, false, -32.0]]:
		spin.get_line_edit().text = str(sample[0])
		spin.apply()
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = spin.global_position + Vector2(spin.size.x - 5, 5 if sample[1] else spin.size.y - 5)
		event.pressed = true
		root.push_input(event)
		event.pressed = false
		root.push_input(event)
		await process_frame
		check(is_equal_approx(spin.value, sample[2]), "Arrow from %s (up=%s) reaches %s, got %s" % [sample[0], sample[1], sample[2], spin.value])
	input_layer.free()

	reset(original, "size")
	var handles: Array = editor.gizmo.handles()
	check(handles.size() == 14, "Size mode exposes six face handles and eight corner handles")
	for handle: Dictionary in handles:
		var resized := Gizmo.transformed(original, handle, 0.25)
		var anchor: Vector3 = Kit.transform(original) * handle.anchor
		check((Kit.transform(resized) * handle.anchor).is_equal_approx(anchor), "Rotated resize keeps the opposite face/corner fixed")
		if handle.kind == "face":
			for axis in 3:
				if axis != handle.axis: check(is_equal_approx(resized.scale[axis], original.scale[axis]), "Face resize preserves other dimensions")
		else:
			var ratio: Vector3 = resized.scale / original.scale
			check(is_equal_approx(ratio.x, ratio.y) and is_equal_approx(ratio.x, ratio.z), "Corner resize preserves proportions")
		var minimum := Gizmo.transformed(original, handle, -100)
		check(minimum.scale.x >= 0.0099 and minimum.scale.y >= 0.0099 and minimum.scale.z >= 0.0099, "Dragging past the opposite side never inverts or collapses geometry")
		check(not Kit.decode(Kit.encode([resized])).is_empty(), "Resized grouped components remain serializable")
	var face: Dictionary = handles.filter(func(h): return h.kind == "face" and h.axis == 1 and h.direction.y > 0)[0]
	var start: Vector2 = workshop.camera.unproject_position(face.point)
	press(start)
	check(editor.gizmo.dragging and editor.gizmo.drag_handle.kind == "face", "Face handle is picked before model geometry")
	var direction: Vector2 = workshop.camera.unproject_position(face.point + face.direction) - start
	motion(start + direction * 0.3)
	release()
	check(editor.parts[0].scale.y > original.scale.y, "Dragging the top node stretches the selected model")
	check(editor.parts[0].contract == original.contract, "Mesh resizing preserves the authored occupied-space contract")
	var path := "/tmp/pyramida-gizmo-%d.pyrstructure" % Time.get_ticks_usec()
	var resized: Dictionary = editor.parts[0].duplicate(true)
	var saved: bool = workshop._save(path)
	var loaded: bool = workshop._load(path)
	# JSON round trips can change the last decimal of contract dimensions.
	check(saved and loaded and Kit.transform(editor.parts[0]).is_equal_approx(Kit.transform(resized))
		and JSON.stringify(Kit.encode(editor.parts)) == JSON.stringify(Kit.encode([resized])), "Resized prefab survives document save/load")
	DirAccess.remove_absolute(path)

	reset(original, "size")
	while workshop.undo_stack.size() < 60: workshop._remember()
	var history: Array = workshop.undo_stack.duplicate(true)
	var dirty: bool = workshop.dirty
	var arrow: Dictionary = editor.gizmo.handles()[1]
	start = workshop.camera.unproject_position(arrow.point)
	press(start)
	direction = workshop.camera.unproject_position(arrow.point + arrow.direction) - start
	motion(start + direction * 0.4)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	workshop._input(escape)
	check(editor.parts[0] == original and workshop.undo_stack == history and workshop.dirty == dirty, "Escape cancels even with a full undo history")
	check(workshop.visible and not editor.gizmo.dragging and editor.selected == -1, "Escape cancels the drag and deselects without closing the editor")
	check(not editor.gizmo.controls.visible and not workshop.overlay.placement_visible, "Escape clears selection controls and outline")
	workshop._input(escape)
	check(workshop.visible and editor.selected == -1, "Repeated Escape with no selection keeps Blueprints open")
	reset(original, "move")
	workshop._input(escape)
	check(workshop.visible and editor.selected == -1 and editor.parts[0] == original, "Escape deselects an idle object without changing it")
	editor.insertion = original.duplicate(true)
	editor.selecting = false
	workshop._input(escape)
	check(workshop.visible and editor.insertion.is_empty() and editor.selecting, "Escape cancels insertion and returns to selection mode")
	reset(original, "face")
	check(editor.gizmo.handles().size() == 6 and editor.gizmo.face_controls.visible and not editor.gizmo.axis_controls.visible, "Face mode exposes six independent sides without whole-object axis controls")
	for side in 6:
		reset(original, "face")
		editor.gizmo.editing_face = side
		var selected_face: Dictionary = editor.gizmo.handles().filter(func(h): return h.side == side)[0]
		var old_anchor: Vector3 = Kit.transform(original) * selected_face.anchor
		editor.gizmo.face_buttons[1].pressed.emit()
		var shifted: Dictionary = editor.parts[0]
		check((Kit.transform(shifted) * selected_face.anchor).is_equal_approx(old_anchor), "Each face nudge keeps its opposite side fixed")
		var local_point: Vector3 = Kit.transform(original).affine_inverse() * selected_face.point
		check((Kit.transform(shifted) * local_point).is_equal_approx(selected_face.point + selected_face.direction * 0.1), "Selected side moves outward by exactly 0.1 metres")
		workshop.undo()
		check(Kit.transform(editor.parts[0]).is_equal_approx(Kit.transform(original)), "Face movement is undoable")
		workshop.redo()
		check(Kit.transform(editor.parts[0]).is_equal_approx(Kit.transform(shifted)), "Face movement is redoable")
	editor.selected = -1
	workshop._refresh()
	check(not editor.gizmo.controls.visible and editor.gizmo.handles().is_empty(), "Controls and handles hide when nothing is selected")
	workshop.free()
	if failures.is_empty(): print("PASS: %d Blueprint transform checks" % checks)
	quit(int(not failures.is_empty()))
