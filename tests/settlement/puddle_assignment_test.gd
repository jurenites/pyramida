extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const SOURCE := Vector3i(3, 0, 0)
const HOME := Vector3i(-3, 0, 0)
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func fixture(pots := 3):
	var world = Model.new()
	for x in range(-6, 7):
		for z in range(-4, 5): world.ground[Vector3i(x, 0, z)] = true
	world.workers.append({"id": 0, "cell": Vector3i.ZERO, "position": Vector3.ZERO, "route": [], "route_index": 0,
		"job": {}, "cargo": "", "status": "idle", "distance": 0.0, "hunger": 0.0, "role": "idle", "life_stage": "adult"})
	world.buildings[HOME] = {"kind": "house", "direction": 0}
	world.add_store(HOME, {"pottery": pots})
	world.Hydrology.populate(world, {SOURCE: "puddle"})
	world.exploration.update(world.workers)
	world.rebuild_navigation()
	return world
func step(world, ticks := 1) -> void:
	for i in ticks:
		world.time += 0.1
		world.workers[0].hunger = 0.0
		world.Jobs.prepare_decisions(world)
		world.tick_citizen_job(world.workers[0], 0.1)
func test_delivery() -> void:
	var world = fixture()
	check(world.order_collect_water(0, SOURCE), "Puddle accepts a direct citizen assignment")
	check(world.workers[0].job.get("kind") == "collect_water" and world.water_orders.is_empty(), "Assignment starts collection without creating a global water order")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Reserved water assignment saves and loads")
	world = restored
	step(world, 700)
	check(world.stores[HOME].count("water") == 3 and world.water_sources[SOURCE].inventory.count("water") == 0, "Citizen brings all three buckets into household vessels")
	check(world.workers[0].get("assigned_water_source") == SOURCE and world.workers[0].job.is_empty(), "Assignment remains at the dry puddle")
	world.stores[HOME].amounts.erase("water")
	world.water_sources[SOURCE].inventory.store("water", 2)
	step(world, 500)
	check(world.stores[HOME].count("water") == 2, "Refilled puddle resumes deliveries automatically")
	world.set_role(0, "idle")
	check(not world.workers[0].has("assigned_water_source"), "Changing occupation clears the puddle assignment")
	world.water_sources[SOURCE].inventory.store("water")
	world.order_collect_water(0, SOURCE)
	check(world.order_move(0, Vector3i(0, 0, 3)), "Move command replaces water work")
	check(not world.workers[0].has("assigned_water_source") and world.water_sources[SOURCE].inventory.reservations.is_empty() and world.water_orders.is_empty(), "Cancellation releases water without queuing work for somebody else")
func test_storage() -> void:
	var world = fixture(0)
	check(world.order_collect_water(0, SOURCE), "Water assignment can wait for vessels")
	step(world, 100)
	check(world.water_sources[SOURCE].inventory.count("water") == 3 and world.workers[0].cargo.is_empty(), "No water is taken when there is nowhere to store it")
	world.stores[HOME].store("pottery", 1)
	for i in 300:
		step(world)
		if world.workers[0].cargo == "water": break
	check(world.workers[0].cargo == "water", "Adding a vessel starts water collection")
	world.stores[HOME].store("water")
	step(world, 150)
	check(world.workers[0].cargo == "water" and world.plans.is_empty(), "Storage filled during travel keeps water in the bucket, not on the ground")
	var other := Vector3i(3, 0, 3)
	world.buildings[other] = {"kind": "house", "direction": 0}
	world.add_store(other, {"pottery": 3})
	world.rebuild_navigation()
	step(world, 650)
	check(world.stores[other].count("water") == 3 and world.workers[0].cargo.is_empty(), "Full first house redirects water to another available household")
	check(world.water_sources[SOURCE].inventory.count("water") == 0, "Physical source is consumed exactly once per bucket")
func test_guards() -> void:
	var world = fixture()
	world.workers[0].life_stage = "child"
	check(not world.order_collect_water(0, SOURCE), "Children cannot be assigned to carry water")
	world.workers[0].life_stage = "adult"
	world.exploration = Model.Exploration.new()
	check(not world.order_collect_water(0, SOURCE), "Puddle assignment cannot reveal hidden water")
	world.exploration.update(world.workers)
	for cell: Vector3i in world.ground.keys():
		if cell.x == 1: world.ground.erase(cell)
	world.rebuild_navigation()
	check(not world.order_collect_water(0, SOURCE), "Unreachable puddles reject assignment")
func test_command() -> void:
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-water-command-%d" % Time.get_ticks_usec()
	root.add_child(game); game.set_process(false)
	game.model = fixture()
	game.world.last_revision = -1
	game.world.sync(game.model, 0, -1)
	game.selected_workers.assign([0])
	var camera: Camera3D = game.rig.camera
	camera.global_position = Vector3(9, 6, 8)
	camera.look_at(Vector3(SOURCE))
	for frame in 3: await physics_frame
	var mouse := camera.unproject_position(Vector3(SOURCE) + Vector3.UP * 0.03)
	check(game.command_target_at(mouse).get("kind") == "puddle", "Right-click ray picks the puddle")
	game.command_at(mouse)
	check(game.model.workers[0].get("assigned_water_source") == SOURCE and game.model.workers[0].job.get("kind") == "collect_water", "Actual command handler starts water collection instead of movement")
	game.chunk_loader.finish(); game.free()
	await process_frame

func run() -> void:
	test_delivery(); test_storage(); test_guards()
	await test_command()
	print("PASS: %d puddle assignment, water delivery, storage recovery and persistence checks" % checks if failures.is_empty() else "FAIL: puddle assignment")
	quit(int(not failures.is_empty()))
