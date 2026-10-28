extends RefCounted
## Original prototype's persistent circular reveal, shared by both world models.
const CELL_SIZE := 0.5

static func cell_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))

static func reveal(cells: Dictionary, point: Vector3, radius: float, bounds := Rect2i()) -> Array[Vector2i]:
	var added: Array[Vector2i] = []
	var centre := cell_at(point)
	var reach := ceili(radius / CELL_SIZE)
	for x in range(centre.x - reach, centre.x + reach + 1):
		for z in range(centre.y - reach, centre.y + reach + 1):
			var cell := Vector2i(x, z)
			if cells.has(cell) or (bounds.has_area() and not bounds.has_point(cell)):
				continue
			var position := (Vector2(cell) + Vector2.ONE * 0.5) * CELL_SIZE
			if position.distance_squared_to(Vector2(point.x, point.z)) <= radius * radius:
				cells[cell] = true
				added.append(cell)
	return added
