extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Soil = preload("res://scripts/settlement/soil_surface.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func fixture(seed_: int, difficulty: String):
	var world = Model.new()
	world.world_seed = seed_; world.difficulty = difficulty; world.soil_enabled = true
	for x in range(20, 70):
		for z in range(20, 70):
			var cell := Vector3i(x, 0, z)
			world.ground[cell] = true
			world.soil_shapes[cell] = [0.2, 0.2, 0.2, 0.2, 0.1]
	return world
func _initialize() -> void:
	for seed_ in [1409, 42, 8123]:
		var sand = fixture(seed_, "normal")
		Soil.add_hollows(sand, sand.ground)
		check(sand.water_sources.size() > 450 and sand.water_sources.size() < 800, "Sand retains roughly one quarter of eligible hollows")
		var streamed = fixture(seed_, "normal")
		var first := {}; var second := {}
		for cell: Vector3i in streamed.ground:
			if cell.x < 45: first[cell] = true
			else: second[cell] = true
		Soil.add_hollows(streamed, second); Soil.add_hollows(streamed, first)
		check(sand.water_sources.keys().all(func(cell): return streamed.water_sources.has(cell)) and sand.water_sources.size() == streamed.water_sources.size(), "Chunk order preserves puddle distribution")
		var easy = fixture(seed_, "easy")
		Soil.add_hollows(easy, easy.ground)
		check(easy.water_sources.size() == 2500, "Easy terrain retains all eligible rain hollows")
		var retained: Vector3i = sand.water_sources.keys()[0]
		sand.water_sources[retained].inventory.store("water", 2)
		Soil.add_hollows(sand, sand.ground)
		check(sand.water_sources[retained].inventory.count("water") == 2, "Generation never removes or empties existing puddles")
	var world = Model.new(); world.setup()
	var reduced: int = world.water_sources.size()
	check(world.water_sources.has(Vector3i(-8, 0, 0)), "Guaranteed opening puddle remains")
	# On the same Sand terrain, bypass only the new thinning to measure its effect.
	world.difficulty = "easy"
	Soil.add_hollows(world, world.ground)
	check(world.water_sources.size() > reduced, "Actual Sand generation contains fewer rain puddles")
	print("Sand sources: %d after thinning, %d with all natural hollows" % [reduced, world.water_sources.size()])
	print("PASS: Sand rain puddle density, deterministic streaming and existing water" if failures.is_empty() else "FAIL: Sand puddle density")
	quit(int(not failures.is_empty()))
