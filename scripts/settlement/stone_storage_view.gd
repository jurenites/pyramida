extends RefCounted

static func sync(node: Node3D, tier: int) -> void:
	node.get_node("Beams").visible = tier >= 2
	node.get_node("Enclosure").visible = tier == 3
