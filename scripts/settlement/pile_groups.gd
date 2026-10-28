extends RefCounted
## Connected room-sized plots; inventories retain their physical pickup addresses.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const CORNERS := [Vector3i(-1, 0, -1), Vector3i(1, 0, -1), Vector3i(1, 0, 1), Vector3i(-1, 0, 1)]

static func is_pile(model, cell: Vector3i) -> bool:
	return model.stores.has(cell) and not model.buildings.has(cell)

static func members(model, start: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if not is_pile(model, start):
		return result
	var seen := {start: true}
	result.append(start)
	var cursor := 0
	while cursor < result.size():
		var cell := result[cursor]
		cursor += 1
		for offset in range(-1, 2):
			for step in [Vector3i(2, 0, offset), Vector3i(-2, 0, offset), Vector3i(offset, 0, 2), Vector3i(offset, 0, -2)]:
				var neighbour: Vector3i = cell + step
				if not seen.has(neighbour) and is_pile(model, neighbour):
					seen[neighbour] = true
					result.append(neighbour)
	return result

static func outline(cells: Array[Vector3i]) -> Array[Dictionary]:
	var tiles := {}
	var vertices := {}
	for cell in cells:
		for x in [-1, 0]:
			for z in [-1, 0]:
				tiles[cell + Vector3i(x, 0, z)] = true
		for index in 4:
			var point: Vector3i = cell + CORNERS[index]
			if not vertices.has(point):
				vertices[point] = {"cell": cell, "index": index}
	var result: Array[Dictionary] = []
	for point: Vector3i in vertices:
		var filled := [tiles.has(point + Vector3i(-1, 0, -1)), tiles.has(point + Vector3i(0, 0, -1)), tiles.has(point), tiles.has(point + Vector3i(-1, 0, 0))]
		var directions: Array[Vector3] = []
		for index in 4:
			if filled[index] != filled[(index + 1) % 4]:
				directions.append([Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT][index])
		if directions.size() == 2 and directions[0].dot(directions[1]) == 0:
			result.append({"point": Vector3(point.x * Grid.CELL_SIZE, point.y * Grid.LEVEL_HEIGHT, point.z * Grid.CELL_SIZE),
				"arms": directions, "cell": vertices[point].cell, "index": vertices[point].index})
	return result

static func totals(model, cell: Vector3i) -> Dictionary:
	var result := {"capacity": 0, "amounts": {}}
	for member in members(model, cell):
		var inventory = model.stores[member]
		result.capacity += inventory.capacity
		for resource: String in inventory.amounts:
			result.amounts[resource] = int(result.amounts.get(resource, 0)) + inventory.count(resource)
	return result
