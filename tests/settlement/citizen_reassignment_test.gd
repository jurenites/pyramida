extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Jobs = preload("res://scripts/settlement/job_system.gd")
const NEAR := Vector3i(-3, 0, 0)
const FAR := Vector3i(5, 0, 0)
const SITE := Vector3i(8, 1, 0)
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fixture():
	var world = Model.new()
	for x in range(-10, 13):
		for z in range(-5, 6): world.ground[Vector3i(x, 0, z)] = true
	world.workers.append({"id": 0, "cell": Vector3i.ZERO, "position": Vector3.ZERO,
		"route": [], "route_index": 0, "job": {}, "cargo": "", "status": "idle",
		"distance": 0.0, "hunger": 0.0, "role": "idle", "life_stage": "adult"})
	world.add_store(NEAR, {"log": 8})
	world.add_store(FAR, {"log": 8})
	world.exploration.reveal(Vector3.ZERO)
	world.exploration.reveal(world.Navigation.point(SITE))
	world.rebuild_navigation()
	check(world.request_build("platform", SITE), "Construction fixture is valid")
	return world

func reload(world):
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Orders and dropped goods survive JSON reload")
	return restored

func step_worker(world, count := 1) -> void:
	for index in count:
		world.workers[0].hunger = 0.0
		Jobs.clear_retry(world.workers[0])
		world.decision_candidates[0] = true
		world.tick_citizen_job(world.workers[0], 0.05)
		world.Deconstruction.cleanup(world)

func test_drop_and_pickup() -> void:
	var world = fixture()
	var worker: Dictionary = world.workers[0]
	worker.cargo = "food"
	worker.cargo_amount = 3
	check(world.order_build(0, 1), "New construction order accepts a loaded citizen")
	check(worker.cargo.is_empty() and worker.job.get("phase") == "pickup", "Unrelated cargo is dropped immediately")
	check(worker.job.get("source") == world.stores[NEAR], "First destination is the nearest material source, even when it is away from the site")
	var drop_id: int = world.next_plan_id - 1
	check(world.plans[drop_id].cell == Vector3i.ZERO and world.plans[drop_id].relocation.parts.count("food") == 3,
		"All dropped goods stay at the citizen's location")
	check(world.plans[1].reserved == 1 and world.stores[NEAR].available("log") == 7, "Construction reserves exactly one material")
	world = reload(world)
	worker = world.workers[0]
	step_worker(world, 500)
	check(world.platforms.has(SITE), "Material pickup and application complete the selected building")
	check(world.plans[drop_id].relocation.parts.count("food") == 3, "Construction does not consume unrelated dropped goods")
	world.buildings[NEAR] = {"kind": "house", "direction": 0}
	check(world.order_build(0, drop_id), "Dropped goods can be recovered with the existing salvage order")
	step_worker(world, 600)
	check(not world.plans.has(drop_id) and world.stores[NEAR].count("food") == 3, "Dropped load is fully recovered without duplication")

func test_use_carried_material() -> void:
	var world = fixture()
	var worker: Dictionary = world.workers[0]
	worker.cargo = "log"
	check(world.order_build(0, 1), "Builder accepts a carried construction material")
	check(worker.cargo == "log" and worker.job.get("phase") == "travel" and not worker.job.has("source"), "Useful cargo goes directly to the construction site")
	check(world.stores[NEAR].reservations.is_empty() and world.next_plan_id == 2, "Useful cargo creates neither a drop nor an extra pickup reservation")
	check(world.request_build("platform", Vector3i(8, 1, 3)), "Second site exists")
	check(world.order_build(0, 2), "Loaded builder can switch sites")
	check(world.plans[1].reserved == 0 and world.plans[2].reserved == 1, "Reassignment transfers the claim to the new site")
	check(world.set_role(0, "forager") and worker.cargo.is_empty(), "A different occupation drops incompatible construction cargo")
	check(world.plans[2].reserved == 0, "Changing occupations releases the construction claim")
	world = reload(world)
	check(world.order_build(0, 1) and world.workers[0].job.source == world.plans[3].relocation.parts,
		"A builder reuses nearby dropped material before walking to storage")

func test_raw_material_delivery() -> void:
	var world = fixture()
	for inventory in world.stores.values(): inventory.amounts.clear()
	world.buildings[NEAR] = {"kind": "log_shed", "direction": 0}
	var tree := Vector3i(-1, 0, 3)
	var inventory = Model.Inventory.new()
	inventory.store("log", 8)
	world.trees[tree] = {"kind": "living", "inventory": inventory, "regrowth": 0.0}
	world.rebuild_navigation()
	check(world.order_build(0, 1) and world.workers[0].job.get("kind") == "fell", "Without stock, the first trip goes straight to raw material")
	for index in 600:
		step_worker(world)
		if world.workers[0].cargo == "log": break
	step_worker(world)
	check(world.workers[0].job.get("kind") == "build" and world.workers[0].job.get("plan_id") == 1,
		"Harvested material goes directly to the assigned construction despite available storage")
	check(world.stores[NEAR].count("log") == 0, "Harvested construction material makes no storage detour")

func test_reservations_and_missing_materials() -> void:
	var world = fixture()
	var worker: Dictionary = world.workers[0]
	world.order_build(0, 1)
	check(world.set_role(0, "forager") and world.stores[NEAR].reservations.is_empty() and world.plans[1].reserved == 0,
		"Interrupting a pickup releases both source and construction reservations")
	worker.cargo = "stone"
	check(not world.order_build(0, 999) and worker.cargo == "stone" and world.next_plan_id == 2,
		"An invalid command does not drop cargo or replace the current order")
	for inventory in world.stores.values(): inventory.amounts.clear()
	check(world.order_build(0, 1) and worker.cargo.is_empty(), "Missing supplies do not prevent dropping unrelated cargo")
	check(worker.job.is_empty() and worker.route.is_empty() and worker.assigned_plan_id == 1,
		"A builder with no available materials waits without visiting the site empty-handed")
	world.stores[FAR].store("log", 1)
	step_worker(world)
	check(worker.job.get("source") == world.stores[FAR] and worker.job.get("phase") == "pickup",
		"The remembered order resumes at the material source when supplies appear")

func test_rendered_drop() -> void:
	var world = fixture()
	world.workers[0].cargo = "food"
	world.set_role(0, "builder")
	var view = preload("res://scripts/settlement/world_view.gd").new()
	root.add_child(view)
	view.setup(world)
	check(view.entity_views.has("parts:2:food:0"), "Dropped goods have a physical world visual")
	view.free()

func test_material_trip_stair_landings() -> void:
	var nav = Model.Navigation.new()
	var lower := Vector3i(-2, 0, 0)
	var upper := Vector3i(2, 2, 0)
	nav.rebuild({lower: true, Vector3i.ZERO: true, upper: true}, {Vector3i.ZERO: 0}, {}, {lower: [0.2, 0.3, 0.4, 0.3]})
	for endpoints in [[lower, upper], [upper, lower]]:
		var position: Vector3 = nav.surface_point(endpoints[0])
		var destination: Vector3 = nav.surface_point(endpoints[1])
		var distance := 0.0
		for tick in 600:
			var next: Vector3 = position.move_toward(nav.movement_target(endpoints[0], endpoints[1], position), 0.025)
			distance += position.distance_to(next)
			position = next
			if position.is_equal_approx(destination): break
		check(position.is_equal_approx(destination), "Repeated material trips reach the actual stair landing height in both directions")
		check(absf(distance - nav.edge_distance(endpoints[0], endpoints[1])) < 0.001, "Material source distance includes the actual stair rise")

func test_private_relocation_drop() -> void:
	var world = fixture()
	var worker: Dictionary = world.workers[0]
	var parts = Model.Inventory.new()
	world.plans[1].relocation = {"source": Vector3i(-6, 1, 0), "pickup_cell": Vector3i(-6, 0, 0),
		"stage": "rebuild", "parts": parts, "payload": {}, "owner": -1, "labour": Jobs.Labour.new(0.6)}
	worker.cargo = "log"
	worker.relocation_cargo = 1
	check(world.order_build(0, 1) and worker.job.get("phase") == "travel", "Reissuing the same relocation keeps its useful cargo")
	check(world.set_role(0, "forager") and worker.cargo.is_empty() and not worker.has("relocation_cargo"),
		"Relocation cargo can be dropped immediately for a different player job")
	check(world.plans[2].parts_owner == 1 and world.plans[2].relocation.parts.count("log") == 1,
		"Dropped relocation parts retain their exclusive owner")
	world = reload(world)
	worker = world.workers[0]
	check(not world.Deconstruction.assign_salvage(world, worker, world.plans[2]), "General hauling cannot consume another relocation's parts")
	check(world.order_build(0, 1) and worker.job.get("source") == world.plans[2].relocation.parts,
		"The original relocation retrieves its dropped parts from their physical location")
	step_worker(world)
	check(worker.cargo == "log" and worker.get("relocation_cargo") == 1, "Pickup restores private cargo ownership")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_drop_and_pickup()
	test_use_carried_material()
	test_raw_material_delivery()
	test_reservations_and_missing_materials()
	test_rendered_drop()
	test_material_trip_stair_landings()
	test_private_relocation_drop()
	if failures.is_empty(): print("PASS: %d citizen reassignment checks" % checks)
	for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
