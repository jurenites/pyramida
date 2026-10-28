extends RefCounted
## Sparse edits over procedural columns: y addresses volumes, not walking floors.
## A volume at y occupies [y, y + 1); negative depths are generated on demand.
const Coast = preload("res://scripts/settlement/greece_landscape.gd")
const Grid = preload("res://scripts/settlement/world_grid.gd")

static func sea_depth(world, cell: Vector3i) -> int:
	if world.difficulty != "easy": return 0
	var distance: float = cell.x - Coast.coast(cell.z, world.world_seed)
	return 0 if distance <= 0.0 else Grid.STOREY.y + floori(distance / 6.0)

static func material_at(world, cell: Vector3i) -> String:
	var column_cell := Vector2i(cell.x, cell.z)
	if world.surface_edits.has(column_cell):
		return "solid" if cell.y < int(world.surface_edits[column_cell]) else "air"
	if world.volume_edits.has(cell): return world.volume_edits[cell]
	var depth := sea_depth(world, cell)
	if depth > 0:
		if cell.y >= 0: return "air"
		return "water" if cell.y >= -depth else "solid"
	var surface: int = world.terrain_heights.get(Vector2i(cell.x, cell.z), 0)
	if cell.y < surface: return "solid"
	return "solid" if soil_fill(world, cell) > 0.000001 else "air"

static func shore_platform(world, cell: Vector3i) -> bool:
	return cell.y == 0 and sea_depth(world, cell) > 0

static func platform_grounded(world, cell: Vector3i, height := 1) -> bool:
	# Existing timber posts span one floor. Every part of the footprint needs
	# a bed within that reach; deep water requires a future longer foundation.
	for floor_cell: Vector3i in Grid.support_cells(cell):
		var anchored := false
		for depth in range(1, height + 2):
			var material := material_at(world, floor_cell + Vector3i.DOWN * depth)
			if material == "solid":
				anchored = true
				break
			if material != "water": return false
		if not anchored: return false
	return true

static func well_connected(world, cell: Vector3i) -> bool:
	# Rain-fed ground remains a valid source; a deck cannot replace earth.
	return world.ground.has(cell) and material_at(world, cell + Vector3i.DOWN) == "solid"

static func soil_fill(world, cell: Vector3i) -> float:
	# A thin covering remains solid material; 50% is never a support test.
	# Exact integration of the shallow top layer's four planar triangles.
	if not world.soil_enabled: return 0.0
	var surface: Vector3i = world.surface_at(cell.x, cell.z)
	var h: Array = world.soil_shapes.get(surface, [])
	if h.size() != 5: return 0.0
	var result := 0.0
	for index in 4: result += clampf(h[index] - cell.y, 0.0, 1.0) / 6.0
	return result + clampf(h[4] - cell.y, 0.0, 1.0) / 3.0
