extends RefCounted
## Presentation follows harvested inventory, never reservations or elapsed work.
const Generator = preload("res://scripts/settlement/nature_generator.gd")
const LOGS_PER_TREE := 3
const STUMP_HEIGHT := 0.18
const LOG_HEIGHT := 0.88

static func asset(tree: Dictionary) -> String:
	return {"dead": "dead_tree", "palm": "palm"}.get(tree.get("kind", "living"), "tree")

static func sync(node: Node3D, tree: Dictionary) -> void:
	if tree.has("appearance_seed") and node.get_meta("nature_seed", -1) != int(tree.appearance_seed):
		Generator.populate(node, tree.get("kind", "living"), int(tree.appearance_seed))
	var growth := float(tree.get("seed_growth", 1.0))
	if node.get_meta("growth", -1.0) != growth:
		node.set_meta("growth", growth)
		node.scale = Vector3.ONE * lerpf(0.10, 1.0, growth)
	var amount: int = 3 if growth < 1.0 else tree.inventory.count("log")
	if node.get_meta("log_count", -1) == amount:
		return
	node.set_meta("log_count", amount)
	if tree.get("kind") == "palm" and not node.has_node("Segment1"):
		# Palm rings disappear from the crown down, retaining the lowest stump ring.
		for child in node.get_children():
			if child is MeshInstance3D:
				var bounds: AABB = child.transform * child.get_aabb()
				child.visible = amount == 3 or bounds.get_center().y < STUMP_HEIGHT + amount * LOG_HEIGHT
	else:
		_sync_segments(node, amount)
	if node.has_meta("nature_seed"):
		_sync_generated_bounds(node)
		return
	if node.has_meta("collider"):
		var shape: CollisionShape3D = node.get_meta("collider").get_child(0)
		var height := STUMP_HEIGHT + amount * LOG_HEIGHT
		if amount == LOGS_PER_TREE:
			height = 3.15 if tree.get("kind", "living") == "dead" else 3.72
		shape.shape.size.y = height
		shape.position.y = height * 0.5

static func _sync_segments(node: Node3D, amount: int) -> void:
	for index in LOGS_PER_TREE:
		node.get_node("Segment%d" % (index + 1)).visible = index < amount
		node.get_node("Segment%d/CutFace" % (index + 1)).visible = index == amount - 1
	node.get_node("StumpCut").visible = amount == 0

static func _sync_generated_bounds(node: Node3D) -> void:
	if not node.has_meta("collider"): return
	var bounds := AABB()
	var first := true
	for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var transform_ := part.transform
		var visible_ := part.visible
		var parent := part.get_parent()
		while parent != node:
			visible_ = visible_ and parent.visible
			transform_ = parent.transform * transform_
			parent = parent.get_parent()
		if not visible_: continue
		var box := transform_ * part.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var shape: CollisionShape3D = node.get_meta("collider").get_child(0)
	shape.shape.size = bounds.size
	shape.position = bounds.get_center()
