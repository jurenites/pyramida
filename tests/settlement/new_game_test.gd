extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Citizens = preload("res://scripts/settlement/citizen_lifecycle.gd")
const Worker = preload("res://scripts/settlement/worker_view.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func test_opening(seed_: int, difficulty: String) -> void:
	var world = Model.new()
	world.setup(seed_, difficulty)
	var home: Vector3i = Model.STARTING_HOUSE
	check(world.buildings.size() == 1 and world.buildings[home].kind == "house", "One completed house starts %s/%d" % [difficulty, seed_])
	check(world.stores.size() == 1 and world.stores[home].capacity == world.Houses.ROOM_STORAGE and world.resource_total("log") == 0, "House replaces the supplied log pile")
	check(world.Houses.totals(world, home).residents == 1 and world.Economy.capacity(world) == 1 and world.workers.size() == 3, "One resident place without deleting the starting family")
	var copy = Model.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Opening household saves and reloads")
	check(copy.buildings == world.buildings and copy.Houses.totals(copy, home) == world.Houses.totals(world, home), "Reload preserves house, residents and meals")
	world.set_role(0, "forager")
	world.set_role(1, "idle")
	world.stores[home].amounts.food = 0
	for step in 800:
		for worker in world.workers: worker.hunger = 0.0
		world.tick(0.05)
		if world.stores[home].count("food") == 4: break
	check(world.stores[home].count("food") > 0 and world.stores[home].count("food") <= 4 and world.deliveries > 0, "Assigned gatherer respects the four-food room limit")
	world.set_role(0, "auto")
	world.set_role(1, "auto")
	var shed := Vector3i(2, 0, 0)
	check(world.request_build("log_shed", shed), "First log shed can be planned with no stored logs")
	for step in 2400:
		for worker in world.workers: worker.hunger = 0.0
		world.tick(0.05)
		if world.buildings.has(shed) and world.stores[shed].count("log") > 0: break
	check(world.buildings.get(shed, {}).get("kind") == "log_shed", "Builders harvest and install the first shed's logs without existing storage")
	check(world.stores.has(shed) and world.stores[shed].count("log") > 0, "Chopped logs reach the completed shed")
	check(world.workers[2].job.is_empty() and world.workers[2].cargo.is_empty(), "Opening construction and gathering remain adult work")

func run() -> void:
	for difficulty in ["normal", "easy"]:
		for seed_ in [1409, 42]: test_opening(seed_, difficulty)
	var model = Model.new()
	model.setup()
	check(model.stores.size() == 1 and model.resource_total("log") == 0 and model.resource_total("food") == 4, "Opening food respects the four-food room limit")
	check(model.buildings.size() == 1 and model.platforms.is_empty() and model.stairs.is_empty() and model.wells.is_empty() and model.gardens.is_empty() and model.plans.is_empty(), "No buildings beyond the home or automatic construction start a new game")
	check(model.workers.size() == 3, "Exactly three citizens start the settlement")
	check(model.can_control(model.workers[0]) and model.can_control(model.workers[1]) and not model.can_control(model.workers[2]), "Only the two adults can be controlled")
	var child: Dictionary = model.workers[2]
	var view := Worker.new()
	root.add_child(view)
	view.setup(2)
	view.sync(child, 0, true)
	check(view.body.scale.x < 0.7 and not view.ring.visible, "Child is visibly smaller and never shows a worker selection ring")
	var initial: Vector3 = child.position
	for step in 240:
		model.tick(0.05)
	check(child.position != initial and child.distance > 0, "Child wanders autonomously")
	check(child.job.is_empty() and child.cargo.is_empty(), "Child does not perform work")
	check(model.request_build("platform", Vector3i(0, 1, 0)), "Player can start construction from an empty settlement")
	# Allow physical home deliveries and meals while the adults build.
	for step in 1200:
		model.tick(0.05)
		check(child.job.is_empty() or child.job.kind == "eat", "Child never accepts construction, gathering, hauling or farming")
		if model.platforms.has(Vector3i(0, 1, 0)): break
	check(model.platforms.has(Vector3i(0, 1, 0)), "Two adults finish the player's construction")
	check(child.hunger < 30.0, "Child independently takes a meal")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Family save loads")
	check(is_equal_approx(restored.workers[2].growth_seconds, child.growth_seconds) and restored.workers[2].appearance == child.appearance and not restored.can_control(restored.workers[2]), "Save retains childhood progress and clothing")
	var age: float = child.growth_seconds
	model.tick(0)
	check(child.growth_seconds == age, "Pause stops aging")
	check(model.request_build("garden", Vector3i(4, 0, 4)), "More work is available at growth")
	child.growth_seconds = Citizens.adulthood_seconds() - 0.1
	child.hunger = 0
	model.tick(0.05)
	check(not model.can_control(child), "Child cannot work before the age boundary")
	model.tick(0.1)
	check(model.can_control(child), "Child becomes controllable at adulthood")
	view.sync(child, 0, true)
	check(view.body.scale == Vector3.ONE and view.ring.visible, "Grown citizen gains adult proportions and selection")
	model.tick(0.05)
	check(not child.job.is_empty() and child.job.get("kind") != "eat", "Grown citizen joins the work scheduler (including food production)")
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) and restored.can_control(restored.workers[2]), "Adult transition survives reload")
	# Legacy citizens lacked these fields and must remain adults, even mid-job.
	for worker in model.workers:
		for key in ["life_stage", "growth_seconds", "appearance", "cloth_color"]:
			worker.erase(key)
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) and restored.can_control(restored.workers[2]), "Older saves preserve their adult workers")
	check(model.request_build("well", model.well), "Former demo well location is empty and buildable")
	model._complete_plan(model.plans[model.next_plan_id - 1])
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) and restored.wells[restored.well] == restored.well_inventory, "Player-built well at the legacy location preserves its shared inventory on reload")
	for variant in 4:
		view.set_appearance(variant, 4)
		check(view.body.has_node("Skeleton3D") and view.body.get_node("Surface").skin != null, "All clothing variants use a shared skinned body and clothing surface")
		for part in view.body.find_children("*", "MeshInstance3D", true, false):
			if part.has_meta("citizen_cloth_surface"):
				check(part.get_active_material(part.get_meta("citizen_cloth_surface")).albedo_color == Worker.CLOTH_PALETTE[4], "Outfits use a single citizen palette colour")
	view.free()
	if failures.is_empty():
		print("PASS: house start, berry delivery, first shed construction and log hauling, two adults and a child, growth and persistence")
	else:
		for message in failures:
			printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))
