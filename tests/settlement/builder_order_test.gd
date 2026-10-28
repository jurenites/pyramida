extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Jobs = preload("res://scripts/settlement/job_system.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func fresh():
	var model = Model.new()
	model.setup()
	for worker in model.workers:
		model.set_role(worker.id, "idle")
	model.request_build("platform", Vector3i(0, 1, 0))
	model.request_build("platform", Vector3i(4, 1, 0))
	model.workers[0].cell = Vector3i(-6, 0, 2)
	model.workers[0].position = Navigation.point(model.workers[0].cell)
	return model

func advance(model, seconds: float) -> void:
	for i in ceili(seconds / 0.05):
		model.tick(0.05)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_deliveries_and_save()
	test_meals_and_new_orders()
	test_waiting()
	test_disconnected_delivery()
	await test_player_command()
	if failures.is_empty():
		print("PASS: %d player construction order checks" % checks)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))

func test_deliveries_and_save() -> void:
	var model = fresh()
	check(model.plans.size() == 2, "Fixture has two competing construction sites")
	check(model.order_build(0, 2), "Player can assign the second construction site")
	var worker: Dictionary = model.workers[0]
	check(worker.job.get("plan_id") == 2, "First pickup reserves material for the clicked site, not the oldest plan")
	model.tick(0.05)
	check(worker.cargo == "log" and worker.job.plan_id == 2, "Pickup retains the original construction destination")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "In-flight player assignment loads from JSON")
	check(restored.workers[0].assigned_plan_id == 2 and restored.workers[0].job.plan_id == 2,
		"Save retains both the primary assignment and the current delivery")
	model = restored
	worker = model.workers[0]
	var changed_site := false
	for i in 3000:
		if not model.plans.has(2):
			break
		model.tick(0.05)
		changed_site = changed_site or (worker.job.get("kind") == "build" and worker.job.plan_id != 2)
	check(not model.plans.has(2) and model.platforms.has(Vector3i(4, 1, 0)), "All deliveries finish the player-assigned building")
	check(not changed_site and model.plans[1].installed == 0 and model.plans[1].reserved == 0,
		"Citizen never switches to the competing building before completing the order")
	check(worker.role == "builder" and worker.assigned_plan_id == -1, "Completion clears the order but preserves the builder role")
	advance(model, 60)
	check(not model.plans.has(1), "Builder automatically continues with another construction afterward")

func test_meals_and_new_orders() -> void:
	var model = fresh()
	var worker: Dictionary = model.workers[0]
	worker.hunger = 30.0
	check(model.order_build(0, 2) and worker.job.get("kind") == "eat", "Hungry builder can take a meal without forgetting the order")
	advance(model, 3)
	check(worker.assigned_plan_id == 2 and worker.job.get("plan_id") == 2, "Citizen resumes the assigned site after eating")
	check(model.order_build(0, 1) and worker.assigned_plan_id == 1, "A new construction order replaces the old assignment")
	check(model.plans[2].reserved == 0, "Reassignment releases the previous material claim")
	check(model.order_move(0, worker.cell) and worker.assigned_plan_id == -1, "An explicit move cancels the remembered order")
	model.order_build(0, 2)
	check(model.set_role(0, "woodcutter") and worker.assigned_plan_id == -1, "Changing work clears the construction order")
	check(not model.order_build(2, 1), "Children cannot receive construction orders")
	check(not model.order_build(0, 999), "Unknown sites cannot replace an existing role")
	for citizen in model.workers:
		citizen.erase("assigned_plan_id")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) and restored.workers[0].assigned_plan_id == -1,
		"Older saves without an assignment field remain compatible")

func test_waiting() -> void:
	var model = fresh()
	# Another builder has reserved every remaining delivery to the requested site.
	Jobs.claim_material(model.plans[2], "log", model.plans[2].required)
	model.order_build(0, 2)
	advance(model, 1)
	check(model.workers[0].job.is_empty() and model.workers[0].assigned_plan_id == 2 and model.plans[1].reserved == 0,
		"Reserved work does not send a player-assigned builder to another site")
	Jobs.claim_material(model.plans[2], "log", -model.plans[2].required)
	advance(model, 1)
	check(model.workers[0].job.get("plan_id") == 2, "Released work resumes the original assignment")

func test_disconnected_delivery() -> void:
	var model = fresh()
	model.platforms[Vector3i(0, 1, 0)] = true
	model.stairs[Vector3i(-2, 0, 0)] = 0
	model.rebuild_navigation()
	model.plans.erase(1)
	check(model.request_build("platform", Vector3i(0, 2, 0)), "Upper-floor assignment is valid")
	check(model.order_build(0, 3), "Citizen accepts a reachable upper-floor site")
	model.tick(0.05)
	model.stairs.clear()
	model.rebuild_navigation()
	advance(model, 3)
	var worker: Dictionary = model.workers[0]
	check(worker.cargo == "log" and worker.job.get("plan_id") == 3 and model.plans[2].reserved == 0,
		"Disconnected delivery keeps its cargo and assignment instead of switching buildings")
	model.stairs[Vector3i(-2, 0, 0)] = 0
	model.rebuild_navigation()
	advance(model, 90)
	check(model.platforms.has(Vector3i(0, 2, 0)), "Restoring access resumes and completes the original order")

func test_player_command() -> void:
	var game = preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-builder-order-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.speed = 0
	await process_frame
	for worker in game.model.workers:
		game.model.set_role(worker.id, "idle")
	game.model.request_build("platform", Vector3i(0, 1, 0))
	game.model.request_build("platform", Vector3i(4, 1, 0))
	game.model.exploration.reveal(Navigation.point(Vector3i(4, 1, 0)))
	game.world.sync(game.model, 0, -1)
	await physics_frame
	await process_frame
	game.selected_workers.assign([0, 1])
	var site: Node3D = game.world.entity_views["plan:2"]
	var mouse: Vector2 = game.rig.camera.unproject_position(site.global_position + Vector3.UP * 0.1)
	check(game.command_target_at(mouse).get("entity_key") == "plan:2", "Real ray picking resolves the selected construction site")
	game.command_at(mouse)
	for id in [0, 1]:
		var worker: Dictionary = game.model.workers[id]
		check(worker.get("assigned_plan_id") == 2 and worker.job.get("plan_id") == 2,
			"Right-click gives each selected citizen the chosen site: %d" % id)
	game.free()
