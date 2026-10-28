extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Move = preload("res://scripts/settlement/relocation.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
var failures: Array[String] = []
var checks := 0
const SOURCE := Vector3i(0, 0, 0)
const TARGET := Vector3i(4, 0, 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fresh():
	var world = Model.new()
	world.setup()
	world.trees.clear()
	world.deposits.clear()
	world.water_sources.clear()
	for worker in world.workers: world.set_role(worker.id, "idle")
	world.exploration.reveal(Nav.point(TARGET))
	return world

func complete(world, kind: String, cell := SOURCE) -> void:
	check(world.request_build(kind, cell), "Fixture can build " + kind)
	if world.plans.is_empty(): return
	var plan: Dictionary = world.plans.values().back()
	world._complete_plan(plan)

func advance(world, seconds: float) -> void:
	for i in ceili(seconds / 0.05): world.tick(0.05)

func reload_world(world):
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Relocation round-trips through JSON")
	return restored

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_building()
	test_reservations_and_handoff()
	test_plants()
	test_adjacent_bushes()
	test_storage_and_structure()
	test_catalog()
	await test_controls()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d relocation checks" % checks)
	quit(int(not failures.is_empty()))

func test_building() -> void:
	var world = fresh()
	complete(world, "house")
	var logs: int = world.resource_total("log")
	check(Move.request(world, SOURCE, TARGET, 2, Vector3(0.12, 0, -0.1)), "Queue move with orientation and offset")
	var id: int = world.next_plan_id - 1
	check(world.buildings.has(SOURCE) and not world.buildings.has(TARGET), "Queue leaves source standing")
	check(not world.request_build("road", TARGET), "Destination is reserved")
	check(not world.request_build("house", SOURCE + Vector3i.UP), "Cannot stack on a moving source")
	check(not Move.request(world, SOURCE, Vector3i(8, 0, 0), 0, Vector3.ZERO), "Duplicate move rejected")
	world = reload_world(world)
	check(world.order_build(0, id), "Builder accepts relocation")
	advance(world, 3)
	world = reload_world(world)
	advance(world, 90)
	check(not world.plans.has(id) and world.buildings.has(TARGET) and not world.buildings.has(SOURCE), "Worker dismantles and reconstructs")
	check(world.resource_total("log") == logs, "Rebuild consumes only recovered pieces")
	if world.buildings.has(TARGET):
		check(world.buildings[TARGET].direction == 2 and world.buildings[TARGET].placement_offset.is_equal_approx(Vector3(0.12, 0, -0.1)), "Destination preserves placement choices")
	world = reload_world(world)
	check(world.construction_materials.get(TARGET) == {"log": 5}, "Original recipe persists after relocation")
	check(world.workers.all(func(worker): return worker.get("home_cell") == TARGET), "Residents retain their home through dismantling, save/load and rebuilding")
	check(world.stores.has(TARGET) and not world.stores.has(SOURCE), "House food inventory moves with its residents")

func test_reservations_and_handoff() -> void:
	var world = fresh()
	complete(world, "house")
	world.stores.values()[0].amounts.log = 0
	Move.request(world, SOURCE, TARGET, 0, Vector3.ZERO)
	var id: int = world.next_plan_id - 1
	world.order_build(0, id)
	for i in 1200:
		world.tick(0.05)
		if world.workers[0].has("relocation_cargo"): break
	check(world.workers[0].cargo == "log", "Recovered log is physically carried")
	check(world.request_build("road", Vector3i(8, 0, 0)), "Competing construction queued")
	var other: int = world.next_plan_id - 1
	world.order_build(1, other)
	world.set_role(0, "idle")
	world = reload_world(world)
	advance(world, 12)
	check(world.resource_total("log") == 0 and world.plans[other].installed == 0, "Interrupted cargo returns to its private reserve")
	world.order_build(1, id)
	advance(world, 90)
	check(world.buildings.has(TARGET) and world.plans[other].installed == 0, "A different constructor completes the same move")

func test_plants() -> void:
	for amount in [1, 3]:
		var world = fresh()
		world.trees[SOURCE] = Chunks.entry("living", "log", 3)
		world.trees[SOURCE].inventory.amounts.log = amount
		check(Move.request(world, SOURCE, TARGET, 0, Vector3.ZERO), "Living tree or remaining trunk can be replanted")
		var id: int = world.next_plan_id - 1
		var original_seed: int = world.trees[SOURCE].appearance_seed
		world.order_build(0, id)
		for i in 500:
			world.tick(0.05)
			if world.workers[0].has("plant_plan_id"): break
		check(world.workers[0].has("plant_plan_id") and not world.trees.has(SOURCE), "Plant uprooted only after worker labour")
		world = reload_world(world)
		world.set_role(0, "idle")
		world.order_build(1, id)
		advance(world, 30)
		check(world.trees.has(TARGET) and not world.trees.has(SOURCE), "Replant survives save and worker handoff")
		if world.trees.has(TARGET):
			check(world.trees[TARGET].inventory.count("log") == amount, "Tree retains remaining trunk sections")
			check(world.trees[TARGET].appearance_seed == original_seed, "Physical replanting preserves generated shape")
	var world = fresh()
	world.soil_beds[TARGET] = {"materials": {"log": 1}}
	world.deposits[SOURCE] = Chunks.entry("berry", "food", 2)
	world.deposits[SOURCE].inventory.amounts.food = 1
	world.deposits[SOURCE].regrowth = 100.0
	Move.request(world, SOURCE, TARGET, 0, Vector3.ZERO)
	world.order_build(0, world.next_plan_id - 1)
	advance(world, 25)
	check(world.deposits.has(TARGET), "Bush replanted")
	if world.deposits.has(TARGET):
		check(world.deposits[TARGET].inventory.count("food") == 1 and world.deposits[TARGET].inventory.capacity == 2 and world.deposits[TARGET].regrowth >= 100, "Bush retains berries, capacity and growth")
		var chunk := Chunks.chunk_for(TARGET)
		Chunks.unload_chunk(world, chunk)
		world = reload_world(world)
		Chunks.load_chunk(world, chunk)
		check(world.deposits.has(TARGET) and not world.deposits.has(SOURCE), "Streaming preserves destination and never respawns the original bush")

func test_adjacent_bushes() -> void:
	var world = fresh()
	world.soil_beds[TARGET] = {"materials": {"log": 1}}
	world.soil_beds[TARGET + Vector3i(2, 0, 0)] = {"materials": {"log": 1}}
	world.deposits[SOURCE] = Chunks.entry("berry", "food", 3)
	world.deposits[TARGET] = Chunks.entry("berry", "food", 3)
	world.rebuild_navigation()
	var adjacent := TARGET + Vector3i.RIGHT
	check(not world.occupied(adjacent, "berry"), "Bushes occupy only their own land tile")
	check(world.occupied(TARGET, "berry"), "Two bushes cannot occupy the same tile")
	check(not Move.destination_error(world, SOURCE, SOURCE + Vector3i.RIGHT, 0, Vector3.ZERO).is_empty(), "A bush cannot be moved onto unprepared ground")
	check(Move.request(world, SOURCE, adjacent, 0, Vector3.ZERO), "Replant directly beside another bush")
	check(not world.build_error("berry", adjacent).is_empty(), "Pending bush reserves its own tile")
	check(world.build_error("berry", adjacent + Vector3i.RIGHT).is_empty(), "Pending bush does not reserve the neighbouring tile")
	check(world.build_error("berry", SOURCE + Vector3i.RIGHT) == "Prepared soil required", "Bare ground still needs preparation during relocation")
	check(not world.request_build("berry", adjacent + Vector3i.RIGHT), "Bushes must be replanted rather than constructed")
	world.order_build(0, world.next_plan_id - 1)
	advance(world, 30)
	check(world.deposits.has(adjacent) and world.deposits.has(TARGET) and not world.deposits.has(SOURCE), "Worker completes adjacent replanting")
	world = reload_world(world)
	check(world.deposits.has(adjacent) and world.deposits.has(TARGET), "Adjacent bushes survive saving")
	check(not world.build_error("house", adjacent + Vector3i.RIGHT).is_empty(), "Room-sized buildings still respect bush clearance")

func test_storage_and_structure() -> void:
	var world = fresh()
	complete(world, "pantry")
	world.stores[SOURCE].store("food", 7)
	Move.request(world, SOURCE, TARGET, 0, Vector3.ZERO)
	world.order_build(0, world.next_plan_id - 1)
	advance(world, 10)
	world = reload_world(world)
	for i in 2000:
		if world.plans.is_empty(): break
		world.tick(0.05)
	check(world.stores.has(TARGET) and not world.stores.has(SOURCE), "Moved storage keeps inventory identity")
	if world.stores.has(TARGET): check(world.stores[TARGET].count("food") == 7, "Stored goods preserved while packed")
	complete(world, "house", TARGET + Vector3i.UP)
	check(not Move.source_error(world, TARGET).is_empty(), "Supporting building cannot be moved")
	check(not Move.request(world, TARGET, Vector3i(30, 0, 0), 0, Vector3.ZERO), "Invalid or hidden destination rejected")

func test_controls() -> void:
	var game = preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-relocation-test-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.speed = 0
	game.model = fresh()
	complete(game.model, "house")
	game.selected_object = {"cell": SOURCE, "kind": "house", "entity_key": "building:%s" % SOURCE}
	game.hud.update(game.model, -1, 1, game.selected_object)
	check(game.hud.move_button.visible and game.hud.move_label == "Move", "Top menu arrow offers Move for a selected building")
	game.hud.move_button.pressed.emit()
	check(game.relocation_source == SOURCE and is_instance_valid(game.preview), "Arrow starts placement preview")
	game._clear_selection()
	check(game.relocation_source == null and game.model.plans.is_empty() and game.model.buildings.has(SOURCE), "Cancel preview leaves building intact")
	game.model.trees[Vector3i(8, 0, 0)] = Chunks.entry("living", "log", 3)
	game.selected_object = {"cell": Vector3i(8, 0, 0), "kind": "tree", "entity_key": "tree:(8, 0, 0)"}
	game.model.exploration.reveal(Nav.point(Vector3i(8, 0, 0)))
	game.hud.update(game.model, -1, 1, game.selected_object)
	check(game.hud.move_button.visible and game.hud.move_label == "Replant", "Trees use Replant tooltip")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_M
	key.pressed = true
	game.menu.hide()
	game._unhandled_input(key)
	check(game.relocation_source == Vector3i(8, 0, 0), "M starts tree replant placement")
	game.world.sync(game.model, 0, -1)
	game.free()

func test_catalog() -> void:
	for kind: String in Model.Catalog.COSTS:
		# Seed orders become plants, not structures with the order's kind.
		# Their growth and relocation lifecycle is covered by planting_test.gd.
		if kind in Model.Catalog.SEEDS: continue
		var world = fresh()
		var source := SOURCE + (Vector3i.UP if kind == "platform" else Vector3i.ZERO)
		var target := TARGET + (Vector3i.UP if kind == "platform" else Vector3i.ZERO)
		complete(world, kind, source)
		check(Move.request(world, source, target, 1, Vector3.ZERO), "Catalog relocation queues: " + kind)
		if world.plans.is_empty(): continue
		var id: int = world.next_plan_id - 1
		world.set_role(0, "builder")
		world.set_role(1, "builder")
		for i in 3600:
			if not world.plans.has(id): break
			world.tick(0.05)
		check(not world.plans.has(id) and Move.kind_at(world, target) == kind and Move.kind_at(world, source).is_empty(), "Two constructors relocate: " + kind)
		if kind == "stairs" and world.stairs.has(target): check(world.stairs[target] == 1, "Relocated stairs retain destination orientation")
