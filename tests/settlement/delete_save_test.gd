extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Slots = preload("res://scripts/settlement/save_slots.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func run() -> void:
	var directory := "/tmp/pyramida-delete-test-%d" % Time.get_ticks_usec()
	var game := Scene.instantiate()
	game.slot_directory = directory
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.menu.buttons.slot_0.pressed.emit()
	game.menu.buttons.normal.pressed.emit()
	game._open_menu()
	var preview = game.menu_preview
	check(game.saves.write_slot(1, game.model), "Create a second independent save")
	var other_save := FileAccess.get_file_as_string(game.saves.path_for(1))
	game.menu.refresh_entries(game.saves.entries())
	game.menu.buttons.settings.pressed.emit()
	check(game.menu.buttons.delete_save.text == "Delete save file", "Settings contains the delete save entry")
	game.menu.buttons.delete_save.pressed.emit()
	check(game.menu.current_page == "delete_slots" and game.menu.pages.slots.visible, "Deletion reuses the save selection screen")
	check(game.menu.title.visible and game.menu.title.text == "Delete save file", "Deletion screen has its own heading")
	check(game.menu.slots[0].tooltip_text == "delete", "Occupied slots show the delete tooltip")
	check(game.menu.slots[2].text == "empty" and game.menu.slots[2].disabled, "Empty deletion slots are labelled empty and disabled")
	var hover: StyleBoxFlat = game.menu.slots[0].get_theme_stylebox("hover")
	var normal: StyleBoxFlat = game.menu.slots[0].get_theme_stylebox("normal")
	check(hover.bg_color.r > hover.bg_color.g and hover.bg_color.g < normal.bg_color.g, "Hover uses a stronger red highlight")
	game.menu.buttons.slots_back.pressed.emit()
	check(game.menu.current_page == "settings" and game.saves.occupied(0), "Cancel returns to settings without deleting")
	game.menu.buttons.delete_save.pressed.emit()
	game.menu.escape()
	check(game.menu.current_page == "settings", "Escape cancels deletion mode")
	game.menu.buttons.delete_save.pressed.emit()
	await capture(game, "delete-save-hover", true)
	var path: String = game.saves.path_for(0)
	check(FileAccess.file_exists(path + ".bak"), "Active save has a recovery backup before deletion")
	write_text(path + ".tmp", "pending save")
	write_text(path + ".bak.tmp", "pending backup")
	game.menu.slots[0].pressed.emit()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		check(not FileAccess.file_exists(path + suffix), "Deletion removes snapshot " + suffix)
	check(game.menu.current_page == "delete_slots" and game.menu.slots[0].text == "empty", "Deleted row becomes empty in place")
	check(game.menu.slots[0].disabled and game.menu.slots[0].tooltip_text.is_empty(), "Deleted row has no delete interaction")
	check(not game.session_started and game.active_slot == -1 and not game.menu.has_session, "Deleting active save ends its in-memory session")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.autosave()
	check(not game.saves.occupied(0), "Autosave cannot recreate a deleted active save")
	check(game.menu.continue_slot == 1 and not game.menu.buttons.resume.disabled, "Continue moves to the remaining save")
	check(FileAccess.get_file_as_string(game.saves.path_for(1)) == other_save, "Deleting one slot preserves the other save exactly")
	check(game.menu_preview == preview, "Deletion preserves the offered preview world")
	await capture(game, "delete-save-empty", false)
	var legacy := directory.path_join("legacy.json")
	write_text(legacy, JSON.stringify(game.model.snapshot()))
	var reopened = Slots.new()
	reopened.directory = directory
	reopened.import_legacy(legacy)
	check(not reopened.occupied(0) and FileAccess.file_exists(legacy), "Relaunch cannot resurrect a deleted slot from a preserved legacy file")
	write_text(game.saves.path_for(1), "damaged save")
	game.menu.refresh_entries(game.saves.entries())
	check(not game.menu.slots[1].disabled, "Damaged saves can be deleted explicitly")
	game.menu.slots[1].pressed.emit()
	check(not game.saves.occupied(1) and not game.menu.buttons.resume.visible, "Deleting last save hides Continue")
	game.menu.choose_slot(0)
	check(game.menu.current_page == "delete_slots" and not game.saves.occupied(0), "Empty deletion row never starts a new game")
	game.menu.show_page("slots")
	check(game.menu.slots[0].text == "New game" and not game.menu.slots[0].disabled and game.menu.slots[0].tooltip_text.is_empty(), "Normal selection restores the New game action")
	game.menu.slots[0].pressed.emit()
	game.menu.buttons.normal.pressed.emit()
	check(game.session_started and game.saves.occupied(0), "Deleted slot can be reused for a new settlement")
	check(not game.saves.delete_slot(-1) and not game.saves.delete_slot(3), "Deletion rejects out-of-range slots")
	game._open_menu()
	game.menu.show_page("delete_slots")
	# Force a removal failure without touching player files or depending on permissions.
	DirAccess.remove_absolute(path + ".deleted")
	DirAccess.make_dir_absolute(path + ".deleted")
	game.menu.slots[0].pressed.emit()
	check(game.saves.occupied(0) and game.session_started, "Failed deletion preserves the active settlement")
	check(game.menu.status.text == "Could not delete save file.", "Failed deletion shows concise feedback")
	DirAccess.remove_absolute(path + ".deleted")
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures.is_empty():
		print("PASS: %d save deletion, isolation and menu checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func capture(game, name_: String, hover: bool) -> void:
	if not OS.get_cmdline_user_args().has("--capture-delete-menu"):
		return
	for frame in 5:
		await process_frame
	if hover:
		var event := InputEventMouseMotion.new()
		event.position = game.menu.slots[0].get_global_rect().get_center()
		root.push_input(event, true)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pyramida-" + name_ + ".png")
