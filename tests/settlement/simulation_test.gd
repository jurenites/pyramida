extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func run_for(model, seconds: float) -> void:
	for index in ceili(seconds / 0.05):
		model.tick(0.05)

func fresh():
	var model = Model.new()
	model.setup()
	preload("res://tests/settlement/terrace_fixture.gd").add_to(model)
	# Hauling fixtures need the dedicated destinations required by live play.
	model.buildings[Vector3i(0, 0, -4)] = {"kind": "house", "direction": 0}
	model.buildings[Vector3i(4, 0, 4)] = {"kind": "log_shed", "direction": 0}
	model.add_store(Vector3i(4, 0, 4))
	model.rebuild_navigation()
	return model

func _initialize() -> void:
	test_navigation()
	test_reservations()
	test_construction_and_food()
	test_disconnected_delivery()
	test_replacement_stairs()
	test_nearest_storage()
	test_new_floor_and_stairs()
	test_local_stockpile()
	test_save_mid_delivery()
	test_corrupt_save()
	test_snapshot_during_work()
	if failures.is_empty():
		print("PASS: %d vertical settlement checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func test_navigation() -> void:
	var nav = Navigation.new()
	var surfaces := {}
	for x in range(-2, 3): surfaces[Vector3i(x, 0, 0)] = true
	for x in range(0, 3): surfaces[Vector3i(x, 1, 0)] = true
	nav.rebuild(surfaces, {})
	check(nav.route(Vector3i.ZERO, Vector3i.UP).is_empty(), "Overlapping floors must not connect vertically")
	nav.rebuild(surfaces, {Vector3i.ZERO: 0})
	check(nav.route(Vector3i.ZERO, Vector3i.UP).size() == 6, "Stairs connect the two distinct floors")
	check(nav.route(Vector3i.UP, Vector3i.ZERO).size() == 6, "Stairs are bidirectional")
	nav.rebuild(surfaces, {})
	check(nav.route(Vector3i.UP, Vector3i.ZERO).is_empty(), "Removing stairs invalidates the route")

func test_reservations() -> void:
	var inventory = Inventory.new()
	inventory.capacity = 1
	check(inventory.store("log"), "Initial inventory accepts a log")
	check(inventory.reserve(1, "log"), "First worker reserves the log")
	check(not inventory.reserve(2, "log"), "Second worker cannot double reserve")
	check(inventory.count("log") == 1, "Reservation must not consume material")
	check(inventory.pickup(1) == "log" and inventory.count("log") == 0, "Pickup transfers exactly one log")
	check(inventory.pickup(1).is_empty(), "A reservation cannot be picked up twice")
	check(inventory.store("food") and not inventory.store("log"), "Capacity blocks overfilling")

func test_construction_and_food() -> void:
	var model = fresh()
	var reached_upper := false
	var cut_tree := false
	for index in 1600:
		model.tick(0.05)
		cut_tree = cut_tree or model.trees.values().any(func(tree): return tree.inventory.count("log") < 3)
		for worker in model.workers:
			if worker.position.y > Navigation.LEVEL_HEIGHT - 0.1 and worker.cargo == "log":
				reached_upper = true
	check(reached_upper, "A real worker carries timber to the upper floor")
	check(model.platforms.has(Vector3i(4, 1, 0)), "Four delivered logs complete the upper platform")
	check(model.plans.is_empty(), "Completed plans leave no outstanding reservations")
	check(model.deliveries >= 5, "Workers also deliver water to the rooftop garden")
	run_for(model, 180)
	check(model.meals_eaten > 5, "Renewable gardens produce meals beyond initial food supply")
	check(cut_tree, "Timber production consumes the actual tree stock")

func test_disconnected_delivery() -> void:
	var model = fresh()
	for worker in model.workers:
		worker.cell = Vector3i(-6, 0, 2)
		worker.position = Navigation.point(worker.cell)
	model.tick(0.05)
	model.tick(0.05)
	check(model.workers[0].cargo == "log", "Worker has picked up construction cargo")
	model.stairs.clear()
	model.rebuild_navigation()
	run_for(model, 30)
	check(not model.platforms.has(Vector3i(4, 1, 0)), "Disconnected sites cannot complete through walls")
	check(model.workers[0].cargo == "log", "Blocked worker retains their material")
	model.stairs[Vector3i(-2, 0, 0)] = 0
	model.rebuild_navigation()
	run_for(model, 65)
	check(model.platforms.has(Vector3i(4, 1, 0)), "Restoring a connector resumes delivery without reissuing orders")

func test_nearest_storage() -> void:
	var model = fresh()
	model.plans.clear()
	model.gardens.clear()
	model.trees.clear()
	model.add_store(Vector3i(2, 1, 0), {"log": 8})
	model.request_build("platform", Vector3i(4, 1, 0))
	var worker: Dictionary = model.workers[0]
	worker.cell = Vector3i(0, 1, 0)
	worker.position = Navigation.point(worker.cell)
	model.tick(0.05)
	check(worker.job.source == model.stores[Vector3i(2, 1, 0)], "Delivery selects a nearby reachable stockpile, not a global starting pile")

func test_new_floor_and_stairs() -> void:
	var model = fresh()
	model.plans.clear()
	check(not model.request_build("platform", Vector3i(6, 2, 6)), "Unsupported platforms are rejected")
	check(model.request_build("platform", Vector3i(4, 1, 0)), "Lower approach A is built behind ladder B")
	check(model.request_build("platform", Vector3i(0, 2, 0)), "A supported upper floor can be constructed from below")
	run_for(model, 80)
	check(model.platforms.has(Vector3i(0, 2, 0)), "Second-level platform completes")
	check(model.navigation.route(Vector3i.ZERO, Vector3i(0, 2, 0)).is_empty(), "A new platform alone does not magically provide access")
	check(model.request_build("stairs", Vector3i(2, 1, 0), 2), "Rotated stairs can target the upper deck")
	run_for(model, 80)
	check(not model.navigation.route(Vector3i.ZERO, Vector3i(0, 2, 0)).is_empty(), "Completed stairs make the second storey reachable")

func test_save_mid_delivery() -> void:
	var model = fresh()
	run_for(model, 4.0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	var restored = Model.new()
	check(restored.restore(data), "JSON snapshot restores the settlement")
	check(restored.resource_total("log") == model.resource_total("log"), "Save retains stock counts")
	for index in 3:
		check(restored.workers[index].cargo == model.workers[index].cargo, "Save retains carried material")
		check(restored.workers[index].position.is_equal_approx(model.workers[index].position), "Save retains precise worker position")
	run_for(model, 90)
	run_for(restored, 90)
	check(restored.platforms == model.platforms, "Restored construction finishes identically")
	check(restored.resource_total("log") == model.resource_total("log"), "Restored jobs neither duplicate nor lose timber")
	check(restored.deliveries == model.deliveries, "Restored delivery schedule matches uninterrupted simulation")
	check(not restored.restore({"version": 999}), "Unknown save format is rejected")

func test_replacement_stairs() -> void:
	var model = fresh()
	for worker in model.workers:
		worker.cell = Vector3i(-6, 0, 2)
		worker.position = Navigation.point(worker.cell)
	model.tick(0.05)
	model.tick(0.05)
	check(model.remove_at(Vector3i(-2, 0, 0)), "Player can remove clear stairs")
	run_for(model, 12)
	check(model.request_build("stairs", Vector3i(-2, 0, 0), 0), "Player can queue replacement stairs")
	run_for(model, 100)
	check(model.stairs.has(Vector3i(-2, 0, 0)), "Blocked builders reuse carried timber to rebuild the connector")
	check(model.platforms.has(Vector3i(4, 1, 0)), "Original construction resumes after rebuilding stairs")

func test_local_stockpile() -> void:
	var model = fresh()
	model.plans.clear()
	model.gardens.clear()
	model.trees.clear()
	model.add_store(Vector3i(2, 1, 0))
	var initial: int = model.resource_total("log")
	run_for(model, 75)
	check(model.stores[Vector3i(2, 1, 0)].count("log") == 0, "Upper pile does not accept logs reserved for sheds")
	check(model.resource_total("log") == initial, "Restocking transfers timber without producing it")

func test_corrupt_save() -> void:
	var model = fresh()
	var before: int = model.resource_total("log")
	var bad := model.snapshot()
	bad.world = {"type": "map", "v": []}
	check(not model.restore(bad), "An incomplete world snapshot is rejected")
	check(model.resource_total("log") == before, "Failed restore does not alter the running world")
	bad = model.snapshot()
	bad.inventories = {"type": "map", "v": [["well", {"type": "map", "v": []}]]}
	check(not model.restore(bad), "An invalid inventory cannot enter the simulation")

func test_snapshot_during_work() -> void:
	var model = fresh()
	var captured := false
	for index in 800:
		model.tick(0.05)
		for worker in model.workers:
			if worker.job.get("phase") == "work" and worker.job.labour.applied_seconds > 0.0:
				captured = true
		if captured:
			break
	check(captured, "Test reaches real partially applied labour")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Partially applied labour restores")
	run_for(model, 100)
	run_for(restored, 100)
	check(model.deliveries == restored.deliveries and model.resource_total("log") == restored.resource_total("log"), "Restored labour neither repeats nor drops a delivery")
