extends RefCounted
## Exact ground footprints; elevated floors do not clear the terrain beneath them.
const Farming = preload("res://scripts/settlement/farming.gd")
const Grid = preload("res://scripts/settlement/world_grid.gd")

static func footprints(world) -> Dictionary:
	var result := {}
	for field in ["buildings", "stores", "wells", "gardens", "soil_beds"]:
		for cell: Vector3i in world.get(field):
			var building: Dictionary = world.buildings.get(cell, {})
			var kind: String = building.get("kind", {"stores": "stockpile", "wells": "well", "gardens": "garden", "soil_beds": "soil_bed"}.get(field, ""))
			_add(result, kind, cell, building.get("placement_offset", Vector3.ZERO), int(building.get("direction", 0)))
	for plan: Dictionary in world.plans.values():
		if int(plan.get("installed", 0)) > 0 and not plan.get("deconstruction", false):
			_add(result, plan.kind, plan.cell, plan.get("placement_offset", Vector3.ZERO), int(plan.direction))
	return result

static func _add(result: Dictionary, kind: String, cell: Vector3i, offset: Vector3, direction: int) -> void:
	if kind in ["platform", "stairs", "vine_tree"] or kind.begins_with("seed_"): return
	var rect := Farming.footprint(kind, cell, offset, direction)
	for x in range(floori(rect.position.x / Grid.CELL_SIZE), ceili(rect.end.x / Grid.CELL_SIZE) + 1):
		for z in range(floori(rect.position.y / Grid.CELL_SIZE), ceili(rect.end.y / Grid.CELL_SIZE) + 1):
			var key := Vector3i(x, cell.y, z)
			if not result.has(key): result[key] = []
			result[key].append(rect)

static func covered(footprints: Dictionary, cell: Vector3i, point: Vector3) -> bool:
	for rect: Rect2 in footprints.get(cell, []):
		if rect.has_point(Vector2(point.x, point.z)): return true
	return false
