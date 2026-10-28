extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Soil = preload("res://scripts/settlement/soil_surface.gd")
const Terrain = preload("res://scripts/settlement/terrain_mesh.gd")
const Water = preload("res://scripts/settlement/water_view.gd")
var failures: Array[String] = []
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = Model.new()
	world.setup(1409)
	var opening_pool: Vector2 = Soil.pool_levels(world, Vector3i(-8, 0, 0))
	check(opening_pool.y - opening_pool.x >= 0.079, "Starting stockpile levelling preserves the nearby freshwater bowl")
	var cell := Vector3i(4, 0, 0)
	var h: Array = world.soil_shapes[cell]
	check(h.size() == 5 and h.max() <= Soil.MAX_RELIEF and h.min() > 0.0, "Natural relief stays inside the metre layer")
	check(h != world.soil_shapes[cell + Vector3i.RIGHT], "Nearby soil has real height variation")
	var other = Model.new()
	other.setup(1409)
	check(other.soil_shapes == world.soil_shapes, "Same seed reconstructs the same surface")
	check(world.Volume.material_at(world, cell) == "solid" and world.Volume.soil_fill(world, cell) > 0.0 and world.Volume.soil_fill(world, cell) < 0.5, "Thin soil is solid without treating it as a flat full cube")
	for candidate: Vector3i in world.ground:
		var right := candidate + Vector3i.RIGHT
		if world.ground.has(right) and not world.terrain_shapes.has(candidate) and not world.terrain_shapes.has(right):
			var a: Array = world.soil_shapes[candidate]
			var b: Array = world.soil_shapes[right]
			check(is_equal_approx(a[1], b[0]) and is_equal_approx(a[2], b[3]), "Shared corners agree across cells and chunks")
	var natural_pool := Vector3i(9999, 0, 9999)
	for source: Vector3i in world.water_sources:
		if world.water_sources[source].kind == "puddle" and world.water_sources[source].inventory.count("water") == 0:
			natural_pool = source
			break
	check(natural_pool.x != 9999, "Perlin hollows produce initially dry rain catchments")
	if natural_pool.x != 9999:
		var levels := Soil.pool_levels(world, natural_pool)
		check(levels.y > levels.x + 0.01, "A puddle is below its lowest surrounding rim")
		world.weather.seconds = 91
		world.Hydrology.tick(world, 1.0)
		check(world.water_sources[natural_pool].inventory.count("water") == 1, "Rain automatically collects in a natural hollow")
		var water := Water.new()
		var mesh := water.pool_mesh(world, natural_pool, 1.0)
		check(mesh != null, "Water has a clipped physical surface")
		if mesh != null:
			var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for index in range(0, vertices.size(), 3):
				check((vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).y < 0.0, "Water triangles face the camera above ground")
			for vertex: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = vertex + world.Navigation.point(natural_pool)
				check(p.y + 0.0001 >= world.navigation.surface_height(natural_pool, p) and p.y < levels.y, "Water lies above the bowl and below its spill rim")
		water.free()
	# Exercise actual labour, not just the direct completion helper.
	check(other.request_build("house", cell), "A builder can prepare an uneven foundation")
	var working_plan: Dictionary = other.plans.values().back()
	var builder: Dictionary = other.workers[0]
	var resource: String = other.Jobs.needed_material(working_plan)
	var stock = other.stores.values()[0]
	check(stock.reserve(builder.id, resource), "Foundation work uses a real construction delivery")
	builder.cargo = stock.pickup(builder.id)
	other.Jobs.claim_material(working_plan, resource, 1)
	builder.job = {"kind": "build", "phase": "work", "plan_id": working_plan.id, "target": cell, "labour": preload("res://scripts/applied_labour.gd").new(1.0)}
	var unworked: Dictionary = other.soil_cuts.duplicate()
	other.Jobs._tick_worker(other, builder, 0.1)
	check(other.soil_cuts == unworked, "Unfinished first work application does not excavate instantly")
	other.Jobs._tick_worker(other, builder, 2.0)
	check(working_plan.installed == 1 and other.soil_shapes[cell].max() == 0.0, "First installed material levels the foundation during real construction")
	var prepared: Dictionary = other.soil_cuts.duplicate()
	other.delete_plan(working_plan.id)
	check(other.soil_cuts == prepared, "Cancelling construction does not regrow excavated soil")
	var before: Dictionary = world.soil_cuts.duplicate()
	check(world.request_build("house", cell), "Construction accepts shallow irregular soil")
	check(world.soil_cuts == before, "Planning alone does not excavate")
	if not world.plans.is_empty(): world._complete_plan(world.plans.values().back())
	for support: Vector3i in world.Grid.support_cells(cell):
		check(world.soil_shapes[support].max() == 0.0, "Completed foundation cuts exactly to the grid")
	check(world.Volume.material_at(world, cell) == "air" and world.Volume.material_at(world, cell + Vector3i.DOWN) == "solid", "Levelling removes only the loose top layer")
	var neighbour := cell + Vector3i(2, 0, 0)
	check(world.soil_shapes[neighbour][0] == 0.0 and world.soil_shapes[neighbour][3] == 0.0 and world.soil_shapes[neighbour][1] > 0.0, "Adjacent soil slopes continuously into the level foundation")
	var saved := world.snapshot()
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))), "Uneven terrain and cuts load")
	check(restored.soil_cuts == world.soil_cuts, "Reload preserves permanent cuts exactly")
	for surface: Vector3i in world.soil_shapes:
		for index in world.soil_shapes[surface].size():
			check(absf(restored.soil_shapes[surface][index] - world.soil_shapes[surface][index]) < 0.000001, "Reload preserves sampled geometry within float serialization precision")
	var legacy := world.snapshot()
	legacy.world.v = legacy.world.v.filter(func(pair): return pair[0] not in ["soil_enabled", "soil_cuts"])
	var old = Model.new()
	check(old.restore(legacy) and not old.soil_enabled and old.soil_shapes.is_empty(), "Legacy saves retain their original flat terrain")
	var remote := Vector2i(9, -8)
	world.Chunks.load_chunk(world, remote)
	var remote_cell := Vector3i(remote.x * 16 + 8, 0, remote.y * 16 + 8)
	Soil.prepare(world, {"kind": "house", "cell": remote_cell})
	var remote_shape: Array = world.soil_shapes.get(remote_cell, []).duplicate()
	world.Chunks.unload_chunk(world, remote)
	world.Chunks.load_chunk(world, remote)
	check(world.soil_shapes.get(remote_cell) == remote_shape, "Unloading never regrows cut soil")
	# Collision, drawing and walking all use the same five sampled heights.
	var parent := Node3D.new()
	root.add_child(parent)
	Terrain.build(parent, world, {Vector3i.ZERO: true})
	for frame in 2: await physics_frame
	var p := Vector3(0.17, 0, -0.23)
	var hit := parent.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 5, p - Vector3.UP))
	check(not hit.is_empty() and absf(hit.position.y - world.navigation.surface_height(Vector3i.ZERO, p)) < 0.0001, "Rendered soil collision matches navigation within a tenth of a millimetre")
	parent.free()
	var scenery = preload("res://scripts/settlement/scenery_view.gd").new()
	root.add_child(scenery)
	scenery.setup(world)
	var original_chunk: int = scenery.chunks[Vector2i.ZERO].get_instance_id()
	var untouched_chunk: int = scenery.chunks[Vector2i(2, 2)].get_instance_id()
	Soil.prepare(world, {"kind": "house", "cell": Vector3i.ZERO})
	scenery.sync(world)
	check(scenery.chunks[Vector2i.ZERO].get_instance_id() != original_chunk, "Levelling invalidates the affected terrain mesh and collider")
	check(scenery.chunks[Vector2i(2, 2)].get_instance_id() == untouched_chunk, "Levelling preserves unrelated chunk geometry")
	for frame in 2: await physics_frame
	hit = scenery.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 5, p - Vector3.UP))
	check(not hit.is_empty() and absf(hit.position.y) < 0.0001, "Updated collision is exactly on the excavated grid plane")
	scenery.free()
	for failure: String in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d soil relief, foundation, rain, persistence and collision checks" % checks)
	quit(int(not failures.is_empty()))
