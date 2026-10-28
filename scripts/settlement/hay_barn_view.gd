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
