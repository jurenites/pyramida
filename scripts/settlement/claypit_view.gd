extends RefCounted
## The existing puddle inventory controls the water inside the bordered basin.
static func sync(node: Node3D, model, cell: Vector3i) -> void:
	var surface := node.get_node_or_null("Water") as MeshInstance3D
	if surface == null: return
	var source: Dictionary = model.water_sources.get(cell, {})
	if source.is_empty(): surface.hide(); return
	var inventory = source.inventory
	var fraction := clampf(float(inventory.count("water")) / maxi(1, inventory.capacity), 0, 1)
	surface.visible = fraction > 0
	surface.scale = Vector3(lerpf(0.70, 1, fraction), 1, lerpf(0.70, 1, fraction))
	surface.position.y = lerpf(0.045, 0.095, fraction)
	if node.has_meta("collider"):
		var collision: CollisionShape3D = node.get_meta("collider").get_child(0)
		collision.shape.size.y = 0.45; collision.position.y = 0.225
