extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Model = preload("res://scripts/settlement/world_model.gd")
const Slots = preload("res://scripts/settlement/save_slots.gd")
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = Scene.instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-background-save-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.capture = true
	game.capture_frames = -100000
	game.session_started = true
	game.active_slot = 0
	game.speed = 0
	check(Slots.AUTOSAVE_SECONDS == 300.0, "Autosave interval is five real-time minutes")
	game.model.time = 41.0
	game._process(299.0)
	check(not game.saves.occupied(0) and not game.autosave_worker.busy(), "No periodic write before five minutes")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.autosave_worker.busy(), "Changing app focus never starts a save")
	game._process(1.0)
	check(game.autosave_worker.busy() and not game.operation_busy, "Five-minute save runs without a modal or simulation lock")
	game.model.time = 42.0
	game.speed = 1
	game._process(0.05)
	check(game.model.time > 42.0, "Simulation advances while a periodic write is pending")
	game.speed = 0
	check(game.autosave(), "An overlapping periodic request is coalesced")
	check(await game._wait_for_autosave(), "Background write completes successfully")
	check(game.saves.read_slot(0).elapsed == 41.0, "Periodic write owns a snapshot rather than the live model")
	# Mutable inventory, job labour, route arrays and terrain must all be frozen.
	var cell: Vector3i = game.model.stores.keys()[0]
	var inventory = game.model.stores[cell]
	var worker: Dictionary = game.model.workers[0]
	worker.job = {"kind": "eat", "phase": "pickup", "source": inventory, "target": cell, "labour": Model.Jobs.Labour.new(2.0)}
	var count: int = inventory.count("food")
	var frozen: Dictionary = Model.SaveCodec.capture(game.model)
	inventory.amounts.food = count + 1
	worker.job.labour.applied_seconds = 1.0
	worker.route.append(Vector3i(123, 0, 123))
	var encoded: Dictionary = Model.SaveCodec.encode_capture(frozen)
	var decoded: Dictionary = Model.SaveCodec._decode(encoded.inventories, {})
	var refs := {}
	for key in decoded:
		var item = game.model.Inventory.new()
		item.amounts = decoded[key].amounts
		refs[key] = item
	var state: Dictionary = Model.SaveCodec._decode(encoded.world, refs)
	check(state.stores[cell].count("food") == count, "Captured inventory is isolated")
	check(state.workers[0].job.source == state.stores[cell], "Shared source inventory identity survives capture")
	check(state.workers[0].job.labour.applied_seconds == 0.0, "Captured labour cannot advance on the worker")
	check(state.workers[0].route.size() + 1 == worker.route.size(), "Captured routes cannot grow with the live model")
	worker.route.pop_back()
	worker.job = {}
	inventory.amounts.food = count
	game.model.time = 50
	check(game.autosave(), "Queue a save immediately before a menu transition")
	game.model.time = 51
	await game._open_menu()
	check(game.saves.read_slot(0).elapsed == 51, "Menu return drains the older save and writes the latest state")
	game._resume_game()
	game.model.time = 60
	check(game.autosave(), "Queue an in-flight write before slot deletion")
	await game._delete_slot(0)
	check(not game.saves.occupied(0) and not game.autosave_worker.busy() and not game.session_started, "Deleting a slot cannot be undone by a late background write")
	game.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: five-minute scheduling, frozen snapshots, nonblocking saves, ordered menu writes and deletion")
	quit(int(not failures.is_empty()))
