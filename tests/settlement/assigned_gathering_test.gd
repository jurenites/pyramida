extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const SOURCE := Vector3i(3, 0, 0)
const STORE := Vector3i(-3, 0, 0)
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func fixture(resource: String):
	var world = Model.new()
	for x in range(-6, 7):
		for z in range(-4, 5): world.ground[Vector3i(x, 0, z)] = true
	world.workers.append({"id": 0, "cell": Vector3i.ZERO, "position": Vector3.ZERO,
		"route": [], "route_index": 0, "job": {}, "cargo": "", "status": "idle",
		"distance": 0.0, "hunger": 0.0, "role": "idle", "life_stage": "adult"})
	if resource == "grain":
		world.gardens[SOURCE] = {"water": 0, "food": 3, "growth": 0.0, "reserved": -1, "species": "grass"}
	else:
		var inventory = Model.Inventory.new()
		inventory.capacity = 3
		inventory.store(resource, 3)
		if resource == "log":
			world.trees[SOURCE] = {"kind": "living", "inventory": inventory, "regrowth": 0.0}
		else:
			world.deposits[SOURCE] = {"kind": "berry" if resource == "food" else "limestone", "inventory": inventory, "regrowth": 0.0}
	world.add_store(STORE)
	world.exploration.update(world.workers)
	world.rebuild_navigation()
	return world

func step(world, count := 1) -> void:
	for index in count:
		# Keep hunger and regrowth out of this assignment/hauling fixture.
		world.workers[0].hunger = 0.0
		world.tick(0.05)

func remaining(world, resource: String) -> int:
	if resource == "grain": return world.gardens[SOURCE].food
	if resource == "log": return world.trees[SOURCE].inventory.count(resource) if world.trees.has(SOURCE) else 0
	return world.deposits[SOURCE].inventory.count(resource)

func test_assignment(resource: String, role: String, storage: String) -> void:
	var world = fixture(resource)
	# Match right-click commands: occupation first, then travel to the resource.
	check(world.set_role(0, role) and world.order_move(0, SOURCE), "%s command is accepted" % role)
	for index in 400:
		step(world)
		if world.workers[0].cargo == resource: break
	check(world.workers[0].cargo == resource and remaining(world, resource) == 2,
		"Assigned %s travels and gathers a physical item before dedicated storage exists" % role)
	if world.workers[0].cargo != resource: return
	if resource != "stone":
		step(world, 80)
		check(world.workers[0].cargo == resource and remaining(world, resource) == 2,
			"%s holds exactly one load while storage is unavailable" % role)
		check(world.stores[STORE].total() == 0, "Incompatible pile never accepts %s" % resource)
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "%s cargo and assignment reload" % role)
	world = restored
	world.buildings[STORE] = {"kind": storage, "direction": 0}
	world.rebuild_navigation()
	for index in 500:
		step(world)
		if world.stores[STORE].count(resource) == 3: break
	check(world.stores[STORE].count(resource) == 3 and world.workers[0].cargo.is_empty(),
		"%s delivers and continues gathering after storage becomes available" % role)
	check(world.workers[0].role == role, "%s retains occupation through the full work loop" % role)

func test_storage_recovery() -> void:
	var world = fixture("log")
	world.buildings[STORE] = {"kind": "log_shed", "direction": 0}
	world.stores[STORE].capacity = 1
	world.stores[STORE].store("log")
	world.rebuild_navigation()
	world.set_role(0, "woodcutter")
	step(world, 200)
	check(world.workers[0].cargo == "log" and remaining(world, "log") == 2, "Full storage still permits one assigned load")
	world.stores[STORE].amounts.clear()
	step(world, 120)
	check(world.stores[STORE].count("log") == 1, "Freeing capacity wakes a waiting carrier")
	check(remaining(world, "log") >= 1, "Full storage never consumes unlimited resources")
	world = fixture("log")
	world.buildings[STORE] = {"kind": "log_shed", "direction": 0}
	var bridge := {}
	for cell: Vector3i in world.ground.keys():
		if cell.x == -1:
			bridge[cell] = true
			world.ground.erase(cell)
	world.rebuild_navigation()
	world.set_role(0, "woodcutter")
	step(world, 200)
	check(world.workers[0].cargo == "log" and world.stores[STORE].total() == 0,
		"Unreachable storage keeps harvested cargo with the worker")
	world.ground.merge(bridge)
	world.rebuild_navigation()
	step(world, 160)
	check(world.stores[STORE].count("log") > 0, "Reconnecting storage resumes delivery without another command")

func test_guards() -> void:
	var world = fixture("log")
	world.set_role(0, "auto")
	step(world, 100)
	check(world.workers[0].job.is_empty() and remaining(world, "log") == 3, "Automatic workers remain available when logs have no destination")
	world.set_role(0, "woodcutter")
	world.exploration = Model.Exploration.new()
	check(not world.Jobs._assign_collection(world, world.workers[0], SOURCE, "log", "fell"), "Assignment cannot gather through fog")
	world.exploration.update(world.workers)
	world.ground.erase(Vector3i.ZERO)
	world.rebuild_navigation()
	check(not world.Jobs._assign_collection(world, world.workers[0], SOURCE, "log", "fell"), "Assignment cannot gather from an unreachable source")
	world = fixture("log")
	world.set_role(0, "woodcutter")
	step(world)
	check(world.trees[SOURCE].inventory.reservations.size() == 1, "Assigned work reserves its actual source")
	world.set_role(0, "idle")
	check(world.trees[SOURCE].inventory.reservations.is_empty() and remaining(world, "log") == 3, "Cancelling assigned work releases the unharvested resource")
	world.set_role(0, "woodcutter")
	world.trees[SOURCE].inventory.amounts.clear()
	check(not world.Jobs._assign_collection(world, world.workers[0], SOURCE, "log", "fell"), "Assigned workers cannot gather depleted resources")

func _initialize() -> void:
	test_assignment("log", "woodcutter", "log_shed")
	test_assignment("food", "forager", "house")
	test_assignment("grain", "farmer", "hay_barn")
	test_assignment("stone", "miner", "stockpile")
	test_storage_recovery()
	test_guards()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: assigned gathering, missing/full storage recovery, mining, cargo saves and reservations")
	quit(int(not failures.is_empty()))
