extends RefCounted
## Sparse resistant sandstone buttes on a level desert floor, sampled in world space.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Random = preload("res://scripts/deterministic_random.gd")
const Vegetation = preload("res://scripts/settlement/vegetation_patches.gd")
const VERSION := 4
const DEFAULT_SEED := 1409
const MAX_HEIGHT := 20
const SAFE_RADIUS := 14
const CHUNK_SIZE := 16
const WORLD_LIMIT := 16382
const INITIAL_BOUNDS := Rect2i(-48, -48, 96, 96)
const EROSION_STEPS := 0
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const CORNERS := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]

static func chunk_at(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE))

static func generate(seed_: int, radius := Grid.WORLD_RADIUS, erosion_steps := EROSION_STEPS) -> Dictionary:
	return generate_region(seed_, Rect2i(-radius, -radius, radius * 2 + 1, radius * 2 + 1), erosion_steps)

static func generate_chunk(seed_: int, chunk: Vector2i, difficulty := "normal") -> Dictionary:
	return generate_region(seed_, Rect2i(chunk * CHUNK_SIZE, Vector2i.ONE * CHUNK_SIZE), EROSION_STEPS, difficulty)

static func formations(seed_: int, bounds: Rect2i) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var sites: Array[Vector2] = [Vector2(-25, -24), Vector2(7, -28), Vector2(28, -8), Vector2(24, 24), Vector2(-26, 20)]
	var result: Array[Dictionary] = []
	for site: Vector2 in sites:
		result.append(make_butte(site, rng))
	# The distant world uses the same sparse patches, independent of load order.
	var padded := bounds.grow(12)
	for x in range(floori(float(padded.position.x) / 48), floori(float(padded.end.x) / 48) + 1):
		for z in range(floori(float(padded.position.y) / 48), floori(float(padded.end.y) / 48) + 1):
			var site := Vector2(x * 48 + 24, z * 48 + 24)
			if maxf(absf(site.x), absf(site.y)) < 50:
				continue
			rng.seed = hash([seed_, x, z])
			if rng.randf() < 0.8:
				result.append(make_butte(site, rng))
	return result

static func make_butte(site: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	return {"centre": site + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)),
		"radius": rng.randf_range(2.2, 3.6), "talus": rng.randf_range(3.2, 4.8),
		"height": rng.randi_range(3, 6) * 2, "angle": rng.randf_range(-PI, PI), "phase": rng.randf_range(0, TAU)}

static func sample(point: Vector2, buttes: Array[Dictionary]) -> Dictionary:
	var level := 0
	var corners: Array[float] = [0.0, 0.0, 0.0, 0.0]
	if maxf(absf(point.x), absf(point.y)) > SAFE_RADIUS:
		for butte: Dictionary in buttes:
			if point.distance_squared_to(butte.centre) > 144:
				continue
			if edge_distance(point, butte) <= 0:
				level = maxi(level, int(butte.height))
			for index in 4:
				var edge := edge_distance(point + CORNERS[index], butte)
				corners[index] = maxf(corners[index], clampf(1.0 - maxf(0, edge) / butte.talus, 0, 1) * 2.6)
	return {"level": level, "corners": corners}

static func generate_region(seed_: int, bounds: Rect2i, _erosion_steps := EROSION_STEPS, difficulty := "normal") -> Dictionary:
	if difficulty == "easy": return preload("res://scripts/settlement/greece_landscape.gd").generate(seed_, bounds)
	var buttes := formations(seed_, bounds)
	var habitat := FastNoiseLite.new()
	habitat.seed = seed_ ^ 5189
	habitat.frequency = 0.035
	var bushes := Vegetation.bushes_in(bounds.grow(1), seed_)
	var forest_cells := Vegetation.trees_in(bounds.grow(1), seed_)
	var result := {"seed": seed_, "version": VERSION, "heights": {}, "ground": {}, "shapes": {},
		"ramps": {}, "water": {}, "nature": {}, "grass": {}, "border": {}, "border_shapes": {}}
	for x in range(bounds.position.x - 1, bounds.end.x + 1):
		for z in range(bounds.position.y - 1, bounds.end.y + 1):
			var column := Vector2i(x, z)
			var value := sample(Vector2(x, z), buttes)
			var cell := Vector3i(x, value.level, z)
			result.border[column] = value.level
			if value.level == 0 and value.corners.max() > 0.001:
				result.border_shapes[cell] = value.corners
			if not bounds.has_point(column):
				continue
			result.heights[column] = value.level
			result.ground[cell] = true
			if value.level == 0 and value.corners.max() > 0.001:
				result.shapes[cell] = value.corners
				continue
			if value.level > 0:
				continue
			var river_x := roundi(18 + sin(float(z) * 0.09 + float(posmod(seed_, 31))) * 2)
			var previous_x := roundi(18 + sin(float(z - 1) * 0.09 + float(posmod(seed_, 31))) * 2)
			if x >= mini(river_x, previous_x) and x <= maxi(river_x, previous_x):
				result.water[cell] = "stream"
			elif cell == Vector3i(-8, 0, 0):
				result.water[cell] = "puddle"
			elif maxi(absi(x), absi(z)) > SAFE_RADIUS and Random.world_fraction(x, z, seed_, 301) < 0.00075:
				result.water[cell] = "puddle"
			if result.water.has(cell):
				continue
			if Vegetation.grass_at(column, seed_):
				result.grass[cell] = true
			if maxi(absi(x), absi(z)) <= SAFE_RADIUS:
				continue
			# Colonies own their footprint before individual trees and rocks.
			var roll := Random.world_fraction(x, z, seed_, 302)
			var clear := true
			for offset in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var nearby := sample(Vector2(x, z) + offset, buttes)
				if nearby.level > 0 or nearby.corners.max() > 0.001:
					clear = false
			if clear and bushes.has(column):
				result.nature[cell] = "berry"
				result.grass.erase(cell)
				continue
			var priority := Random.world_fraction(x, z, seed_, 304)
			var moisture := clampf(0.5 + habitat.get_noise_2d(x, z), 0.0, 1.0)
			var tree_candidate := forest_cells.has(column)
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if bushes.has(column + Vector2i(dx, dz)):
						clear = false
					# Trees share neighbouring cells inside a forest; rocks keep clearance.
					if tree_candidate and forest_cells.has(column + Vector2i(dx, dz)):
						continue
					if (dx != 0 or dz != 0) and Random.world_fraction(x + dx, z + dz, seed_, 304) <= priority:
						clear = false
			if clear:
				if tree_candidate: result.nature[cell] = forest_cells[column]
				elif roll >= moisture * 0.5 + 0.05 and roll < moisture * 0.5 + 0.15: result.nature[cell] = "limestone"
			if result.nature.has(cell): result.grass.erase(cell)
	return result

static func edge_distance(point: Vector2, butte: Dictionary) -> float:
	var local: Vector2 = (point - butte.centre).rotated(butte.angle)
	var facets := maxf(absf(local.x) * 0.92 + absf(local.y) * 0.28, absf(local.y) * 0.93 + absf(local.x) * 0.22)
	return facets - float(butte.radius) + sin(local.angle() * 5.0 + butte.phase) * 0.25

static func thermal_step(heights: Dictionary) -> Dictionary:
	var next := heights.duplicate()
	for cell: Vector2i in heights:
		var lowest := cell
		for direction: Vector2i in DIRECTIONS:
			var neighbour := cell + direction
			if heights.has(neighbour) and float(heights[neighbour]) < float(heights[lowest]):
				lowest = neighbour
		var difference := float(heights[cell]) - float(heights[lowest])
		if difference > 1.3:
			var sediment := (difference - 1.3) * 0.12
			next[cell] = float(next[cell]) - sediment
			next[lowest] = float(next[lowest]) + sediment
	return next

static func drainage(heights: Dictionary) -> Dictionary:
	var cells := heights.keys()
	cells.sort_custom(func(a, b): return float(heights[a]) > float(heights[b]))
	var flow := {}
	for cell in cells:
		flow[cell] = 1.0
	for cell: Vector2i in cells:
		var lowest := cell
		for direction: Vector2i in DIRECTIONS:
			var neighbour := cell + direction
			if heights.has(neighbour) and float(heights[neighbour]) < float(heights[lowest]):
				lowest = neighbour
		if lowest != cell:
			flow[lowest] += flow[cell]
	return flow

static func erosion_difference(before: Dictionary, after: Dictionary) -> float:
	var result := 0.0
	for cell in before:
		result += absf(float(before[cell]) - float(after[cell]))
	return result
