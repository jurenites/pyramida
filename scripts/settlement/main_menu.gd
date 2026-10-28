extends CanvasLayer
const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")
const Settings = preload("res://scripts/gameplay_settings.gd")
## Modal menu. The controller pauses the world while this layer is open.
signal resume_requested
signal slot_requested(slot: int, create: bool)
signal delete_slot_requested(slot: int)
signal settings_changed(values: Dictionary)
signal quit_requested
signal structure_workshop_requested
const Hotkeys = preload("res://scripts/settlement/hotkeys.gd")
var hotkeys = Hotkeys.new()
var key_buttons: Dictionary = {}
var capturing_action := ""
var key_prompt: Label
var menu_scroll: ScrollContainer
var root: Control
const FONT_SIZE := VisualTokens.UI_FONT_SIZE
const HEADING_COLOR := Color("64452f")
const ACTION_COLOR := Color("174f52")
const NEW_GAME_COLOR := Color("9c4f2f")
const DISABLED_COLOR := Color("858580")
var pages: Dictionary = {}
var buttons: Dictionary = {}
var slots: Array[Button] = []
var action_spacers: Array[Control] = []
var status: Label
var seed_label: Label
var slot_caption: Label
var title: Label
var fullscreen: CheckBox
var debug_mode: CheckBox
var sound_effects: HSlider
var sound_effects_value: Label
var current_page := "home"
var pending_slot := -1
var selected_difficulty := "normal"
var active_slot := -1
var has_session := false
var continue_slot := -1
var slot_entries: Array[Dictionary] = []
var keyboard_focus_visible := false
var hover_refresh_pending := false

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	visibility_changed.connect(_queue_hover_refresh)
	root.resized.connect(_queue_hover_refresh)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	backdrop.color.a = 0.38
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	var seed_margin := MarginContainer.new()
	seed_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	seed_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		seed_margin.add_theme_constant_override("margin_" + side, 16 * VisualTokens.PADDING_UNIT)
	root.add_child(seed_margin)
	seed_label = label("")
	seed_label.name = "WorldSeed"
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	seed_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	seed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seed_margin.add_child(seed_label)
	menu_scroll = ScrollContainer.new()
	menu_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	menu_scroll.get_v_scroll_bar().value_changed.connect(func(_value): _queue_hover_refresh())
	root.add_child(menu_scroll)
	var menu_margin := MarginContainer.new()
	menu_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_margin.add_theme_constant_override("margin_top", 64 * VisualTokens.PADDING_UNIT)
	menu_margin.add_theme_constant_override("margin_bottom", 24 * VisualTokens.PADDING_UNIT)
	menu_scroll.add_child(menu_margin)
	var layout := VBoxContainer.new()
	layout.custom_minimum_size.x = 440 * VisualTokens.POINT
	layout.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	layout.add_theme_constant_override("separation", 16 * VisualTokens.GAP_UNIT)
	menu_margin.add_child(layout)
	# Reserve the same heading space even when a page has no heading.
	var header := Control.new()
	header.custom_minimum_size.y = 80 * VisualTokens.POINT
	layout.add_child(header)
	title = label("settlement_menu_title_text")
	title.add_theme_font_size_override("font_size", VisualTokens.TITLE_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	slot_caption = label("settlement_menu_tagline_text")
	slot_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(slot_caption)
	slot_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	for page in ["home", "slots", "difficulty", "settings", "hotkeys"]:
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 9 * VisualTokens.GAP_UNIT)
		layout.add_child(content)
		pages[page] = content
		content.sort_children.connect(_queue_hover_refresh)
		content.item_rect_changed.connect(_queue_hover_refresh)
	add_button("resume", "settlement_menu_resume_text", "home", continue_game)
	add_button("settlements", "settlement_menu_slots_text", "home", func(): show_page("slots"))
	add_button("settings", "settlement_menu_settings_text", "home", func(): show_page("settings"))
	add_button("quit", "settlement_menu_quit_text", "home", func(): quit_requested.emit())
	# Reserve Continue's row so Play, slot one and Sand share a click position.
	for page in ["slots", "difficulty"]:
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.custom_minimum_size.y = buttons.resume.get_combined_minimum_size().y
		pages[page].add_child(spacer)
		action_spacers.append(spacer)
		buttons.resume.minimum_size_changed.connect(func():
			spacer.custom_minimum_size.y = buttons.resume.get_combined_minimum_size().y)
	for slot in 3:
		var item := add_button("slot_%d" % slot, "", "slots", func(): choose_slot(slot))
		slots.append(item)
	add_button("slots_back", "settlement_menu_back_text", "slots", func(): show_page("settings" if current_page == "delete_slots" else "home"))
	for difficulty in ["normal", "easy", "hard"]:
		var item := add_button(difficulty, "settlement_difficulty_" + difficulty + "_text", "difficulty", func(): pass)
		item.tooltip_text = tr("settlement_difficulty_" + difficulty + "_tooltip_text")
		item.disabled = difficulty == "hard"
		if difficulty != "hard":
			item.pressed.connect(func():
				selected_difficulty = difficulty
				slot_requested.emit(pending_slot, true))
	add_button("difficulty_back", "settlement_menu_back_text", "difficulty", func(): show_page("slots"))
	fullscreen = CheckBox.new()
	fullscreen.add_theme_icon_override("checked", preload("res://assets/ui/checkbox_checked.svg"))
	fullscreen.add_theme_icon_override("unchecked", preload("res://assets/ui/checkbox_empty.svg"))
	style_option(fullscreen)
	fullscreen.text = tr("settlement_setting_fullscreen_text")
	pages.settings.add_child(fullscreen)
	fullscreen.toggled.connect(func(_enabled): _settings_changed())
	_build_sound_effects_setting()
	debug_mode = CheckBox.new()
	debug_mode.add_theme_icon_override("checked", preload("res://assets/ui/checkbox_checked.svg"))
	debug_mode.add_theme_icon_override("unchecked", preload("res://assets/ui/checkbox_empty.svg"))
	style_option(debug_mode)
	debug_mode.text = "Debug mode"
	pages.settings.add_child(debug_mode)
	debug_mode.toggled.connect(func(_enabled): _settings_changed())
	add_button("hotkeys", "Hotkeys", "settings", func(): show_page("hotkeys"))
	_build_hotkeys_page()
	add_button("delete_save", "settlement_menu_delete_save_text", "settings", func(): show_page("delete_slots"))
	add_button("settings_back", "settlement_menu_back_text", "settings", func(): show_page("home"))
	status = label("")
	status.custom_minimum_size.x = 380
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status)
	var debug_button := Button.new()
	debug_button.text = hotkeys.hint("Blueprints", "blueprints")
	debug_button.tooltip_text = "Open the building authoring workspace. The settlement pauses until you return."
	style_option(debug_button)
	debug_button.pressed.connect(func(): structure_workshop_requested.emit())
	layout.add_child(debug_button)
	buttons["structure_editor"] = debug_button
	visible = false

func add_button(id: String, key: String, page: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = tr(key) if not key.is_empty() else ""
	result.custom_minimum_size.y = 42
	result.custom_minimum_size.x = 160 * VisualTokens.POINT
	result.pressed.connect(action)
	pages[page].add_child(result)
	style_option(result)
	buttons[id] = result
	return result

func _build_sound_effects_setting() -> void:
	var control := VBoxContainer.new()
	control.custom_minimum_size.x = 320 * VisualTokens.POINT
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	control.add_theme_constant_override("separation", 4 * VisualTokens.GAP_UNIT)
	pages.settings.add_child(control)
	var heading := HBoxContainer.new()
	control.add_child(heading)
	var caption := label("Sound effects")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(caption)
	sound_effects_value = label("100%")
	heading.add_child(sound_effects_value)
	sound_effects = HSlider.new()
	sound_effects.name = "SoundEffectsVolume"
	sound_effects.min_value = 0
	sound_effects.max_value = 100
	sound_effects.step = 1
	sound_effects.value = 100
	sound_effects.custom_minimum_size.y = 42 * VisualTokens.POINT
	sound_effects.scrollable = false
	sound_effects.tooltip_text = "Sound effects"
	for state in ["slider", "grabber_area", "grabber_area_highlight"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("d69b77") if state == "slider" else ACTION_COLOR
		track.content_margin_top = VisualTokens.LINE_WIDTH / 2
		track.content_margin_bottom = VisualTokens.LINE_WIDTH / 2
		sound_effects.add_theme_stylebox_override(state, track)
	for state in ["grabber", "grabber_highlight"]:
		var gradient := Gradient.new()
		var color := HEADING_COLOR if state == "grabber_highlight" else ACTION_COLOR
		gradient.colors = PackedColorArray([color, color])
		var handle := GradientTexture2D.new()
		handle.gradient = gradient
		handle.width = 16 * VisualTokens.POINT
		handle.height = 24 * VisualTokens.POINT
		sound_effects.add_theme_icon_override(state, handle)
	control.add_child(sound_effects)
	sound_effects.value_changed.connect(func(value: float):
		sound_effects_value.text = "%d%%" % roundi(value)
		_settings_changed())

func style_option(control: Button, destructive := false, action_color := ACTION_COLOR) -> void:
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	control.custom_minimum_size.y = 42
	control.add_theme_font_size_override("font_size", FONT_SIZE)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, action_color)
	control.add_theme_color_override("font_disabled_color", DISABLED_COLOR)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		var highlighted: bool = state in ["hover", "hover_pressed"]
		style.bg_color = Color("fff1cf") if highlighted else Color.TRANSPARENT
		style.border_color = Color("d69b77") if highlighted else Color.TRANSPARENT
		if destructive and state != "disabled":
			style.bg_color = Color("f16b51") if highlighted or state == "pressed" else Color("f2c3ab")
			style.border_color = Color("c85843") if highlighted or state == "pressed" else Color("f2c3ab")
		style.set_border_width_all(int(VisualTokens.LINE_WIDTH))
		# Content margins include the border; keep real padding inside its stroke.
		style.content_margin_left = VisualTokens.LINE_WIDTH + VisualTokens.PANEL_PADDING_X
		style.content_margin_right = VisualTokens.LINE_WIDTH + VisualTokens.PANEL_PADDING_X
		style.content_margin_top = VisualTokens.LINE_WIDTH + VisualTokens.PANEL_PADDING_Y
		style.content_margin_bottom = VisualTokens.LINE_WIDTH + VisualTokens.PANEL_PADDING_Y
		control.add_theme_stylebox_override(state, style)
	style_focus(control)

func style_focus(control: Button) -> void:
	control.add_theme_stylebox_override("focus", control.get_theme_stylebox("hover") if keyboard_focus_visible else StyleBoxEmpty.new())

func set_keyboard_focus_visible(value: bool) -> void:
	if keyboard_focus_visible == value:
		return
	keyboard_focus_visible = value
	for control in root.find_children("*", "Button", true, false):
		style_focus(control)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not capturing_action.is_empty() and event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			_capture_key(event)
		return
	if current_page == "hotkeys" and event is InputEventKey and event.pressed and not event.echo and Hotkeys.keycode(event) == KEY_ESCAPE:
		escape()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and Hotkeys.keycode(event) == KEY_TAB:
		set_keyboard_focus_visible(true)
		if root.get_viewport().gui_get_focus_owner() == null:
			var controls := root.find_children("*", "Button", true, false)
			if event.shift_pressed:
				controls.reverse()
			for control: Button in controls:
				if control.is_visible_in_tree() and not control.disabled and control.focus_mode != Control.FOCUS_NONE:
					control.grab_focus()
					root.get_viewport().set_input_as_handled()
					break
	elif event is InputEventMouseButton or (event is InputEventMouseMotion and not event.relative.is_zero_approx()):
		set_keyboard_focus_visible(false)

func label(key: String) -> Label:
	var result := Label.new()
	result.text = tr(key) if not key.is_empty() else ""
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", FONT_SIZE)
	result.add_theme_color_override("font_color", HEADING_COLOR)
	return result

func open_menu(entries: Array[Dictionary], session: bool, slot: int, settings: Dictionary) -> void:
	set_keyboard_focus_visible(false)
	has_session = session
	active_slot = slot
	refresh_entries(entries)
	fullscreen.set_pressed_no_signal(settings.get("fullscreen", false))
	debug_mode.set_pressed_no_signal(settings.get("debug_mode", false))
	sound_effects.set_value_no_signal(settings.get("sound_effects", 100.0))
	sound_effects_value.text = "%d%%" % roundi(sound_effects.value)
	slot_caption.text = tr("settlement_menu_active_text") % [slot + 1, _slot_landscape(entries[slot])] if slot >= 0 else tr("settlement_menu_tagline_text")
	status.text = ""
	visible = true
	show_page("home" if session else "slots")

func refresh_entries(entries: Array[Dictionary]) -> void:
	slot_entries = entries
	continue_slot = -1
	var latest_save := -1.0
	for entry: Dictionary in entries:
		if entry.valid and float(entry.saved_at) > latest_save:
			latest_save = float(entry.saved_at)
			continue_slot = int(entry.slot)
	buttons.resume.disabled = not has_session and continue_slot < 0
	buttons.resume.visible = not buttons.resume.disabled
	for spacer in action_spacers:
		spacer.visible = buttons.resume.visible
	refresh_slots()

func refresh_slots() -> void:
	var deleting := current_page == "delete_slots"
	for entry: Dictionary in slot_entries:
		var subtitle := tr("settlement_slot_deleted_text" if deleting else "settlement_slot_empty_text")
		if entry.occupied:
			subtitle = tr("settlement_slot_unavailable_text")
			if entry.valid:
				var elapsed := float(entry.elapsed)
				var day := int(elapsed / Settings.SIMULATION_DAY_SECONDS) + 1
				var is_night := fposmod(elapsed, Settings.SIMULATION_DAY_SECONDS) >= Settings.SIMULATION_DAY_SECONDS * 0.5
				var key := "settlement_slot_night_progress_text" if is_night else "settlement_slot_progress_text"
				subtitle = tr(key) % [_slot_landscape(entry), day]
		slots[entry.slot].text = subtitle
		slots[entry.slot].disabled = not entry.occupied if deleting else entry.occupied and not entry.valid
		slots[entry.slot].tooltip_text = tr("settlement_slot_delete_text") if deleting and entry.occupied else ""
		style_option(slots[entry.slot], deleting, NEW_GAME_COLOR if not deleting and not entry.occupied else ACTION_COLOR)
		if keyboard_focus_visible and slots[entry.slot].disabled and slots[entry.slot].has_focus():
			buttons.slots_back.grab_focus()
	buttons.slots_back.text = tr("settlement_menu_cancel_text" if deleting else "settlement_menu_back_text")

func _slot_landscape(entry: Dictionary) -> String:
	return tr("settlement_difficulty_" + str(entry.difficulty) + "_text")

func set_preview_seed(seed_value: int) -> void:
	seed_label.text = tr("settlement_menu_seed_text") % seed_value

func continue_game() -> void:
	if has_session:
		resume_requested.emit()
	elif continue_slot >= 0:
		slot_requested.emit(continue_slot, false)

func show_page(page: String) -> void:
	_cancel_capture()
	current_page = page
	menu_scroll.scroll_vertical = 0
	buttons.structure_editor.visible = page == "home"
	status.text = ""
	refresh_slots()
	title.visible = true
	slot_caption.visible = page == "difficulty"
	if page == "difficulty":
		slot_caption.text = tr("settlement_menu_difficulty_text")
	title.text = tr("settlement_menu_settings_text") if page == "settings" else tr("settlement_menu_title_text")
	if page == "slots":
		title.text = tr("settlement_menu_select_slot_text")
	if page == "hotkeys":
		title.text = "Hotkeys"
		refresh_hotkeys()
	if page == "delete_slots":
		title.text = tr("settlement_menu_delete_save_text")
	title.add_theme_font_size_override("font_size", VisualTokens.UI_FONT_SIZE if page in ["slots", "settings", "delete_slots", "hotkeys"] else VisualTokens.TITLE_FONT_SIZE)
	var content_page := "slots" if page == "delete_slots" else page
	for key: String in pages:
		pages[key].visible = key == content_page
	_queue_hover_refresh()
	if not keyboard_focus_visible:
		var focused := root.get_viewport().gui_get_focus_owner()
		if focused != null and root.is_ancestor_of(focused):
			focused.release_focus()
		return
	for child in pages[content_page].get_children():
		if child is Button and child.visible and not child.disabled:
			child.grab_focus()
			break

func _queue_hover_refresh() -> void:
	if hover_refresh_pending:
		return
	hover_refresh_pending = true
	_refresh_hover.call_deferred()

func _refresh_hover() -> void:
	hover_refresh_pending = false
	if visible and is_inside_tree():
		# Container layout is deferred; hit-test the settled UI without moving the mouse.
		get_viewport().update_mouse_cursor_state()

func choose_slot(slot: int) -> void:
	if slot < 0 or slot >= slot_entries.size():
		return
	if current_page == "delete_slots":
		if slot_entries[slot].occupied:
			delete_slot_requested.emit(slot)
		return
	if slot_entries[slot].occupied:
		if slot_entries[slot].valid:
			slot_requested.emit(slot, false)
	else:
		pending_slot = slot
		show_page("difficulty")

func escape() -> void:
	if not capturing_action.is_empty():
		_cancel_capture()
	elif current_page in ["delete_slots", "hotkeys"]:
		show_page("settings")
	elif current_page != "home":
		show_page("home")
	elif has_session:
		resume_requested.emit()

func _settings_changed(keys: Dictionary = {}) -> void:
	settings_changed.emit({"fullscreen": fullscreen.button_pressed, "routes": false,
		"debug_mode": debug_mode.button_pressed,
		"sound_effects": sound_effects.value, "hotkeys": (hotkeys.values if keys.is_empty() else keys).duplicate()})

func _build_hotkeys_page() -> void:
	key_prompt = label("Click a key to change it")
	pages.hotkeys.add_child(key_prompt)
	var key_panel := PanelContainer.new()
	key_panel.custom_minimum_size.x = 700 * VisualTokens.POINT
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("fff1cf")
	paper.bg_color.a = 0.94
	paper.content_margin_left = 12 * VisualTokens.PADDING_UNIT
	paper.content_margin_right = 12 * VisualTokens.PADDING_UNIT
	paper.content_margin_top = 8 * VisualTokens.PADDING_UNIT
	paper.content_margin_bottom = 8 * VisualTokens.PADDING_UNIT
	key_panel.add_theme_stylebox_override("panel", paper)
	pages.hotkeys.add_child(key_panel)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4 * VisualTokens.GAP_UNIT)
	key_panel.add_child(rows)
	for action: String in Hotkeys.DEFAULTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16 * VisualTokens.GAP_UNIT)
		rows.add_child(row)
		var description := label(Hotkeys.LABELS[action])
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var key_button := Button.new()
		style_option(key_button)
		key_button.custom_minimum_size.x = 150 * VisualTokens.POINT
		key_button.pressed.connect(func(): _begin_capture(action))
		row.add_child(key_button)
		key_buttons[action] = key_button
	for entry in [["Deselect / cancel", "Esc"], ["Add to selection", "Shift + click"], ["Select / place", "Left click"], ["Order / cancel placement", "Right click"], ["Rotate camera", "Right / middle drag"], ["Zoom", "Scroll"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16 * VisualTokens.GAP_UNIT)
		rows.add_child(row)
		var description := label(entry[0])
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var value := Button.new()
		style_option(value)
		value.text = entry[1]
		value.disabled = true
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.custom_minimum_size.x = 150 * VisualTokens.POINT
		row.add_child(value)
	add_button("reset_hotkeys", "Reset to defaults", "hotkeys", _reset_hotkeys)
	add_button("hotkeys_back", "settlement_menu_back_text", "hotkeys", func(): show_page("settings"))
	refresh_hotkeys()

func refresh_hotkeys() -> void:
	for action: String in key_buttons:
		key_buttons[action].text = "Press a key…" if action == capturing_action else hotkeys.key_text(action)
	if buttons.has("structure_editor"):
		buttons.structure_editor.text = hotkeys.hint("Blueprints", "blueprints")

func _begin_capture(action: String) -> void:
	capturing_action = action
	key_prompt.text = "Press one key · Esc cancels"
	status.text = ""
	refresh_hotkeys()

func _cancel_capture() -> void:
	capturing_action = ""
	if key_prompt != null:
		key_prompt.text = "Click a key to change it"
	refresh_hotkeys()

func _capture_key(event: InputEventKey) -> void:
	var key := Hotkeys.keycode(event)
	if key == KEY_ESCAPE:
		_cancel_capture()
		return
	if not Hotkeys.allowed(key) or event.ctrl_pressed or event.meta_pressed or event.alt_pressed or event.shift_pressed:
		key_prompt.text = "Choose one key · Esc / Tab reserved"
		return
	var other: String = hotkeys.conflict(capturing_action, key)
	if not other.is_empty():
		key_prompt.text = "Used by: " + Hotkeys.LABELS[other]
		return
	var values: Dictionary = hotkeys.values.duplicate()
	values[capturing_action] = key
	_cancel_capture()
	_settings_changed(values)
	refresh_hotkeys()

func _reset_hotkeys() -> void:
	_cancel_capture()
	status.text = ""
	_settings_changed(Hotkeys.DEFAULTS)
	refresh_hotkeys()
