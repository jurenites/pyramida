extends RefCounted
## World-space patches, independent of chunk boundaries and generation order.
const Random = preload("res://scripts/deterministic_random.gd")
const LegacyGrass = preload("res://scripts/grass_renderer.gd")
const PATCH_SPACING := 28
# New colonies use adjacent single-tile centres so the rounded crowns touch.
const BUSH_SHAPES := [
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(0, -1)],
	[Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(2, -1)],
	[Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(2, 0)],
]

static func grass_at(column: Vector2i, seed_: int) -> bool:
	# Keep the old connected grass silhouette, including greenery at the start.
	if absi(column.x) <= 3 and absi(column.y) <= 3:
		return true
	var shift := Vector2i(Random.world_roll(0, 0, seed_, 410) % 512, Random.world_roll(0, 0, seed_, 411) % 512)
	return LegacyGrass.generated_grass_at(column + shift)

static func bush_offsets(shape: int, turns := 0) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Vector2i in BUSH_SHAPES[posmod(shape, BUSH_SHAPES.size())]:
		var offset := value
		for turn in posmod(turns, 4):
			offset = Vector2i(-offset.y, offset.x)
		result.append(offset)
	return result

static func bushes_in(bounds: Rect2i, seed_: int) -> Dictionary:
	var result := {}
	# Include neighbouring colony anchors so patches cross stream seams intact.
	var padded := bounds.grow(10)
	for x in range(floori(float(padded.position.x) / PATCH_SPACING), floori(float(padded.end.x) / PATCH_SPACING) + 1):
		for z in range(floori(float(padded.position.y) / PATCH_SPACING), floori(float(padded.end.y) / PATCH_SPACING) + 1):
			# Patch anchors stay on integer cells.
			@warning_ignore("integer_division")
			var centre := Vector2i(x, z) * PATCH_SPACING + Vector2i.ONE * (PATCH_SPACING / 2)
			centre += Vector2i(Random.world_roll(x, z, seed_, 412) % 11 - 5, Random.world_roll(x, z, seed_, 413) % 11 - 5)
			# The opening economy places its own reachable colonies.
			if maxi(absi(centre.x), absi(centre.y)) <= 20:
				continue
			var shape := Random.world_roll(x, z, seed_, 414) % BUSH_SHAPES.size()
			var turns := Random.world_roll(x, z, seed_, 415) % 4
			for offset: Vector2i in bush_offsets(shape, turns):
				var column := centre + offset
				if bounds.has_point(column): result[column] = true
	return result

static func trees_in(bounds: Rect2i, seed_value: int, coastal_world := false) -> Dictionary:
	# One continuous field creates dense stands and open ground across chunk seams.
	var forest_noise := FastNoiseLite.new()
	forest_noise.seed = seed_value ^ 8273
	forest_noise.frequency = 0.055
	var tree_cells := {}
	for cell_x in range(bounds.position.x, bounds.end.x):
		for cell_z in range(bounds.position.y, bounds.end.y):
			var forest_strength := smoothstep(-0.08, 0.28, forest_noise.get_noise_2d(cell_x, cell_z))
			var tree_density := 0.025 + forest_strength * 0.72
			if Random.world_fraction(cell_x, cell_z, seed_value, 420) >= tree_density: continue
			var dead_fraction := 0.25 if coastal_world else 0.40
			tree_cells[Vector2i(cell_x, cell_z)] = "dead_tree" if Random.world_fraction(cell_x, cell_z, seed_value, 421) < dead_fraction else "tree"
	return tree_cells
