extends CanvasLayer
const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")
## A reversible authoring workspace; the settlement is paused while it is open.
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
const Picker = preload("res://scripts/settlement/structure_picker.gd")
const View = preload("res://scripts/settlement/structure_workshop_view.gd")
const Life = preload("res://scripts/settlement/structure_life.gd")
const Overlay = preload("res://scripts/settlement/structure_workshop_overlay.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const PartsEditor = preload("res://scripts/settlement/asset_workbench.gd")
var layout_sandbox: CanvasLayer
var pieces: RefCounted
var legacy_controls: Control
var advanced_button: Button
var back_to_assets: Button
const DEFAULT_PATH := "user://structures/workshop.pyrstructure"
signal closed
@export var restore_last := true
var draft := Shape.preset(0)
var instances: Array = []
var undo_stack: Array = []
var redo_stack: Array = []
var mode := 0
var edit_level := 0
var manual_level := false
var auto_height: CheckButton
var last_pointer: Variant = null
var origin := Vector3i.ZERO
var turns := 0
var selected_material := "stone"
var brush := 0
var brace_start: Variant = null
var selected_instance := -1
var current_path := DEFAULT_PATH
var dirty := false
var root: Control
var scene_view: SubViewport
var scene_container: SubViewportContainer
var scene_root: Node3D
var geometry: Node3D
var hover_mesh: MeshInstance3D
var camera: Camera3D
var yaw := 0.72
var pitch := 0.55
var zoom := 12.0
var focus := Vector3(0, 0.5, 0)
var orbiting := false
var panning := false
var hovered: Variant = null
var name_edit: LineEdit
var level_spin: SpinBox
var origin_spins: Array[SpinBox] = []
var work_spin: SpinBox
var brace_work_spin: SpinBox
var worker_spin: SpinBox
var stats: Label
var support_label: Label
var status: Label
var mode_buttons: Array[Button] = []
var brush_buttons: Array[Button] = []
var layer_buttons: Dictionary = {}
var right_tabs: TabContainer
var stack_controls: VBoxContainer
var assembly_list: ItemList
var preview_bar: ProgressBar
var play_button: Button
var file_dialog: FileDialog
var cutaway: CheckButton
var layer_caption: Label
var save_button: Button
var undo_button: Button
var redo_button: Button
var elapsed := 0.0
var playing := false
var updating := false
var grid_x: SpinBox
var grid_z: SpinBox
var last_preview_step := -1
var settling_instance := -1
var rotation_label: Label
var help_dialog: AcceptDialog
var status_seconds := 0.0
var overlay: Control
var move_index := -1
var move_origin := Vector3i.ZERO
var move_turns := 0
var utility_mount := "wall"
var rng := RandomNumberGenerator.new()
var upgrade_buttons: Dictionary = {}
var advanced_panel: Control
var selection_actions: HBoxContainer
var placement_actions: HBoxContainer
var cancel_button: Button

const INK := Color("64452f")
const MUTED := Color("96704f")
const PAPER := Color("ffe6b5")
const ACCENT := Color("174f52")

func _ready() -> void:
	layer = 20
	rng.randomize()
	pieces = PartsEditor.new(self)
	_create_interface()
	_create_world()
	if restore_last and FileAccess.file_exists(DEFAULT_PATH):
		_load(DEFAULT_PATH)
	_refresh()
	_status("")
	if restore_last:
		pieces.enabled = true
		if pieces.parts.is_empty(): pieces.open_asset("house")
		_refresh()
		pieces.fit()

func open_layout() -> void:
	# Older callers now land in the same asset editor.
	visible = true
	scene_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pieces.activate()

func _style(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(0)
	style.content_margin_left = VisualTokens.PANEL_PADDING_X
	style.content_margin_right = VisualTokens.PANEL_PADDING_X
	style.content_margin_top = VisualTokens.PANEL_PADDING_Y
	style.content_margin_bottom = VisualTokens.PANEL_PADDING_Y
	return style

func _label(parent: Node, text_: String, colour := INK) -> Label:
	var label := Label.new()
	label.text = text_
	label.add_theme_font_size_override("font_size", VisualTokens.UI_FONT_SIZE)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label

func _wrap(parent: Node, text_: String, colour := MUTED) -> Label:
	var label := _label(parent, text_, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _icon_button(parent: Node, symbol: String, hint: String, callback: Callable) -> Button:
	var paths := {
		"open": '<path d="M3 8h7l2-3h9v14H3z"/><path d="M3 8V5h6l2 3"/>',
		"save": '<path d="M4 3h13l3 3v15H4z"/><path d="M8 3v6h8V3M8 21v-8h8v8"/>',
		"save_as": '<path d="M4 3h13l3 3v6M4 3v18h7M8 3v6h8V3M8 21v-8h4M17 15v7M13.5 18.5h7"/>',
		"close": '<path d="m6 6 12 12M18 6 6 18"/>',
		"add": '<path d="M12 4v16M4 12h16"/>',
		"minus": '<path d="M4 12h16"/>',
		"erase": '<path d="m4 14 9-10 8 7-9 10H9zM9 9l8 7M12 21h9"/>',
		"brace": '<path d="M4 4v16h16M4 18 18 4M12 4h8v8"/>',
		"undo": '<path d="m8 4-5 5 5 5M3 9h11a7 7 0 0 1 0 14"/>',
		"redo": '<path d="m16 4 5 5-5 5M21 9H10a7 7 0 0 0 0 14"/>',
		"copy": '<rect x="8" y="8" width="12" height="13" rx="1"/><path d="M16 8V3H3v13h5"/>',
		"remove": '<path d="M3 6h18M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7M14 10v7"/>',
		"fit": '<path d="M9 3H3v6M15 3h6v6M3 15v6h6M21 15v6h-6"/><rect x="8" y="8" width="8" height="8"/>',
		"rotate": '<path d="M20 10a8 8 0 1 0-2 8M20 3v7h-7"/>',
		"select": '<path d="M5 3v17l5-5 4 7 4-2-4-7h7z"/>',
		"move": '<path d="M12 2v20M2 12h20M8 6l4-4 4 4M8 18l4 4 4-4M6 8l-4 4 4 4M18 8l4 4-4 4"/>',
		"door": '<path d="M5 22V3h14v19M14 12h2"/>',
		"ladder": '<path d="M6 2v20M18 2v20M6 6h12M6 12h12M6 18h12"/>',
		"ac": '<rect x="3" y="5" width="18" height="14"/><path d="M7 9h10M7 14h10"/>',
		"dish": '<path d="M4 5a13 13 0 0 0 15 15zM11 13l7-9M9 18v4h9"/>',
		"help": '<circle cx="12" cy="12" r="9"/><path d="M9 9a3 3 0 1 1 4 3c-1 .5-1 1-1 2M12 17v.5"/>',
	}
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#64452f" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">' + str(paths[symbol]) + '</g></svg>'
	var image := Image.new()
	image.load_svg_from_string(svg, 2.0)
	var button := _button(parent, "", callback)
	button.icon = ImageTexture.create_from_image(image)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 24 * VisualTokens.POINT)
	button.custom_minimum_size = Vector2(40, 40) * VisualTokens.POINT
	button.tooltip_text = hint
	return button

func _spin(parent: Node, title: String, low: float, high: float, value: float, callback: Callable, step_ := 1.0) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row, title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	# Typed decimals retain their precision; only the arrows snap to the edit grid.
	spin.step = 0.0 if step_ < 1.0 else step_
	spin.custom_arrow_step = step_
	spin.custom_arrow_round = step_ >= 1.0
	if step_ < 1.0:
		spin.gui_input.connect(_prepare_decimal_step.bind(spin, step_))
	spin.value = value
	spin.custom_minimum_size.x = 90
	spin.value_changed.connect(callback)
	row.add_child(spin)
	return spin

func _prepare_decimal_step(event: InputEvent, spin: SpinBox, increment: float) -> void:
	if not spin.editable or not event is InputEventMouseButton: return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	if event.position.x < spin.get_line_edit().get_rect().end.x: return
	spin.apply()
	var direction := 1.0 if event.position.y < spin.size.y / 2.0 else -1.0
	var units := spin.value / increment
	if absf(units - roundf(units)) < 1e-12: units = roundf(units)
	var next := (floorf(units) + 1.0 if direction > 0 else ceilf(units) - 1.0) * increment
	if (direction > 0 and spin.value >= spin.max_value) or (direction < 0 and spin.value <= spin.min_value):
		spin.accept_event()
		return
	# Native arrows handle pressing, hold-repeat and bounds. Seed their additive
	# step so the first click reaches the next tenth, avoiding native rounding's
	# min-offset floating-point error (e.g. an up click stuck at 0.7).
	spin.set_value_no_signal(clampf(next, spin.min_value, spin.max_value) - direction * increment)

func _section(parent: Node, title: String) -> void:
	var divider := HSeparator.new()
	parent.add_child(divider)
	var title_label := _label(parent, title, MUTED)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _panel(parent: Node, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8 * VisualTokens.GAP_UNIT)
	scroll.add_child(column)
	return column

func _create_interface() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var theme := Theme.new()
	var font := preload("res://assets/fonts/Minecraft.ttf").duplicate() as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	theme.default_font = font
	theme.default_font_size = VisualTokens.UI_FONT_SIZE
	var divider := StyleBoxLine.new()
	divider.color = Color("d69b77")
	divider.thickness = int(VisualTokens.LINE_WIDTH)
	theme.set_stylebox("separator", "HSeparator", divider)
	theme.set_stylebox("panel", "TooltipPanel", _style(Color.BLACK))
	theme.set_color("font_color", "TooltipLabel", Color.WHITE)
	for type in ["Label", "Button", "LineEdit", "SpinBox", "CheckButton", "OptionButton"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, INK)
	theme.set_stylebox("panel", "PanelContainer", _style(PAPER))
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _style(Color("ffe6b5")))
		theme.set_stylebox("hover", type, _style(Color("fff1cf")))
		theme.set_stylebox("pressed", type, _style(Color("efbf8c")))
	theme.set_stylebox("normal", "LineEdit", _style(Color("fff1cf")))
	theme.set_stylebox("read_only", "LineEdit", _style(PAPER))
	theme.set_color("font_uneditable_color", "LineEdit", INK)
	theme.set_stylebox("panel", "ItemList", _style(Color("ffe6b5")))
	theme.set_color("font_color", "ItemList", INK)
	theme.set_color("font_selected_color", "ItemList", INK)
	theme.set_stylebox("selected", "ItemList", _style(Color("efbf8c")))
	theme.set_stylebox("selected_focus", "ItemList", _style(Color("efbf8c")))
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("disabled", type, _style(PAPER))
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_disabled_color", type, MUTED)
	theme.set_stylebox("panel", "TabContainer", _style(PAPER))
	theme.set_stylebox("tab_selected", "TabContainer", _style(Color("efbf8c")))
	theme.set_stylebox("tab_unselected", "TabContainer", _style(Color("ffe6b5")))
	theme.set_stylebox("tab_disabled", "TabContainer", _style(PAPER))
	theme.set_color("font_disabled_color", "TabContainer", MUTED)
	theme.set_color("font_selected_color", "TabContainer", INK)
	theme.set_color("font_unselected_color", "TabContainer", MUTED)
	root.theme = theme
	var background := ColorRect.new()
	background.color = Color("fff1cf")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	root.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10 * VisualTokens.GAP_UNIT)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12 * VisualTokens.GAP_UNIT)
	layout.add_child(header)
	_label(header, "Blueprints")
	back_to_assets = _button(header, "Assets", pieces.activate)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_icon_button(header, "open", "Open · Ctrl/Cmd+O", func(): _open_dialog(false))
	save_button = _icon_button(header, "save", "Save · Ctrl/Cmd+S", func(): _save(current_path))
	_icon_button(header, "save_as", "Save as · Ctrl/Cmd+Shift+S", func(): _open_dialog(true))
	_icon_button(header, "help", "Controls", func(): help_dialog.popup_centered())
	_icon_button(header, "close", "Return to game · F2", close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10 * VisualTokens.GAP_UNIT)
	layout.add_child(body)
	var left := _panel(body, 240)
	name_edit = LineEdit.new()
	name_edit.max_length = 80
	name_edit.text = draft.name
	name_edit.placeholder_text = "Building name"
	name_edit.text_submitted.connect(func(_text): _rename())
	name_edit.focus_exited.connect(_rename)
	left.add_child(name_edit)
	var modes := HFlowContainer.new()
	left.add_child(modes)
	modes.hide() # Legacy volume/access studies stay loadable; assets are the main workspace.
	pieces.button = _button(modes, "Assets", pieces.activate)
	pieces.button.toggle_mode = true
	for title in ["Volumes", "Access"]:
		var index := mode_buttons.size()
		var button := _button(modes, title, func(): set_mode(index))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_buttons.append(button)
	pieces.create_ui(left)
	var legacy := VBoxContainer.new()
	legacy.add_theme_constant_override("separation", 8 * VisualTokens.GAP_UNIT)
	left.add_child(legacy)
	legacy_controls = legacy
	left = legacy
	_section(left, "Shape")
	var preset_row := HBoxContainer.new()
	left.add_child(preset_row)
	var preset_picker := OptionButton.new()
	preset_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for title in ["L", "T", "Steps", "Courtyard", "Cellar", "Cube"]:
		preset_picker.add_item(title)
	preset_row.add_child(preset_picker)
	_button(preset_row, "Use", func():
		cancel_move()
		_remember()
		draft = Shape.preset(preset_picker.selected)
		origin = Vector3i.ZERO
		turns = 0
		edit_level = 0
		set_mode(0))
	_button(preset_row, "Vary", vary_shape).tooltip_text = "Create a varied building (undoable)"
	_button(left, "Example", load_example).tooltip_text = "Load the stacking example (undoable)"
	var tools_row := HBoxContainer.new()
	left.add_child(tools_row)
	for title in ["add", "erase", "brace", "select"]:
		var index := brush_buttons.size()
		var button := _icon_button(tools_row, title, ["Add / paint a unit", "Erase a unit", "Brace: pick a lower unit, then a diagonal neighbour one layer up. Shift-click removes a brace.", "Select a building on the map"][index], func():
			cancel_move()
			brush = index
			brace_start = null
			_refresh())
		button.toggle_mode = true
		brush_buttons.append(button)
	var material_picker := OptionButton.new()
	for material in Shape.MATERIALS:
		material_picker.add_item(material.capitalize())
	material_picker.item_selected.connect(func(index): selected_material = Shape.MATERIALS[index])
	left.add_child(material_picker)

	var history := HBoxContainer.new()
	left.add_child(history)
	undo_button = _icon_button(history, "undo", "Undo · Ctrl/Cmd+Z", undo)
	redo_button = _icon_button(history, "redo", "Redo · Ctrl/Cmd+Shift+Z", redo)
	_section(left, "Assembly")
	assembly_list = ItemList.new()
	assembly_list.custom_minimum_size.y = 100
	assembly_list.item_selected.connect(func(index):
		selected_instance = index
		_refresh())
	left.add_child(assembly_list)
	var assembly_actions := HBoxContainer.new()
	selection_actions = assembly_actions
	left.add_child(assembly_actions)
	_icon_button(assembly_actions, "move", "Move selection · M", begin_move)
	_icon_button(assembly_actions, "copy", "Copy selection into editor; keeps the placed building", _copy_selected)
	_icon_button(assembly_actions, "remove", "Remove selected building", _remove_selected)
	var place_row := HBoxContainer.new()
	placement_actions = place_row
	left.add_child(place_row)
	_button(place_row, "Place", place_copy)
	cancel_button = _button(place_row, "Cancel", cancel_move)
	cancel_button.tooltip_text = "Cancel moving · Escape"
	_section(left, "Details")
	var detail_tools := HBoxContainer.new()
	left.add_child(detail_tools)
	for tool in ["door", "ladder", "ac", "dish"]:
		var index := brush_buttons.size()
		var button := _icon_button(detail_tools, tool, {"door": "Place entrance on a wall", "ladder": "Add ladder · Shift-click removes", "ac": "Place AC manually · Shift-click removes", "dish": "Place dish manually · Shift-click removes"}[tool], func():
			cancel_move()
			brush = index
			_refresh())
		button.toggle_mode = true
		brush_buttons.append(button)
	var mount := OptionButton.new()
	mount.add_item("Wall")
	mount.add_item("Sidewalk")
	mount.item_selected.connect(func(index): utility_mount = "wall" if index == 0 else "ground")
	left.add_child(mount)
	for kind in Life.KINDS:
		upgrade_buttons[kind] = _button(left, "Upgrade " + ("AC" if kind == "ac" else "dish"), func(): upgrade(kind))
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(middle)
	var view_header := HBoxContainer.new()
	middle.add_child(view_header)
	advanced_button = _button(view_header, "Advanced", func(): advanced_panel.visible = not advanced_panel.visible)

	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_header.add_child(stretch)
	_icon_button(view_header, "minus", "Zoom out", func(): zoom_by(1.0 / 0.88))
	_icon_button(view_header, "add", "Zoom in", func(): zoom_by(0.88))
	_icon_button(view_header, "fit", "Fit view", fit_view)
	cutaway = CheckButton.new()
	cutaway.text = "Slice"
	cutaway.tooltip_text = "Hide units above the current layer"
	cutaway.toggled.connect(func(value):
		if value:
			manual_level = true
		_refresh())
	view_header.add_child(cutaway)
	scene_container = preload("res://scripts/window_world_surface.gd").new()
	scene_container.stretch = true
	scene_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene_container.custom_minimum_size = Vector2(280, 280)
	scene_container.mouse_filter = Control.MOUSE_FILTER_STOP
	scene_container.focus_mode = Control.FOCUS_ALL
	scene_container.gui_input.connect(_view_input)
	scene_container.mouse_exited.connect(func():
		pieces.leave()
		last_pointer = null
		hovered = null
		if not pieces.enabled: overlay.placement_visible = false
		if is_instance_valid(hover_mesh):
			hover_mesh.visible = false)
	middle.add_child(scene_container)
	scene_view = SubViewport.new()
	scene_view.world_3d = World3D.new()
	scene_view.msaa_3d = Viewport.MSAA_4X
	scene_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scene_container.add_child(scene_view)
	Illustration.configure(scene_container, scene_view)
	overlay = Overlay.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_container.add_child(overlay)
	support_label = _wrap(middle, "", ACCENT)

	var right := _panel(body, 255)
	advanced_panel = right.get_parent().get_parent()
	advanced_panel.visible = false
	stats = _wrap(right, "", INK)

	level_spin = _spin(right, "Level", Shape.MIN_LEVEL, Shape.MAX_LEVEL, 0, func(value):
		edit_level = int(value)
		manual_level = true
		brace_start = brace_start if brush == 2 else null
		_refresh())
	level_spin.tooltip_text = "Q / E: lock a lower / higher level for underground or interior editing"
	auto_height = CheckButton.new()
	auto_height.text = "Auto"
	auto_height.tooltip_text = "Follow the hovered surface · F. Q / E locks a level."
	auto_height.button_pressed = true
	auto_height.toggled.connect(func(value):
		manual_level = not value
		if value:
			cutaway.set_pressed_no_signal(false)
		_refresh()
		_repick())
	right.add_child(auto_height)
	layer_caption = _label(right, "", ACCENT)
	right_tabs = TabContainer.new()
	right.add_child(right_tabs)
	var layer_controls := VBoxContainer.new()
	layer_controls.name = "Grid"
	layer_controls.add_theme_constant_override("separation", 8 * VisualTokens.GAP_UNIT)
	right_tabs.add_child(layer_controls)
	layer_controls.tooltip_text = "Each square = one world unit. Click to add; Shift-click to erase."
	var grid := GridContainer.new()
	grid.columns = 9
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 2 * VisualTokens.GAP_UNIT)
	grid.add_theme_constant_override("v_separation", 2 * VisualTokens.GAP_UNIT)
	layer_controls.add_child(grid)
	for z in range(-4, 5):
		for x in range(-4, 5):
			var point := Vector2i(x, z)
			var button := Button.new()
			button.custom_minimum_size = Vector2(24, 24) * VisualTokens.POINT
			button.draw.connect(func():
				if button.get_meta("origin_marker", false):
					var center := button.size * 0.5
					var arm := 5 * VisualTokens.POINT
					button.draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), INK, VisualTokens.LINE_WIDTH)
					button.draw_line(center - Vector2(0, arm), center + Vector2(0, arm), INK, VisualTokens.LINE_WIDTH))
			button.add_theme_stylebox_override("normal", _style(Color("f2d6a5")))
			button.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					var cell := Vector3i(point.x + int(grid_x.value), edit_level, point.y + int(grid_z.value))
					act_on_cell(cell, event.shift_pressed)
					button.accept_event())
			grid.add_child(button)
			layer_buttons[point] = button
	grid_x = _spin(layer_controls, "View X", -8, 8, 0, func(_v): _refresh())
	grid_z = _spin(layer_controls, "View Y", -8, 8, 0, func(_v): _refresh())
	stack_controls = VBoxContainer.new()
	stack_controls.name = "Move"
	stack_controls.add_theme_constant_override("separation", 8 * VisualTokens.GAP_UNIT)
	right_tabs.add_child(stack_controls)

	for axis in VisualTokens.BLUEPRINT_AXIS_LABELS:
		var index := origin_spins.size()
		var spin := _spin(stack_controls, axis, -18 if index == 1 else -24, 18 if index == 1 else 24, 0, func(value):
			origin[index] = int(value)
			if index == 1:
				manual_level = true
				edit_level = clampi(origin.y + Picker.anchor(active_draft(), turns).y, Shape.MIN_LEVEL, Shape.MAX_LEVEL)
			_refresh())
		origin_spins.append(spin)
	rotation_label = _label(stack_controls, "")
	_icon_button(stack_controls, "rotate", "Rotate 90° · R", rotate_draft)
	_button(stack_controls, "Auto-brace", add_suggested_braces).tooltip_text = "Add diagonal braces where supported lower neighbours exist"
	_button(stack_controls, "Place", place_copy).tooltip_text = "Place an independent copy of this building"

	var budget := VBoxContainer.new()
	budget.name = "Work"
	budget.add_theme_constant_override("separation", 8 * VisualTokens.GAP_UNIT)
	right_tabs.add_child(budget)

	work_spin = _spin(budget, "Unit · s", 0.1, 3600, 6, func(value): _change_work("work_per_cell", value), 0.1)
	brace_work_spin = _spin(budget, "Brace · s", 0.1, 3600, 3, func(value): _change_work("work_per_brace", value), 0.1)
	worker_spin = _spin(budget, "Workers", 1, 20, 1, func(_value): _refresh())
	budget.tooltip_text = "Seconds of work per unit / brace. Total ÷ workers estimates build time, excluding hauling and travel."
	preview_bar = ProgressBar.new()
	preview_bar.custom_minimum_size.y = 18
	budget.add_child(preview_bar)
	play_button = _button(budget, "Play", func():
		playing = not playing
		if playing:
			elapsed = 0.0
			last_preview_step = -1
		_refresh())
	status = _label(left, "", MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 210
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	file_dialog = FileDialog.new()
	# Dialog backgrounds are dark, unlike the workshop's paper panels.
	var dialog_theme := root.theme.duplicate() as Theme
	dialog_theme.set_color("font_color", "Label", Color("ffe6b5"))
	file_dialog.theme = dialog_theme
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.pyrstructure ; Pyramida structure workshop"])
	file_dialog.size = Vector2i(850, 580)
	file_dialog.file_selected.connect(func(path):
		if file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
			_save(path)
		else:
			_load(path))
	root.add_child(file_dialog)
	help_dialog = AcceptDialog.new()
	help_dialog.theme = dialog_theme
	help_dialog.title = "Controls"
	help_dialog.dialog_text = "Click: add / place\nParts: Shift-click to multi-select · Delete: remove\nRoom / Map: Erase tool / Shift-click: erase\nRight / middle drag: orbit · Wheel: zoom\nQ / E: lock level · F: auto · R: rotate · F2: return · Esc: deselect\n\nBrace: lower unit → diagonal unit one level up.\nRed units need a bearing. Ground = level 0.\n\nWork is in worker-seconds; hauling and travel add time.\nHover any icon for its action and shortcut."
	root.add_child(help_dialog)
	pieces.create_inspector(body)

func _create_world() -> void:
	scene_root = Node3D.new()
	scene_view.add_child(scene_root)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("fef1cf")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color.WHITE
	sky.ambient_light_energy = 0.75
	environment.environment = sky
	scene_root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -28, 0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	scene_root.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	scene_root.add_child(camera)
	_camera_update()

func _camera_update() -> void:
	camera.size = zoom
	camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 30
	camera.look_at(focus)
	if pieces.enabled and overlay != null and pieces.selected >= 0: pieces.outline_selection()

func candidate() -> Dictionary:
	return Shape.transformed(active_draft(), origin, turns) if mode == 1 else draft

func _redraw() -> void:
	if not is_instance_valid(scene_root):
		return
	if is_instance_valid(geometry):
		geometry.free()
	geometry = Node3D.new()
	scene_root.add_child(geometry)
	overlay.volume_edges.clear()
	overlay.origin_visible = pieces.enabled
	var grid_spacing: float = PartsEditor.Contract.Grid.ROOM_SIZE if pieces.enabled else 1.0
	if pieces.enabled:
		View.grid(geometry, 0, 24, Color("f1e2c5"), PartsEditor.Contract.Grid.CELL_SIZE, true)
	View.grid(geometry, 0, 12, Color("ead6b3"), grid_spacing, pieces.enabled)
	if edit_level != 0 and manual_level:
		View.grid(geometry, edit_level, 3, Color("b0c2b5"), grid_spacing, pieces.enabled)
	if pieces.enabled:
		pieces.draw()
		return
	var preview := candidate()
	var all := Shape.merged(map_instances() if mode == 1 else [], preview)
	var floating := Shape.unsupported(all)
	var cutoff := edit_level if cutaway.button_pressed else 99
	if mode == 1:
		for index in instances.size():
			if index == move_index: continue
			var building := Node3D.new()
			geometry.add_child(building)
			View.draw(building, instances[index], [], false, cutoff)
			if index == settling_instance:
				building.position.y = 0.18
				building.create_tween().tween_property(building, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settling_instance = -1
	var ratio := minf(1.0, elapsed * worker_spin.value / maxf(Shape.work(draft), 0.1)) if playing else 1.0
	var show_preview := mode == 0 or brush in [0, 2] or move_index >= 0
	if show_preview:
		View.draw(geometry, preview, floating, mode == 1, cutoff, ratio)
	var shown: Array = instances.duplicate() if mode == 1 else [draft]
	if move_index >= 0: shown[move_index] = preview
	elif mode == 1 and show_preview: shown.append(preview)
	var reached := Life.reachable(shown)
	var cells := Life.occupancy(shown)
	for building: Dictionary in shown:
		View.details(geometry, building, Life.connected(building, reached, cells), cutoff)
	overlay.camera = camera
	overlay.buildings = shown
	overlay.selected = selected_instance if mode == 1 else 0
	overlay.reached = reached
	overlay.cells = cells
	overlay.cutoff = cutoff
	overlay.placement_edges.assign(Overlay.PlacementOutline.cell_edges(preview.cells, cutoff) if _placing_building() else [])
	overlay.placement_visible = _placing_building() and hovered != null
	if move_index >= 0: overlay.selected = -1
	Illustration.apply(geometry)
	hover_mesh = View.box(geometry, Vector3(0.98, 0.98 if mode == 0 else 0.025, 0.98), Vector3.ZERO, Color(0.3, 0.55, 0.48, 0.3))
	hover_mesh.visible = false

func _refresh() -> void:
	if updating or not is_instance_valid(stats):
		return
	updating = true
	name_edit.editable = mode == 0
	name_edit.text = selected_building().get("name", draft.name) if mode == 1 else draft.name
	level_spin.set_value_no_signal(edit_level)
	auto_height.set_pressed_no_signal(not manual_level)
	for i in 3:
		origin_spins[i].set_value_no_signal(origin[i])
	work_spin.set_value_no_signal(draft.work_per_cell)
	brace_work_spin.set_value_no_signal(draft.work_per_brace)
	for i in 2:
		mode_buttons[i].set_pressed_no_signal(mode == i and not pieces.enabled)
	for i in brush_buttons.size():
		brush_buttons[i].set_pressed_no_signal(brush == i)
	right_tabs.set_tab_disabled(1, mode == 0)
	if mode == 0 and right_tabs.current_tab == 1:
		right_tabs.current_tab = 0
	rotation_label.text = "%d°" % (turns * 90)
	var size_ := Shape.bounds(draft)
	var footprint := {}
	for cell: Vector3i in draft.cells:
		footprint[Vector2i(cell.x, cell.z)] = true
	var total := Shape.work(draft)
	stats.text = "%d × %d × %d\n%d units · %.1f s" % [size_.x, size_.z, size_.y, draft.cells.size(), total / worker_spin.value]
	stats.tooltip_text = "Width × depth × height\n%d footprint tiles · %d braces\n%.1f worker-seconds total · %d workers\nEstimate excludes hauling and travel." % [footprint.size(), draft.braces.size(), total, int(worker_spin.value)]
	stats.mouse_filter = Control.MOUSE_FILTER_STOP
	layer_caption.text = "Underground" if edit_level < 0 else ("Ground" if edit_level == 0 else "")
	layer_caption.visible = edit_level <= 0
	var preview := candidate()
	var all := Shape.merged(map_instances() if mode == 1 else [], preview)
	var floating := Shape.unsupported(all)
	var error := Shape.placement_error(preview, map_instances()) if mode == 1 else ""
	if mode == 0:
		error = "%d unsupported units — add a bearing below or a diagonal brace." % floating.size() if not floating.is_empty() else ""
	support_label.text = "Supported"
	support_label.visible = mode == 0 or brush == 0 or move_index >= 0
	if not error.is_empty():
		support_label.text = "%d unsupported" % floating.size() if not floating.is_empty() else "Cannot place"
	support_label.tooltip_text = error if not error.is_empty() else "Every unit has a bearing path to ground."
	support_label.mouse_filter = Control.MOUSE_FILTER_STOP
	support_label.add_theme_color_override("font_color", Color("b45443") if not error.is_empty() else ACCENT)
	if draft.cells.is_empty():
		support_label.text = "Empty"
		support_label.tooltip_text = "Click the grid to add a unit"
	for point: Vector2i in layer_buttons:
		var cell := Vector3i(point.x + int(grid_x.value), edit_level, point.y + int(grid_z.value))
		var button: Button = layer_buttons[point]
		var colour := Color("f2d6a5")
		if all.cells.has(cell):
			colour = View.COLOURS[all.cells[cell]]
		if cell in floating:
			colour = Color("df8775")
		if brace_start == cell:
			colour = Color("79b9b1")
		button.add_theme_stylebox_override("normal", _style(colour))
		button.tooltip_text = "X %d · Y %d · Z %d" % [cell.x, cell.z, cell.y]
		button.set_meta("origin_marker", cell == Vector3i.ZERO)
		button.queue_redraw()
	assembly_list.clear()
	for i in instances.size():
		assembly_list.add_item("%02d  %s" % [i + 1, instances[i].name])
	if selected_instance >= 0 and selected_instance < instances.size():
		assembly_list.select(selected_instance)
	var target := selected_building()
	for kind in upgrade_buttons:
		var installed := false
		for entry: Dictionary in target.get("utilities", []):
			if entry.kind == kind: installed = true
		upgrade_buttons[kind].disabled = target.is_empty() or installed or move_index >= 0
		upgrade_buttons[kind].text = ("AC" if kind == "ac" else "Dish") + " installed" if installed else "Upgrade " + ("AC" if kind == "ac" else "dish")
	selection_actions.visible = mode == 1 and selected_instance >= 0
	placement_actions.visible = mode == 1 and (brush == 0 or move_index >= 0)
	cancel_button.visible = move_index >= 0
	assembly_list.visible = mode == 1
	undo_button.disabled = undo_stack.is_empty()
	redo_button.disabled = redo_stack.is_empty()
	save_button.text = ""
	save_button.tooltip_text = "Save changes · Ctrl/Cmd+S" if dirty else "Saved · Ctrl/Cmd+S"
	save_button.add_theme_stylebox_override("normal", _style(Color("efbf8c") if dirty else Color("ffe6b5")))
	play_button.text = "Stop" if playing else "Play"
	preview_bar.value = minf(100.0, elapsed * worker_spin.value / maxf(total, 0.1) * 100.0)
	pieces.refresh()
	back_to_assets.visible = not pieces.enabled
	legacy_controls.visible = not pieces.enabled
	advanced_button.visible = not pieces.enabled
	cutaway.visible = not pieces.enabled
	if pieces.enabled:
		advanced_panel.visible = false
		support_label.visible = false
		name_edit.editable = true
		name_edit.text = draft.name
	updating = false
	_redraw()

func _rename() -> void:
	if (mode == 0 or pieces.enabled) and not updating and name_edit.text != draft.name:
		_remember()
		draft.name = name_edit.text
		_refresh()

func _change_work(field: String, value: float) -> void:
	if updating:
		return
	_remember()
	draft[field] = value
	_refresh()

func _remember() -> void:
	undo_stack.append({"draft": draft.duplicate(true), "instances": instances.duplicate(true), "origin": origin, "turns": turns, "parts": pieces.parts.duplicate(true), "piece_editing": pieces.enabled, "building_kind": pieces.building_kind, "building_drafts": pieces.building_drafts.duplicate(true), "authoring": pieces.state()})
	if undo_stack.size() > 60:
		undo_stack.pop_front()
	redo_stack.clear()
	dirty = true
	playing = false
	elapsed = 0.0

func _restore_history(source: Array, target: Array) -> void:
	if source.is_empty():
		return
	target.append({"draft": draft.duplicate(true), "instances": instances.duplicate(true), "origin": origin, "turns": turns, "parts": pieces.parts.duplicate(true), "piece_editing": pieces.enabled, "building_kind": pieces.building_kind, "building_drafts": pieces.building_drafts.duplicate(true), "authoring": pieces.state()})
	var previous: Dictionary = source.pop_back()
	draft = previous.draft
	instances = previous.instances
	origin = previous.origin
	turns = previous.turns
	pieces.parts = previous.parts.duplicate(true)
	pieces.enabled = previous.piece_editing
	pieces.building_kind = previous.building_kind
	pieces.building_drafts = previous.building_drafts.duplicate(true)
	pieces.restore_state(previous.get("authoring", {}))
	pieces.selected = -1
	brace_start = null
	dirty = true
	playing = false
	_refresh()

func undo() -> void:
	cancel_move()
	_restore_history(undo_stack, redo_stack)

func redo() -> void:
	cancel_move()
	_restore_history(redo_stack, undo_stack)

func set_mode(value: int) -> void:
	cancel_move()
	pieces.leave()
	pieces.enabled = false
	mode = value
	last_pointer = null
	hovered = null
	right_tabs.current_tab = 0 if mode == 0 else 1
	brace_start = null
	_refresh()
	fit_view()

func rotate_draft() -> void:
	if pieces.enabled:
		pieces.rotate(1, PI / 2)
		return
	if mode == 1:
		turns = (turns + 1) % 4
	else:
		_remember()
		draft = Shape.transformed(draft, Vector3i.ZERO, 1)
	_refresh()
	_repick()

func act_on_cell(cell: Vector3i, erase := false) -> void:
	if move_index >= 0:
		origin = cell - Picker.anchor(active_draft(), turns)
		_refresh()
		return
	if not Shape.in_bounds(cell):
		_status("Choose a unit within X/Y ±12 and levels −6 to 12.")
		return
	if brush == 2:
		var assembly := Shape.merged(instances if mode == 1 else [], candidate())
		if erase:
			_remember()
			var local := Shape.rotate_cell(cell - origin, -turns) if mode == 1 else cell
			draft.braces = draft.braces.filter(func(item): return item.to != local)
			brace_start = null
		elif not assembly.cells.has(cell):
			_status("A brace endpoint must touch an occupied unit.")
			return
		elif brace_start == null:
			brace_start = cell
			_status("Pick the upper diagonal unit.")
		elif Shape.valid_brace(brace_start, cell):
			var a: Vector3i = Shape.rotate_cell(brace_start - origin, -turns) if mode == 1 else brace_start
			var b := Shape.rotate_cell(cell - origin, -turns) if mode == 1 else cell
			if not draft.cells.has(b):
				_status("The upper endpoint must belong to the draft building.")
				return
			var brace := {"from": a, "to": b}
			if brace not in draft.braces:
				_remember()
				draft.braces.append(brace)
			brace_start = null
		else:
			_status("Use a one-level rise and one tile sideways. Lower bearing remains selected.")
			return
	elif mode == 1:
		origin = cell - Picker.anchor(active_draft(), turns)
		edit_level = cell.y
		_status("")
	else:
		if not erase and brush == 0 and not draft.cells.has(cell) and draft.cells.size() >= Shape.MAX_CELLS:
			_status("This building already has the maximum 2048 occupied units.")
			return
		_remember()
		if erase or brush == 1:
			draft.cells.erase(cell)
			draft.braces = draft.braces.filter(func(item): return item.from != cell and item.to != cell)
		else:
			draft.cells[cell] = selected_material
		Life.normalize(draft)
	_refresh()

func add_suggested_braces() -> void:
	if move_index >= 0:
		_status("Place or cancel the move first.")
		return
	var additions := Shape.suggest_braces(candidate(), instances if mode == 1 else [])
	if additions.is_empty():
		_status("No supported diagonal anchor is available. Add a lower bearing or reposition the copy.")
		return
	_remember()
	for brace: Dictionary in additions:
		var a: Vector3i = Shape.rotate_cell(brace.from - origin, -turns) if mode == 1 else brace.from
		var b: Vector3i = Shape.rotate_cell(brace.to - origin, -turns) if mode == 1 else brace.to
		draft.braces.append({"from": a, "to": b})
	_refresh()
	_status("%d braces added." % additions.size())

func place_copy() -> void:
	if move_index >= 0:
		commit_move()
		return
	var item := candidate()
	var error := Shape.placement_error(item, instances)
	if not error.is_empty():
		_status(error)
		return
	_remember()
	instances.append(item.duplicate(true))
	_join_instance(instances.size() - 1)
	settling_instance = selected_instance
	_refresh()
	_status("Placed.")

func _join_instance(index: int) -> void:
	var joined := Shape.joined(instances, index)
	instances = joined.instances
	selected_instance = joined.selected

func _copy_selected() -> void:
	cancel_move()
	if selected_instance < 0 or selected_instance >= instances.size():
		_status("Select a placed building first.")
		return
	_remember()
	draft = instances[selected_instance].duplicate(true)
	origin = Vector3i.ZERO
	turns = 0
	set_mode(0)
	_status("Copy ready.")

func _remove_selected() -> void:
	cancel_move()
	if selected_instance < 0 or selected_instance >= instances.size():
		return
	var remainder := instances.duplicate(true)
	remainder.remove_at(selected_instance)
	var assembly := Shape.merged(remainder)
	for brace: Dictionary in assembly.braces:
		if not assembly.cells.has(brace.from) or not assembly.cells.has(brace.to):
			_status("Another building depends on this bearing. Remove the supported building first.")
			return
	if not Shape.unsupported(assembly).is_empty():
		_status("Another building depends on this bearing. Remove the supported building first.")
		return
	for building: Dictionary in remainder:
		for utility: Dictionary in building.get("utilities", []):
			if not Life.attachment_error(building, assembly.cells, utility, true).is_empty():
				_status("Installed equipment needs this floor.")
				return
	if Life.loses_access(instances, remainder):
		_status("Keep entrance access.")
		return
	_remember()
	instances = remainder
	selected_instance = -1
	_refresh()

func load_example() -> void:
	cancel_move()
	_remember()
	instances.clear()
	var base := Shape.preset(0)
	base.name = "Stone corner + cellar"
	base.cells[Vector3i(0, -1, 0)] = "stone"
	base.cells[Vector3i(0, -2, 0)] = "stone"
	base.ladders.append({"cell": Vector3i(0, 0, 1), "side": Vector3i.BACK})
	instances.append(base)
	var hall := Shape.transformed(Shape.preset(1), Vector3i(1, 1, 0), 0)
	hall.name = "Braced clay hall"
	for cell: Vector3i in hall.cells:
		hall.cells[cell] = "clay"
	hall.braces.append_array(Shape.suggest_braces(hall, instances))
	hall.door = {"cell": Vector3i(1, 1, 1), "side": Vector3i.LEFT}
	hall.ladders.append({"cell": Vector3i(1, 1, 1), "side": Vector3i.LEFT})
	instances.append(hall)
	draft = Shape.preset(0)
	draft.name = "Timber roof rooms"
	draft.door = {"cell": Vector3i(0, 0, 1), "side": Vector3i.LEFT}
	for cell: Vector3i in draft.cells:
		draft.cells[cell] = "timber"
	origin = Vector3i(1, 2, 0)
	edit_level = 2
	turns = 0
	mode = 1
	right_tabs.current_tab = 1
	brush = 0
	cutaway.set_pressed_no_signal(false)
	manual_level = false
	last_pointer = null
	_refresh()
	fit_view()
	_status("")

func fit_view() -> void:
	if pieces.enabled:
		pieces.fit()
		return
	var all := Shape.merged(instances if mode == 1 else [], candidate())
	if all.cells.is_empty():
		focus = Vector3(0, 0.5, 0)
		zoom = 10.0
	else:
		var average := Vector3.ZERO
		for cell: Vector3i in all.cells:
			average += Vector3(cell) + Vector3.UP * 0.5
		focus = average / all.cells.size()
		var dimensions := Shape.bounds(all)
		zoom = clampf(maxf(dimensions.length() * 1.5, 8.0), 8, 38)
	_camera_update()

func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, 0.5, 100.0)
	_camera_update()
	if pieces.enabled: pieces.repick()
	else: _repick()

func _view_input(event: InputEvent) -> void:
	if pieces.enabled and (pieces.gizmo.dragging or pieces.marquee_pending):
		pieces.input(event)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_by(0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.88)
		scene_container.accept_event()
		return
	# Camera gestures are handled before any editor tool can mutate geometry.
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		orbiting = event.pressed
		panning = event.shift_pressed
		if event.pressed: scene_container.grab_focus()
		scene_container.accept_event()
		return
	if orbiting:
		if event is InputEventMouseMotion:
			if panning:
				focus += (-camera.global_basis.x * event.relative.x + camera.global_basis.y * event.relative.y) * zoom / maxf(scene_container.size.y, 1)
			else:
				yaw -= event.relative.x * 0.008
				pitch = clampf(pitch + event.relative.y * 0.004, 0.10, 1.55)
			_camera_update()
		scene_container.accept_event()
		return
	if pieces.enabled:
		pieces.input(event)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if brush >= 3 and move_index < 0:
			inspect_at(event.position, event.shift_pressed)
			scene_container.accept_event()
			return
	if event is InputEventMouseButton:
		if event.pressed:
			scene_container.grab_focus()
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 4, 40)
			_camera_update()
			_pick(event.position)
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var erase: bool = event.shift_pressed or brush == 1
			_pick(event.position, erase)
			if hovered != null:
				if mode == 1 and brush != 2:
					if not erase:
						place_copy()
					else:
						for index in instances.size():
							if instances[index].cells.has(hovered):
								selected_instance = index
								_remove_selected()
								break
				else:
					act_on_cell(hovered, erase)
				_pick(event.position)
	if event is InputEventMouseMotion:
		_pick(event.position)
	scene_container.accept_event()

func placement_at(at: Vector2, erase := false) -> Dictionary:
	var cells: Dictionary = draft.cells
	if mode == 1:
		cells = Shape.merged(map_instances(), candidate() if brush == 2 else {}).cells
	return Picker.pick(camera.project_ray_origin(at), camera.project_ray_normal(at), cells,
		edit_level, manual_level, erase or brush in [1, 2], edit_level if cutaway.button_pressed else 99)

func _placing_building() -> bool:
	return mode == 1 and (brush == 0 or move_index >= 0)

func _pick(at: Vector2, erase := false) -> void:
	last_pointer = at
	var placement := placement_at(at, erase)
	hovered = placement.get("cell")
	if hovered != null:
		var changed: bool = not manual_level and edit_level != hovered.y
		if not manual_level:
			edit_level = hovered.y
		if mode == 1 and (brush == 0 or move_index >= 0) and not erase:
			var next_origin: Vector3i = hovered - Picker.anchor(active_draft(), turns)
			changed = changed or origin != next_origin
			origin = next_origin
		if changed:
			_refresh()
	overlay.placement_visible = _placing_building() and hovered != null
	if is_instance_valid(hover_mesh):
		hover_mesh.visible = hovered != null and brush < 3 and not _placing_building()
		if hovered != null:
			hover_mesh.position = Vector3(hovered) + Vector3.UP * (0.5 if mode == 0 else 0.035)

func _repick() -> void:
	if last_pointer != null:
		_pick(last_pointer)

func shift_level(amount: int) -> void:
	if pieces.enabled:
		pieces.shift_height(amount)
		return
	var current := edit_level
	if not manual_level and hovered != null:
		current = hovered.y
	edit_level = clampi(current + amount, Shape.MIN_LEVEL, Shape.MAX_LEVEL)
	manual_level = true
	if mode == 1 and brush == 0:
		origin.y = edit_level - Picker.anchor(active_draft(), turns).y
	_refresh()
	_repick()

func resume_surface_snap() -> void:
	if pieces.enabled:
		pieces.automatic = true
		pieces.refresh()
		pieces.repick()
		return
	manual_level = false
	cutaway.set_pressed_no_signal(false)
	_refresh()
	_repick()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Capture area drags even when the pointer crosses a sidebar or leaves the view.
	if pieces.enabled and pieces.marquee_pending:
		var release: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
		if event is InputEventMouseMotion or release:
			var point: Vector2 = scene_container.get_global_transform().affine_inverse() * event.position
			if release: pieces.finish_marquee(point)
			else: pieces.update_marquee(point)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pieces.gizmo.end_drag()
		pieces.dragging = false
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] and not event.pressed:
		orbiting = false
	if not event is InputEventKey or not event.pressed or event.echo or file_dialog.visible or help_dialog.visible or (pieces.exchange_dialog != null and pieces.exchange_dialog.visible):
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_ESCAPE:
		pieces.gizmo.cancel()
		pieces.cancel_drag()
		pieces.selected = -1
		pieces.selecting = true
		pieces.insertion = {}
		pieces.library.deselect_all()
		pieces.leave()
		cancel_move()
		selected_instance = -1
		brace_start = null
		if mode == 1: brush = 3
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if pieces.gizmo.dragging:
		if key == KEY_F2:
			pieces.gizmo.end_drag()
			close()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_F2:
		close()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed or event.meta_pressed:
		match key:
			KEY_G:
				if event.alt_pressed or get_viewport().gui_get_focus_owner() is LineEdit: return
				if pieces.enabled:
					if event.shift_pressed: pieces.ungroup_selected()
					else: pieces.group_selected()
			KEY_S:
				_rename()
				if event.shift_pressed:
					_open_dialog(true)
				else:
					_save(current_path)
			KEY_O: _open_dialog(false)
			KEY_Z:
				if event.shift_pressed:
					redo()
				else:
					undo()
			KEY_Y: redo()
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	match key:
		KEY_Q: shift_level(-1)
		KEY_E: shift_level(1)
		KEY_F: resume_surface_snap()
		KEY_R: rotate_draft()
		KEY_T:
			if pieces.enabled: pieces.rotate(0 if event.shift_pressed else 2, PI / 4)
		KEY_DELETE, KEY_BACKSPACE:
			if pieces.enabled: pieces.remove_selected()
			elif mode == 1: _remove_selected()
		KEY_M:
			if not pieces.enabled: begin_move()
		_: return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if visible and status_seconds > 0:
		status_seconds = maxf(0.0, status_seconds - delta)
		if status_seconds == 0:
			status.text = ""
			status.visible = false
	if not visible or not playing:
		return
	elapsed += delta
	var total := maxf(Shape.work(draft), 0.1)
	preview_bar.value = minf(100, elapsed * worker_spin.value / total * 100)
	var preview_step := floori(elapsed * worker_spin.value / total * draft.cells.size())
	if preview_step != last_preview_step:
		last_preview_step = preview_step
		_redraw()
	if elapsed * worker_spin.value >= total:
		playing = false
		_refresh()
		_status("Done · %.1f work · %.1f s" % [total, total / worker_spin.value])

func _status(message: String) -> void:
	status.text = message
	status.visible = not message.is_empty()
	status.tooltip_text = message
	status_seconds = 6.0

func _open_dialog(save: bool) -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_path = ProjectSettings.globalize_path(current_path)
	file_dialog.popup_centered(Vector2i(850, 580))

func _save(path: String) -> bool:
	if move_index >= 0:
		_status("Place or cancel the move first.")
		return false
	_rename()
	if not path.ends_with(".pyrstructure"):
		path += ".pyrstructure"
	var directory := ProjectSettings.globalize_path(path).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_status("Could not create the save folder. Choose Save as…")
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		_status("Could not write the file. Your work remains in the editor.")
		return false
	file.store_string(JSON.stringify(Shape.document(draft, instances, workspace_state()), "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		_status("Save failed. Your work remains in the editor.")
		return false
	current_path = path
	dirty = false
	_refresh()
	_status("Saved.")
	status.tooltip_text = ProjectSettings.globalize_path(path)
	return true

func _load(path: String) -> bool:
	cancel_move()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4 * 1024 * 1024:
		_status("Cannot open this structure file (maximum 4 MB).")
		return false
	var parsed := Shape.parse_document(JSON.parse_string(file.get_as_text()))
	if parsed.is_empty():
		_status("Invalid structure file. Current work is preserved.")
		return false
	_remember()
	draft = parsed.draft
	instances = parsed.instances
	current_path = path
	var workspace: Dictionary = parsed.workspace
	pieces.parts = PartsEditor.Kit.decode(workspace.get("parts", [])).parts
	pieces.enabled = workspace.get("piece_editing", false)
	pieces.building_kind = workspace.get("building_kind", "")
	pieces.building_drafts = {}
	for key: String in workspace.get("building_drafts", {}):
		pieces.building_drafts[key] = PartsEditor.Kit.decode(workspace.building_drafts[key]).parts
	pieces.restore_state(workspace.get("authoring", {}))
	pieces.selected = -1
	var address: Array = workspace.get("origin", [0, 0, 0])
	origin = Vector3i(int(address[0]), int(address[1]), int(address[2]))
	turns = int(workspace.get("turns", 0))
	edit_level = int(workspace.get("layer", 0))
	mode = int(workspace.get("mode", 0))
	manual_level = bool(workspace.get("manual_level", false))
	last_pointer = null
	worker_spin.set_value_no_signal(int(workspace.get("workers", 1)))
	right_tabs.current_tab = 0 if mode == 0 else 1
	selected_instance = -1
	dirty = false
	_refresh()
	fit_view()
	_status("Opened.")
	status.tooltip_text = path
	return true

func close() -> void:
	pieces.cancel_marquee()
	pieces.gizmo.end_drag()
	if is_instance_valid(layout_sandbox):
		layout_sandbox.save_layout()
		layout_sandbox.queue_free()
		layout_sandbox = null
	cancel_move()
	_rename()
	# Keep the node alive: returning to the settlement never discards an unsaved draft.
	visible = false
	playing = false
	orbiting = false
	scene_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()

func is_open() -> bool:
	return visible or is_instance_valid(layout_sandbox)

func open() -> void:
	visible = true
	scene_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_refresh()

func _exit_tree() -> void:
	if is_instance_valid(layout_sandbox): layout_sandbox.queue_free()

func workspace_state() -> Dictionary:
	var building_drafts := {}
	for key: String in pieces.building_drafts:
		building_drafts[key] = pieces.Workspace.encode_parts(pieces.building_drafts[key])
	return {"origin": [origin.x, origin.y, origin.z], "turns": turns, "mode": mode,
		"layer": edit_level, "workers": int(worker_spin.value), "manual_level": manual_level, "parts": pieces.Workspace.encode_parts(pieces.parts), "piece_editing": pieces.enabled, "building_kind": pieces.building_kind, "building_drafts": building_drafts, "authoring": pieces.state()}

func active_draft() -> Dictionary:
	return instances[move_index] if move_index >= 0 else draft

func map_instances() -> Array:
	var result := instances.duplicate()
	if move_index >= 0: result.remove_at(move_index)
	return result

func selected_building() -> Dictionary:
	if mode == 0: return draft
	return instances[selected_instance] if selected_instance >= 0 and selected_instance < instances.size() else {}

func begin_move() -> void:
	if mode != 1 or selected_building().is_empty() or move_index >= 0: return
	move_index = selected_instance
	move_origin = origin
	move_turns = turns
	origin = Vector3i.ZERO
	turns = 0
	brush = 0
	_refresh()

func cancel_move() -> void:
	if move_index < 0: return
	move_index = -1
	origin = move_origin
	turns = move_turns
	brush = 3
	_refresh()

func commit_move() -> bool:
	if move_index < 0: return false
	var item := candidate()
	var error := Shape.placement_error(item, map_instances())
	if not error.is_empty():
		_status(error)
		return false
	_remember()
	var moved := move_index
	instances[moved] = item
	cancel_move()
	_join_instance(moved)
	settling_instance = selected_instance
	_refresh()
	_status("Moved.")
	return true

func upgrade(kind: String) -> bool:
	var target := selected_building()
	if target.is_empty() or move_index >= 0: return false
	var cells := Life.occupancy(instances if mode == 1 else [draft])
	var entry := Life.automatic(target, cells, kind, rng)
	if entry.is_empty():
		_status("Already installed or no clear wall.")
		return false
	_remember()
	target.utilities.append(entry)
	_refresh()
	return true

func inspect_at(at: Vector2, erase := false) -> void:
	var buildings: Array = instances if mode == 1 else [draft]
	var cells := Life.occupancy(buildings)
	var ray := camera.project_ray_origin(at)
	var direction := camera.project_ray_normal(at)
	var hit := Picker.pick(ray, direction, cells, 0, false, true, edit_level if cutaway.button_pressed else 99)
	if not hit.has("hit_cell"):
		if brush == 3:
			selected_instance = -1
			_refresh()
		return
	var cell: Vector3i = hit.hit_cell
	var index := -1
	for i in buildings.size():
		if buildings[i].cells.has(cell): index = i; break
	if index < 0: return
	selected_instance = index if mode == 1 else -1
	if brush == 3:
		_refresh()
		return
	var side: Vector3i = hit.normal
	if side not in Life.SIDES:
		_status("Choose a wall face.")
		_refresh()
		return
	var target: Dictionary = buildings[index]
	Life.normalize(target)
	var before := buildings.duplicate(true)
	var entry := {"cell": cell, "side": side}
	if brush == 4:
		for utility: Dictionary in target.utilities:
			if utility.cell == cell and utility.side == side:
				_status("Clear the utility from this wall first.")
				return
		var proposed := buildings.duplicate(true)
		proposed[index].door = entry
		if mode == 1 and (not Life.connected(proposed[index], Life.reachable(proposed), {}) or Life.loses_access(before, proposed)):
			_status("No entrance access.")
			return
		_remember()
		target.door = entry
		target.extra_doors = target.get("extra_doors", []).filter(func(other): return other != entry)
		if mode == 1: _join_instance(index)
	elif brush == 5:
		var proposed := buildings.duplicate(true)
		if erase: proposed[index].ladders.erase(entry)
		elif entry not in proposed[index].ladders: proposed[index].ladders.append(entry)
		if mode == 1 and Life.loses_access(before, proposed):
			_status("Keep entrance access.")
			return
		_remember()
		if erase: target.ladders.erase(entry)
		elif entry not in target.ladders: target.ladders.append(entry)
	else:
		var kind := "ac" if brush == 6 else "dish"
		if erase:
			_remember()
			target.utilities = target.utilities.filter(func(a): return not (a.cell == cell and a.side == side and a.kind == kind))
		else:
			var exact := Picker.ray_box(ray, direction, cell)
			var point: Vector3 = ray + direction * float(exact.distance) - Vector3(cell)
			var tangent := Vector3(side.z, 0, -side.x)
			entry.merge({"kind": kind, "mount": utility_mount, "offset": Vector2(clampf(point.dot(tangent), -0.3, 0.3), 0.18 if utility_mount == "ground" else clampf(point.y, 0.15, 0.8))})
			var error := Life.attachment_error(target, cells, entry)
			if not error.is_empty():
				_status(error)
				return
			var proposed := buildings.duplicate(true)
			proposed[index].utilities.append(entry)
			if mode == 1 and Life.loses_access(before, proposed):
				_status("Keep entrance access.")
				return
			_remember()
			target.utilities.append(entry)
	_refresh()

func vary_shape() -> void:
	cancel_move()
	_remember()
	draft = Shape.preset(rng.randi_range(0, 3))
	var material: String = Shape.MATERIALS[rng.randi_range(0, 2)]
	var cells: Array = draft.cells.keys()
	var extra: Vector3i = cells[rng.randi_range(0, cells.size() - 1)] + Vector3i.UP
	while draft.cells.has(extra): extra += Vector3i.UP
	for cell: Vector3i in cells: draft.cells[cell] = material
	draft.cells[extra] = material
	Life.normalize(draft)
	origin = Vector3i.ZERO
	turns = 0
	set_mode(0)
