extends RefCounted
## Piece construction shares the F2 viewport, history and document lifecycle.
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
var host: CanvasLayer
var enabled := false
var parts: Array = []
var kind := "log"
var component := ""
var piece_scale := Vector3.ONE
var piece_timber_species := "tree"
var piece_basis := Basis.IDENTITY
var building_kind := ""
var building_picker: OptionButton
var apply_button: Button
var original_button: Button
var building_drafts: Dictionary = {}
var rotation := Vector3.ZERO
var selected := -1:
	set(value):
		selected = value
		selection_changed()
var selecting := false
var plane_height := 0.0
var automatic := true
var pointer: Variant = null
var candidate := {}
var ghost: Node3D
var panel: VBoxContainer
var button: Button
var palette: OptionButton
var height_spin: SpinBox
var auto_button: CheckButton
var select_button: Button
var coordinates: Array[SpinBox] = []
var selection_panel: VBoxContainer
var updating := false

func _init(workshop: CanvasLayer) -> void:
	host = workshop

func selection_changed() -> void:
	pass

func create_ui(parent: VBoxContainer) -> void:
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8 * Tokens.GAP_UNIT)
	parent.add_child(panel)
	host._label(panel, "Building")
	building_picker = OptionButton.new()
	building_picker.fit_to_longest_item = false
	building_picker.add_item("Custom")
	for item in Kit.Appearance.buildings(): building_picker.add_item(Kit.title(item).capitalize())
	building_picker.item_selected.connect(func(index): open_building("" if index == 0 else str(Kit.Appearance.buildings()[index - 1])))
	panel.add_child(building_picker)
	apply_button = host._button(panel, "Apply to game", apply_building)
	apply_button.tooltip_text = "Save this appearance for every building of this type"
	original_button = host._button(panel, "Original", restore_original)
	original_button.tooltip_text = "Restore the original building in this draft (undoable)"
	host._label(panel, "Add piece")
	palette = OptionButton.new()
	palette.fit_to_longest_item = false
	for item in Kit.kinds(): palette.add_item(Kit.title(item))
	palette.item_selected.connect(func(index):
		kind = Kit.kinds()[index]
		component = ""
		piece_scale = Vector3.ONE
		piece_timber_species = "tree"
		piece_basis = Basis.IDENTITY
		selecting = false
		selected = -1
		refresh()
		repick())
	panel.add_child(palette)
	var tools := HBoxContainer.new()
	panel.add_child(tools)
	host._icon_button(tools, "add", "Place individual pieces", func(): selecting = false; selected = -1; refresh(); repick())
	select_button = host._icon_button(tools, "select", "Select a piece", func(): selecting = true; refresh(); repick())
	select_button.toggle_mode = true
	host._icon_button(tools, "copy", "Copy selected piece", copy_selected)
	host._icon_button(tools, "remove", "Remove selected piece", remove_selected)
	var angles := HBoxContainer.new()
	panel.add_child(angles)
	host._button(angles, "Z ↻", func(): rotate(1, PI / 2)).tooltip_text = "Rotate 90° · R"
	host._button(angles, "X ↻", func(): rotate(0, PI / 4)).tooltip_text = "Pitch 45° · Shift+T"
	host._button(angles, "Y ↻", func(): rotate(2, PI / 4)).tooltip_text = "Tilt 45° · T"
	auto_button = CheckButton.new()
	auto_button.text = "Surface snap"
	auto_button.button_pressed = automatic
	auto_button.toggled.connect(func(value): automatic = value; refresh(); repick())
	panel.add_child(auto_button)
	height_spin = host._spin(panel, "Height", -6, 12, 0, func(value):
		if updating: return
		plane_height = value
		automatic = false
		refresh()
		repick(), Kit.SNAP)
	height_spin.tooltip_text = "Placement plane in metres · Q / E · F restores surface snap"
	selection_panel = VBoxContainer.new()
	panel.add_child(selection_panel)
	for axis in 3:
		coordinates.append(host._spin(selection_panel, Tokens.BLUEPRINT_AXIS_LABELS[axis], -12, 12, 0, func(value):
			if updating or selected < 0: return
			host._remember()
			parts[selected].at[axis] = value
			host._refresh(), Kit.SNAP))
	var history := HBoxContainer.new()
	panel.add_child(history)
	host._icon_button(history, "undo", "Undo · Ctrl/Cmd+Z", host.undo)
	host._icon_button(history, "redo", "Redo · Ctrl/Cmd+Shift+Z", host.redo)
	host._button(panel, "Cabin", func():
		host._remember()
		stash_building()
		building_kind = ""
		parts = Kit.cabin()
		host.draft.name = "Log cabin"
		selected = -1
		host._refresh()
		fit()).tooltip_text = "Load a log, plank and hay example (undoable)"
	host._button(panel, "Clear", func():
		if parts.is_empty(): return
		host._remember()
		parts = []
		selected = -1
		host._refresh()).tooltip_text = "Start an empty piece building (undoable)"

func stash_building() -> void:
	building_drafts[building_kind] = parts.duplicate(true)

func open_building(value: String) -> void:
	if value == building_kind: return
	host._remember()
	stash_building()
	building_kind = value
	if building_drafts.has(value):
		parts = building_drafts[value].duplicate(true)
	elif value.is_empty():
		parts = []
	else:
		var saved := Kit.Appearance.saved(value)
		parts = saved.parts.duplicate(true) if not saved.is_empty() else Kit.Appearance.defaults(value)
	host.draft.name = "Custom" if value.is_empty() else Kit.title(value).capitalize()
	selected = -1
	selecting = true
	leave()
	host._refresh()
	fit()

func restore_original() -> void:
	if building_kind.is_empty(): return
	host._remember()
	parts = Kit.Appearance.defaults(building_kind)
	selected = -1
	selecting = true
	leave()
	host._refresh()
	fit()

func apply_building() -> void:
	if building_kind.is_empty(): return
	if Kit.Appearance.save(building_kind, parts):
		Kit.bounds_cache.clear()
		host._status("Appearance applied.")
	else:
		host._status("Could not apply appearance.")

func activate() -> void:
	host.cancel_move()
	enabled = true
	host.playing = false
	host.orbiting = false
	host._refresh()
	fit()

func refresh() -> void:
	panel.visible = enabled
	button.set_pressed_no_signal(enabled)
	if not enabled: return
	updating = true
	building_picker.select(0 if building_kind.is_empty() else Kit.Appearance.buildings().find(building_kind) + 1)
	apply_button.visible = not building_kind.is_empty()
	original_button.visible = apply_button.visible
	apply_button.disabled = parts.is_empty()
	palette.select(Kit.kinds().find(kind))
	select_button.set_pressed_no_signal(selecting)
	height_spin.set_value_no_signal(plane_height)
	auto_button.set_pressed_no_signal(automatic)
	if selected >= parts.size(): selected = -1
	selection_panel.visible = selected >= 0
	if selected >= 0:
		for axis in 3: coordinates[axis].set_value_no_signal(parts[selected].at[axis])
	updating = false

func draw() -> void:
	for part: Dictionary in parts: Kit.draw(host.geometry, part)
	host.overlay.buildings = []
	host.overlay.camera = host.camera
	host.overlay.placement_visible = false
	ghost = null
	candidate = {}
	if selected >= 0: outline(parts[selected])
	repick()

func outline(part: Dictionary) -> void:
	var box := Kit.bounds(part)
	host.overlay.placement_edges.clear()
	for corner in 8:
		for axis in 3:
			var other: int = corner ^ (1 << axis)
			if other > corner:
				host.overlay.placement_edges.append(PackedVector3Array([box.get_endpoint(corner), box.get_endpoint(other)]))
	host.overlay.placement_visible = true

func pick(at: Vector2) -> Dictionary:
	var ray: Vector3 = host.camera.project_ray_origin(at)
	var direction: Vector3 = host.camera.project_ray_normal(at)
	return Kit.pick(parts, ray, direction)

func hover(at: Vector2) -> void:
	pointer = at
	if is_instance_valid(ghost): ghost.free()
	candidate = {}
	host.overlay.placement_visible = false
	if selecting:
		var hit := pick(at)
		if not hit.is_empty(): outline(parts[hit.index])
		elif selected >= 0: outline(parts[selected])
		return
	var hit := pick(at) if automatic else {}
	var point: Variant
	var normal := Vector3.UP
	if not hit.is_empty():
		point = hit.point
		normal = hit.normal
	else:
		point = Plane(Vector3.UP, plane_height).intersects_ray(host.camera.project_ray_origin(at), host.camera.project_ray_normal(at))
	if point == null: return
	candidate = Kit.placement(kind, rotation, point, normal, component, piece_scale, piece_basis)
	if Kit.Appearance.has_timber(candidate): candidate.timber_species = piece_timber_species
	var box := Kit.bounds(candidate)
	if box.position.x < -12 or box.end.x > 12 or box.position.z < -12 or box.end.z > 12 or box.position.y < -6 or box.end.y > 12:
		candidate = {}
		return
	ghost = Kit.draw(host.geometry, candidate, true)
	outline(candidate)

func leave() -> void:
	pointer = null
	candidate = {}
	if is_instance_valid(ghost): ghost.free()
	host.overlay.placement_visible = false
	if enabled and selected >= 0: outline(parts[selected])

func repick() -> void:
	if pointer != null and enabled: hover(pointer)

func click(at: Vector2, erase := false) -> void:
	var hit := pick(at)
	if erase:
		if not hit.is_empty():
			host._remember()
			parts.remove_at(hit.index)
			selected = -1
	elif selecting:
		selected = int(hit.get("index", -1))
	else:
		hover(at)
		if candidate.is_empty() or parts.size() >= Kit.LIMIT: return
		host._remember()
		parts.append(candidate.duplicate(true))
	host._refresh()

func rotate(axis: int, angle: float) -> void:
	if selecting and selected >= 0:
		host._remember()
		parts[selected].rotation[axis] = wrapf(parts[selected].rotation[axis] + angle, -PI, PI)
		host._refresh()
	else:
		rotation[axis] = wrapf(rotation[axis] + angle, -PI, PI)
		repick()

func copy_selected() -> void:
	if selected < 0: return
	kind = parts[selected].kind
	component = parts[selected].get("component", "")
	piece_scale = parts[selected].get("scale", Vector3.ONE)
	piece_timber_species = parts[selected].get("timber_species", "tree")
	piece_basis = parts[selected].get("basis", Basis.IDENTITY)
	rotation = parts[selected].rotation
	selecting = false
	selected = -1
	refresh()
	repick()

func remove_selected() -> void:
	if selected < 0: return
	host._remember()
	parts.remove_at(selected)
	selected = -1
	host._refresh()

func shift_height(amount: int) -> void:
	plane_height = clampf(plane_height + amount * Kit.SNAP, -6, 12)
	automatic = false
	refresh()
	repick()

func fit() -> void:
	var box := AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	for part: Dictionary in parts: box = box.merge(Kit.bounds(part))
	host.focus = box.get_center()
	host.zoom = clampf(box.size.length() * 1.4, 4, 38)
	host._camera_update()
	repick()

func input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed: host.scene_container.grab_focus()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			click(event.position, event.shift_pressed)
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			host.zoom = clampf(host.zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 2, 40)
			host._camera_update()
			hover(event.position)
	if event is InputEventMouseMotion:
		hover(event.position)
	host.scene_container.accept_event()
