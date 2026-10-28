extends RefCounted
## Design units: a room is 1×1; a terrain/placement cell is 0.5×0.5.
## A room is 2 m wide and a floor is 2 m high.
const ROOM_SIZE := 2.0
const CELL_SIZE := ROOM_SIZE * 0.5
const CELLS_PER_ROOM := 2
const LEVEL_HEIGHT := 1.0
const STOREY_HEIGHT := 2.0
const STOREY := Vector3i(0, 2, 0)
const WORLD_RADIUS := 40

static func snap_position(point: Vector3) -> Vector3:
	return point.snapped(Vector3(CELL_SIZE, LEVEL_HEIGHT, CELL_SIZE))

static func from_room(cell: Vector3i) -> Vector3i:
	return Vector3i(cell.x * CELLS_PER_ROOM, cell.y, cell.z * CELLS_PER_ROOM)

static func overlaps(a: Vector3i, b: Vector3i, width := CELLS_PER_ROOM) -> bool:
	return a.y == b.y and absi(a.x - b.x) < width and absi(a.z - b.z) < width

static func support_cells(centre: Vector3i) -> Array[Vector3i]:
	# Centres snap to the half grid. The footprint also touches half of the
	# surrounding terrain cells, so check those edges rather than just its centre.
	var result: Array[Vector3i] = []
	for x in range(-1, 2):
		for z in range(-1, 2):
			result.append(centre + Vector3i(x, 0, z))
	return result
