extends SceneTree
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Terrain = preload("res://scripts/settlement/terrain_mesh.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for seed_value in [1409, 9182]:
		var generated := Generator.generate_region(seed_value, Generator.INITIAL_BOUNDS)
		var shared := {}
		var shelves := {2: 0, 4: 0, 6: 0}
		for cell: Vector3i in generated.ground:
			var corners: Array = generated.shapes.get(cell, [cell.y, cell.y, cell.y, cell.y])
			if shelves.has(cell.y) and not generated.shapes.has(cell): shelves[cell.y] += 1
			for index in 4:
				var key: Vector2 = Vector2(cell.x, cell.z) + Generator.CORNERS[index]
				if shared.has(key): check(is_equal_approx(float(shared[key]), float(corners[index])), "Neighbouring terrace triangles share exact edge heights")
				shared[key] = corners[index]
			if maxi(absi(cell.x), absi(cell.z)) <= Generator.SAFE_RADIUS:
				check(cell.y == 0 and not generated.shapes.has(cell), "Opening stays flat")
		for level in shelves: check(shelves[level] > 30, "Each of the three terraces has broad level ground")
		for chunk in [Vector2i(-2, -2), Vector2i(-1, -2), Vector2i(1, 1)]:
			var streamed := Generator.generate_chunk(seed_value, chunk)
			for cell in streamed.ground:
				check(generated.ground.has(cell) and generated.shapes.get(cell, []) == streamed.shapes.get(cell, []), "Streaming reproduces the initial terrace geometry")
	var world := Model.new()
	world.setup()
	var restored := Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Elevated shoulder shapes save and restore")
	check(restored.ground == world.ground, "Saved terrace levels remain exact")
	check(restored.terrain_shapes.size() == world.terrain_shapes.size(), "Saved shoulders are retained")
	# Retained version-4 saves must also use that generator when exploring.
	world.generator_version = Generator.LEGACY_VERSION
	var legacy := Model.new()
	check(legacy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Version-4 streaming saves remain accepted")
	var distant := Vector2i(-7, 4)
	Model.Chunks.load_chunk(legacy, distant)
	var expected := Generator.generate_chunk(legacy.world_seed, distant, "normal", Generator.LEGACY_VERSION)
	for cell in expected.ground:
		check(legacy.ground.has(cell) and legacy.terrain_shapes.get(cell, []) == expected.shapes.get(cell, []), "Old worlds continue using their saved generator in future chunks")
	# Verify actual triangle collision against the navigation height sampler.
	var ground := Node3D.new()
	root.add_child(ground)
	var region := Generator.generate_region(1409, Rect2i(-34, -34, 22, 22))
	var sample := Model.new()
	sample.ground = region.ground
	sample.terrain_heights = region.heights
	sample.terrain_shapes = region.shapes
	sample.rebuild_navigation()
	Terrain.build(ground, sample, region.ground, region.border, region.border_shapes)
	await physics_frame
	await physics_frame
	var tested := 0
	for cell: Vector3i in sample.terrain_shapes:
		if cell.y < 2: continue
		var point := Vector3(cell.x + 0.17, 0, cell.z + 0.11)
		var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 12, point - Vector3.UP))
		check(not hit.is_empty(), "Elevated shoulder has a real collision surface")
		if not hit.is_empty(): check(absf(hit.position.y - sample.navigation.surface_height(cell, point)) < 0.002, "Collision and navigation agree on elevated slopes")
		tested += 1
		if tested == 20: break
	check(tested == 20, "Checked twenty elevated shoulder surfaces")
	ground.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d terrace generation, streaming, save and collision checks" % checks)
	quit(int(not failures.is_empty()))
