extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	for seed_ in [1409, 9182, 123, 42, 79931]:
		var generated := Generator.generate(seed_)
		var flat := 0
		var raised := 0
		for cell: Vector3i in generated.ground:
			if cell.y == 0 and not generated.shapes.has(cell): flat += 1
			if cell.y >= 3: raised += 1
			if maxi(absi(cell.x), absi(cell.z)) <= Generator.SAFE_RADIUS:
				check(cell.y == 0 and not generated.shapes.has(cell), "Opening is flat and free of talus")
		check(float(flat) / generated.ground.size() > 0.78, "At least 78 percent of the landscape stays flat")
		check(raised > 40 and raised < 400, "Small isolated patches contain tall intact columns")
		check(generated.shapes.size() > 100, "Buttes have gravel aprons")
		check(generated == Generator.generate(seed_), "Seed reproduces every height and detail")
		for cell: Vector3i in generated.shapes:
			check(not generated.water.has(cell) and not generated.nature.has(cell), "No resources float on sloping debris")
			var corners: Array = generated.shapes[cell]
			check(corners.max() <= 2.6 and corners.min() >= 0, "Talus heights stay bounded below the solid tower")
	var model = Model.new()
	model.setup()
	model.deposits.clear()
	model.trees.clear()
	model.water_sources.clear()
	model.stores.clear()
	check(Nav.CELL_SIZE * 2 == Grid.ROOM_SIZE, "Half-grid leaves room asset dimensions intact")
	var centre := Vector3i(1, 0, 1)
	check(model.request_build("house", centre), "House can be placed at half-unit offsets on both axes")
	check(not model.request_build("house", centre + Vector3i.RIGHT), "Half-room overlap with a plan is rejected")
	model._complete_plan(model.plans[model.next_plan_id - 1])
	check(not model.request_build("house", centre + Vector3i(1, 0, 1)), "Diagonal partial overlap is rejected")
	check(model.request_build("house", centre + Vector3i(2, 0, 0)), "Touching room edges are allowed")
	model.plans.clear()
	check(model.request_build("house", centre + Grid.STOREY), "Whole roof supports a stacked room")
	model.plans.clear()
	check(not model.request_build("house", centre + Vector3i(1, 2, 0)), "Half-overhanging room needs support under its entire footprint")
	var slope: Vector3i = model.terrain_shapes.keys()[0]
	check(not model.request_build("house", slope), "Gravel apron rejects construction")
	check(model.navigation.surfaces.has(slope) and model.navigation.surface_point(slope).y > 0, "Citizens walk on gravel at its actual surface height")
	var edge := Vector3i(8, 0, 2)
	model.ground.erase(edge + Vector3i.RIGHT)
	model.rebuild_navigation()
	check(not model.request_build("house", edge), "Missing edge support rejects placement even when centre is supported")
	var house := Assets.create("house")
	for direction in 4:
		house.rotation.y = -direction * PI * 0.5
		var door: Vector3 = house.transform * house.get_node("AccessFront").position
		var expected := Vector3.BACK.rotated(Vector3.UP, house.rotation.y) * 0.95
		check(door.is_equal_approx(expected), "Door remains centred on each rotated front wall")
	house.free()
	var nav = Nav.new()
	var lower := Vector3i(-2, 0, 0)
	var upper := Vector3i(2, 2, 0)
	nav.rebuild({lower: true, Vector3i.ZERO: true, upper: true}, {Vector3i.ZERO: 0})
	check(nav.route(lower, upper).size() == 2, "Ladder retains its full room length on the finer grid")
	for pair in [[lower, upper], [upper, lower]]:
		var position := Nav.point(pair[0])
		var distance := 0.0
		for step in 600:
			var previous := position
			position = position.move_toward(nav.movement_target(pair[0], pair[1], position), 0.03)
			distance += previous.distance_to(position)
		check(position.is_equal_approx(Nav.point(pair[1])), "Ladder traverses both ways")
		check(is_equal_approx(distance, nav.edge_distance(pair[0], pair[1])), "Ladder travel matches route cost")
	var original = Model.new()
	original.setup()
	original.request_build("house", Vector3i(1, 0, 1))
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(original.snapshot()))), "Half-grid map saves and reloads")
	check(restored.ground == original.ground and same_shapes(restored.terrain_shapes, original.terrain_shapes), "Exact terrain and gravel corners survive JSON")
	check(restored.plans.values()[0].cell == Vector3i(1, 0, 1), "Half-grid construction address survives JSON")
	original.workers[0].cell = Vector3i(-4, 0, 4)
	original.workers[0].position = Vector3(-3.4, 0, 4)
	original.workers[0].route = [Vector3i(-4, 0, 4), Vector3i(-2, 0, 4), Vector3i(0, 0, 4)]
	original.workers[0].route_index = 1
	original.workers[0].job = {"kind": "move", "phase": "travel", "target": Vector3i(0, 0, 4), "labour": preload("res://scripts/applied_labour.gd").new(0.1)}
	var legacy := original.snapshot()
	legacy.version = 4
	# Build a genuine old-coordinate fixture, not a relabelled new-grid snapshot.
	legacy.world = old_addresses(legacy.world)
	for pair: Array in legacy.world.v:
		if pair[0] == "grid_version": pair[1] = 1
		if pair[0] == "level_height": pair[1] = 2.0
		if pair[0] == "terrain_shapes": pair[1] = {"type": "map", "v": []}
		if pair[0] == "ground":
			pair[1] = {"type": "map", "v": []}
			for x in range(-20, 21):
				for z in range(-20, 21): pair[1].v.append([{"type": "cell", "v": [x, 0, z]}, true])
		if pair[0] in ["plans", "water_sources", "terrain_ramps"]: pair[1] = {"type": "map", "v": []}
	var old = Model.new()
	check(old.restore(JSON.parse_string(JSON.stringify(legacy))), "Version 4 settlement migrates")
	check(old.stores.has(Vector3i(-6, 0, 2)), "Old stockpile stays at the same world position")
	check(not old.workers.is_empty() and old.workers[0].position == original.workers[0].position and old.workers[0].cell == original.workers[0].cell, "Migration preserves citizens and their world positions")
	check(old.resource_total("log") == original.resource_total("log"), "Migration preserves inventory")
	check(not old.workers.is_empty() and old.workers[0].route[old.workers[0].route_index] == Vector3i(-3, 0, 4), "Migration inserts the next half-grid waypoint for an in-flight job")
	if not old.workers.is_empty():
		for step in 80: old.tick(0.05)
		check(old.workers[0].cell == Vector3i(0, 0, 4), "Migrated travel finishes without a disconnected route")
	var invalid := original.snapshot()
	for pair: Array in invalid.world.v:
		if pair[0] == "terrain_shapes": pair[1].v[0][1] = [0, -1, 0, 0]
	check(not restored.restore(invalid) and same_shapes(restored.terrain_shapes, original.terrain_shapes), "Invalid slope save is rejected without changing live world")
	if failures.is_empty():
		print("PASS: %d butte, half-grid placement, doorway, ladder and migration checks" % checks)
		quit()
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)

func old_addresses(value: Variant) -> Variant:
	if value is Array:
		var result := []
		for item: Variant in value: result.append(old_addresses(item))
		return result
	if value is Dictionary:
		if value.get("type") == "cell":
			return {"type": "cell", "v": [int(value.v[0] / 2), int(value.v[1] / 2), int(value.v[2] / 2)]}
		var result := {}
		for key in value: result[key] = old_addresses(value[key])
		return result
	return value

func same_shapes(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for cell in a:
		if not b.has(cell): return false
		for index in 4:
			if not is_equal_approx(a[cell][index], b[cell][index]): return false
	return true
