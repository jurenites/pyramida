extends CanvasLayer
const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")
const PlacementOutline = preload("res://scripts/settlement/placement_outline.gd")
const Houses = preload("res://scripts/settlement/house_groups.gd")
const Piles = preload("res://scripts/settlement/pile_groups.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Jobs = preload("res://scripts/settlement/job_system.gd")
const Settings = preload("res://scripts/gameplay_settings.gd")
const Text = preload("res://scripts/settlement/text.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const ObjectTooltip = preload("res://scripts/settlement/object_tooltip.gd")
const Icon = preload("res://scripts/settlement/build_icon.gd")
const SPEED_ICONS = [
	preload("res://assets/ui/speed_1.svg"),
	preload("res://assets/ui/speed_2.svg"),
	preload("res://assets/ui/speed_3.svg"),
]
const Compass = preload("res://scripts/compass_widget.gd")
const DayNight = preload("res://scripts/settlement/day_cycle_icon.gd")
const DayCycle = preload("res://scripts/settlement/day_cycle.gd")
var compass = Compass.new()
var day_icon: Control
signal reset_view_requested
signal idle_citizen_requested
var idle_button: Button
var idle_count: Label
var day_label: Label
var selection_drag := Rect2()
var work_bars: Array[Dictionary] = []
signal collect_water_requested(cell: Vector3i)
var collect_button: Button
var water_cell := Vector3i.ZERO
signal relocation_requested
signal copy_requested
signal removal_requested
signal finish_requested
var finish_button: Button
var move_button: Button
var hotkeys = preload("res://scripts/settlement/hotkeys.gd").new()
var workshop_button: Button
var copy_button: Button
var removal_button: Button
var deleting_plan := false
var move_label := ""
var top_toolbar: HBoxContainer
var selection_toolbar: HBoxContainer
signal tool_changed(kind: String)
signal structure_workshop_requested
signal leave_settlement_requested
signal level_changed(level: int)
signal speed_changed(speed: float)
var resource_label: Label
var resource_counts: Dictionary = {}
var status_label: Label
var detail_label: Label
var level_label: Label
var buttons: Dictionary = {}
var category_buttons: Dictionary = {}
var category_lists: Dictionary = {}
var level := 1
var speed := 1.0
var speed_button: Button
var selection_outline: Control
var selection_points := PackedVector2Array()
var ground_hover_points := PackedVector2Array()
var object_hover_strokes: Array[PackedVector2Array] = []
var placement_color := VisualTokens.SELECTION_COLOR
var placement_strokes: Array[PackedVector2Array] = []
var selection_strokes: Array[PackedVector2Array] = []
var route_strokes: Array[PackedVector2Array] = []
var root: Control
var build_panel: PanelContainer
var build_scroll: ScrollContainer
var build_content: VBoxContainer
var detail_panel: PanelContainer
var detail_readout: PanelContainer
var world_tooltips: Dictionary = {}
var category_title: Label
var description_label: Label
var description_tooltip: PanelContainer
var tooltip_request := 0
var toolbar_tooltip: PanelContainer
var toolbar_tooltip_label: Label
var toolbar_tooltip_targets: Dictionary = {}
var toolbar_hovered: Control
var toolbar_hover_time := 0.0
var population_tooltip := ""
var current_category := "housing"
const INK := Color("64452f")
const MUTED := Color("96704f")
const PAPER := Color("ffe6b5")
const EDGE := Color("d69b77")
const TOOLBAR_BUTTON_SIZE := VisualTokens.GAME_TOOLBAR_BUTTON_SIZE
const WORK_PIXELS_PER_SECOND := 24.0
const WORK_TRACK := Color("efbd8c")
const WORK_FILL := Color("d87045")

func style(colour: Color, border := true) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = colour
	result.border_color = EDGE
	result.set_border_width_all(int(VisualTokens.LINE_WIDTH) if border else 0)
	result.content_margin_left = VisualTokens.PANEL_PADDING_X
	result.content_margin_right = VisualTokens.PANEL_PADDING_X
	result.content_margin_top = VisualTokens.PANEL_PADDING_Y
	result.content_margin_bottom = VisualTokens.PANEL_PADDING_Y
	return result

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	var font := preload("res://assets/fonts/Minecraft.ttf").duplicate() as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.multichannel_signed_distance_field = false
	theme.default_font = font
	theme.default_font_size = VisualTokens.UI_FONT_SIZE
	for type in ["Label", "Button", "CheckButton"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, INK)
	theme.set_stylebox("normal", "Button", style(PAPER, false))
	theme.set_stylebox("hover", "Button", style(Color("fff1cf"), false))
	theme.set_stylebox("pressed", "Button", style(Color("efbf8c"), false))
	theme.set_stylebox("hover_pressed", "Button", style(Color("f5cd9f"), false))
	theme.set_stylebox("disabled", "Button", style(PAPER, false))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", style(PAPER))
	theme.set_stylebox("panel", "TooltipPanel", style(Color.BLACK, false))
	theme.set_color("font_color", "TooltipLabel", Color.WHITE)
	for type in ["HSeparator", "VSeparator"]:
		var divider := StyleBoxLine.new()
		divider.color = EDGE
		divider.thickness = int(VisualTokens.LINE_WIDTH)
		divider.vertical = type == "VSeparator"
		theme.set_stylebox("separator", type, divider)
		theme.set_constant("separation", type, VisualTokens.GAP_UNIT)
	root.theme = theme
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	selection_outline = Control.new()
	selection_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_outline.draw.connect(_draw_selection)
	root.add_child(selection_outline)

	compass.mount(self, root, func(): reset_view_requested.emit())

	var resources := PanelContainer.new()
	resources.position = Vector2(12, 12)
	resources.add_theme_stylebox_override("panel", style(PAPER, false))
	root.add_child(resources)
	var resource_row := HFlowContainer.new()
	resource_row.add_theme_constant_override("h_separation", 12 * VisualTokens.GAP_UNIT)
	resource_row.add_theme_constant_override("v_separation", 4 * VisualTokens.GAP_UNIT)
	resources.add_child(resource_row)
	var day_row := HBoxContainer.new()
	day_row.add_theme_constant_override("separation", 4 * VisualTokens.GAP_UNIT)
	resource_row.add_child(day_row)
	day_icon = DayNight.new()
	day_row.add_child(day_icon)
	day_label = counter_label()
	day_row.add_child(day_label)
	day_row.mouse_filter = Control.MOUSE_FILTER_STOP
	bind_toolbar_tooltip(day_row, resources, func(): return tr("economy_night_text" if day_icon.is_night else "day_tooltip_text"))
	for kind in ["food", "log", "grain", "plank", "stone", "block", "pottery", "water", "citizens"]:
		var item := HBoxContainer.new()
		item.visible = kind == "citizens"
		item.add_theme_constant_override("separation", 4 * VisualTokens.GAP_UNIT)
		var tooltip_key: String = "settlement_citizens_tooltip_text" if kind == "citizens" else ("log_tooltip_text" if kind == "log" else "settlement_resource_" + kind + "_text")
		bind_toolbar_tooltip(item, resources, func(): return tr(tooltip_key) + (" · −1/person/30s" if kind == "food" else ""))
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := Control.new()
		icon.set_script(Icon)
		icon.kind = kind
		item.add_child(icon)
		var count := counter_label(true)
		if kind == "food":
			count.custom_minimum_size.x += root.theme.default_font.get_string_size("  −888", HORIZONTAL_ALIGNMENT_LEFT, -1, VisualTokens.UI_FONT_SIZE).x
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(count)
		resource_counts[kind] = count
		resource_row.add_child(item)
		if kind == "citizens":
			count.mouse_filter = Control.MOUSE_FILTER_PASS
			bind_toolbar_tooltip(count, resources, func(): return population_tooltip)
			idle_button = button("", func(): idle_citizen_requested.emit())
			idle_button.name = "CitizenCounter"
			idle_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				idle_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
			icon.add_child(idle_button)
			idle_count = count
			icon.self_modulate = Color.BLACK
			idle_count.add_theme_color_override("font_color", Color.BLACK)
	resource_label = resource_counts.water

	var top := HBoxContainer.new()
	top_toolbar = top
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top.offset_left = -12 - TOOLBAR_BUTTON_SIZE * (Catalog.CATEGORIES.size() + 4)
	top.offset_right = -12
	top.offset_top = 12
	top.add_theme_constant_override("separation", 0 * VisualTokens.GAP_UNIT)
	root.add_child(top)
	selection_toolbar = HBoxContainer.new()
	selection_toolbar.name = "SelectionToolbar"
	selection_toolbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	selection_toolbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	selection_toolbar.offset_left = -TOOLBAR_BUTTON_SIZE / 2.0
	selection_toolbar.offset_right = TOOLBAR_BUTTON_SIZE / 2.0
	selection_toolbar.offset_top = 12 * VisualTokens.POINT
	selection_toolbar.add_theme_constant_override("separation", 0 * VisualTokens.GAP_UNIT)
	selection_toolbar.hide()
	root.add_child(selection_toolbar)
	root.resized.connect(func():
		_size_resource_bar(resources)
		_position_selection_toolbar(resources))
	resources.resized.connect(func(): _position_selection_toolbar(resources))

	build_panel = PanelContainer.new()
	build_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	build_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	build_panel.offset_left = -292
	build_panel.offset_right = -12
	build_panel.offset_top = 12 * VisualTokens.POINT + TOOLBAR_BUTTON_SIZE + 4 * VisualTokens.GAP_UNIT
	root.add_child(build_panel)
	build_panel.resized.connect(func(): build_panel.position.x = root.size.x - 12 * VisualTokens.POINT - build_panel.size.x)
	var content := VBoxContainer.new()
	build_content = content
	content.add_theme_constant_override("separation", 6 * VisualTokens.GAP_UNIT)
	build_scroll = ScrollContainer.new()
	build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build_scroll.custom_minimum_size.x = 264 * VisualTokens.POINT
	build_panel.add_child(build_scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_scroll.add_child(content)
	content.minimum_size_changed.connect(_size_build_menu)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0 * VisualTokens.GAP_UNIT)
	top.add_child(tabs)
	for category: String in Catalog.CATEGORIES:
		var tab := toolbar_button(func():
			if current_category == category and build_panel.visible:
				build_panel.hide()
				category_buttons[category].set_pressed_no_signal(false)
				hide_building_tooltip()
				return
			show_category(category)
			build_panel.visible = true)
		tab.toggle_mode = true
		bind_toolbar_tooltip(tab, top, func(): return tr("settlement_category_" + category + "_text"))
		var icon := Control.new()
		icon.set_script(Icon)
		icon.kind = category
		icon.framed = false
		icon.position = Vector2.ONE * (TOOLBAR_BUTTON_SIZE - VisualTokens.GAME_ICON_SIZE) / 2.0
		tab.add_child(icon)
		tabs.add_child(tab)
		category_buttons[category] = tab
	for terrain_tool: String in ["terrain_dig", "terrain_fill"]:
		var terrain_button := toolbar_button(func(): tool_changed.emit(terrain_tool))
		terrain_button.name = terrain_tool.to_pascal_case()
		terrain_button.toggle_mode = true
		terrain_button.focus_mode = Control.FOCUS_ALL
		var focus_style := style(PAPER, true)
		focus_style.draw_center = false
		terrain_button.add_theme_stylebox_override("focus", focus_style)
		var terrain_icon := Icon.new()
		terrain_icon.kind = terrain_tool
		terrain_icon.position = Vector2.ONE * (TOOLBAR_BUTTON_SIZE - VisualTokens.GAME_ICON_SIZE) / 2.0
		terrain_button.add_child(terrain_icon)
		tabs.add_child(terrain_button)
		buttons[terrain_tool] = terrain_button
		bind_toolbar_tooltip(terrain_button, top, func(): return tr(terrain_tool + "_text"))
	move_button = toolbar_button(func(): relocation_requested.emit())
	move_button.name = "MoveObject"
	move_button.hide()
	var move_icon := Icon.new()
	move_icon.kind = "relocate"
	move_icon.position = Vector2.ONE * (TOOLBAR_BUTTON_SIZE - VisualTokens.GAME_ICON_SIZE) / 2.0
	move_button.add_child(move_icon)
	selection_toolbar.add_child(move_button)
	bind_toolbar_tooltip(move_button, selection_toolbar, func(): return hotkeys.hint(move_label, "move"))
	copy_button = selection_action_button("CopyObject", "copy", func(): copy_requested.emit(), "building_copy_text")
	removal_button = selection_action_button("RemoveObject", "deconstruct", func(): removal_requested.emit(), "building_remove_text")
	finish_button = selection_action_button("FinishBuilding", "debug_finish", func(): finish_requested.emit(), "Finish · Debug")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := finish_button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		box.bg_color = Color("eadcff") if state == "hover" else Color("d4b5f5")
		box.border_color = Color("8054a8")
		box.set_border_width_all(int(VisualTokens.LINE_WIDTH))
		finish_button.add_theme_stylebox_override(state, box)
	selection_toolbar.resized.connect(func(): _position_selection_toolbar(resources))
	speed_button = toolbar_button(func():
		speed = 2.0 if speed == 1 else (4.0 if speed == 2 else 1.0)
		speed_changed.emit(speed))
	speed_button.icon = SPEED_ICONS[0]
	speed_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(speed_button)
	bind_toolbar_tooltip(speed_button, top, func(): return tr("simulation_speed_tooltip_text"))
	var remove_button := toolbar_button(func(): leave_settlement_requested.emit())
	bind_toolbar_tooltip(remove_button, top, func(): return tr("settlement_save_exit_text"))
	var remove_icon := Control.new()
	remove_icon.set_script(Icon)
	remove_icon.kind = "remove"
	remove_icon.framed = false
	remove_icon.position = Vector2.ONE * (TOOLBAR_BUTTON_SIZE - VisualTokens.GAME_ICON_SIZE) / 2.0
	remove_button.add_child(remove_icon)
	buttons["exit"] = remove_button
	top.add_child(remove_button)
	category_title = label("", MUTED)
	content.add_child(category_title)
	for category: String in Catalog.CATEGORIES:
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 2 * VisualTokens.GAP_UNIT)
		content.add_child(list)
		category_lists[category] = list
		for kind: String in Catalog.CATEGORIES[category]:
			var row := button("", func(): tool_changed.emit(kind))
			row.toggle_mode = true
			row.custom_minimum_size = Vector2(264, 64) * VisualTokens.POINT
			row.add_theme_stylebox_override("normal", style(PAPER, false))
			var icon := Control.new()
			icon.set_script(Icon)
			icon.kind = kind
			icon.position = Vector2(4, 15) * VisualTokens.POINT
			row.add_child(icon)
			var title := label("", INK)
			title.text = Catalog.title(kind)
			if kind in ["seed_vine", "seed_bush"]:
				row.set_meta("plant_title", title)
				row.hide()
			title.position = Vector2(44, 4) * VisualTokens.POINT
			title.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(title)
			var cost := label("", MUTED)
			cost.text = Catalog.cost_text(kind)
			if kind in Catalog.SEEDS:
				row.custom_minimum_size.y = 44 * VisualTokens.POINT
				title.position.y = 8 * VisualTokens.POINT
				icon.position.y = 5 * VisualTokens.POINT
			cost.position = Vector2(44, 32) * VisualTokens.POINT
			cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(cost)
			var cost_icon := Control.new()
			cost_icon.set_script(Icon)
			cost_icon.kind = "log"
			cost_icon.position = Vector2(70, 25)
			cost_icon.scale = Vector2(0.55, 0.55)
			cost_icon.visible = false
			row.add_child(cost_icon)
			row.mouse_entered.connect(func(): show_building_tooltip(row, kind))
			row.mouse_exited.connect(func(): hide_building_tooltip())
			row.visibility_changed.connect(func():
				if not row.is_visible_in_tree() and description_tooltip:
					hide_building_tooltip())
			buttons[kind] = row
			list.add_child(row)
			row.custom_minimum_size.x = 44 * VisualTokens.POINT + maxf(title.get_combined_minimum_size().x, cost.get_combined_minimum_size().x) + VisualTokens.PANEL_PADDING_X
			build_scroll.custom_minimum_size.x = maxf(build_scroll.custom_minimum_size.x, row.custom_minimum_size.x + build_scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	workshop_button = button(hotkeys.hint("Blueprints", "blueprints"), func(): structure_workshop_requested.emit())
	content.add_child(workshop_button)
	description_tooltip = PanelContainer.new()
	description_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_tooltip.z_index = 10
	description_tooltip.add_theme_stylebox_override("panel", style(Color.BLACK, false))
	root.add_child(description_tooltip)
	description_label = label("", Color.WHITE)
	description_label.custom_minimum_size.x = 214
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_tooltip.add_child(description_label)
	hide_building_tooltip()
	toolbar_tooltip = PanelContainer.new()
	toolbar_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar_tooltip.z_index = 11
	toolbar_tooltip.add_theme_stylebox_override("panel", style(Color.BLACK, false))
	root.add_child(toolbar_tooltip)
	toolbar_tooltip_label = label("", Color.WHITE)
	toolbar_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar_tooltip.add_child(toolbar_tooltip_label)
	toolbar_tooltip.hide()

	detail_panel = PanelContainer.new()
	detail_panel.position = Vector2(12, 142)
	detail_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root.add_child(detail_panel)
	var detail_content := VBoxContainer.new()
	detail_panel.add_child(detail_content)
	detail_readout = ObjectTooltip.new()
	detail_readout.set_black(true)
	detail_readout.hide()
	detail_content.add_child(detail_readout)
	detail_label = detail_readout.title
	collect_button = Button.new()
	collect_button.text = tr("collect_water_text")
	collect_button.pressed.connect(func(): collect_water_requested.emit(water_cell))
	collect_button.visible = false
	detail_content.add_child(collect_button)
	var bottom := PanelContainer.new()
	bottom.visible = false
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_top = -62
	bottom.offset_bottom = -12
	root.add_child(bottom)
	var hints := VBoxContainer.new()
	bottom.add_child(hints)
	status_label = label("settlement_hint_text", INK)
	hints.add_child(status_label)
	hints.add_child(label("settlement_controls_text", MUTED))
	set_level(1)
	show_category("housing")
	select_tool("inspect")

func bind_toolbar_tooltip(control: Control, bar: Control, text: Callable) -> void:
	control.tooltip_text = ""
	toolbar_tooltip_targets[control] = {"bar": bar, "text": text}

func _process(delta: float) -> void:
	var hovered := root.get_viewport().gui_get_hovered_control() if visible else null
	while hovered != null and not toolbar_tooltip_targets.has(hovered):
		hovered = hovered.get_parent_control()
	if hovered != toolbar_hovered:
		toolbar_hovered = hovered
		toolbar_hover_time = 0.0
		toolbar_tooltip.hide()
	if hovered == null:
		return
	toolbar_hover_time += delta
	if toolbar_hover_time < float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)):
		return
	var target: Dictionary = toolbar_tooltip_targets[hovered]
	toolbar_tooltip_label.text = target.text.call()
	toolbar_tooltip.reset_size()
	var rect := hovered.get_global_rect()
	var bar_rect: Rect2 = target.bar.get_global_rect()
	var gap := 4 * VisualTokens.GAP_UNIT
	var x := rect.get_center().x - toolbar_tooltip.size.x * 0.5
	x = clampf(x, gap, maxf(gap, root.size.x - toolbar_tooltip.size.x - gap))
	toolbar_tooltip.global_position = Vector2(x, bar_rect.end.y + gap)
	toolbar_tooltip.show()


func counter_label(fraction := false) -> Label:
	var count := label("", INK)
	var font := root.theme.default_font
	var digit_width := 0.0
	for digit in 10:
		digit_width = maxf(digit_width, font.get_string_size(str(digit), HORIZONTAL_ALIGNMENT_LEFT, -1, VisualTokens.UI_FONT_SIZE).x)
	var number_width := digit_width * 3
	# Reserve both sides of current/capacity so icons remain stable.
	var width := number_width * 2 + font.get_string_size(" / ", HORIZONTAL_ALIGNMENT_LEFT, -1, VisualTokens.UI_FONT_SIZE).x if fraction else number_width
	count.custom_minimum_size.x = ceilf(width)
	return count

func hide_building_tooltip() -> void:
	tooltip_request += 1
	if description_tooltip:
		description_tooltip.hide()

func show_building_tooltip(row: Control, kind: String) -> void:
	hide_building_tooltip()
	var request := tooltip_request
	await get_tree().create_timer(1.0).timeout
	if request != tooltip_request or not is_instance_valid(row) or not visible or not row.is_visible_in_tree():
		return
	description_label.text = Catalog.description(kind)
	description_tooltip.size = Vector2(row.size.x, 0)
	description_tooltip.global_position = row.global_position + Vector2(0, row.size.y + 2)
	description_tooltip.show()

func show_category(category: String) -> void:
	current_category = category
	for key: String in category_lists:
		category_lists[key].visible = key == category
		category_buttons[key].set_pressed_no_signal(key == category)
	category_title.text = tr("settlement_category_" + category + "_text")
	if description_tooltip:
		hide_building_tooltip()

func label(key: String, colour: Color) -> Label:
	var result := Label.new()
	result.text = tr(key) if not key.is_empty() else ""
	result.add_theme_font_size_override("font_size", VisualTokens.UI_FONT_SIZE)
	result.add_theme_color_override("font_color", colour)
	return result

func button(key: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = tr(key)
	result.focus_mode = Control.FOCUS_NONE
	result.pressed.connect(action)
	return result

func _size_resource_bar(resources: Control) -> void:
	var row := resources.get_child(0) as HFlowContainer
	var width := 0.0
	var count := 0
	for item: Control in row.get_children():
		if item.visible:
			width += item.get_combined_minimum_size().x
			count += 1
	width += max(0, count - 1) * row.get_theme_constant("h_separation")
	var padding := resources.get_theme_stylebox("panel").get_minimum_size().x
	row.custom_minimum_size.x = minf(width, root.size.x - 24 * VisualTokens.POINT - padding)
	resources.reset_size()

func _position_selection_toolbar(resources: Control) -> void:
	var margin := 12 * VisualTokens.POINT
	var gap := 4 * VisualTokens.GAP_UNIT
	var resource_rect := resources.get_rect()
	var top_target := Rect2(Vector2(root.size.x - margin - top_toolbar.size.x, margin), Vector2(top_toolbar.size.x, TOOLBAR_BUTTON_SIZE))
	if top_target.intersects(resource_rect.grow(gap)):
		top_target.position.y = resource_rect.end.y + gap
	top_toolbar.position.y = top_target.position.y
	if is_instance_valid(build_panel):
		build_panel.position.y = top_target.end.y + gap
		_size_build_menu()
	var width := maxf(TOOLBAR_BUTTON_SIZE, selection_toolbar.get_combined_minimum_size().x)
	selection_toolbar.size.x = width
	var target := Rect2(Vector2((root.size.x - width) / 2.0, margin), Vector2(width, TOOLBAR_BUTTON_SIZE))
	for bar: Control in [resources, top_toolbar]:
		var bar_rect := bar.get_rect().grow(4 * VisualTokens.GAP_UNIT)
		if target.intersects(bar_rect):
			target.position.y = bar_rect.end.y
	selection_toolbar.position = target.position

func selection_action_button(node_name: String, icon_kind: String, action: Callable, tooltip_key: String) -> Button:
	var result := toolbar_button(action)
	result.name = node_name
	result.hide()
	var icon := Icon.new()
	icon.kind = icon_kind
	icon.position = Vector2.ONE * (TOOLBAR_BUTTON_SIZE - VisualTokens.GAME_ICON_SIZE) / 2.0
	result.add_child(icon)
	selection_toolbar.add_child(result)
	bind_toolbar_tooltip(result, selection_toolbar, func():
		if icon_kind == "debug_finish": return tooltip_key
		return hotkeys.hint(tr("construction_delete_text" if icon_kind == "deconstruct" and deleting_plan else tooltip_key), "copy_cutaway" if icon_kind == "copy" else "remove"))
	return result

func _size_build_menu() -> void:
	if not is_instance_valid(build_scroll):
		return
	var padding := build_panel.get_theme_stylebox("panel").get_minimum_size().y
	var available := root.size.y - build_panel.position.y - 12 * VisualTokens.POINT - padding
	build_scroll.custom_minimum_size.y = minf(build_content.get_combined_minimum_size().y, maxf(TOOLBAR_BUTTON_SIZE, available))
	build_panel.reset_size()

func toolbar_button(action: Callable) -> Button:
	var result := button("", action)
	result.custom_minimum_size = Vector2.ONE * TOOLBAR_BUTTON_SIZE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var selected: bool = state in ["pressed", "hover_pressed"]
		var hovered: bool = state in ["hover", "hover_pressed"]
		var colour := Color("f5cd9f") if selected and hovered else (Color("efbf8c") if selected else (Color("fff1cf") if hovered else PAPER))
		var box := style(colour, false)
		# Equal padding keeps icon buttons square in every interaction state.
		box.content_margin_left = 2 * VisualTokens.POINT
		box.content_margin_right = 2 * VisualTokens.POINT
		box.content_margin_top = 2 * VisualTokens.POINT
		box.content_margin_bottom = 2 * VisualTokens.POINT
		result.add_theme_stylebox_override(state, box)
	return result

func set_level(value: int) -> void:
	level = clampi(value, 0, Catalog.MAX_LEVEL)
	if level_label:
		level_label.text = tr("settlement_cutaway_floor_text") % level
	level_changed.emit(level)

func select_tool(kind: String) -> void:
	for key: String in buttons:
		buttons[key].set_pressed_no_signal(key == kind)
	if kind in ["terrain_dig", "terrain_fill"]:
		build_panel.hide()
		for category_button: Button in category_buttons.values(): category_button.set_pressed_no_signal(false)
	if kind in Catalog.COSTS:
		for category: String in Catalog.CATEGORIES:
			if kind in Catalog.CATEGORIES[category]:
				show_category(category)
		build_panel.visible = true

func update(model, selected: int, speed_value: float, selected_object: Dictionary = {}) -> void:
	for kind in ["seed_vine", "seed_bush"]:
		var row: Button = buttons[kind]
		var count: int = model.vine_roots if kind == "seed_vine" else model.uprooted_bushes.size()
		row.visible = model.vine_discovered if kind == "seed_vine" else model.bush_discovered
		row.disabled = count == 0
		row.modulate = Color(1, 1, 1, 0.45) if row.disabled else Color.WHITE
		var title: Label = row.get_meta("plant_title")
		title.text = "%s (%d)" % [Catalog.title("berry" if kind == "seed_bush" else kind), count]
		row.custom_minimum_size.x = 44 * VisualTokens.POINT + title.get_combined_minimum_size().x + VisualTokens.PANEL_PADDING_X
	for resource in ["food", "log", "grain", "plank", "stone", "block", "pottery", "water"]:
		resource_counts[resource].text = "%d/%d" % [model.resource_total(resource), Economy.storage_capacity(model, resource)]
		if resource == "food": resource_counts[resource].text += "  −%d" % model.workers.size()
		resource_counts[resource].get_parent().visible = model.discovered_resources.has(resource)
	var phase: float = fposmod(model.time, Settings.SIMULATION_DAY_SECONDS) / Settings.SIMULATION_DAY_SECONDS
	day_icon.set_phase(phase)
	root.modulate = Color.WHITE.lerp(Color("94b8ff"), DayCycle.night_amount(phase))
	# Selection feedback retains its colour while the surrounding paper UI cools.
	var untinted := Color(1.0 / root.modulate.r, 1.0 / root.modulate.g, 1.0 / root.modulate.b)
	idle_button.modulate = untinted
	selection_outline.modulate = untinted
	day_label.text = str(int(model.time / Settings.SIMULATION_DAY_SECONDS) + 1)
	resource_counts["citizens"].text = str(model.workers.size())
	var adults := 0
	for citizen in model.workers:
		adults += int(model.can_control(citizen))
	population_tooltip = tr("settlement_population_ages_text") % [adults, model.workers.size() - adults]
	var idle_total: int = model.idle_citizen_ids().size()
	idle_count.text = "%d/%d" % [model.workers.size(), Economy.capacity(model)]
	population_tooltip += " · %d idle" % idle_total
	idle_button.disabled = idle_total == 0
	_size_resource_bar(resource_counts.food.get_parent().get_parent().get_parent())
	collect_button.visible = false
	var entity_key := str(selected_object.get("entity_key", ""))
	deleting_plan = selected < 0 and entity_key.begins_with("plan:") and not model.editable_plan(int(entity_key.trim_prefix("plan:"))).is_empty()
	finish_button.visible = model.debug_mode and deleting_plan and model.Planning.includes(model.plans[int(entity_key.trim_prefix("plan:"))])
	finish_button.disabled = not finish_button.visible or not model.can_debug_finish(int(entity_key.trim_prefix("plan:")))
	var movable_object: bool = selected < 0 and selected_object.has("cell") and not entity_key.begins_with("plan:") and not model.Relocation.kind_at(model, selected_object.cell).is_empty() and not model.Relocation.locked(model, selected_object.cell)
	# Apply each button's final state once. Hiding then showing a plan action
	# during a frame cancels a mouse press before its release can activate it.
	move_button.visible = movable_object or deleting_plan
	move_button.disabled = movable_object and not model.Relocation.source_error(model, selected_object.cell).is_empty()
	if movable_object:
		move_label = tr("replant_bush_text" if model.Relocation.kind_at(model, selected_object.cell) in ["tree", "berry"] else "relocation_move_text")
		if model.vines.has(selected_object.cell): move_label = "Collect root"
		if model.deposits.get(selected_object.cell, {}).get("kind") == "berry": move_label = "Move"
	var copyable_object: bool = movable_object and model.Relocation.kind_at(model, selected_object.cell) in Catalog.COSTS
	copy_button.visible = copyable_object and model.gardens.get(selected_object.cell, {}).get("species") != "grass"
	removal_button.visible = copyable_object or deleting_plan
	removal_button.disabled = move_button.disabled
	if deleting_plan:
		move_label = tr("relocation_move_text")
	selection_toolbar.visible = move_button.visible or removal_button.visible or finish_button.visible
	_position_selection_toolbar(resource_counts.food.get_parent().get_parent().get_parent())
	speed = speed_value
	speed_button.icon = SPEED_ICONS[2 if speed_value >= 4 else (1 if speed_value >= 2 else 0)]
	# Object information lives above the object; this panel holds actions only.
	detail_panel.visible = false
	if selected < 0 and not selected_object.is_empty() and not selected_object.has("worker_id"):
		var cell: Vector3i = selected_object.cell
		if model.water_sources.has(cell) or model.wells.has(cell):
			detail_panel.visible = true
			collect_button.visible = true
			collect_button.disabled = model.Hydrology.inventory_at(model, cell).available("water") <= 0 or int(model.water_orders.get(cell, 0)) > 0
			water_cell = cell
		detail_panel.reset_size()

# Project floor markers onto the GUI: world geometry never occludes selection.
# Each stroke is separate so rectangular footprints show only their four corners.
func update_selection(world, camera: Camera3D, selection: Dictionary, model = null) -> void:
	compass.update_camera(camera.global_basis.z)
	work_bars.clear()
	var screen_scale := root.size / Vector2(camera.get_viewport().size)
	route_strokes.clear()
	for stroke: PackedVector3Array in world.route_strokes:
		var projected := _project_marker(camera, screen_scale, world, stroke)
		if projected.size() > 1:
			route_strokes.append(projected)
	if model != null:
		for plan: Dictionary in model.plans.values():
			if plan.get("deconstruction", false) and plan.relocation.stage == "salvage": continue
			var entity_key := "plan:%s" % plan.id
			if selection.get("entity_key", "") != entity_key:
				continue
			var site: Node3D = world.entity_views.get(entity_key)
			if not is_instance_valid(site) or not site.is_visible_in_tree():
				continue
			var definition: Dictionary = Catalog.DEFINITIONS[plan.kind]
			var anchor: Vector3 = site.to_global(definition.offset + Vector3.UP * (definition.size.y * 0.5 + 0.35))
			var progress := Jobs.construction_progress(plan, model.workers)
			_add_work_bar(camera, screen_scale, anchor, progress.required_seconds, progress.applied_seconds)
		for worker: Dictionary in model.workers:
			if worker.job.get("kind") in ["eat", "restock"]:
				continue
			if worker.job.get("phase") not in ["work", "collect"] or worker.route_index < worker.route.size():
				continue
			var anchor: Vector3 = worker.position + Vector3.UP * 1.7
			if worker.job.get("kind") in ["build", "relocate"]:
				# The site owns the total; a selected builder shows only this application.
				if worker.job.phase != "work" or not model.plans.has(worker.job.plan_id):
					continue
				if selection.get("entity_key", "") == "plan:%s" % worker.job.plan_id:
					continue
				var actor: Node3D = world.actors[worker.id]
				if not actor.is_visible_in_tree() or not actor.ring.visible:
					continue
				anchor = actor.global_position + Vector3.UP * 1.7
			if camera.is_position_behind(anchor):
				continue
			var labour = worker.job.labour
			_add_work_bar(camera, screen_scale, anchor, labour.required_seconds, labour.applied_seconds)
	selection_points.clear()
	selection_strokes.clear()
	var marker := _object_marker(world, camera, {} if selection.has("worker_id") else selection, model)
	selection_points = marker.points
	selection_strokes.assign(marker.strokes)
	selection_outline.queue_redraw()

# Selection and hover share footprint geometry; hover never changes selection or work bars.
func _object_marker(world, camera: Camera3D, selection: Dictionary, model) -> Dictionary:
	var points := PackedVector2Array()
	var strokes: Array[PackedVector2Array] = []
	var screen_scale := root.size / Vector2(camera.get_viewport().size)
	if selection.has("worker_id"):
		var id: int = selection.worker_id
		if id >= 0 and id < world.actors.size():
			var actor: Node3D = world.actors[id]
			if actor.is_visible_in_tree():
				points = _project_circle(camera, screen_scale, actor, actor.ring.position, 0.33)
				if not points.is_empty(): strokes.append(points)
		return {"points": points, "strokes": strokes}
	var node: Node3D = world.entity_views.get(selection.get("entity_key", ""))
	if not is_instance_valid(node) and selection.has("cell"):
		node = world.water_view.sources.get(selection.cell)
	if is_instance_valid(node) and node.is_visible_in_tree():
		var definition: Dictionary = Catalog.DEFINITIONS.get(selection.kind, {})
		if definition.is_empty() and selection.kind in ["puddle", "stream"]:
			definition = {"size": Vector3(0.85, 0.16, 0.85), "offset": Vector3.ZERO}
		if not definition.is_empty():
			var size: Vector3 = definition.size
			var centre: Vector3 = definition.offset
			centre.y = 0.035
			if model != null and selection.kind in ["stockpile", "house"] and not node.get_meta("planned", false):
				var members := Houses.members(model, selection.cell) if selection.kind == "house" else Piles.members(model, selection.cell)
				var placement_offset: Vector3 = model.buildings.get(selection.cell, {}).get("placement_offset", Vector3.ZERO) if selection.kind == "house" else Vector3.ZERO
				for corner in Piles.outline(members):
					var point: Vector3 = corner.point + placement_offset + Vector3.UP * 0.035
					var marker := PackedVector3Array()
					for position: Vector3 in [point + corner.arms[0] * 0.35, point, point + corner.arms[1] * 0.35]:
						marker.append(node.to_local(position))
					strokes.append(_round_marker_corner(_project_marker(camera, screen_scale, node, marker)))
			elif definition.get("living", false) and not node.get_meta("planned", false):
				var radius := maxf(size.x, size.z) * 0.5 + 0.1
				if selection.kind in ["tree", "dead_tree"]:
					radius *= 0.5
				points = _project_circle(camera, screen_scale, node, centre, radius)
				if not points.is_empty():
					strokes.append(points)
			else:
				var corners := PackedVector3Array()
				for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
					corners.append(centre + corner * (size * 0.5 + Vector3(0.1, 0, 0.1)))
				points = _project_marker(camera, screen_scale, node, corners)
				if not points.is_empty():
					for i in 4:
						var corner := corners[i]
						var previous := corners[(i + 3) % 4]
						var next := corners[(i + 1) % 4]
						var arm := minf(0.35, minf(corner.distance_to(previous), corner.distance_to(next)) * 0.22)
						strokes.append(_round_marker_corner(_project_marker(camera, screen_scale, node, PackedVector3Array([
							corner.move_toward(previous, arm), corner, corner.move_toward(next, arm)]))))
	return {"points": points, "strokes": strokes}

func _round_marker_corner(stroke: PackedVector2Array) -> PackedVector2Array:
	if stroke.size() != 3:
		return stroke
	# Round after projection so the bend stays subtle at every camera zoom.
	var corner := stroke[1]
	var trim := minf(6.0 * VisualTokens.POINT, minf(corner.distance_to(stroke[0]), corner.distance_to(stroke[2])) * 0.5)
	var start := corner.move_toward(stroke[0], trim)
	var end := corner.move_toward(stroke[2], trim)
	var rounded := PackedVector2Array([stroke[0]])
	for step in 9:
		var t := float(step) / 8.0
		rounded.append(start.lerp(corner, t).lerp(corner.lerp(end, t), t))
	rounded.append(stroke[2])
	return rounded

func update_object_hover(world, camera: Camera3D, model, selection: Dictionary, hovered_object: Dictionary) -> void:
	object_hover_strokes.clear()
	if not hovered_object.is_empty():
		ground_hover_points.clear()
		var already_selected := not selection.is_empty() and _tooltip_key(selection, model) == _tooltip_key(hovered_object, model)
		if hovered_object.has("worker_id"):
			var id: int = hovered_object.worker_id
			already_selected = already_selected or (id >= 0 and id < world.actors.size() and world.actors[id].ring.visible)
		if not already_selected:
			object_hover_strokes.assign(_object_marker(world, camera, hovered_object, model).strokes)
	selection_outline.queue_redraw()

func _project_marker(camera: Camera3D, screen_scale: Vector2, node: Node3D, points: PackedVector3Array) -> PackedVector2Array:
	var projected := PackedVector2Array()
	for local_point in points:
		var point := node.to_global(local_point)
		if camera.is_position_behind(point):
			return PackedVector2Array()
		projected.append(camera.unproject_position(point) * screen_scale)
	return projected

func _project_circle(camera: Camera3D, screen_scale: Vector2, node: Node3D, centre: Vector3, radius: float) -> PackedVector2Array:
	var points := PackedVector3Array()
	for i in 49:
		var angle := TAU * float(i) / 48.0
		points.append(centre + Vector3(cos(angle), 0, sin(angle)) * radius)
	return _project_marker(camera, screen_scale, node, points)

func _add_work_bar(camera: Camera3D, screen_scale: Vector2, anchor: Vector3, required: float, applied: float) -> void:
	if camera.is_position_behind(anchor):
		return
	work_bars.append({"position": camera.unproject_position(anchor) * screen_scale,
		"width": maxf(1.0, required) * WORK_PIXELS_PER_SECOND,
		"fraction": clampf(applied / maxf(0.01, required), 0, 1)})

func update_ground_hover(camera: Camera3D, cell: Variant) -> void:
	ground_hover_points.clear()
	if cell is Vector3i:
		var screen_scale := root.size / Vector2(camera.get_viewport().size)
		var centre := Jobs.Navigation.point(cell) + Vector3.UP * 0.015
		var half_cell: float = Jobs.Navigation.CELL_SIZE * 0.5
		for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
			var point: Vector3 = centre + corner * half_cell
			if camera.is_position_behind(point):
				ground_hover_points.clear()
				break
			ground_hover_points.append(camera.unproject_position(point) * screen_scale)
	selection_outline.queue_redraw()

func update_placement_outline(camera: Camera3D, preview: Node3D = null, kind := "", placement_valid := true) -> void:
	placement_color = VisualTokens.SELECTION_COLOR if placement_valid else WORK_FILL
	placement_strokes.clear()
	if is_instance_valid(preview) and preview.is_visible_in_tree():
		var definition: Dictionary = Catalog.DEFINITIONS.get(kind, {})
		if kind in ["terrain_dig", "terrain_fill"]: definition = {"offset": Vector3.UP * 0.5, "size": Vector3.ONE}
		if not definition.is_empty():
			var screen_scale := root.size / Vector2(camera.get_viewport().size)
			for edge in preview.get_meta("placement_edges", PlacementOutline.box_edges(definition.offset, definition.size)):
				placement_strokes.append(_project_marker(camera, screen_scale, preview, edge))
	selection_outline.queue_redraw()

func _draw_selection() -> void:
	for stroke in route_strokes:
		selection_outline.draw_polyline(stroke, VisualTokens.SELECTION_COLOR, VisualTokens.LINE_WIDTH, true)
	if ground_hover_points.size() == 5:
		selection_outline.draw_polyline(ground_hover_points, Color(VisualTokens.SELECTION_COLOR, 0.82), VisualTokens.LINE_WIDTH, true)
	for bar: Dictionary in work_bars:
		var rect := Rect2(bar.position - Vector2(bar.width * 0.5, 4), Vector2(bar.width, 8))
		selection_outline.draw_rect(rect.grow(VisualTokens.LINE_WIDTH), INK)
		selection_outline.draw_rect(rect, WORK_TRACK)
		selection_outline.draw_rect(Rect2(rect.position, Vector2(bar.width * bar.fraction, rect.size.y)), WORK_FILL)
	if selection_drag.has_area():
		selection_outline.draw_rect(selection_drag, Color(VisualTokens.SELECTION_COLOR, 0.15))
		selection_outline.draw_rect(selection_drag, VisualTokens.SELECTION_COLOR, false, VisualTokens.LINE_WIDTH)
	for stroke in placement_strokes:
		if stroke.size() >= 2: selection_outline.draw_polyline(stroke, placement_color, VisualTokens.LINE_WIDTH, true)
	for stroke in selection_strokes + object_hover_strokes:
		if stroke.size() < 2:
			continue
		selection_outline.draw_polyline(stroke, Color(VisualTokens.SELECTION_COLOR, 0.82), VisualTokens.LINE_WIDTH, true)

func update_object_tooltips(world, camera: Camera3D, model, selection: Dictionary, hovered_object: Dictionary = {}) -> void:
	update_object_hover(world, camera, model, selection, hovered_object)
	var targets: Dictionary = {}
	if not hovered_object.is_empty():
		targets[_tooltip_key(hovered_object, model)] = {"target": hovered_object, "selected": false}
	if not selection.is_empty():
		targets[_tooltip_key(selection, model)] = {"target": selection, "selected": true}
	for id in world.actors.size():
		if world.actors[id].ring.visible:
			targets["worker:%d" % id] = {"target": {"worker_id": id}, "selected": true}
	var shown := {}
	var screen_scale := root.size / Vector2(camera.get_viewport().size)
	for key: String in targets:
		var target: Dictionary = targets[key].target
		var node: Node3D
		var anchor: Vector3
		if target.has("worker_id"):
			if target.worker_id >= world.actors.size():
				continue
			node = world.actors[target.worker_id]
			anchor = node.global_position + Vector3.UP * (1.15 if not model.can_control(model.workers[target.worker_id]) else 1.7)
		else:
			node = world.entity_views.get(target.get("entity_key", ""))
			if not is_instance_valid(node):
				node = world.water_view.sources.get(target.cell)
			if not is_instance_valid(node):
				continue
			var definition: Dictionary = Catalog.DEFINITIONS.get(target.kind, {})
			var height: float = definition.get("offset", Vector3.ZERO).y + definition.get("size", Vector3.ZERO).y * 0.5
			if node.has_meta("collider"):
				var shape: CollisionShape3D = node.get_meta("collider").get_child(0)
				height = shape.position.y
				if shape.shape is BoxShape3D:
					height += shape.shape.size.y * 0.5
				# Mesh colliders have no size; their visible silhouette is projected below.
			anchor = node.to_global(Vector3(0, height, 0))
		if not node.is_visible_in_tree() or camera.is_position_behind(anchor):
			continue
		var screen := camera.unproject_position(anchor) * screen_scale
		if not target.has("worker_id"):
			# A roof's far corner can project above its centre even at the same height.
			# Keep the name above the visible silhouette, including rotated buildings.
			for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
				var bounds := mesh.get_aabb()
				for index in 8:
					var corner := mesh.to_global(bounds.get_endpoint(index))
					if not camera.is_position_behind(corner):
						screen.y = minf(screen.y, camera.unproject_position(corner).y * screen_scale.y)
		if not Rect2(Vector2.ZERO, root.size).has_point(screen):
			continue
		if not world_tooltips.has(key):
			var created := ObjectTooltip.new()
			root.add_child(created)
			world_tooltips[key] = created
		var tooltip = world_tooltips[key]
		tooltip.set_black(targets[key].selected)
		tooltip.show_info(ObjectTooltip.describe(model, target), targets[key].selected)
		var wanted := screen - Vector2(tooltip.size.x * 0.5, tooltip.size.y + 8 * VisualTokens.GAP_UNIT)
		# Leave selected construction and work bars visible below the name.
		for bar: Dictionary in work_bars:
			if absf(bar.position.x - screen.x) < (bar.width + tooltip.size.x) * 0.5 and absf(bar.position.y - screen.y) < tooltip.size.y + 24 * VisualTokens.POINT:
				wanted.y = minf(wanted.y, bar.position.y - tooltip.size.y - 16 * VisualTokens.GAP_UNIT)
		tooltip.position = Vector2(clampf(wanted.x, 4, maxf(4, root.size.x - tooltip.size.x - 4)), clampf(wanted.y, 4, maxf(4, root.size.y - tooltip.size.y - 4)))
		shown[key] = true
	for key: String in world_tooltips.keys():
		if not shown.has(key):
			world_tooltips[key].free()
			world_tooltips.erase(key)

func _tooltip_key(target: Dictionary, model = null) -> String:
	if model != null and target.get("kind") in ["stockpile", "house"] and not str(target.get("entity_key", "")).begins_with("plan:"):
		var members := Houses.members(model, target.cell) if target.kind == "house" else Piles.members(model, target.cell)
		var addresses: Array[String] = []
		for member in members:
			addresses.append(str(member))
		addresses.sort()
		if not addresses.is_empty():
			return str(target.kind) + ":" + addresses[0]
	if target.has("worker_id"):
		return "worker:%d" % target.worker_id
	return "%s:%s" % [target.kind, target.cell] if str(target.get("entity_key", "")).is_empty() else target.entity_key

func refresh_hotkeys() -> void:
	workshop_button.text = hotkeys.hint("Blueprints", "blueprints")
