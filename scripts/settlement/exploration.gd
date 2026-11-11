extends RefCounted
const Mask = preload("res://scripts/exploration_mask.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
# Five tiles includes the opening grove while leaving most of the map unknown.
const RADIUS := 5.0 * Navigation.ROOM_SIZE
const EXTENT := (preload("res://scripts/settlement/world_generator.gd").WORLD_LIMIT + 0.5) * Navigation.CELL_SIZE
const BOUNDS := Rect2i(-int(EXTENT / Mask.CELL_SIZE), -int(EXTENT / Mask.CELL_SIZE), int(EXTENT * 2 / Mask.CELL_SIZE), int(EXTENT * 2 / Mask.CELL_SIZE))
var cells := {}
var revision := 0
var last_positions := {}
var islands: Array[PackedVector2Array] = []
var revealed_islands := {}

func configure_islands(world) -> void:
	islands.clear()
	revealed_islands.clear()
	last_positions.clear()
	var solids = preload("res://scripts/settlement/solid_islands.gd")
	if world.difficulty != "easy" or not solids.enabled(world): return
	for island in solids.definitions(world.world_seed, world.generator_version):
		islands.append(island.coast)

func reveal_island(point: Vector3) -> void:
	for index in islands.size():
		if revealed_islands.has(index): continue
		var coast := islands[index]
		if not Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), coast): continue
		revealed_islands[index] = true
		var changed := false
		# Include the beach, complete tree crowns and a little navigable water.
		for outline in Geometry2D.offset_polygon(coast, 5.0):
			var area := Rect2(outline[0], Vector2.ZERO)
			for vertex in outline: area = area.expand(vertex)
			var first := Vector2i((area.position / Mask.CELL_SIZE).floor())
			var last := Vector2i((area.end / Mask.CELL_SIZE).ceil())
			for x in range(first.x, last.x + 1):
				for z in range(first.y, last.y + 1):
					var cell := Vector2i(x,z)
					if cells.has(cell) or not BOUNDS.has_point(cell): continue
					if Geometry2D.is_point_in_polygon((Vector2(cell) + Vector2.ONE * 0.5) * Mask.CELL_SIZE, outline):
						cells[cell] = true
						changed = true
		if changed: revision += 1

func update(workers: Array) -> void:
	for worker: Dictionary in workers:
		var cell := Mask.cell_at(worker.position)
		if last_positions.get(worker.id) == cell:
			continue
		last_positions[worker.id] = cell
		reveal(worker.position)

func reveal(point: Vector3) -> void:
	reveal_island(point)
	if not Mask.reveal(cells, point, RADIUS, BOUNDS).is_empty():
		revision += 1

func contains(point: Vector3) -> bool:
	return cells.has(Mask.cell_at(point))

func contains_bounds(box: AABB) -> bool:
	# Keep a half-cell margin so crowns at the discovery edge stay whole.
	var margin := Vector3(Mask.CELL_SIZE * 0.5, 0, Mask.CELL_SIZE * 0.5)
	var first := Mask.cell_at(box.position - margin)
	var last := Mask.cell_at(box.end + margin)
	for x in range(first.x, last.x + 1):
		for z in range(first.y, last.y + 1):
			if not cells.has(Vector2i(x, z)): return false
	return true

func snapshot() -> Array:
	var result := []
	for cell: Vector2i in cells:
		result.append([cell.x, cell.y])
	return result

func restore(data: Variant) -> bool:
	if not data is Array or data.size() > 16000000:
		return false
	var restored := {}
	for pair: Variant in data:
		if not pair is Array or pair.size() != 2 or not pair[0] is int or not pair[1] is int:
			return false
		var cell := Vector2i(pair[0], pair[1])
		if not BOUNDS.has_point(cell) or restored.has(cell):
			return false
		restored[cell] = true
	cells = restored
	revealed_islands.clear()
	last_positions.clear()
	revision += 1
	return true
