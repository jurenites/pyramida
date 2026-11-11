extends RefCounted
const Grid = preload("res://scripts/settlement/world_grid.gd")
static func join_step(direction: int) -> Vector3i:
	var v := Vector3.RIGHT.rotated(Vector3.UP, -direction * PI * 0.5) / Grid.CELL_SIZE
	return Vector3i(roundi(v.x), 0, roundi(v.z))

static func direction_for(_world, _cell: Vector3i, direction: int) -> int:
	# Placement keeps the chosen heading, regardless of adjacent shelters.
	return direction

static func sync(_world, _cell: Vector3i, _node: Node3D) -> void:
	# Keep each placed shelter's original posts and rafters.
	pass

static func attachment(world, cell: Vector3i, cursor: Vector3, direction: int) -> Dictionary:
	# The rear (local -X) meets a House wall. Preserve the integer save key,
	# while the half-metre offset aligns a 1 m Barn with a 2 m House.
	var outward := Vector3.RIGHT.rotated(Vector3.UP, -direction * PI / 2)
	var nearest := 0.85
	var result := {}
	var houses: Array = []
	for at: Vector3i in world.buildings:
		if world.buildings[at].kind == "house":
			houses.append({"cell": at, "offset": world.buildings[at].get("placement_offset", Vector3.ZERO)})
	for plan: Dictionary in world.plans.values():
		if plan.kind == "house" and not world.Deconstruction.is_salvage(plan):
			houses.append({"cell": plan.cell, "offset": plan.get("placement_offset", Vector3.ZERO)})
	for house: Dictionary in houses:
		if house.cell.y != cell.y: continue
		var centre: Vector3 = Vector3(house.cell.x, house.cell.y, house.cell.z) + house.offset + outward * 1.5
		var distance := Vector2(centre.x - cursor.x, centre.z - cursor.z).length()
		if distance >= nearest: continue
		nearest = distance
		var anchor := Vector3i(roundi(centre.x), cell.y, roundi(centre.z))
		result = {"cell": anchor, "offset": centre - Vector3(anchor)}
	return result
