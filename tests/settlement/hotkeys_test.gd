extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Hotkeys = preload("res://scripts/settlement/hotkeys.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event

func run() -> void:
	Input.use_accumulated_input = false
	var directory := "/tmp/pyramida-hotkeys-%d" % Time.get_ticks_usec()
	var game := Scene.instantiate()
	game.slot_directory = directory
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.menu.buttons.settings.pressed.emit()
	check(game.menu.sound_effects.value == 100, "Existing settings default to full sound effects volume")
	var effects_bus := AudioServer.get_bus_index(game.soundscape.BUS)
	game.menu.sound_effects.value = 0
	check(AudioServer.is_bus_mute(effects_bus) and game.menu.sound_effects_value.text == "0%", "Zero percent mutes sound effects")
	game.menu.sound_effects.value = 37
	check(not AudioServer.is_bus_mute(effects_bus) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(effects_bus)), 0.37), "Slider applies volume to the effects bus immediately")
	check(game.saves.read_settings().sound_effects == 37, "Sound effects volume persists to settings")
	game.menu._reset_hotkeys()
	check(game.saves.read_settings().sound_effects == 37, "Resetting hotkeys preserves sound effects volume")
	game.menu.open_menu(game.saves.entries(), false, -1, game.saves.read_settings())
	check(game.menu.sound_effects.value == 37 and game.menu.sound_effects_value.text == "37%", "Reopening Settings restores the saved percentage")
	game.menu.show_page("settings")
	game.menu.sound_effects.value = 100
	check(not AudioServer.is_bus_mute(effects_bus) and is_zero_approx(AudioServer.get_bus_volume_db(effects_bus)), "One hundred percent restores original sound levels")
	game.menu.buttons.hotkeys.pressed.emit()
	check(game.menu.current_page == "hotkeys" and game.menu.key_buttons.size() == Hotkeys.DEFAULTS.size(), "Settings opens all settlement bindings")
	check(game.menu.key_buttons.remove.text == "Backspace", "Removal defaults to Backspace")
	check(game.menu.key_buttons.build.text == "B", "Default key is shown")
	game.menu.key_buttons.build.pressed.emit()
	game.menu._input(key(KEY_M))
	check(game.hotkeys.values.build == KEY_B and game.menu.capturing_action == "build", "Duplicate key stays pending without changing bindings")
	var modified := key(KEY_K)
	modified.ctrl_pressed = true
	game.menu._input(modified)
	check(game.hotkeys.values.build == KEY_B, "Modifier chords are rejected")
	game.menu._input(key(KEY_ESCAPE))
	check(game.menu.current_page == "hotkeys" and game.menu.capturing_action.is_empty(), "Esc cancels capture without leaving the page")
	game.menu.key_buttons.build.pressed.emit()
	Input.parse_input_event(key(KEY_F2))
	await process_frame
	check(not is_instance_valid(game.structure_workshop) and game.menu.capturing_action == "build", "F2 during capture never opens Blueprints")
	game.menu._input(key(KEY_K))
	check(game.hotkeys.values.build == KEY_K and game.menu.key_buttons.build.text == "K", "New key applies and updates its label")
	check(game.saves.read_settings().hotkeys.build == KEY_K, "Key persists to settings")
	game.menu._settings_changed()
	check(game.saves.read_settings().hotkeys.build == KEY_K, "Display changes preserve custom keys")
	game.menu._input(key(KEY_ESCAPE))
	check(game.menu.current_page == "settings", "Esc from Hotkeys returns to Settings")
	game.menu.hide()
	var before: bool = game.hud.build_panel.visible
	game._unhandled_input(key(KEY_B))
	check(game.hud.build_panel.visible == before, "Old binding no longer triggers action")
	game._unhandled_input(key(KEY_K))
	check(game.hud.build_panel.visible != before, "New binding triggers the real building menu")
	game.menu.open_menu(game.saves.entries(), false, -1, game.preferences)
	game.menu.show_page("hotkeys")
	game.menu.key_buttons.pan_forward.pressed.emit()
	game.menu._input(key(KEY_UP))
	game.menu.hide()
	Input.parse_input_event(key(KEY_W))
	var focus: Vector3 = game.rig.focus
	game.rig.advance(0.1)
	check(game.rig.focus == focus, "Old movement key no longer pans")
	var release := key(KEY_W)
	release.pressed = false
	Input.parse_input_event(release)
	Input.parse_input_event(key(KEY_UP))
	game.rig.advance(0.1)
	check(game.rig.focus != focus, "Custom held key pans the camera")
	release = key(KEY_UP)
	release.pressed = false
	Input.parse_input_event(release)
	game.menu.show()
	game.menu.key_buttons.copy_cutaway.pressed.emit()
	game.menu._input(key(KEY_J))
	var target: Dictionary = game.hud.toolbar_tooltip_targets[game.hud.copy_button]
	check(target.text.call() == "Copy · J", "Tooltip reflects custom shortcut")
	var reloaded := Scene.instantiate()
	reloaded.slot_directory = directory
	root.add_child(reloaded)
	reloaded.set_process(false)
	check(reloaded.hotkeys.values.build == KEY_K and reloaded.hotkeys.values.pan_forward == KEY_UP, "Fresh game loads custom bindings")
	reloaded.queue_free()
	await process_frame
	var blocked := directory.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("file")
	file.close()
	game.saves.directory = blocked
	game.menu.key_buttons.build.pressed.emit()
	game.menu._input(key(KEY_L))
	check(game.hotkeys.values.build == KEY_K and not game.menu.status.text.is_empty(), "Failed save retains applied binding and reports failure")
	game.saves.directory = directory
	game.menu.buttons.reset_hotkeys.pressed.emit()
	check(game.hotkeys.values == Hotkeys.DEFAULTS and game.saves.read_settings().hotkeys == Hotkeys.DEFAULTS, "Reset restores and saves every default")
	var bindings := Hotkeys.new()
	bindings.load_values({"build": KEY_M})
	check(bindings.values == Hotkeys.DEFAULTS, "Malformed duplicate settings fall back safely")
	bindings.load_values({"build": "invalid"})
	check(bindings.values == Hotkeys.DEFAULTS, "Malformed key type falls back safely")
	game.queue_free()
	await process_frame
	for name_ in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name_))
	DirAccess.remove_absolute(directory)
	if failures.is_empty():
		print("PASS: %d hotkey UI, routing, camera, persistence and reset checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
