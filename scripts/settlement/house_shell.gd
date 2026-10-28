extends RefCounted
## Adjacent rooms keep their authored shell. Only vertical caps change in WorldView.
const SIDES := [Vector3i.BACK, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.LEFT]
const WALLS := ["PlasterWall", "PlasterWall2", "BackWall", "DoorSide", "DoorSide2", "DoorLintel"]

static func apply(asset: Node3D, _neighbours: Array, _doors: Array) -> void:
	if asset.has_node("JoinedWalls"): asset.get_node("JoinedWalls").free()
	for name in WALLS: asset.get_node(name).visible = true
	asset.get_node("EntranceCarpet").visible = true
	for child in asset.get_children():
		if str(child.name).begins_with("Pot"): child.visible = true
