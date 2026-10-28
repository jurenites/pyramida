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

func update(workers: Array) -> void:
	for worker: Dictionary in workers:
		var cell := Mask.cell_at(worker.position)
		if last_positions.get(worker.id) == cell:
			continue
		last_positions[worker.id] = cell
		reveal(worker.position)

func reveal(point: Vector3) -> void:
	if not Mask.reveal(cells, point, RADIUS, BOUNDS).is_empty():
		revision += 1

func contains(point: Vector3) -> bool:
	return cells.has(Mask.cell_at(point))

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
	last_positions.clear()
	revision += 1
	return true
