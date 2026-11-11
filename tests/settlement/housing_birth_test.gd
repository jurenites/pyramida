extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Balance = preload("res://scripts/settlement/balance.gd")
const HOME := Vector3i.ZERO
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func fresh():
	var world = Model.new()
	world.setup()
	world.workers.resize(1)
	world.trees.clear()
	world.deposits.clear()
	world.vines.clear()
	world.water_sources.clear()
	for inventory in world.stores.values(): inventory.amounts.clear()
	for worker in world.workers:
		if world.can_control(worker): world.set_role(worker.id, "idle")
	world.rebuild_navigation()
	return world

func reload_world(world):
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Housing and birth progress round-trip")
	return restored

func test_completion_and_empty_food() -> void:
	var world = fresh()
	var interval: float = Balance.number("birth_interval_seconds")
	Economy.tick(world, interval)
	check(world.workers.size() == 1 and world.birth_clock == 0.0, "Full starting house cannot grow")
	if not world.request_build("house", HOME):
		check(false, "New house can be planned: " + world.last_message)
		return
	var id: int = world.next_plan_id - 1
	Economy.tick(world, interval)
	check(world.workers.size() == 1 and world.birth_clock == 0.0, "Unfinished house grants no birth progress")
	check(world.debug_finish_plan(id), "Complete the actual house plan")
	check(Economy.capacity(world) == 2, "Completion adds one resident place")
	# Exercise the normal simulation tick, including hunger and citizen jobs.
	for step in 60: world.tick(1.0)
	check(world.birth_clock == 60.0 and world.workers.size() == 1, "Empty stores do not pause births or skip the interval")
	world = reload_world(world)
	check(world.birth_clock == 60.0, "Reload preserves partial birth progress without food")
	for step in 60: world.tick(1.0)
	check(world.workers.size() == 2, "First child arrives after 120 seconds without food")
	if world.workers.size() != 2: return
	var child: Dictionary = world.workers.back()
	check(child.life_stage == "child" and not world.can_control(child), "New arrival remains a non-working child")
	check(child.home_cell == HOME and world.navigation.walkable(child.cell), "Child belongs to the new house and spawns at walkable access")
	check(world.resource_total("food") == 0, "Birth neither needs nor invents food")
	world = reload_world(world)
	check(world.workers.size() == 2 and world.workers.back().home_cell == HOME, "New child and home survive reload")
	for birth in 2: Economy.tick(world, interval)
	check(world.workers.size() == 2 and world.Houses.room_occupancy(world, HOME) == 1, "No further births in the occupied single-person room")
	Economy.tick(world, interval * 2.0)
	check(world.workers.size() == 2 and world.birth_clock == 0.0, "Growth stops at completed housing capacity")

func test_unreachable_house() -> void:
	var world = fresh()
	var isolated := Vector3i(100, 0, 100)
	world.ground[isolated] = true
	world.buildings[isolated] = {"kind": "house", "direction": 0}
	world.rebuild_navigation()
	for worker in world.workers:
		check(world.navigation.route(worker.cell, isolated).is_empty(), "Isolated house has no route")
	world.birth_clock = 45.0
	Economy.tick(world, Balance.number("birth_interval_seconds"))
	check(world.workers.size() == 1 and world.birth_clock == 45.0, "Unreachable spare housing pauses existing progress")

func run() -> void:
	test_completion_and_empty_food()
	test_unreachable_house()
	if failures.is_empty(): print("PASS: %d housing birth, empty food, access and persistence checks" % checks)
	for message in failures: printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))
