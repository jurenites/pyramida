class_name BuildingBlueprintEditor
extends Node3D

const UIVisualTokens = preload("res://scripts/ui_visual_tokens.gd")

const BuildingBlueprintScript = preload("res://scripts/building_blueprint.gd")
const BlueprintInstanceScript = preload("res://scripts/building_blueprint_instance.gd")
const MaterialCatalog = preload("res://scripts/building_material_catalog.gd")
const Palette = preload("res://scripts/game_palette.gd")
const PixelUI = preload("res://scripts/pixel_ui.gd")

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const DEFAULT_BLUEPRINT_PATH := "user://blueprints/developer_world_unit.pyrbuilding"
const PART_KINDS: Array[String] = ["block", "log", "plank"]
const ORIENTATIONS: Array[String] = ["x", "y", "z"]

var _blueprint: BuildingBlueprint
var _blueprint_instance: BuildingBlueprintInstance
var _camera: Camera3D
var _hovered_sub_unit := Vector3i(-1, -1, -1)
var _selected_sub_unit := Vector3i.ZERO
var _selection_outline: MeshInstance3D
var _sub_unit_bodies: Array[StaticBody3D] = []
var _part_kind_index := 0
var _material_index := 0
var _orientation_index := 1
var _visual_variant := 0
var _edit_layer := 0
var _gray_mode := true
var _current_file_path := DEFAULT_BLUEPRINT_PATH
var _status_label: Label
var _mode_label: Label
var _blueprint_id_edit: LineEdit
var _file_dialog: FileDialog
var _file_dialog_is_save := false


func _ready() -> void:
	_blueprint = BuildingBlueprintScript.create_empty()
	_create_environment()
	_create_staging_world_unit()
	_create_camera()
	_create_interface()
	_refresh_blueprint_instance()
	_update_mode_label()
	_set_status("Empty one-World-Unit blueprint. Left-click a Sub-Unit to place a part.")


func _process(_delta: float) -> void:
	_update_hovered_sub_unit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key_input(event as InputEventKey)
	elif event is InputEventMouseButton:
		_handle_mouse_input(event as InputEventMouseButton)


func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_S:
		_open_file_dialog(true)
		return
	if event.ctrl_pressed and event.keycode == KEY_S:
		_save_blueprint(_current_file_path)
		return
	if event.ctrl_pressed and event.keycode == KEY_O:
		_open_file_dialog(false)
		return
	match event.keycode:
		KEY_ESCAPE, KEY_F2:
			_return_to_main_game()
		KEY_1:
			_select_part_kind(0)
		KEY_2:
			_select_part_kind(1)
		KEY_3:
			_select_part_kind(2)
		KEY_M:
			_cycle_material()
		KEY_R:
			_cycle_orientation()
		KEY_V:
			_cycle_variant()
		KEY_Y:
			_toggle_edit_layer()
		KEY_TAB:
			_toggle_gray_mode()
		KEY_DELETE, KEY_BACKSPACE:
			_remove_selected_part()
		KEY_N:
			_clear_blueprint()


func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if not event.pressed or get_viewport().gui_get_hovered_control() != null:
		return
	if not _is_valid_sub_unit(_hovered_sub_unit):
		return
	_selected_sub_unit = _hovered_sub_unit
	_update_selection_outline()
	if event.button_index == MOUSE_BUTTON_LEFT:
		_place_current_part()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_remove_selected_part()


func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Palette.SAND_SURFACE
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.78
	world_environment.environment = environment
	add_child(world_environment)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sunlight.light_color = Color("#FFF1D1")
	sunlight.light_energy = 1.15
	sunlight.shadow_enabled = true
	add_child(sunlight)

	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(18.0, 18.0)
	ground.mesh = ground_mesh
	ground.position.y = -0.015
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Palette.SAND_SURFACE
	ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = ground_material
	add_child(ground)


func _create_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 3.5
	_camera.position = Vector3(3.1, 2.75, 3.1)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.5, 0.0), Vector3.UP)
	_camera.current = true
	add_child(_camera)


func _create_staging_world_unit() -> void:
	var staging_root := Node3D.new()
	staging_root.name = "EditableWorldUnit"
	add_child(staging_root)

	for sub_x in 2:
		for sub_y in 2:
			for sub_z in 2:
				var sub_unit := Vector3i(sub_x, sub_y, sub_z)
				var cell_centre := _sub_unit_centre(sub_unit)
				var cell_body := StaticBody3D.new()
				cell_body.name = "SubUnit_%d_%d_%d" % [sub_x, sub_y, sub_z]
				cell_body.position = cell_centre
				cell_body.set_meta("blueprint_sub_unit", sub_unit)
				var cell_collision := CollisionShape3D.new()
				var cell_shape := BoxShape3D.new()
				cell_shape.size = Vector3.ONE * 0.48
				cell_collision.shape = cell_shape
				cell_body.add_child(cell_collision)
				staging_root.add_child(cell_body)
				_sub_unit_bodies.append(cell_body)

	var grid_lines := MeshInstance3D.new()
	grid_lines.name = "WorldUnitGrid"
	grid_lines.mesh = _world_unit_grid_mesh(Color("#6E6E6E"))
	staging_root.add_child(grid_lines)

	_selection_outline = MeshInstance3D.new()
	_selection_outline.name = "SelectedSubUnit"
	_selection_outline.mesh = _unit_box_line_mesh(0.49, Color.WHITE)
	_selection_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	staging_root.add_child(_selection_outline)
	_update_edit_layer_collisions()
	_update_selection_outline()


func _world_unit_grid_mesh(line_colour: Color) -> ImmediateMesh:
	var grid_mesh := ImmediateMesh.new()
	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = line_colour
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
	for sub_x in 2:
		for sub_y in 2:
			for sub_z in 2:
				_append_box_lines(
					grid_mesh,
					_sub_unit_centre(Vector3i(sub_x, sub_y, sub_z)),
					0.5
				)
	grid_mesh.surface_end()
	return grid_mesh


func _unit_box_line_mesh(box_size: float, line_colour: Color) -> ImmediateMesh:
	var box_lines := ImmediateMesh.new()
	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = line_colour
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.no_depth_test = true
	box_lines.surface_begin(Mesh.PRIMITIVE_LINES, line_material)
	_append_box_lines(box_lines, Vector3.ZERO, box_size)
	box_lines.surface_end()
	return box_lines


func _append_box_lines(target_mesh: ImmediateMesh, box_centre: Vector3, box_size: float) -> void:
	var half_size := box_size * 0.5
	var corners: Array[Vector3] = []
	for corner_x in 2:
		for corner_y in 2:
			for corner_z in 2:
				corners.append(box_centre + Vector3(
					-half_size if corner_x == 0 else half_size,
					-half_size if corner_y == 0 else half_size,
					-half_size if corner_z == 0 else half_size
				))
	for edge in [
		[0, 1], [0, 2], [0, 4], [1, 3], [1, 5], [2, 3],
		[2, 6], [3, 7], [4, 5], [4, 6], [5, 7], [6, 7],
	]:
		target_mesh.surface_add_vertex(corners[int(edge[0])])
		target_mesh.surface_add_vertex(corners[int(edge[1])])


func _create_interface() -> void:
	var interface_layer := CanvasLayer.new()
	interface_layer.name = "BlueprintEditorInterface"
	add_child(interface_layer)

	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(12.0, 12.0)
	toolbar.add_theme_constant_override("separation", 6)
	interface_layer.add_child(toolbar)

	toolbar.add_child(_make_button("← Main", _return_to_main_game))
	toolbar.add_child(_make_button("Block [1]", _select_part_kind.bind(0)))
	toolbar.add_child(_make_button("Log [2]", _select_part_kind.bind(1)))
	toolbar.add_child(_make_button("Plank [3]", _select_part_kind.bind(2)))
	toolbar.add_child(_make_button("Material [M]", _cycle_material))
	toolbar.add_child(_make_button("Rotate [R]", _cycle_orientation))
	toolbar.add_child(_make_button("Variant [V]", _cycle_variant))
	toolbar.add_child(_make_button("Layer [Y]", _toggle_edit_layer))
	toolbar.add_child(_make_button("Gray / Preview [Tab]", _toggle_gray_mode))
	toolbar.add_child(_make_button("Clear [N]", _clear_blueprint))
	toolbar.add_child(_make_button("Save", _save_current_blueprint))
	toolbar.add_child(_make_button("Save As", _open_file_dialog.bind(true)))
	toolbar.add_child(_make_button("Load", _open_file_dialog.bind(false)))

	var id_row := HBoxContainer.new()
	id_row.position = Vector2(12.0, 60.0)
	id_row.add_theme_constant_override("separation", 8)
	interface_layer.add_child(id_row)
	var id_label := Label.new()
	id_label.text = "Blueprint ID"
	id_row.add_child(id_label)
	_blueprint_id_edit = LineEdit.new()
	_blueprint_id_edit.text = _blueprint.blueprint_id
	_blueprint_id_edit.custom_minimum_size = Vector2(260.0, 32.0)
	_blueprint_id_edit.text_changed.connect(_on_blueprint_id_changed)
	id_row.add_child(_blueprint_id_edit)

	_mode_label = Label.new()
	_mode_label.position = Vector2(12.0, 104.0)
	_mode_label.add_theme_font_size_override("font_size", UIVisualTokens.BLUEPRINT_EDITOR_MODE_FONT_SIZE)
	interface_layer.add_child(_mode_label)

	var instructions := Label.new()
	instructions.position = Vector2(12.0, 132.0)
	instructions.text = (
		"Left click: place or replace part   •   Right click / Delete: remove\n"
		+ "Ctrl+S: save   •   Ctrl+Shift+S: save as   •   Ctrl+O: load   •   F2/Esc: main game"
	)
	instructions.add_theme_font_size_override("font_size", UIVisualTokens.BLUEPRINT_EDITOR_INSTRUCTIONS_FONT_SIZE)
	interface_layer.add_child(instructions)

	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status_label.position = Vector2(12.0, -46.0)
	_status_label.add_theme_font_size_override("font_size", UIVisualTokens.BLUEPRINT_EDITOR_STATUS_FONT_SIZE)
	interface_layer.add_child(_status_label)

	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.pyrbuilding ; Town Building Blueprint"])
	_file_dialog.file_selected.connect(_on_file_selected)
	interface_layer.add_child(_file_dialog)

	_apply_pixel_font(interface_layer)


func _make_button(button_text: String, callback: Callable) -> Button:
	var editor_button := Button.new()
	editor_button.text = button_text
	editor_button.custom_minimum_size = Vector2(0.0, 36.0)
	editor_button.pressed.connect(callback)
	return editor_button


func _apply_pixel_font(parent: Node) -> void:
	if parent is Control:
		PixelUI.apply(parent as Control)
	for child in parent.get_children():
		_apply_pixel_font(child)


func _update_hovered_sub_unit() -> void:
	if _camera == null or get_viewport().gui_get_hovered_control() != null:
		return
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_position)
	var ray_end := ray_origin + _camera.project_ray_normal(mouse_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var hit_collider := hit.get("collider") as Node
	if hit_collider == null or not hit_collider.has_meta("blueprint_sub_unit"):
		return
	var hit_sub_unit: Vector3i = hit_collider.get_meta("blueprint_sub_unit")
	if hit_sub_unit == _hovered_sub_unit:
		return
	_hovered_sub_unit = hit_sub_unit
	_selected_sub_unit = hit_sub_unit
	_update_selection_outline()


func _place_current_part() -> void:
	var part_kind := PART_KINDS[_part_kind_index]
	var orientation := ORIENTATIONS[_orientation_index]
	var material_id := MaterialCatalog.MATERIAL_IDS[_material_index]
	var blueprint_part := BuildingBlueprintScript.make_sub_unit_part(
		part_kind,
		_selected_sub_unit,
		orientation,
		material_id,
		_visual_variant
	)
	_blueprint.replace_part_at_sub_unit(_selected_sub_unit, blueprint_part)
	_refresh_blueprint_instance()
	_set_status("Placed %s in Sub-Unit %s. Recipe: %s" % [
		part_kind.capitalize(),
		str(_selected_sub_unit),
		_recipe_text(),
	])


func _remove_selected_part() -> void:
	if not _blueprint.remove_part_at_sub_unit(_selected_sub_unit):
		_set_status("Selected Sub-Unit is already empty.")
		return
	_refresh_blueprint_instance()
	_set_status("Removed part from Sub-Unit %s. Recipe: %s" % [
		str(_selected_sub_unit),
		_recipe_text(),
	])


func _select_part_kind(part_kind_index: int) -> void:
	_part_kind_index = clampi(part_kind_index, 0, PART_KINDS.size() - 1)
	_update_mode_label()


func _cycle_material() -> void:
	_material_index = (_material_index + 1) % MaterialCatalog.MATERIAL_IDS.size()
	_update_selected_part_from_tool()
	_update_mode_label()


func _cycle_orientation() -> void:
	_orientation_index = (_orientation_index + 1) % ORIENTATIONS.size()
	_update_selected_part_from_tool()
	_update_mode_label()


func _cycle_variant() -> void:
	_visual_variant = (_visual_variant + 1) % 3
	_update_selected_part_from_tool()
	_update_mode_label()


func _toggle_edit_layer() -> void:
	_edit_layer = 1 - _edit_layer
	_selected_sub_unit.y = _edit_layer
	_hovered_sub_unit = Vector3i(-1, -1, -1)
	_update_edit_layer_collisions()
	_update_selection_outline()
	_update_mode_label()


func _update_edit_layer_collisions() -> void:
	for sub_unit_body in _sub_unit_bodies:
		if not is_instance_valid(sub_unit_body):
			continue
		var sub_unit: Vector3i = sub_unit_body.get_meta("blueprint_sub_unit")
		sub_unit_body.collision_layer = 1 if sub_unit.y == _edit_layer else 0
		sub_unit_body.collision_mask = 1 if sub_unit.y == _edit_layer else 0


func _update_selected_part_from_tool() -> void:
	var existing_part := _blueprint.part_at_sub_unit(_selected_sub_unit)
	if existing_part.is_empty():
		return
	var updated_part := BuildingBlueprintScript.make_sub_unit_part(
		str(existing_part.get("kind", "block")),
		_selected_sub_unit,
		ORIENTATIONS[_orientation_index],
		MaterialCatalog.MATERIAL_IDS[_material_index],
		_visual_variant
	)
	_blueprint.replace_part_at_sub_unit(_selected_sub_unit, updated_part)
	_refresh_blueprint_instance()
	_set_status("Updated selected part. Recipe: %s" % _recipe_text())


func _toggle_gray_mode() -> void:
	_gray_mode = not _gray_mode
	_refresh_blueprint_instance()
	_update_mode_label()


func _clear_blueprint() -> void:
	_blueprint.clear_parts()
	_refresh_blueprint_instance()
	_set_status("Blueprint cleared. The editable World Unit is empty.")


func _refresh_blueprint_instance() -> void:
	if not is_instance_valid(_blueprint_instance):
		_blueprint_instance = BlueprintInstanceScript.new() as BuildingBlueprintInstance
		_blueprint_instance.name = "EditableBlueprint"
		add_child(_blueprint_instance)
	_blueprint_instance.editor_gray_mode = _gray_mode
	_blueprint_instance.set_blueprint(_blueprint)


func _update_selection_outline() -> void:
	if is_instance_valid(_selection_outline):
		_selection_outline.position = _sub_unit_centre(_selected_sub_unit)


func _update_mode_label() -> void:
	if not is_instance_valid(_mode_label):
		return
	_mode_label.text = "BUILDING CONSTRUCTOR — %s • %s • %s-axis • variant %d • %s layer • %s" % [
		PART_KINDS[_part_kind_index].capitalize(),
		MaterialCatalog.display_name(MaterialCatalog.MATERIAL_IDS[_material_index]),
		ORIENTATIONS[_orientation_index].to_upper(),
		_visual_variant + 1,
		"upper" if _edit_layer == 1 else "lower",
		"gray edit mode" if _gray_mode else "material preview",
	]


func _open_file_dialog(save_mode: bool) -> void:
	_file_dialog_is_save = save_mode
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save_mode else FileDialog.FILE_MODE_OPEN_FILE
	var absolute_path := ProjectSettings.globalize_path(_current_file_path)
	_file_dialog.current_dir = absolute_path.get_base_dir()
	_file_dialog.current_file = absolute_path.get_file()
	_file_dialog.title = "Save Building Blueprint" if save_mode else "Load Building Blueprint"
	_file_dialog.popup_centered_ratio(0.72)


func _on_file_selected(file_path: String) -> void:
	if _file_dialog_is_save:
		_save_blueprint(file_path)
	else:
		_load_blueprint(file_path)


func _save_current_blueprint() -> void:
	_save_blueprint(_current_file_path)


func _save_blueprint(file_path: String) -> void:
	_blueprint.blueprint_id = _safe_blueprint_id(_blueprint_id_edit.text)
	_blueprint.display_name = _blueprint.blueprint_id.replace("_", " ").capitalize()
	_blueprint_id_edit.text = _blueprint.blueprint_id
	var save_error := _blueprint.save_to_file(file_path)
	if save_error != OK:
		_set_status("Save failed: %s" % _blueprint.last_error)
		return
	_current_file_path = file_path
	_set_status("Saved %d logical parts to %s" % [
		_blueprint.parts.size(),
		ProjectSettings.globalize_path(file_path),
	])


func _load_blueprint(file_path: String) -> void:
	var loaded_blueprint := BuildingBlueprintScript.load_from_file(file_path)
	if not loaded_blueprint.last_error.is_empty():
		_set_status("Load failed: %s" % loaded_blueprint.last_error)
		return
	_blueprint = loaded_blueprint
	_current_file_path = file_path
	_blueprint_id_edit.text = _blueprint.blueprint_id
	_refresh_blueprint_instance()
	_set_status("Loaded %s with %d parts. Recipe: %s" % [
		ProjectSettings.globalize_path(file_path),
		_blueprint.parts.size(),
		_recipe_text(),
	])


func _on_blueprint_id_changed(new_text: String) -> void:
	_blueprint.blueprint_id = _safe_blueprint_id(new_text)


func _recipe_text() -> String:
	var recipe := _blueprint.recipe()
	if recipe.is_empty():
		return "empty"
	var resource_ids := recipe.keys()
	resource_ids.sort()
	var recipe_parts: Array[String] = []
	for resource_id in resource_ids:
		recipe_parts.append("%s ×%d" % [str(resource_id), int(recipe[resource_id])])
	return ", ".join(recipe_parts)


func _set_status(status_text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = status_text


func _return_to_main_game() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _sub_unit_centre(sub_unit: Vector3i) -> Vector3:
	return Vector3(
		-0.25 + 0.5 * float(sub_unit.x),
		0.25 + 0.5 * float(sub_unit.y),
		-0.25 + 0.5 * float(sub_unit.z)
	)


func _is_valid_sub_unit(sub_unit: Vector3i) -> bool:
	return (
		sub_unit.x in [0, 1]
		and sub_unit.y in [0, 1]
		and sub_unit.z in [0, 1]
	)


func _safe_blueprint_id(source_text: String) -> String:
	var normalised := source_text.strip_edges().to_lower().replace(" ", "_")
	var invalid_character := RegEx.create_from_string("[^a-z0-9_-]")
	normalised = invalid_character.sub(normalised, "", true)
	return normalised if not normalised.is_empty() else "building"
