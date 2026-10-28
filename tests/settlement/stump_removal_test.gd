extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
const CELL := Vector3i(-8, 0, -4)
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void: call_deferred("run")

func fresh():
	var model = Model.new()
	model.setup()
	model.exploration.reveal(Model.Navigation.point(CELL))
	for worker in model.workers: model.set_role(worker.id, "idle")
	return model

func test_legacy() -> void:
	for kind in ["living", "dead", "palm"]:
		var model = fresh()
		var tree: Dictionary = model.trees[CELL]
		tree.kind = kind
		check(not model.remove_stump(CELL), "Standing %s remains harvestable" % kind)
		tree.inventory.amounts.log = 1
		check(not model.remove_stump(CELL), "Partial trunk remains harvestable")
		tree.inventory.amounts.clear()
		tree.seed_growth = 0.5
		var restored = Model.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) and restored.trees.has(CELL), "Empty seedling survives loading")
		check(restored.Relocation.source_error(restored, CELL).is_empty(), "Seedling retains replanting")
		tree.seed_growth = 1.0
		check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) and not restored.trees.has(CELL), "Old %s stump disappears on loading" % kind)
		check(not restored.navigation.blocked.has(CELL) and restored.build_error("house", CELL).is_empty(), "Old stump no longer blocks navigation or building")
		Chunks.unload_chunk(model, Chunks.chunk_for(CELL))
		check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Old dormant stump save loads")
		Chunks.load_chunk(restored, Chunks.chunk_for(CELL))
		check(not restored.trees.has(CELL) and not restored.navigation.blocked.has(CELL), "Old dormant stump disappears when chunk loads")

func harvest_last(model, kind: String) -> void:
	for cell in model.trees.keys():
		if cell != CELL: model.trees.erase(cell)
	model.trees[CELL].kind = kind
	model.trees[CELL].inventory.amounts.log = 1
	model.deposits.clear()
	model.buildings[Vector3i(-6, 0, 2)] = {"kind": "log_shed", "direction": 0}
	for inventory in model.stores.values(): inventory.amounts.clear()
	model.rebuild_navigation()
	model.set_role(0, "woodcutter")
	for tick in 1000:
		model.tick(0.05)
		if model.workers[0].cargo == "log": break

func test_carrier() -> void:
	for kind in ["living", "dead", "palm"]:
		var model = fresh()
		harvest_last(model, kind)
		check(model.workers[0].cargo == "log" and not model.trees.has(CELL), "Final %s cut removes tree while worker carries its log" % kind)
		check(not model.navigation.blocked.has(CELL) and model.build_error("house", CELL).is_empty(), "Final cut frees navigation and construction")
		var before: int = model.resource_total("log")
		var restored = Model.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Carrier saves without dangling tree inventory")
		for tick in 1000:
			restored.tick(0.05)
			if restored.workers[0].cargo.is_empty(): break
		check(restored.resource_total("log") == before + 1, "Final log reaches storage exactly once")
		Chunks.unload_chunk(restored, Chunks.chunk_for(CELL))
		Chunks.load_chunk(restored, Chunks.chunk_for(CELL))
		check(not restored.trees.has(CELL), "Harvested tree stays absent after save and chunk reload")

func test_selection() -> void:
	var game = preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-stump-actions-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.model = fresh()
	game.selected_object = {"cell": CELL, "kind": "tree", "entity_key": "tree:%s" % CELL}
	game.world.sync(game.model, 0, -1)
	check(game.world.entity_views.has("tree:%s" % CELL), "Standing tree has geometry and picking collider")
	harvest_last(game.model, "living")
	game._process(0.0)
	check(not game.world.entity_views.has("tree:%s" % CELL), "Final cut removes geometry and picking collider")
	check(game.selected_object.is_empty() and not game.hud.selection_toolbar.visible, "Harvest clears selection and contextual actions")
	game.free()

func run() -> void:
	test_legacy()
	test_carrier()
	test_selection()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d automatic tree removal, carrier, persistence and UI checks" % checks)
	quit(int(not failures.is_empty()))
