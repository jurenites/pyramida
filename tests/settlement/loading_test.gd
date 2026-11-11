extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	var game := Scene.instantiate()
	game.slot_directory = "/tmp/pyramida-loading-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	var seed_value: int = game.menu_preview.world_seed
	game.menu.selected_difficulty = "easy"
	game._choose_slot(0, true)
	check(game.operation_busy and game.loading_overlay.visible, "New Game immediately shows modal feedback")
	game._choose_slot(1, true)
	var frames := 0
	var stages := {}
	while game.operation_busy:
		stages[game.loading_overlay.status.text] = true
		var before: float = game.model.time
		game._process(2.0)
		check(game.model.time == before, "Simulation cannot advance during loading")
		await process_frame
		frames += 1
	check(frames > 10 and stages.has("Creating world…") and stages.has("Saving…") and stages.has("Preparing view…"), "Frames continue through generation, persistence and view preparation")
	check(not game.loading_overlay.visible and game.session_started and game.active_slot == 0, "Loader closes only after the game is ready")
	check(game.model.world_seed == seed_value and game.model.difficulty == "easy", "Background generation preserves the offered seed and chosen difficulty")
	check(not game.saves.occupied(1), "Repeated start clicks cannot create a second settlement")
	var restored = Model.new()
	check(not game.saves.read_slot(0, restored).is_empty() and restored.difficulty == "easy", "New save can restore directly into its playable model")
	check(not restored.navigation.surfaces.is_empty(), "Playable restore still builds navigation")
	var validation = Model.new()
	var data: Dictionary = game.saves.read_slot(0)
	check(Model.SaveCodec.restore(validation, data.world, true) and validation.navigation.surfaces.is_empty(), "Validation checks save data without rebuilding navigation")
	var damaged: Dictionary = data.world.duplicate(true)
	damaged.inventories = {}
	check(not Model.SaveCodec.restore(Model.new(), damaged, true), "Fast validation still rejects malformed inventories")
	check(game.saves.write_slot(2, restored), "Recovery test creates a separate slot")
	restored.time = 10
	check(game.saves.write_slot(2, restored), "Recovery test retains a valid backup")
	var corrupt := FileAccess.open(game.saves.path_for(2), FileAccess.WRITE)
	corrupt.store_string("broken primary")
	corrupt.close()
	restored.time = 20
	check(game.saves.write_slot(2, restored), "Saving after primary corruption succeeds")
	corrupt = FileAccess.open(game.saves.path_for(2), FileAccess.WRITE)
	corrupt.store_string("broken again")
	corrupt.close()
	var recovered: Dictionary = game.saves.read_slot(2)
	check(recovered.get("recovered", false) and recovered.get("elapsed") == 0, "Fast backup validation never replaces the last good backup with corrupt data")
	var good_directory: String = game.saves.directory
	var blocked := good_directory.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	game.saves.directory = blocked
	await game._quit_game()
	check(not game.operation_busy and game.session_started and game.menu.visible and not game.menu.status.text.is_empty(), "Failed close-save keeps progress alive and shows the existing error")
	game.saves.directory = good_directory
	game.model.time = 4320
	check(game.autosave(), "A periodic write can be in flight when closing")
	game.model.time = 4321
	probe_repeated_close(game)
	await game._quit_game()
	check(game.saves.read_slot(0).elapsed == 4321, "Close commits the latest progress before requesting exit")
	if failures.is_empty():
		print("PASS: responsive loading, duplicate suppression, validation, failed close and saved exit")
	else:
		for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))

func probe_repeated_close(game) -> void:
	await process_frame
	check(game.operation_busy and game.loading_overlay.visible, "Closing shows feedback before disk work")
	game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.close_requested, "Repeated close is coalesced while saving")
