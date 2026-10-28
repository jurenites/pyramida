extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Slots = preload("res://scripts/settlement/save_slots.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func escape(game) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	game._input(event)

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func run() -> void:
	var directory := "/tmp/pyramida-menu-%d" % Time.get_ticks_usec()
	var game := Scene.instantiate()
	game.slot_directory = directory
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.menu.visible and game.menu.current_page == "home" and game.menu.title.is_visible_in_tree() and game.menu.title.text == "Pyramida", "Launch starts with the Pyramida main menu")
	check(not game.session_started and game.active_slot == -1, "Opening menu never silently starts or overwrites a settlement")
	var preview = game.menu_preview
	var preview_snapshot: Dictionary = preview.snapshot()
	check(game.menu.seed_label.text == "Seed %d" % preview.world_seed, "Menu displays the generated preview seed")
	check(is_equal_approx(game.menu.seed_label.get_global_rect().end.y, game.menu.root.size.y - 16), "Seed label reaches the bottom margin of the viewport")
	check(game.world.scenery.model_id == preview.get_instance_id() and game.world.scenery.terrain_revision == preview.terrain_revision, "Rendered background uses the preview terrain")
	check(game.menu.root.get_child(0).color.a < 1.0, "Menu backdrop reveals the generated world")
	check(not game.menu.buttons.resume.visible, "Continue is hidden when no playable save exists")
	var play_rect: Rect2 = game.menu.buttons.settlements.get_global_rect()
	check(is_equal_approx(play_rect.position.y, 160.0), "Play starts at the fixed action position without an empty Continue row")
	game.menu.buttons.settings.pressed.emit()
	game.menu.buttons.settings_back.pressed.emit()
	game.menu.buttons.settlements.pressed.emit()
	await process_frame
	await process_frame
	check(game.menu.buttons.slot_0.get_global_rect().is_equal_approx(play_rect), "First New game shares Play's click area")
	check(game.menu.title.is_visible_in_tree() and game.menu.title.text == "Select slot", "Slot selection has its own visible title")
	check(not game.menu.buttons.slot_0.disabled and game.menu.buttons.slot_0.get_theme_color("font_color") != game.menu.buttons.slots_back.get_theme_color("font_color"), "New game has a distinct color and remains clickable")
	check(game.menu_preview == preview, "Navigating menu pages preserves the offered world")
	var before: float = game.model.time
	game._process(1.0)
	check(game.model.time == before, "Background world is paused before a slot is selected")
	check(not DirAccess.dir_exists_absolute(directory), "Browsing empty slots does not create save files")
	check(game.hud.root.find_children("*", "Button", true, false).all(func(button): return button.text not in ["Save", "Load", "..."]), "Manual persistence controls are absent from the HUD")
	game.menu.buttons.slot_0.pressed.emit()
	await process_frame
	await process_frame
	check(game.menu.pages.difficulty.get_child(1) == game.menu.buttons.normal and game.menu.buttons.normal.get_global_rect().is_equal_approx(play_rect), "Sand shares Play's click area")
	check(game.menu.current_page == "difficulty", "Empty slot opens difficulty selection")
	check(not game.menu.buttons.easy.disabled and game.menu.buttons.hard.disabled and not game.menu.buttons.normal.disabled, "Easy and Normal are available; Hard stays disabled")
	check(not game.menu.buttons.has("start") and not game.session_started, "Difficulty selection waits for one click without an extra start button")
	game.menu.buttons.normal.pressed.emit()
	check(game.session_started and game.active_slot == 0 and not game.menu.visible, "Starting Normal creates slot one and enters play")
	check(game.speed == 1.0, "New settlement starts at normal speed")
	check(game.model == preview and game.model.snapshot() == preview_snapshot, "New Game starts the exact untouched preview model")
	var saved_preview = Model.new()
	check(saved_preview.restore(game.saves.read_slot(0).world) and saved_preview.world_seed == preview.world_seed, "First save persists the seed shown on the menu")
	check(not game.menu.seed_label.is_visible_in_tree() or not game.menu.visible, "Preview seed hides with the menu during play")
	game.set_process(false)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	for expected_speed in [1.0, 2.0, 4.0, 1.0]:
		check(game.speed == expected_speed, "Toolbar cycles only 1x, 2x and 4x")
		game._input(space)
		game._unhandled_input(space)
		check(game.speed == expected_speed, "Space never changes the current play speed")
		before = game.model.time
		game._process(0.1)
		check(is_equal_approx(game.model.time - before, 0.1 * expected_speed), "Simulation keeps running after Space")
		game.hud.speed_button.pressed.emit()
	for legacy_speed in [0.0, -1.0, 0.5, 3.0, 99.0]:
		game._restore_view({"speed": legacy_speed})
		check(game.speed == 1.0, "Unsupported saved speed resumes at 1x")
	check(FileAccess.file_exists(game.saves.path_for(0)), "A new settlement is immediately saved")
	check(game.saves.read_slot(0).difficulty == "normal", "Difficulty persists with the slot")
	game.model.time = 101.0
	game.autosave_elapsed = Slots.AUTOSAVE_SECONDS
	game._process(0.01)
	check(float(game.saves.read_slot(0).elapsed) >= 101, "Periodic autosave writes current simulation progress")
	game.speed = 4.0
	game._set_tool("house")
	game.selected = 0
	game.selected_workers.assign([0, 1])
	game.selected_object = {"kind": "stockpile", "cell": Vector3i.ZERO}
	game.left_selecting = true
	game.hud.selection_drag = Rect2(10, 10, 100, 100)
	game.world.actors[0].ring.show()
	var saved_text := FileAccess.get_file_as_string(game.saves.path_for(0))
	game.model.time += 1.0
	var autosave_elapsed: float = game.autosave_elapsed
	escape(game)
	check(not game.menu.visible and game.session_started and game.hud.visible, "Esc stays in the running settlement")
	check(FileAccess.get_file_as_string(game.saves.path_for(0)) == saved_text and game.autosave_elapsed == autosave_elapsed, "Esc neither writes a save nor resets the autosave timer")
	check(game.selected == -1 and game.selected_workers.is_empty() and game.selected_object.is_empty(), "Esc deselects all citizens and objects")
	check(not game.left_selecting and not game.hud.selection_drag.has_area(), "Esc cancels drag selection before mouse release")
	check(game.hud.selection_strokes.is_empty() and not game.hud.detail_panel.visible, "Esc immediately clears markers and selection details")
	check(game.tool == "inspect" and not is_instance_valid(game.preview), "Esc safely cancels placement")
	before = game.model.time
	game._process(0.1)
	check(game.model.time > before and game.speed == 4.0, "Esc keeps simulation running at the chosen speed")
	escape(game)
	check(not game.menu.visible and game.selected == -1, "Esc with nothing selected remains in gameplay")
	game.rig.focus = Vector3(4, 2, 3)
	game.rig.zoom = 32.0
	game.world.cutaway = true
	game._open_menu()
	check(game.menu.buttons.resume.visible and not game.menu.buttons.resume.disabled, "Continue appears after a slot is created")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var menu_save_view: Dictionary = game.saves.read_slot(0).view
	check(menu_save_view.zoom == 32.0 and menu_save_view.cutaway, "Autosave during preview preserves the gameplay camera and cutaway")
	before = game.model.time
	game.accumulator = 2.025
	var focus: Vector3 = game.rig.focus
	game._process(0.5)
	check(game.model.time == before and game.rig.focus == focus, "Menu pauses simulation and camera without changing speed")
	check(game.accumulator == 2.025, "Menu neither drains pending ticks nor accrues menu time")
	var rotate := InputEventKey.new()
	rotate.physical_keycode = KEY_R
	rotate.pressed = true
	var direction: int = game.direction
	game._unhandled_input(rotate)
	check(game.direction == direction, "Menu blocks gameplay hotkeys")
	game.menu.buttons.settings.pressed.emit()
	check(game.menu.current_page == "settings", "Settings open from the main menu")
	game.preferences.routes = true
	game._apply_settings()
	check(not game.world.show_routes, "Legacy route setting cannot enable routes for unselected citizens")
	check(game.menu.fullscreen is CheckBox, "Fullscreen uses a square checkbox")
	escape(game)
	check(game.menu.current_page == "home" and game.menu.visible, "Esc returns from Settings to the main menu")
	escape(game)
	check(not game.menu.visible and game.speed == 4.0, "Esc resumes the previous game speed")
	check(game.rig.focus == Vector3(4, 2, 3) and game.rig.zoom == 32.0 and game.world.cutaway, "Resume restores the gameplay camera and cutaway after preview")
	check(game.world.scenery.model_id == game.model.get_instance_id() and game.world.scenery.terrain_revision == game.model.terrain_revision, "Resume restores the saved settlement terrain")
	game._process(0.0)
	check(game.model.time > before and game.accumulator < 2.025, "Returning from Esc resumes pending simulation work")
	game.accumulator = 0.0
	game.model.time = 1234.0
	game.rig.zoom = 30.0
	game._open_menu()
	game.menu.buttons.settlements.pressed.emit()
	var second_preview = game.menu_preview
	check(second_preview.world_seed != preview.world_seed, "Returning to the menu offers a fresh seed")
	check(second_preview.time == 0.0 and game.model.time == 1234.0, "Preview stays pristine without changing the active settlement")
	game.menu.buttons.slot_1.pressed.emit()
	game.menu.buttons.normal.pressed.emit()
	check(game.model == second_preview, "A second New Game also uses its displayed preview")
	check(game.active_slot == 1 and game.model.time == 0, "Second empty slot starts an independent settlement")
	check(game.saves.read_slot(0).elapsed == 1234, "Switching slots saves the previous settlement first")
	game._open_menu()
	game.menu.buttons.settlements.pressed.emit()
	game.menu.buttons.slot_0.pressed.emit()
	check(game.active_slot == 0 and game.model.time == 1234 and game.rig.zoom == 30, "Selecting occupied slot resumes progress and camera")
	game._choose_slot(0, true)
	check(game.model.time == 1234, "Stale create action cannot replace an occupied slot")
	game.model.time = 1300
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.saves.read_slot(0).elapsed == 1300, "Leaving the application flushes progress automatically")
	game.hud.buttons.exit.pressed.emit()
	check(game.saves.read_slot(0).elapsed == 1300, "Toolbar exit saves current progress")
	check(game.menu_preview.world_seed != game.model.world_seed and game.menu_preview.time == 0.0, "Leaving gameplay prepares a fresh unplayed world")
	check(game.menu.seed_label.text == "Seed %d" % game.menu_preview.world_seed, "Seed label refreshes after leaving a settlement")
	check(not game.session_started and game.active_slot == -1 and not game.hud.visible, "Toolbar exit ends the settlement session")
	check(game.menu.visible and game.menu.current_page == "slots" and not game.menu.buttons.resume.disabled, "Toolbar exit returns to selection with the saved settlement available to Continue")
	escape(game)
	check(game.menu.visible and not game.session_started, "Escape cannot resume an exited settlement")
	game.menu.buttons.resume.pressed.emit()
	check(game.session_started and game.active_slot == 0 and game.model.time == 1300, "Continue reopens the most recently saved settlement")
	var another_game := Scene.instantiate()
	another_game.slot_directory = directory.path_join("another-launch")
	root.add_child(another_game)
	check(another_game.menu_preview.world_seed != preview.world_seed, "A separate launch generates a new preview seed")
	another_game.queue_free()
	await process_frame
	var isolated = Slots.new()
	isolated.directory = directory.path_join("recovery")
	var model = Model.new()
	model.setup()
	model.time = 42
	check(isolated.write_slot(0, model), "Initial atomic save succeeds")
	model.time = 84
	check(isolated.write_slot(0, model), "Later autosave replaces primary while retaining backup")
	write_text(isolated.path_for(0), "broken json")
	var recovered: Dictionary = isolated.read_slot(0)
	check(recovered.get("recovered", false) and recovered.elapsed == 42, "Corrupt newest save recovers previous valid snapshot")
	write_text(isolated.path_for(0) + ".bak", "also broken")
	check(isolated.read_slot(0).is_empty() and isolated.occupied(0), "Unrecoverable save stays occupied and cannot be mistaken for an empty slot")
	game.saves = isolated
	game._open_menu(false)
	check(game.menu.buttons.slot_0.disabled, "Unreadable slot is visibly unavailable, not reset")
	game.saves = Slots.new()
	game.saves.directory = directory
	var legacy_path := directory.path_join("legacy.json")
	write_text(legacy_path, JSON.stringify(model.snapshot()))
	isolated.directory = directory.path_join("migration")
	isolated.import_legacy(legacy_path)
	check(isolated.read_slot(0).elapsed == 84 and FileAccess.file_exists(legacy_path), "Legacy save imports to slot one while preserving original file")
	model.time = 99
	write_text(legacy_path, JSON.stringify(model.snapshot()))
	isolated.import_legacy(legacy_path)
	check(isolated.read_slot(0).elapsed == 84, "Legacy migration never overwrites an existing slot")
	var blocked := directory.path_join("not_a_directory")
	write_text(blocked, "file")
	game.saves.directory = blocked
	before = game.model.time
	check(not game.autosave(), "Write failure is reported rather than claiming success")
	game._choose_slot(2, true)
	check(game.active_slot == 0 and game.model.time == before, "Failed autosave prevents switching away from unsaved progress")
	game.hud.buttons.exit.pressed.emit()
	check(game.session_started and game.active_slot == 0, "Failed save prevents toolbar exit from discarding the active session")
	game.queue_free()
	await process_frame
	remove_directory(directory)
	if failures.is_empty():
		print("PASS: %d menu, autosave, slot isolation and recovery checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func remove_directory(path: String) -> void:
	for child in DirAccess.get_directories_at(path):
		remove_directory(path.path_join(child))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
