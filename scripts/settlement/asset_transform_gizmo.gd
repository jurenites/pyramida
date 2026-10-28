extends RefCounted
## Projected handles share the viewport's camera and logical UI point system.
const RotationTool = preload("res://scripts/settlement/asset_rotation_tool.gd")
var rotation_tool: RefCounted
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Contract = preload("res://scripts/settlement/asset_contract.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const COLOURS := [Color("cd5544"), Color("377fa7"), Color("42834e")]
const HIT_RADIUS := 12.0 * Tokens.POINT
const MOVE_LENGTH := 40.0 * Tokens.POINT
const MOVE_GAP := 14.0 * Tokens.POINT
const MOVE_HEAD := 8.0 * Tokens.POINT
const MOVE_HIT_RADIUS := 8.0 * Tokens.POINT
var _editor: WeakRef
var editor: RefCounted:
	get: return _editor.get_ref()
var mode := "move"
var controls: VBoxContainer
var mode_buttons: Array[Button] = []
var nudge_buttons: Array[Button] = []
var face_controls: VBoxContainer
var face_picker: OptionButton
var face_buttons: Array[Button] = []
var axis_controls: HBoxContainer
var editing_face := 1
var dragging := false
var changed := false
var drag_index := -1
var drag_part: Dictionary = {}
var drag_handle: Dictionary = {}
var drag_pointer := Vector2.ZERO
var screen_axis := Vector2.ZERO
var previous_dirty := false
var previous_redo: Array = []
var previous_undo: Array = []

func _init(owner: RefCounted) -> void:
	_editor = weakref(owner)

func active() -> bool:
	return is_instance_valid(editor) and editor.enabled and editor.selecting and editor.selected >= 0 and editor.selected < editor.parts.size()

func create_controls(parent: Control) -> void:
	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 4 * Tokens.GAP_UNIT)
	parent.add_child(controls)
	var modes := GridContainer.new()
	modes.columns = 2
	controls.add_child(modes)
	for title: String in ["Move", "Size", "Face", "Angle"]:
		var value := title.to_lower()
		var button: Button = editor.host._button(modes, title, func(): set_mode(value))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_buttons.append(button)
	var axes := HBoxContainer.new()
	axis_controls = axes
	axes.add_theme_constant_override("separation", 4 * Tokens.GAP_UNIT)
	controls.add_child(axes)
	for axis in 3:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		axes.add_child(column)
		var label: Label = editor.host._label(column, Tokens.BLUEPRINT_AXIS_LABELS[axis], COLOURS[axis])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var row := HBoxContainer.new()
		column.add_child(row)
		for sign_ in [-1, 1]:
			var button: Button = editor.host._icon_button(row, "minus" if sign_ < 0 else "add", "", func(): nudge(axis, sign_))
			nudge_buttons.append(button)
	face_controls = VBoxContainer.new()
	controls.add_child(face_controls)
	face_picker = OptionButton.new()
	for title in ["−X side", "+X side", "Bottom", "Top", "−Y side", "+Y side"]: face_picker.add_item(title)
	face_picker.select(editing_face)
	face_picker.item_selected.connect(func(index): editing_face = index; refresh(); editor.host.overlay.queue_redraw())
	face_controls.add_child(face_picker)
	var face_actions := HBoxContainer.new()
	face_controls.add_child(face_actions)
	for sign_ in [-1, 1]:
		var button: Button = editor.host._icon_button(face_actions, "minus" if sign_ < 0 else "add", "Move side %s · 0.1 m" % ("inward" if sign_ < 0 else "outward"), func(): nudge_face(sign_))
		face_buttons.append(button)
	rotation_tool = RotationTool.new(self)
	rotation_tool.create_controls(controls)
	refresh()

func nudge_face(sign_: int) -> void:
	if not active(): return
	end_drag()
	var matching := handles().filter(func(handle): return handle.get("side", -1) == editing_face)
	if matching.is_empty(): return
	var part: Dictionary = editor.parts[editor.selected]
	var result := transformed(part, matching[0], sign_ * editor.EDIT_STEP)
	if result == part: return
	editor.host._remember()
	editor.parts[editor.selected] = result
	editor.host._refresh()

func refresh() -> void:
	if controls == null: return
	var locked: bool = active() and (editor.multiple_selected() or not Kit.Appearance.can_resize(editor.parts[editor.selected]))
	var length_axis: int = Kit.Appearance.log_length_axis(editor.parts[editor.selected]) if active() else -1
	if locked and mode in ["size", "face"]: mode = "move"
	for index in [1, 2]: mode_buttons[index].disabled = locked
	controls.visible = active()
	face_controls.visible = active() and mode == "face"
	axis_controls.visible = mode in ["move", "size"]
	rotation_tool.controls.visible = active() and mode == "angle"
	for side in 6: face_picker.set_item_disabled(side, length_axis >= 0 and side / 2 != length_axis)
	if length_axis >= 0 and editing_face / 2 != length_axis: editing_face = length_axis * 2 + 1
	face_picker.select(editing_face)
	for index in mode_buttons.size(): mode_buttons[index].set_pressed_no_signal(mode == ["move", "size", "face", "angle"][index])
	for index in nudge_buttons.size():
		var axis: int = index / 2
		nudge_buttons[index].disabled = mode == "size" and length_axis >= 0 and axis != length_axis
		var direction := -1 if index % 2 == 0 else 1
		var action := "Move" if mode == "move" else "Resize"
		var step := "1 m" if active() and mode == "move" and editor.selection_step() > editor.EDIT_STEP else "0.1 m"
		nudge_buttons[index].tooltip_text = "%s %s%s · %s" % [action, "+" if direction > 0 else "−", Tokens.BLUEPRINT_AXIS_LABELS[axis], step]

func set_mode(value: String) -> void:
	if value not in ["move", "size", "face", "angle"]: return
	if active() and value in ["size", "face"] and (editor.multiple_selected() or not Kit.Appearance.can_resize(editor.parts[editor.selected])): return
	end_drag()
	mode = value
	refresh()
	editor.host.overlay.queue_redraw()

static func local_bounds(part: Dictionary) -> AABB:
	var result := AABB()
	var first := true
	for mesh: Dictionary in Kit.part_geometry(part):
		var bounds: AABB = mesh.transform * mesh.bounds
		result = bounds if first else result.merge(bounds)
		first = false
	return result

func handles() -> Array:
	if not active(): return []
	if mode == "move": return move_handles()
	if mode == "angle" or editor.multiple_selected(): return []
	var camera: Camera3D = editor.host.camera
	var part: Dictionary = editor.parts[editor.selected]
	var bounds := local_bounds(part)
	if not Kit.Appearance.can_resize(part): return []
	var pose := Kit.transform(part)
	var centre := pose * bounds.get_center()
	if camera.is_position_behind(centre): return []
	var result: Array = []
	if mode in ["size", "face"]:
		for axis in 3:
			if not Kit.Appearance.can_resize(part, axis): continue
			if bounds.size[axis] < 0.00001: continue
			for sign_ in [-1, 1]:
				var local := bounds.get_center()
				local[axis] = bounds.position[axis] if sign_ < 0 else bounds.end[axis]
				var anchor := local
				anchor[axis] = bounds.end[axis] if sign_ < 0 else bounds.position[axis]
				var vector := pose * local - pose * anchor
				result.append({"kind": "face", "axis": axis, "direction": vector.normalized(), "point": pose * local,
					"anchor": anchor, "length": vector.length(), "side": axis * 2 + (1 if sign_ > 0 else 0)})
		if mode == "face" or Kit.Appearance.log_length_axis(part) >= 0: return result
		for corner in 8:
			var local := bounds.get_endpoint(corner)
			var anchor := bounds.get_endpoint(corner ^ 7)
			var vector := pose * local - pose * anchor
			if vector.length() < 0.00001: continue
			result.append({"kind": "corner", "axis": -1, "direction": vector.normalized(), "point": pose * local,
				"anchor": anchor, "length": vector.length()})
	return result

func move_handles() -> Array:
	var camera: Camera3D = editor.host.camera
	var part: Dictionary = editor.selection_part()
	var centre := Kit.transform(part) * local_bounds(part).get_center()
	if camera.is_position_behind(centre): return []
	var origin := camera.unproject_position(centre)
	var result: Array = []
	for axis in 3:
		var direction := Vector3.ZERO
		direction[axis] = 1
		var projected := camera.unproject_position(centre + direction) - origin
		# An axis viewed end-on cannot provide a usable drag direction.
		if projected.length() < 0.5: continue
		var ray := projected.normalized()
		result.append({"kind": "move", "axis": axis, "direction": direction, "point": centre,
			"screen_start": origin + ray * MOVE_GAP, "screen_end": origin + ray * MOVE_LENGTH})
	return result

func hit(at: Vector2) -> Dictionary:
	var nearest := {}
	var distance := HIT_RADIUS
	var camera: Camera3D = editor.host.camera
	# Front handles win ties when opposite faces project to the same location.
	var candidates := handles()
	candidates.sort_custom(func(a, b): return camera.position.distance_squared_to(a.point) < camera.position.distance_squared_to(b.point))
	for handle: Dictionary in candidates:
		if handle.kind == "move":
			var closest := Geometry2D.get_closest_point_to_segment(at, handle.screen_start, handle.screen_end)
			var candidate := closest.distance_to(at)
			if candidate < minf(distance, MOVE_HIT_RADIUS):
				distance = candidate
				nearest = handle
			continue
		var projected := camera.unproject_position(handle.point)
		var axis := camera.unproject_position(handle.point + handle.direction) - projected
		if axis.length() < 0.5: continue
		var candidate := projected.distance_to(at)
		if candidate < distance:
			distance = candidate
			nearest = handle
	return nearest

func draw(canvas: Control) -> void:
	if not active(): return
	if mode == "angle":
		rotation_tool.draw(canvas)
		return
	var camera: Camera3D = editor.host.camera
	if mode in ["size", "face"]:
		var part: Dictionary = editor.parts[editor.selected]
		for edge in Contract.edges(local_bounds(part), Kit.transform(part)):
			canvas.draw_line(camera.unproject_position(edge[0]), camera.unproject_position(edge[1]), Color(Tokens.SELECTION_COLOR, 0.85), Tokens.LINE_WIDTH, true)
	var entries := handles()
	entries.sort_custom(func(a, b): return camera.position.distance_squared_to(a.point) > camera.position.distance_squared_to(b.point))
	for handle: Dictionary in entries:
		if handle.kind == "move":
			var tip: Vector2 = handle.screen_end
			var direction: Vector2 = (tip - handle.screen_start).normalized()
			var side := direction.orthogonal() * MOVE_HEAD * 0.6
			var colour: Color = Tokens.SELECTION_COLOR if dragging and drag_handle.get("axis") == handle.axis else COLOURS[handle.axis]
			canvas.draw_line(handle.screen_start, tip - direction * MOVE_HEAD * 0.5, colour, Tokens.LINE_WIDTH, true)
			canvas.draw_colored_polygon(PackedVector2Array([tip, tip - direction * MOVE_HEAD + side, tip - direction * MOVE_HEAD - side]), colour)
			continue
		var point := camera.unproject_position(handle.point)
		var colour: Color = Tokens.SELECTION_COLOR if mode == "face" and handle.get("side", -1) == editing_face else COLOURS[handle.axis] if handle.axis >= 0 else Tokens.SELECTION_COLOR
		var radius := 6.0 * Tokens.POINT
		var box := Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2)
		canvas.draw_rect(box, Color("fff1cf"))
		canvas.draw_rect(box, colour, false, Tokens.LINE_WIDTH)

func begin(at: Vector2) -> bool:
	if not active(): return false
	var handle := hit(at)
	if mode == "angle": handle = rotation_tool.drag_handle(at)
	if handle.is_empty(): return false
	if mode == "face":
		editing_face = handle.side
		refresh()
	dragging = true
	changed = false
	drag_index = editor.selected
	drag_part = editor.selection_part()
	drag_handle = handle
	drag_pointer = at
	var camera: Camera3D = editor.host.camera
	if handle.kind == "rotation": rotation_tool.choose_axis(handle.axis)
	else: screen_axis = camera.unproject_position(handle.point + handle.direction) - camera.unproject_position(handle.point)
	previous_dirty = editor.host.dirty
	previous_redo = editor.host.redo_stack.duplicate(true)
	previous_undo = editor.host.undo_stack.duplicate()
	editor.dragging = false
	return true

func drag(at: Vector2) -> void:
	if not dragging: return
	if not active() or editor.selected != drag_index:
		end_drag()
		return
	var part: Dictionary
	if drag_handle.kind == "rotation":
		part = rotation_tool.drag_part(drag_part, drag_handle, at)
	else:
		var step: float = editor.selection_step() if drag_handle.kind == "move" else editor.EDIT_STEP
		var distance := snappedf((at - drag_pointer).dot(screen_axis) / screen_axis.length_squared(), step)
		part = transformed(drag_part, drag_handle, distance)
	if editor.selection_matches(part) or not editor.selection_valid(part): return
	if not changed:
		editor.host._remember()
		changed = true
	editor.apply_selection(part)
	editor.host._refresh()

static func transformed(part: Dictionary, handle: Dictionary, distance: float) -> Dictionary:
	var result := part.duplicate(true)
	if is_zero_approx(distance): return result
	if handle.kind == "move":
		result.at = (result.at + handle.direction * distance).clamp(Vector3.ONE * -32, Vector3.ONE * 32)
		return result
	if not Kit.Appearance.can_resize(part, handle.axis): return result
	var length_axis := Kit.Appearance.log_length_axis(part)
	if length_axis >= 0 and handle.kind != "face": return result
	var scale: Vector3 = Kit.Appearance.resize_scale(part)
	var minimum := 0.0
	var maximum := INF
	for axis in 3:
		if handle.kind != "corner" and handle.axis != axis: continue
		minimum = maxf(minimum, 0.01 / absf(scale[axis]))
		maximum = minf(maximum, (1.0 if length_axis >= 0 else 32.0) / absf(scale[axis]))
	var ratio := clampf((float(handle.length) + distance) / float(handle.length), minimum, maximum)
	if is_equal_approx(ratio, 1.0): return result
	for axis in 3:
		if handle.kind == "corner" or handle.axis == axis: scale[axis] *= ratio
	Kit.Appearance.set_resize_scale(result, scale)
	# The opposite face/corner remains fixed, including rotated/imported bases.
	var anchor: Vector3 = Kit.transform(part) * handle.anchor
	result.at = anchor - Kit.transform(result).basis * handle.anchor
	if not (result.at as Vector3).is_finite(): return part.duplicate(true)
	for axis in 3:
		if absf(result.at[axis]) > 32: return part.duplicate(true)
	return result

func end_drag() -> void:
	if dragging and changed and drag_index >= 0 and drag_index < editor.parts.size() and editor.selection_matches(drag_part):
		editor.host.undo_stack = previous_undo
		editor.host.redo_stack = previous_redo
		editor.host.dirty = previous_dirty
	dragging = false
	drag_part = {}
	drag_handle = {}
	previous_redo = []
	previous_undo = []

func cancel() -> void:
	if not dragging: return
	if drag_handle.get("kind") == "rotation":
		rotation_tool.choose_axis(drag_handle.previous_axis)
		rotation_tool.angle_spin.set_value_no_signal(drag_handle.previous_angle)
	if changed and drag_index >= 0 and drag_index < editor.parts.size():
		editor.apply_selection(drag_part)
		# Restore even when _remember evicted the oldest of 60 history states.
		editor.host.undo_stack = previous_undo
		editor.host.redo_stack = previous_redo
		editor.host.dirty = previous_dirty
	end_drag()
	editor.host._refresh()

func nudge(axis: int, sign_: int) -> void:
	if not active(): return
	end_drag()
	if editor.multiple_selected():
		if mode != "move": return
		var delta := Vector3.ZERO
		delta[axis] = sign_ * editor.selection_step()
		editor.move_selection(delta)
		return
	var part: Dictionary = editor.parts[editor.selected]
	var handle := {"kind": "move", "direction": Vector3.ZERO}
	handle.direction[axis] = 1
	if mode in ["size", "face"]:
		var bounds := local_bounds(part)
		var anchor := bounds.get_center()
		anchor[axis] = bounds.position[axis]
		var length := bounds.size[axis] * Kit.transform(part).basis[axis].length()
		if length < 0.00001: return
		handle = {"kind": "face", "axis": axis, "anchor": anchor, "length": length}
	var step: float = editor.Contract.Grid.CELL_SIZE if mode == "move" and editor.grid_placed(part) else editor.EDIT_STEP
	var result := transformed(part, handle, sign_ * step)
	if mode == "move" and editor.grid_placed(part):
		# A constrained nudge must not move untouched axes with numeric overrides.
		result.at[axis] = editor.placement_position(part, result.at)[axis]
	if result == part: return
	editor.host._remember()
	editor.parts[editor.selected] = result
	editor.host._refresh()
