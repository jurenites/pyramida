extends CanvasLayer
## Full-scale building layout experiments, isolated from settlement simulation.
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const View = preload("res://scripts/settlement/structure_workshop_view.gd")
const PATH := "user://structures/building_layout.json"
signal finished(to_editor: bool)
var storage_path := PATH
var restore_last := true
var auto_save := true
var entries: Array = []
var nodes: Array[Node3D] = []
var history: Array = []
var future: Array = []
var selected := -1
var snap := 0.5
var zoom := 32.0
var yaw := 0.55
var pitch := 0.85
var focus := Vector3.ZERO
var root: Control
var container: SubViewportContainer
var viewport: SubViewport
var scene: Node3D
var models: Node3D
var camera: Camera3D
var selection: Node3D
var readout: Label
var coordinates: Array[SpinBox] = []
var updating := false
var dragging := false
var orbiting := false
var panning := false
var drag_offset := Vector3.ZERO
var show_labels := true
var palette: ItemList
var specimens: Array = []
var save_timer := 0.0

func _ready() -> void:
	layer = 30
	_create_ui()
	_create_scene()
	if not restore_last or not _load(): gallery()
	else: _rebuild()
	_camera()

func _button(parent: Node, title: String, hint: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.tooltip_text = hint
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _create_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = Tokens.UI_FONT_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ffe6b5")
	style.content_margin_left = 8 * Tokens.POINT
	style.content_margin_right = 8 * Tokens.POINT
	style.content_margin_top = 5 * Tokens.POINT
	style.content_margin_bottom = 5 * Tokens.POINT
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, style)
		var hover := style.duplicate()
		hover.bg_color = Color("fff4d9")
		theme.set_stylebox("hover", type, hover)
		for state in ["font_color", "font_hover_color", "font_pressed_color"]: theme.set_color(state, type, Color("64452f"))
	theme.set_stylebox("panel", "ItemList", style)
	theme.set_color("font_color", "ItemList", Color("64452f"))
	root.theme = theme
	var background := ColorRect.new()
	background.color = Color("ffe6b5")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 4 * Tokens.POINT)
	root.add_child(layout)
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 4 * Tokens.POINT)
	toolbar.add_theme_constant_override("v_separation", 4 * Tokens.POINT)
	layout.add_child(toolbar)
	_button(toolbar, "Blueprints", "Return to settlement", func(): close(false))
	_button(toolbar, "Edit parts", "Open the existing blueprint editor", func(): close(true))
	_button(toolbar, "−", "Zoom out · mouse wheel", func(): zoom_by(1.2))
	_button(toolbar, "+", "Zoom in · mouse wheel", func(): zoom_by(1.0 / 1.2))
	_button(toolbar, "Fit", "Frame all buildings · F", fit_all)
	_button(toolbar, "Top", "Top-down footprint comparison", func(): pitch = PI * 0.499; _camera())
	var snapping := OptionButton.new()
	for title in ["Free", "0.5 m", "1 m"]: snapping.add_item(title)
	snapping.select(1)
	snapping.tooltip_text = "Placement snap; metre grid stays fixed"
	snapping.item_selected.connect(func(index): snap = [0.0, 0.5, 1.0][index])
	toolbar.add_child(snapping)
	_button(toolbar, "Copy", "Duplicate selection · D", duplicate_selected)
	_button(toolbar, "↻", "Rotate 90° · R", rotate_selected)
	_button(toolbar, "Delete", "Remove selection · Delete", remove_selected)
	_button(toolbar, "Undo", "Undo · Ctrl/Cmd+Z", undo)
	_button(toolbar, "Redo", "Redo · Ctrl/Cmd+Shift+Z", redo)
	_button(toolbar, "Labels", "Toggle building labels", func(): show_labels = not show_labels; _rebuild())
	_button(toolbar, "All tiers", "Reset to the comparison gallery (undoable)", func(): remember(); gallery())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	palette = ItemList.new()
	palette.custom_minimum_size.x = 230 * Tokens.POINT
	palette.tooltip_text = "Double-click to add a copy at the camera centre"
	body.add_child(palette)
	palette.item_activated.connect(func(index): add_specimen(specimens[index]))
	container = preload("res://scripts/window_world_surface.gd").new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.focus_mode = Control.FOCUS_ALL
	container.tooltip_text = "Drag: move · Right-drag: orbit · Middle-drag: pan · Wheel: zoom"
	container.gui_input.connect(_view_input)
	body.add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)
	var details := HBoxContainer.new()
	layout.add_child(details)
	readout = Label.new()
	readout.add_theme_color_override("font_color", Color("64452f"))
	readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(readout)
	for axis in 3:
		var label := Label.new()
		label.text = Tokens.BLUEPRINT_AXIS_LABELS[axis]
		label.add_theme_color_override("font_color", Color("64452f"))
		details.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = -500
		spin.max_value = 500
		spin.step = 0.1
		spin.custom_minimum_size.x = 110
		spin.value_changed.connect(func(value):
			if updating or selected < 0: return
			remember()
			entries[selected].at[axis] = value
			_rebuild())
		details.add_child(spin)
		coordinates.append(spin)

func _create_scene() -> void:
	scene = Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("fff1cf")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color.WHITE
	sky.ambient_light_energy = 0.8
	environment.environment = sky
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	scene.add_child(light)
	View.box(scene, Vector3(1000, 0.02, 1000), Vector3(0, -0.04, 0), Color("f5e5c7"))
	View.grid(scene, 0, 100, Color("ded3bb"))
	models = Node3D.new()
	scene.add_child(models)
	selection = Node3D.new()
	scene.add_child(selection)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.far = 2000
	scene.add_child(camera)
	var kinds: Array = []
	for group: Array in Catalog.CATEGORIES.values():
		for kind: String in group:
			if kind not in Catalog.SEEDS and kind not in kinds: kinds.append(kind)
	for kind in Catalog.COSTS:
		if kind not in kinds and kind not in Catalog.SEEDS and Catalog.DEFINITIONS.has(kind) and ResourceLoader.exists("res://data/settlement/" + kind + ".tscn"): kinds.append(kind)
	for kind: String in kinds:
		var tiers := 3 if kind in ["windmill", "sawmill", "stone_storage", "well"] else (2 if kind == "platform" else 1)
		for tier in range(1, tiers + 1):
			var spec := {"kind": kind, "tier": tier}
			specimens.append(spec)
			palette.add_item(title(spec))

func title(entry: Dictionary) -> String:
	return entry.kind.replace("_", " ").capitalize() + (" · T%d" % entry.tier if entry.kind in ["windmill", "sawmill", "stone_storage", "platform", "well"] else "")

func gallery() -> void:
	entries.clear()
	for index in specimens.size():
		var entry: Dictionary = specimens[index].duplicate()
		entry.at = Vector3((index % 6) * 7.0, 0, (index / 6) * 7.0)
		entry.turn = 0
		entries.append(entry)
	selected = -1
	_rebuild()
	fit_all()

func dimensions(entry: Dictionary) -> Vector3:
	var size: Vector3 = Catalog.DEFINITIONS[entry.kind].size
	if entry.kind == "platform": return Vector3(2, entry.tier, 2)
	if entry.kind == "windmill" and entry.tier < 3: size.y = 1.15
	if entry.kind == "well": size.y = [0.15, 0.42, 1.85][entry.tier - 1]
	return size

func _rebuild() -> void:
	for child in models.get_children(): child.free()
	nodes.clear()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var holder := Node3D.new()
		holder.position = entry.at
		holder.rotation.y = -int(entry.turn) * PI / 2
		models.add_child(holder)
		nodes.append(holder)
		var asset := Assets.create(entry.kind)
		holder.add_child(asset)
		match str(entry.kind):
			"windmill": preload("res://scripts/settlement/mill_view.gd").sync(asset, entry.tier)
			"sawmill": preload("res://scripts/settlement/sawmill_view.gd").sync(asset, entry.tier)
			"stone_storage": preload("res://scripts/settlement/stone_storage_view.gd").sync(asset, entry.tier)
			"well": preload("res://scripts/settlement/well_view.gd").sync(asset, entry.tier, 1, entry.tier)
			"waterworks": preload("res://scripts/settlement/well_view.gd").sync(asset, 3, 1, 3, true)
			"platform":
				preload("res://scripts/settlement/platform_tiers.gd").sync(asset, entry.tier)
				asset.position.y = entry.tier
		var size := dimensions(entry)
		var body := StaticBody3D.new()
		body.set_meta("entry", index)
		holder.add_child(body)
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size.max(Vector3(0.15, 0.15, 0.15))
		collider.shape = box
		collider.position.y = size.y * 0.5
		body.add_child(collider)
		_outline(holder, size, Color("b79167"), 0.018)
		var access := asset.get_node_or_null("AccessFront") as Node3D
		if access != null:
			var marker := access.position
			marker.y = 0.045
			View.box(holder, Vector3(0.24, 0.035, 0.24), marker, Color("287d82"))
			View.box(holder, Vector3(0.045, 0.04, 0.5), marker + Vector3(0, 0, 0.15), Color("287d82"))
		if show_labels:
			var label := Label3D.new()
			label.text = title(entry)
			label.font_size = 40
			label.pixel_size = 0.009
			label.modulate = Color("64452f")
			label.outline_modulate = Color("fff1cf")
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = Vector3(0, 0.3, size.z * 0.5 + 0.7)
			holder.add_child(label)
	_refresh_selection()
	save_timer = 0.5

func _outline(parent: Node3D, size: Vector3, colour: Color, thickness: float) -> void:
	for x in [-size.x / 2, size.x / 2]: View.box(parent, Vector3(thickness, 0.025, size.z), Vector3(x, 0.025, 0), colour)
	for z in [-size.z / 2, size.z / 2]: View.box(parent, Vector3(size.x, 0.025, thickness), Vector3(0, 0.025, z), colour)

func _refresh_selection() -> void:
	for child in selection.get_children(): child.free()
	updating = true
	readout.text = "1 m grid" if selected < 0 else "%s   %.2f × %.2f × %.2f m" % [title(entries[selected]), dimensions(entries[selected]).x, dimensions(entries[selected]).z, dimensions(entries[selected]).y]
	for axis in 3:
		coordinates[axis].editable = selected >= 0
		coordinates[axis].set_value_no_signal(entries[selected].at[axis] if selected >= 0 else 0)
	if selected >= 0:
		selection.position = entries[selected].at
		selection.rotation.y = -int(entries[selected].turn) * PI / 2
		_outline(selection, dimensions(entries[selected]), Color("e58b3e"), 0.07)
	updating = false

func remember() -> void:
	history.append(entries.duplicate(true))
	if history.size() > 80: history.pop_front()
	future.clear()

func undo() -> void:
	if history.is_empty(): return
	future.append(entries.duplicate(true))
	entries = history.pop_back()
	selected = -1
	_rebuild()

func redo() -> void:
	if future.is_empty(): return
	history.append(entries.duplicate(true))
	entries = future.pop_back()
	selected = -1
	_rebuild()

func add_specimen(spec: Dictionary) -> void:
	remember()
	var entry := spec.duplicate()
	entry.at = snapped_position(Vector3(focus.x, 0, focus.z))
	entry.turn = 0
	entries.append(entry)
	selected = entries.size() - 1
	_rebuild()

func duplicate_selected() -> void:
	if selected < 0: return
	remember()
	var entry: Dictionary = entries[selected].duplicate(true)
	entry.at += Vector3(1, 0, 1) * (snap if snap > 0 else 0.5)
	entries.append(entry)
	selected = entries.size() - 1
	_rebuild()

func rotate_selected() -> void:
	if selected < 0: return
	remember()
	entries[selected].turn = (int(entries[selected].turn) + 1) % 4
	_rebuild()

func remove_selected() -> void:
	if selected < 0: return
	remember()
	entries.remove_at(selected)
	selected = -1
	_rebuild()

func snapped_position(point: Vector3) -> Vector3:
	if snap <= 0: return point
	return Vector3(snappedf(point.x, snap), point.y, snappedf(point.z, snap))

func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, 2, 180)
	_camera()

func fit_all() -> void:
	if entries.is_empty(): return
	var bounds := AABB(entries[0].at, Vector3.ONE)
	for entry: Dictionary in entries: bounds = bounds.merge(AABB(entry.at - Vector3(2, 0, 2), dimensions(entry) + Vector3(4, 0, 4)))
	focus = bounds.get_center()
	zoom = maxf(8, maxf(bounds.size.x, bounds.size.z) * 1.1)
	_camera()

func _camera() -> void:
	camera.size = zoom
	camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 300
	camera.look_at(focus)

func ground_point(at: Vector2, height: float) -> Variant:
	return Plane(Vector3.UP, height).intersects_ray(camera.project_ray_origin(at), camera.project_ray_normal(at))

func pick(at: Vector2) -> int:
	var origin := camera.project_ray_origin(at)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(at) * 2000)
	var hit := scene.get_world_3d().direct_space_state.intersect_ray(query)
	return int(hit.collider.get_meta("entry", -1)) if not hit.is_empty() else -1

func _view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		container.grab_focus()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_by(1 / 1.12)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_by(1.12)
		if event.button_index == MOUSE_BUTTON_RIGHT: orbiting = event.pressed
		if event.button_index == MOUSE_BUTTON_MIDDLE: panning = event.pressed
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				selected = pick(event.position)
				_refresh_selection()
				if selected >= 0:
					if event.alt_pressed: duplicate_selected()
					remember()
					var point = ground_point(event.position, entries[selected].at.y)
					if point != null:
						drag_offset = entries[selected].at - point
						dragging = true
			else:
				dragging = false
				save_timer = 0.1
	if event is InputEventMouseMotion:
		if orbiting:
			yaw -= event.relative.x * 0.008
			pitch = clampf(pitch + event.relative.y * 0.006, 0.2, PI * 0.499)
			_camera()
		elif panning:
			var factor := zoom / maxf(container.size.y, 1)
			focus += (-camera.global_basis.x * event.relative.x + Vector3(sin(yaw), 0, cos(yaw)) * event.relative.y) * factor
			_camera()
		elif dragging and selected >= 0:
			var point = ground_point(event.position, entries[selected].at.y)
			if point != null:
				entries[selected].at = snapped_position(point + drag_offset)
				nodes[selected].position = entries[selected].at
				_refresh_selection()
	container.accept_event()

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging = false; save_timer = 0.1
		if event.button_index == MOUSE_BUTTON_RIGHT: orbiting = false
		if event.button_index == MOUSE_BUTTON_MIDDLE: panning = false
	if not event is InputEventKey or not event.pressed or event.echo: return
	if root.get_viewport().gui_get_focus_owner() is LineEdit: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_D: duplicate_selected()
		KEY_R: rotate_selected()
		KEY_DELETE, KEY_BACKSPACE: remove_selected()
		KEY_F: fit_all()
		KEY_Z:
			if event.ctrl_pressed or event.meta_pressed:
				if event.shift_pressed: redo()
				else: undo()
		KEY_ESCAPE:
			selected = -1
			dragging = false
			_refresh_selection()
		KEY_F2: close(false)
		_: return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if auto_save and save_timer > 0:
		save_timer -= delta
		if save_timer <= 0 and not dragging: save_layout()

func save_layout(path := "") -> bool:
	if path.is_empty(): path = storage_path
	var packed: Array = []
	for entry: Dictionary in entries: packed.append({"kind": entry.kind, "tier": entry.tier, "turn": entry.turn, "at": [entry.at.x, entry.at.y, entry.at.z]})
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version": 1, "entries": packed, "camera": {"focus": [focus.x, focus.y, focus.z], "zoom": zoom, "yaw": yaw, "pitch": pitch}, "snap": snap}))
	return true

func _load(path := "") -> bool:
	if path.is_empty(): path = storage_path
	if not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1 or not data.get("entries") is Array: return false
	var loaded: Array = []
	for entry in data.entries:
		if not entry is Dictionary or not Catalog.DEFINITIONS.has(entry.get("kind", "")) or not entry.get("at") is Array or entry.at.size() != 3: return false
		if not specimens.any(func(spec): return spec.kind == entry.kind and spec.tier == entry.get("tier")): return false
		loaded.append({"kind": entry.kind, "tier": int(entry.tier), "turn": posmod(int(entry.get("turn", 0)), 4), "at": Vector3(float(entry.at[0]), float(entry.at[1]), float(entry.at[2]))})
	entries = loaded
	var pose: Dictionary = data.get("camera", {})
	if pose.get("focus") is Array and pose.focus.size() == 3:
		focus = Vector3(float(pose.focus[0]), float(pose.focus[1]), float(pose.focus[2]))
		zoom = clampf(float(pose.get("zoom", 32)), 2, 180)
		yaw = float(pose.get("yaw", 0.55))
		pitch = clampf(float(pose.get("pitch", 0.85)), 0.2, PI * 0.499)
	return true

func close(to_editor: bool) -> void:
	save_layout()
	finished.emit(to_editor)
	queue_free()
