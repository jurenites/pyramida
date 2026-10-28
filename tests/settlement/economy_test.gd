extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Jobs = preload("res://scripts/settlement/job_system.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func run_for(world, seconds: float) -> void:
	for i in ceili(seconds / 0.1): world.tick(0.1)
func fresh():
	var world = Model.new()
	world.setup()
	for worker in world.workers: worker.role = "idle"
	# Economy fixtures operate on known deposits; fog behavior has its own suite.
	for cell: Vector3i in world.deposits: world.exploration.reveal(Jobs.Navigation.point(cell))
	return world
func complete(world, kind: String, cell: Vector3i) -> void:
	check(world.request_build(kind, cell), "Can plan " + kind)
	if world.plans.has(world.next_plan_id - 1): world._complete_plan(world.plans[world.next_plan_id - 1])
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	test_roads()
	test_food_chain()
	test_materials()
	test_population_and_school()
	test_commands_and_save()
	test_retired_monument_saves()
	await test_views()
	if failures.is_empty(): print("PASS: %d peaceful economy, production, progression and persistence checks" % checks)
	for message in failures: printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))
func test_food_chain() -> void:
	var world = fresh()
	complete(world, "house", Vector3i(4, 0, 0))
	# The guaranteed wild vine borders this field footprint; isolate production.
	world.vines.clear()
	var field := Vector3i(-4, 0, -4)
	complete(world, "hay_field", field)
	check(not Economy.irrigated(world, field), "Distant field is not silently irrigated")
	world.request_build("well", Vector3i(-4, 0, -6))
	check(not Economy.irrigated(world, field), "Unbuilt well cannot irrigate")
	world._complete_plan(world.plans[world.next_plan_id - 1])
	check(Economy.irrigated(world, field), "Completed same-floor well irrigates nearby fields")
	check(not Economy.irrigated(world, field + Vector3i.UP), "Irrigation does not jump floors")
	complete(world, "hay_barn", Vector3i(-4, 0, 0))
	complete(world, "windmill", Vector3i(0, 0, 0))
	world.set_role(0, "farmer")
	world.set_role(1, "baker")
	run_for(world, 160)
	check(world.meals_eaten > 5, "Field and mill feed family beyond initial meals")
	check(world.resource_total("food") > 0, "Baker delivers bread physically")
	check(Economy.field_resource(world, field) == "grain", "Hay fields produce grain, not ready-to-eat food")
	check(world.stores[Vector3i(-4, 0, 0)].count("log") == 0, "Hay barn does not fill with automatic timber transfers")
	check(not Economy.accepts(world, Vector3i(-4, 0, 0), "food"), "Hay barn stores grain separately from meals")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Save restores production jobs and new resource inventories")
	run_for(world, 40)
	run_for(restored, 40)
	check(world.resource_total("food") == restored.resource_total("food") and world.meals_eaten == restored.meals_eaten, "Reloaded production matches uninterrupted run")
func test_materials() -> void:
	var world = fresh()
	complete(world, "sawmill", Vector3i(-4, 0, 0))
	complete(world, "log_shed", Vector3i(-6, 0, 0))
	world.set_role(0, "sawyer")
	run_for(world, 50)
	check(world.resource_total("plank") > 0 and world.resource_total("log") < 18, "Sawyer consumes timber to produce planks")
	world.set_role(0, "builder")
	world.stores[Vector3i(-6, 0, 2)].store("stone", 2)
	check(world.request_build("windmill", Vector3i(-2, 0, 0)), "Queue the tier-one stone mill")
	run_for(world, 80)
	check(world.buildings.has(Vector3i(-2, 0, 0)), "Builder delivers the millstones from the pile")
	complete(world, "mine_camp", Vector3i(12, 0, 6))
	complete(world, "masonry", Vector3i(10, 0, 6))
	# Mining requires a discovered deposit now that citizen exploration is used.
	check(world.order_move(0, Vector3i(14, 0, 6)), "Scout the quarry before assigning mining")
	run_for(world, 20)
	world.set_role(0, "miner")
	world.set_role(1, "mason")
	run_for(world, 180)
	check(world.resource_total("block") > 0, "Mining and masonry produce dressed stone")
	check(world.deposits.values().any(func(deposit): return deposit.kind == "limestone" and deposit.inventory.count("stone") < deposit.inventory.capacity), "Mining consumes actual finite limestone")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Mining progress persists")
	check(restored.resource_total("block") == world.resource_total("block"), "Dressed blocks survive reload")
	check(Economy.work_speed(world) == 1.0, "No bonus without workshop")
	complete(world, "workshop", Vector3i(4, 0, 0))
	check(Economy.work_speed(world) == 1.5, "Workshop grants verified 1.5x work bonus")
	complete(world, "workshop", Vector3i(4, 0, 2))
	check(Economy.work_speed(world) == 1.5, "Workshop bonus does not stack")
func test_population_and_school() -> void:
	var world = fresh()
	complete(world, "house", Vector3i(-2, 0, 0))
	complete(world, "house", Vector3i(0, 0, 0))
	world.stores[Vector3i(-6, 0, 2)].capacity = 500
	world.stores[Vector3i(-6, 0, 2)].store("food", 120)
	run_for(world, 125)
	check(world.workers.size() == 4 and not world.can_control(world.workers[3]), "House and steady food reserve permit a new child")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Save is not limited to the original three citizens")
	check(restored.workers.size() == 4, "Expanded population reloads")
	complete(world, "school", Vector3i(2, 0, 0))
	var before: float = world.workers[2].growth_seconds
	world.tick(1.0)
	check(is_equal_approx(world.workers[2].growth_seconds - before, 2.0), "School doubles child maturation")
	check(Economy.capacity(world) == 6, "Each completed house adds three places")
func test_commands_and_save() -> void:
	var world = fresh()
	check(not world.set_role(2, "miner"), "Children cannot be assigned jobs")
	complete(world, "house", Vector3i(0, 0, 0))
	world.set_role(0, "forager")
	world.tick(0.1)
	check(world.workers[0].job.kind == "gather", "Right-click role can reserve berries")
	var source = world.workers[0].job.source
	world.set_role(0, "builder")
	check(source.reservations.is_empty(), "Changing jobs releases resource claim")
	world.set_role(0, "forager")
	for i in 300:
		world.tick(0.1)
		if world.workers[0].cargo == "food": break
	check(world.workers[0].cargo == "food", "Forager physically carries harvested food")
	world.set_role(0, "idle")
	check(world.workers[0].cargo == "food" and world.workers[0].job.phase == "store", "Reassignment keeps already-carried resources")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Reassigned carrier reloads")
func test_retired_monument_saves() -> void:
	const Codec = preload("res://scripts/settlement/save_codec.gd")
	var world = fresh()
	check(not world.set_role(0, "monument"), "Retired monument role cannot be assigned")
	check(not world.snapshot().world.v.any(func(pair): return pair[0] == "monument"), "New saves contain no monument")
	var store = world.stores[Vector3i(-6, 0, 2)]
	store.store("block", 2)
	store.reserve(0, "block")
	for id in 2:
		var worker: Dictionary = world.workers[id]
		worker.role = "monument"
		worker.route = [worker.cell, Vector3i.ZERO]
		worker.job = {"kind": "monument", "phase": "pickup" if id == 0 else "work", "target": Vector3i.ZERO,
			"source": store, "labour": Jobs.Labour.new(4.0)}
	world.workers[1].cargo = "block"
	var legacy := world.snapshot()
	legacy.world.v.append(["monument", Codec._encode({"cell": Vector3i(4, 0, 0), "discovered": true, "active": true,
		"installed": 12, "required": 40, "reserved": 2}, {})])
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(legacy))), "Legacy active monument save loads")
	check(restored.workers[0].job.is_empty() and restored.workers[0].route.is_empty(), "Retired pickup job and route are cleared")
	check(restored.stores[Vector3i(-6, 0, 2)].reservations.is_empty(), "Retired block reservation is released")
	check(restored.workers[1].cargo == "block" and restored.workers[1].job.phase == "store", "Carried block returns to storage")
	check(restored.workers[0].role == "auto" and restored.workers[1].role == "auto", "Retired builders return to automatic work")
	check(restored.request_build("house", Vector3i(4, 0, 0)), "Former monument site is available for construction")
	for worker in restored.workers: worker.role = "idle"
	run_for(restored, 20)
	check(restored.workers[1].cargo.is_empty() and restored.resource_total("block") == 3, "Retired delivery preserves all blocks")
	var reloaded = Model.new()
	check(reloaded.restore(JSON.parse_string(JSON.stringify(restored.snapshot()))), "Migrated save reloads without monument data")
	var bad := legacy.duplicate(true)
	for pair: Array in bad.world.v:
		if pair[0] == "monument":
			for entry: Array in pair[1].v:
				if entry[0] == "installed": entry[1] = 999
	check(not reloaded.restore(bad), "Malformed legacy monument progress is still rejected")
func test_views() -> void:
	var world = fresh()
	var view = View.new()
	root.add_child(view)
	view.setup(world)
	view.sync(world, 0, -1)
	check(not view.entity_views.has("monument"), "New world has no monument view or collider")
	for resource in Economy.RESOURCES:
		world.workers[0].cargo = resource
		view.sync(world, 0, 0)
		check(is_instance_valid(view.actors[0].cargo), "Distinct valid cargo mesh for " + resource)
	world.workers[0].cargo = ""
	var child: Dictionary = world.workers[2].duplicate(true)
	child.id = 3
	world.workers.append(child)
	view.sync(world, 0, -1)
	check(view.actors.size() == 4, "Birth adds a render actor without reloading the scene")
	world.workers.pop_back()
	view.sync(world, 0, -1)
	check(view.actors.size() == 3, "Switching to a smaller save removes old actors")
	view.free()
	await process_frame

func test_roads() -> void:
	var nav = preload("res://scripts/settlement/navigation.gd").new()
	var ground := {}
	for x in 8:
		ground[Vector3i(x, 0, 0)] = true
		ground[Vector3i(x, 0, 1)] = true
		nav.roads[Vector3i(x, 0, 1)] = true
	nav.rebuild(ground, {})
	var route: Array[Vector3i] = nav.route(Vector3i.ZERO, Vector3i(7, 0, 0))
	check(route.any(func(cell): return cell.z == 1), "Routing takes a slightly longer road when its travel time is shorter")
	nav.roads.clear()
	nav.rebuild(ground, {})
	route = nav.route(Vector3i.ZERO, Vector3i(7, 0, 0))
	check(route.all(func(cell): return cell.z == 0), "Removing roads invalidates the preferred route")
