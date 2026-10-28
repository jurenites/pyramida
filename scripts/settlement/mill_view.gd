extends RefCounted
## Tier visibility and driven parts; the tower keeps its placed compass direction.
static func sync(node: Node3D, tier: int) -> void:
	node.get_node("Chair").visible = tier == 1
	node.get_node("ManualDrive").visible = tier == 2
	node.get_node("WindTower").visible = tier == 3
	if node.has_meta("collider"):
		var collision: CollisionShape3D = node.get_meta("collider").get_child(0)
		var height := 6.0 if tier == 3 else (1.15 if tier == 2 else 0.9)
		collision.shape.size = Vector3(2, height, 2)
		collision.position.y = height * 0.5

static func animate(node: Node3D, tier: int, delta: float, working: bool) -> void:
	if tier == 3:
		node.get_node("WindTower/Rotor").rotation.z += delta * 0.55
		node.get_node("WindTower/CentralShaft").rotation.y += delta * 0.55
	if working:
		node.get_node("Runner").rotation.y += delta * 0.55
		if tier == 2: node.get_node("ManualDrive").rotation.y += delta * 0.55
