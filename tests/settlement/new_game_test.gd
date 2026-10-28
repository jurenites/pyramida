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

func run() -> void:
	var model = Model.new()
	model.setup()
	check(model.stores.size() == 1 and model.resource_total("log") == 18 and model.resource_total("food") == 5, "One supplied stockpile starts the settlement")
	check(model.buildings.is_empty() and model.platforms.is_empty() and model.stairs.is_empty() and model.wells.is_empty() and model.gardens.is_empty() and model.plans.is_empty(), "No other buildings or automatic construction start a new game")
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
	for step in 600:
		model.tick(0.05)
		check(child.job.is_empty() or child.job.kind == "eat", "Child never accepts construction, gathering, hauling or farming")
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
		check(view.body.has_node("LeftArm/PillArm") and view.body.has_node("RightLeg/PillLeg"), "All clothing variants use articulated pill limbs")
		for part in view.body.find_children("*", "MeshInstance3D", true, false):
			if part.get_meta("citizen_cloth", false):
				check(part.material_override.albedo_color == Worker.CLOTH_PALETTE[4], "Outfits use a single citizen palette colour")
	view.free()
	if failures.is_empty():
		print("PASS: stockpile-only start, two adults and a child, autonomous childhood, growth, jobs, persistence and appearance")
	else:
		for message in failures:
			printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))
