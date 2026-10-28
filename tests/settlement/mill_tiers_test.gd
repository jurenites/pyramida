extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/mill_view.gd")
func _initialize() -> void:
	var world = Model.new()
	world.setup()
	world.trees.clear()
	world.deposits.clear()
	world.water_sources.clear()
	world.rebuild_navigation()
	var cell := Vector3i(0, 0, -4)
	for tier in [1, 2, 3]:
		assert(world.request_build("windmill", cell), world.last_message)
		var plan: Dictionary = world.plans[world.next_plan_id - 1]
		assert(plan.mill_tier == tier)
		world._complete_plan(plan)
		assert(world.buildings[cell].mill_tier == tier)
		var restored = Model.new()
		assert(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))))
		assert(restored.buildings[cell].mill_tier == tier)
		var visual = load("res://data/settlement/windmill.tscn").instantiate()
		View.sync(visual, tier)
		assert(visual.get_node("Chair").visible == (tier == 1))
		assert(visual.get_node("ManualDrive").visible == (tier == 2))
		assert(visual.get_node("WindTower").visible == (tier == 3))
		for path in ["Bedstone", "Runner/GrindingStone"]:
			var wheel: MeshInstance3D = visual.get_node(path)
			for vertex: Vector3 in wheel.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				assert(Vector2(vertex.x, vertex.z).length() >= 0.179)
		var heading: float = visual.rotation.y
		View.animate(visual, tier, 1, true)
		assert(visual.rotation.y == heading)
		assert(visual.get_node("Runner").rotation.y > 0)
		assert(visual.get_node("Bedstone").rotation.y == 0)
		visual.free()
	assert(not world.request_build("windmill", cell))
	assert(world.construction_materials[cell] == {"stone": 2, "log": 8, "plank": 4})
	world.buildings[cell].mill_tier = 2
	world.workers[0].job = {"kind": "process", "phase": "work", "target": cell}
	assert(world.Economy.production_speed(world, cell) == 0)
	world.workers[1].job = {"kind": "process", "phase": "work", "target": cell}
	assert(world.Economy.production_speed(world, cell) == 1)
	world.workers[1].job.phase = "pickup"
	assert(world.Economy.production_speed(world, cell) == 0)
	# Real reservations allocate exactly two distinct operating positions.
	world.workers[0].job = {}
	world.workers[1].job = {}
	world.set_role(0, "baker")
	world.set_role(1, "baker")
	world.stores.values()[0].store("grain", 4)
	assert(world.Jobs._assign_recipe(world, world.workers[0], "windmill"))
	assert(world.Jobs._assign_recipe(world, world.workers[1], "windmill"))
	assert(world.workers[0].job.work_cell != world.workers[1].job.work_cell)
	assert(not world.Jobs._assign_recipe(world, world.workers[2], "windmill"))
	var crew_save = Model.new()
	assert(crew_save.restore(JSON.parse_string(JSON.stringify(world.snapshot()))))
	assert(crew_save.workers[0].job.work_cell == world.workers[0].job.work_cell)
	world.buildings[cell].mill_tier = 3
	assert(world.Economy.production_speed(world, cell) == 1.5)
	print("PASS: three mill upgrades, preserved materials, tier saves, two-person manual operation, fixed tower direction and tier silhouettes")
	quit()
