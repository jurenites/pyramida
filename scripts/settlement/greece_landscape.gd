extends RefCounted
## Seeded coastal meadows; all samples use absolute coordinates for streaming.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Random = preload("res://scripts/deterministic_random.gd")
const Vegetation = preload("res://scripts/settlement/vegetation_patches.gd")
const CORNERS := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]

static func coast(z: float, seed_: int) -> float:
	var phase := float(posmod(seed_, 97)) * 0.064
	return 24.0 + sin(z * 0.045 + phase) * 5.0 + sin(z * 0.12 + phase) * 1.8

static func height(point: Vector2, seed_: int) -> float:
	# A buildable opening, then broad low hills with continuous shared corners.
	var opening := smoothstep(16.0, 30.0, point.length())
	var inland := smoothstep(3.0, 16.0, coast(point.y, seed_) - point.x)
	var phase := float(posmod(seed_, 71)) * 0.09
	var waves := sin(point.x * 0.065 + phase) * cos(point.y * 0.052 - phase)
	return pow(maxf(0.0, waves), 2.0) * 2.5 * opening * inland

static func ground_color(point: Vector2, seed_: int) -> Color:
	var inland := coast(point.y, seed_) - point.x
	var meadow := Color("90b56b").lerp(Color("b2c780"), 0.5 + 0.5 * sin(point.x * 0.11) * cos(point.y * 0.09))
	return Color("ead9ad").lerp(meadow, smoothstep(1.0, 6.0, inland))

static func generate(seed_: int, bounds: Rect2i) -> Dictionary:
	var result := {"seed": seed_, "version": 4, "heights": {}, "ground": {}, "shapes": {},
		"ramps": {}, "water": {}, "nature": {}, "grass": {}, "border": {}, "border_shapes": {}}
	var bushes := Vegetation.bushes_in(bounds.grow(1), seed_)
	var forest_cells := Vegetation.trees_in(bounds.grow(1), seed_, true)
	for x in range(bounds.position.x - 1, bounds.end.x + 1):
		for z in range(bounds.position.y - 1, bounds.end.y + 1):
			var column := Vector2i(x, z)
			var cell := Vector3i(x, 0, z)
			# Sea has no walkable or buildable ground and is never drinking water.
			if x > coast(z, seed_): continue
			var corners: Array[float] = []
			for offset in CORNERS: corners.append(height(Vector2(x, z) + offset, seed_))
			result.border[column] = 0
			var sloped: bool = corners.max() > 0.001
			if sloped: result.border_shapes[cell] = corners
			if not bounds.has_point(column): continue
			result.heights[column] = 0
			result.ground[cell] = true
			if sloped: result.shapes[cell] = corners
			if cell in [Vector3i(-8, 0, 0), Vector3i(8, 0, -8), Vector3i(-10, 0, 8)]:
				result.water[cell] = "puddle"
				continue
			if coast(z, seed_) - x > 2.5: result.grass[cell] = true
			if maxi(absi(x), absi(z)) <= 16 or sloped or coast(z, seed_) - x < 4: continue
			var clear := true
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if height(Vector2(x + dx, z + dz), seed_) > 0.001: clear = false
			if not clear: continue
			if bushes.has(column):
				result.nature[cell] = "berry"
			else:
				var priority := Random.world_fraction(x, z, seed_, 304)
				var roll := Random.world_fraction(x, z, seed_, 302)
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						if bushes.has(column + Vector2i(dx, dz)): clear = false
						if forest_cells.has(column) and forest_cells.has(column + Vector2i(dx, dz)): continue
						if (dx != 0 or dz != 0) and Random.world_fraction(x + dx, z + dz, seed_, 304) <= priority: clear = false
				if clear and forest_cells.has(column): result.nature[cell] = forest_cells[column]
				elif clear and roll >= 0.52 and roll < 0.64: result.nature[cell] = "limestone"
			if result.nature.has(cell): result.grass.erase(cell)
	return result
