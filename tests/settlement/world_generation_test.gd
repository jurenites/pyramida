extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Hydro = preload("res://scripts/settlement/hydrology.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
func _initialize() -> void:
	var first := Generator.generate(1409)
	check(first.ground == Generator.generate(1409).ground, "Seed reproduces exact terrain")
	check(first.ground != Generator.generate(9182).ground, "Different seeds create different mountains")
	check(first.shapes.size() > 100, "Eroded bases contain sloping gravel")
	var sample := {Vector2i.ZERO: 10.0, Vector2i.RIGHT: 0.0, Vector2i.DOWN: 2.0}
	var eroded := Generator.thermal_step(sample)
	check(is_equal_approx(eroded.values().reduce(func(a, b): return a + b), 12.0), "Thermal erosion conserves sediment")
	check(eroded[Vector2i.ZERO] < 10 and eroded[Vector2i.RIGHT] > 0, "Erosion transfers material downhill")
	for seed_ in [1409, 9182, 123, 42, 79931]:
		var model = Model.new()
		model.setup(seed_)
		check(model.ground.size() == Generator.INITIAL_BOUNDS.get_area() and model.terrain_heights.values().max() > 0, "Each seed has a complete map and mountains")
		for cell: Vector3i in model.ground:
			check(cell.y >= 0 and cell.y <= 10, "Height bounded 0–10")
			if maxi(absi(cell.x), absi(cell.z)) <= Generator.SAFE_RADIUS:
				check(cell.y == 0, "Starting clearing remains level")
		check(model.terrain_ramps.is_empty(), "New worlds have no built-in terrain stairs")
		var peak := Vector3i.ZERO
		for cell: Vector3i in model.ground:
			if cell.y > peak.y:
				peak = cell
		check(model.navigation.route(Vector3i.ZERO, peak).is_empty(), "Mountains require player-built elevation access")
		check(not model.build_error("house", Vector3i(peak.x, 0, peak.z)).is_empty(), "Solid mountains reject buried construction")
		var supported_peak := false
		for candidate: Vector3i in model.ground:
			if candidate.y == peak.y and model.build_error("house", candidate).is_empty(): supported_peak = true
		check(supported_peak, "Peak has space for a fully supported building")
		for cell: Vector3i in model.water_sources:
			check(model.ground.has(cell) and model.water_sources[cell].inventory.capacity <= 3, "Water sits on terrain and stays bucket sized")
		var copy = Model.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Generated map JSON restores")
		check(copy.ground == model.ground and copy.terrain_ramps == model.terrain_ramps and copy.world_seed == seed_, "Save retains exact terrain, seed and trails")
	test_trail_movement()
	test_water()
	if failures.is_empty():
		print("PASS: %d terrain, erosion, navigation, water and migration checks" % checks)
		quit()
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
func test_water() -> void:
	var a = Model.new()
	a.setup()
	var b = Model.new()
	b.setup()
	var cell := Vector3i(-8, 0, 0)
	Hydro.tick(a, 70)
	for index in 280:
		Hydro.tick(b, 0.25)
	check(a.weather == b.weather and a.water_sources[cell].inventory.count("water") == 1, "Evaporation is independent of tick rate")
	check(a.water_sources[cell].inventory.reserve(0, "water"), "Citizen reserves last bucket")
	Hydro.tick(a, 19)
	check(a.water_sources[cell].inventory.available("water") == 0 and a.water_sources[cell].inventory.count("water") == 1, "Reserved bucket survives drying")
	Hydro.tick(a, 15)
	check(a.weather.raining and a.water_sources[cell].inventory.count("water") == 3, "Rain replenishes puddle without overflow")
	a.water_sources[cell].inventory.release(0)
	var save = Model.new()
	check(save.restore(JSON.parse_string(JSON.stringify(a.snapshot()))) and save.weather == a.weather, "Rain phase survives save")
	var model = Model.new()
	model.setup()
	model.plans.clear()
	model.gardens.clear()
	check(model.request_collect_water(cell), "Player can order collection")
	for index in 600:
		model.tick(0.05)
	check(model.resource_total("water") == 3 and model.water_sources[cell].inventory.count("water") == 0, "Three real buckets hauled to storage, source exhausted")
	check(not model.request_collect_water(cell), "Dry source cannot produce extra water")
	# Save during collection: all source inventory references must survive JSON.
	var carrying = Model.new()
	carrying.setup()
	carrying.plans.clear()
	carrying.gardens.clear()
	carrying.request_collect_water(cell)
	carrying.tick(0.05)
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(carrying.snapshot()))), "Collection job saves mid-route")
	check(restored.workers[0].job.source == restored.water_sources[cell].inventory, "Reservation points to restored source")
	for index in 600:
		restored.tick(0.05)
	check(restored.resource_total("water") == 3, "Reloaded collection delivers each bucket once")
	# Water source is also usable by the ordinary garden scheduler.
	var garden = Model.new()
	garden.setup()
	garden.plans.clear()
	garden.wells.clear()
	garden.gardens[Vector3i(2, 0, 2)] = {"water": 0, "growth": 0.0, "food": 0, "reserved": -1}
	for index in 500:
		garden.tick(0.05)
	check(garden.gardens.values()[0].water == 1, "Gardener draws from reachable surface water")
	var legacy := model.snapshot()
	legacy.version = 2
	var old = Model.new()
	check(old.restore(legacy) and old.water_sources.is_empty() and old.terrain_ramps.is_empty(), "Older save loads without inserting new sources or trails")
	var bad := a.snapshot()
	for pair: Array in bad.world.v:
		if pair[0] == "weather":
			pair[1] = null
	var before: Dictionary = save.ground.duplicate()
	check(not save.restore(bad) and save.ground == before, "Malformed terrain metadata rejected atomically")

func test_trail_movement() -> void:
	var nav = Nav.new()
	var lower := Vector3i.ZERO
	var upper := Vector3i(2, 1, 0)
	nav.rebuild({lower: true, upper: true}, {}, {lower: upper})
	for pair in [[lower, upper], [upper, lower]]:
		var position := Nav.point(pair[0])
		var travelled := 0.0
		for step in 100:
			var previous := position
			position = position.move_toward(nav.movement_target(pair[0], pair[1], position), 0.07)
			travelled += previous.distance_to(position)
			check(position.x < 1.0 or position.y >= Nav.LEVEL_HEIGHT - 0.001, "Citizen crosses cliff lip above solid rock")
		check(position.is_equal_approx(Nav.point(pair[1])), "Terrain step completes in both directions")
		check(is_equal_approx(travelled, nav.edge_distance(pair[0], pair[1])), "Pathfinding cost matches actual trail travel distance")
