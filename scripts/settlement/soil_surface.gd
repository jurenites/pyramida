extends RefCounted
## Sub-metre soil relief is physical geometry, independent of integer floor identity.
## Saved cuts remove relief at shared half-metre samples; generation never refills them.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const OFFSETS := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2.ZERO]
const MAX_RELIEF := 0.44

static func noise(seed_: int) -> FastNoiseLite:
	var result := FastNoiseLite.new()
	result.seed = seed_ ^ 48271
	result.noise_type = FastNoiseLite.TYPE_PERLIN
	result.frequency = 0.23
	result.fractal_octaves = 2
	return result

static func sample_key(cell: Vector3i, offset: Vector2) -> Vector3i:
	return Vector3i(cell.x * 2 + roundi(offset.x * 2), cell.y, cell.z * 2 + roundi(offset.y * 2))

static func shape(world, cell: Vector3i, base: Array = []) -> Array:
	if world.surface_edits.has(Vector2i(cell.x, cell.z)):
		return [float(cell.y), float(cell.y), float(cell.y), float(cell.y)]
	if base.is_empty():
		var h := cell.y * Grid.LEVEL_HEIGHT
		base = world.terrain_shapes.get(cell, [h, h, h, h])
	if not world.soil_enabled or cell.y > 0: return base
	if world.soil_noise == null: world.soil_noise = noise(world.world_seed)
	var result: Array = []
	for index in 5:
		var offset: Vector2 = OFFSETS[index]
		var p := Vector2(cell.x, cell.z) + offset
		var relief := clampf(0.22 + world.soil_noise.get_noise_2d(p.x, p.y) * 0.5, 0.025, MAX_RELIEF)
		if world.soil_cuts.has(sample_key(cell, offset)): relief = 0.0
		var height: float = base[index] if index < 4 else (base[0] + base[2]) * 0.5
		result.append(height + relief)
	# Existing freshwater spots become actual bowls, preserving saved water identity.
	if world.water_sources.get(cell, {}).get("kind") == "puddle" and not world.soil_cuts.has(sample_key(cell, Vector2.ZERO)):
		result[4] = minf(result[4], maxf(cell.y - 0.08, minf(minf(result[0], result[1]), minf(result[2], result[3])) - 0.08))
	return result

static func rebuild(world, cells: Dictionary = {}) -> void:
	if not world.soil_enabled:
		world.soil_shapes.clear()
		return
	if cells.is_empty():
		world.soil_shapes.clear()
		cells = world.ground
	for cell: Vector3i in cells:
		world.soil_shapes[cell] = shape(world, cell)

static func walking_shapes(world) -> Dictionary:
	return world.soil_shapes if world.soil_enabled else world.terrain_shapes

static func add_hollows(world, cells: Dictionary) -> void:
	if not world.soil_enabled: return
	for cell: Vector3i in cells:
		if cell.y != 0 or world.terrain_shapes.has(cell) or world.water_sources.has(cell): continue
		if world.trees.has(cell) or world.deposits.has(cell) or world.vines.has(cell): continue
		# Keep the starting work area free; the guaranteed opening puddle remains.
		if maxi(absi(cell.x), absi(cell.z)) < 14: continue
		var h: Array = world.soil_shapes[cell]
		if h[4] + 0.012 >= minf(minf(h[0], h[1]), minf(h[2], h[3])): continue
		var inventory = world.Inventory.new()
		inventory.capacity = 3
		world.water_sources[cell] = {"kind": "puddle", "inventory": inventory, "regrowth": 0.0}
		world.soil_shapes[cell] = shape(world, cell)

static func prepare(world, plan: Dictionary) -> void:
	if not world.soil_enabled or plan.kind in world.Catalog.SEEDS or plan.kind == "berry" or plan.get("deconstruction", false): return
	var centre: Vector3i = plan.cell
	if plan.kind == "platform": centre.y -= int(plan.get("platform_tier", 1))
	var changed := false
	for cell: Vector3i in Grid.support_cells(centre):
		if not world.ground.has(cell) or world.terrain_shapes.has(cell): continue
		for offset: Vector2 in OFFSETS:
			var key := sample_key(cell, offset)
			if not world.soil_cuts.has(key):
				world.soil_cuts[key] = true
				changed = true
	if not changed: return
	# Shared edge samples also update the neighbouring cells, keeping a continuous
	# transition into the cut instead of introducing cracks or invisible steps.
	rebuild(world)
	world.terrain_revision += 1
	world.soil_revision += 1
	world.rebuild_navigation()
	for worker: Dictionary in world.workers:
		worker.position = world.navigation.ground_position(worker.position, worker.cell.y)

static func pool_levels(world, cell: Vector3i) -> Vector2:
	var h: Array = world.soil_shapes.get(cell, [])
	if h.size() != 5: return Vector2.ZERO
	var rim := minf(minf(h[0], h[1]), minf(h[2], h[3]))
	return Vector2(h[4], rim)

static func valid(world: Dictionary) -> bool:
	if not world.get("soil_enabled", false) is bool or not world.get("soil_cuts", {}) is Dictionary: return false
	for key: Variant in world.get("soil_cuts", {}):
		if not key is Vector3i or abs(key.x) > 32768 or abs(key.z) > 32768 or abs(key.y) > 16384 or world.soil_cuts[key] != true: return false
	return true
