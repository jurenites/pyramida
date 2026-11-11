extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Jobs = preload("res://scripts/settlement/job_system.gd")
const MILL := Vector3i(4, 0, 0)
const OTHER := Vector3i(0, 0, -4)
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fixture():
	var world = Model.new()
	world.setup()
	world.trees.clear()
	world.deposits.clear()
	world.water_sources.clear()
	for worker in world.workers: world.set_role(worker.id, "idle")
	world.rebuild_navigation()
	for cell in [MILL, OTHER]:
		check(world.request_build("windmill", cell), "Mill can be placed")
		world._complete_plan(world.plans[world.next_plan_id - 1])
	return world

func step(world, count := 1) -> void:
	for i in count:
		for worker in world.workers:
			worker.hunger = 0.0
			Jobs.clear_retry(worker)
			world.decision_candidates[worker.id] = true
			world.tick_citizen_job(worker, 0.05)

func reload(world):
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Loaded baker and workplace survive save/load")
	return restored

func _initialize() -> void:
	var world = fixture()
	var worker: Dictionary = world.workers[0]
	worker.cargo = "grain"
	check(world.order_workplace(0, MILL), "Assign loaded baker to chosen mill")
	check(worker.job.get("kind") == "process" and worker.job.get("phase") == "travel" and worker.job.get("target") == MILL,
		"Carried hay goes directly into milling at the selected workplace")
	check(not worker.job.has("source") and world.resource_total("grain") == 0, "No duplicate input reservation or storage detour")
	world = reload(world)
	worker = world.workers[0]
	var meals: int = world.stores[Model.STARTING_HOUSE].count("food")
	var saw_output := false
	for i in 900:
		step(world)
		if worker.cargo == "food":
			saw_output = true
			check(worker.get("cargo_food") == "bread", "Freshly milled food retains its bread appearance")
			check(worker.cargo_amount == 3, "One hay bundle produces the existing three-food batch")
			break
	check(saw_output, "Baker applies labour and turns carried hay into food")
	world = reload(world)
	for i in 600:
		step(world)
		if world.stores[Model.STARTING_HOUSE].count("food") == meals + 3: break
	check(world.stores[Model.STARTING_HOUSE].count("food") == meals + 3, "Bread is physically delivered into household food storage")
	check(world.stores[MILL].count("food") == 0, "Available household storage is preferred to leaving food at the mill")
	world.stores[Model.STARTING_HOUSE].store("grain", 1)
	for i in 100:
		step(world)
		if world.workers[0].job.get("kind") == "process": break
	check(world.workers[0].job.get("target") == MILL and world.workers[0].assigned_workplace == MILL,
		"Repeated batches retain the selected mill even with another mill available")
	world.set_role(0, "idle")
	check(not world.workers[0].has("assigned_workplace"), "Changing role releases the workplace assignment")

	world = fixture()
	worker = world.workers[0]
	worker.cargo = "grain"
	world.set_role(0, "baker")
	step(world, 2)
	check(worker.job.get("kind") == "process", "Existing loaded bakers in restock state resume production")
	var saved_job: Dictionary = worker.job.duplicate()
	check(not world.order_workplace(0, Vector3i(100, 0, 100)) and worker.job == saved_job, "Invalid workplace orders preserve the current job")

	world = fixture()
	world.buildings[MILL].mill_tier = 2
	for id in [0, 1]:
		world.workers[id].cargo = "grain"
		check(world.order_workplace(id, MILL), "Manual mill accepts a loaded operator")
	check(world.workers[0].job.work_cell != world.workers[1].job.work_cell, "Loaded operators use distinct manual-mill positions")
	for i in 1000:
		step(world)
		if world.stores[Model.STARTING_HOUSE].count("food") == 11: break
	check(world.stores[Model.STARTING_HOUSE].count("food") == 11, "Two loaded operators finish their batches and deliver six food")
	if failures.is_empty(): print("PASS: %d baker workplace checks" % checks)
	for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
