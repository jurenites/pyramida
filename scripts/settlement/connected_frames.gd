extends RefCounted
## Shared joints are rebuilt from adjacent module footprints, never stretched assets.
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const KINDS := ["stone_storage", "log_shed", "hay_barn", "brickyard"]
const SIGNS := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
const SIDES := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

static func frame_part(name_: String) -> bool:
	return name_.begins_with("Post") or name_.begins_with("ShedPost") or name_.begins_with("SideRail") or name_.begins_with("EndRail") or name_.begins_with("Upper") or name_.begins_with("Rail")

static func member(root: Node3D, name_: String, a: Vector3, b: Vector3) -> void:
	var part := MeshInstance3D.new(); part.name = name_
	var mesh := BoxMesh.new(); mesh.size = Vector3(0.18, 0.18, a.distance_to(b))
	part.mesh = mesh
	part.position = (a + b) / 2
	part.basis = Basis.looking_at(b - a, Vector3.RIGHT if absf((b - a).normalized().y) > 0.9 else Vector3.UP)
	root.add_child(part)

static func key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x * 1000), roundi(point.y * 1000), roundi(point.z * 1000))

static func linked(a: Dictionary, b: Dictionary) -> bool:
	if a.kind != b.kind or not is_equal_approx(a.at.y, b.at.y): return false
	if a.kind in ["log_shed", "hay_barn"] and a.direction != b.direction: return false
	var delta: Vector3 = a.basis.inverse() * (b.at - a.at)
	return (is_equal_approx(absf(delta.x), a.size.x) and is_zero_approx(delta.z)) or (is_equal_approx(absf(delta.z), a.size.z) and is_zero_approx(delta.x))

static func sync(model, views: Dictionary) -> void:
	var entries: Array[Dictionary] = []
	for cell: Vector3i in views:
		var node: Node3D = views[cell]
		var building: Dictionary = model.buildings.get(cell, {})
		if building.get("kind", "") not in KINDS or node.has_meta("construction_parts"): continue
		# Respect manually edited frames; the procedural source is still editable.
		if node.get_meta("custom_appearance", false): continue
		var direction: int = building.get("direction", 0)
		entries.append({"cell": cell, "node": node, "kind": building.kind, "direction": direction,
			"at": Vector3(cell) + building.get("placement_offset", Vector3.ZERO),
			"basis": Basis(Vector3.UP, -direction * PI / 2), "size": Catalog.Reviewed.size(building.kind)})
	entries.sort_custom(func(a, b): return a.cell.x < b.cell.x if a.cell.x != b.cell.x else (a.cell.z < b.cell.z if a.cell.z != b.cell.z else a.cell.y < b.cell.y))
	var visited := {}
	for start in entries.size():
		if visited.has(start): continue
		var group: Array[int] = [start]; visited[start] = true
		var cursor := 0
		while cursor < group.size():
			for candidate in entries.size():
				if not visited.has(candidate) and linked(entries[group[cursor]], entries[candidate]):
					visited[candidate] = true; group.append(candidate)
			cursor += 1
		group.sort()
		var owners := {}
		var inset_directions := {}
		for index in group:
			var entry := entries[index]
			for sign_: Vector2 in SIGNS:
				var corner: Vector3 = entry.at + entry.basis * Vector3(sign_.x * entry.size.x / 2, 0, sign_.y * entry.size.z / 2)
				if not owners.has(key(corner)): owners[key(corner)] = index
				inset_directions[key(corner)] = inset_directions.get(key(corner), Vector3.ZERO) + entry.basis * Vector3(-sign_.x, 0, -sign_.y)
		for index in group:
			var entry := entries[index]
			var joins: Array[bool] = [false, false, false, false]
			var beams: Array[bool] = [true, true, true, true]
			for other in group:
				if other == index or not linked(entry, entries[other]): continue
				var delta: Vector3 = entry.basis.inverse() * (entries[other].at - entry.at)
				var side := (1 if delta.x > 0 else 3) if absf(delta.x) > absf(delta.z) else (2 if delta.z > 0 else 0)
				joins[side] = true; beams[side] = index < other
			var posts: Array[bool] = []
			var corners: Array[Vector3] = []
			for sign_: Vector2 in SIGNS:
				var corner: Vector3 = entry.at + entry.basis * Vector3(sign_.x * entry.size.x / 2, 0, sign_.y * entry.size.z / 2)
				posts.append(owners[key(corner)] == index)
				var inward: Vector3 = inset_directions[key(corner)]
				inward = inward.snapped(Vector3.ONE).sign() * 0.12
				corners.append(entry.basis.inverse() * (corner + inward - entry.at))
			apply(entry.node, entry.size, joins, posts, beams, corners, group.size() > 1)

static func apply(node: Node3D, size: Vector3, joins: Array[bool], posts: Array[bool], beams: Array[bool], corners: Array[Vector3], connected: bool) -> void:
	var signature := [size, joins, posts, beams, corners, connected]
	if node.get_meta("frame_join_signature", []) == signature: return
	node.set_meta("frame_join_signature", signature.duplicate(true))
	if node.has_node("ConnectedFrame"): node.get_node("ConnectedFrame").free()
	for child in node.get_children():
		if not child is MeshInstance3D or not frame_part(str(child.name)): continue
		if not child.has_meta("standalone_frame_visible"): child.set_meta("standalone_frame_visible", child.visible)
		child.visible = false if connected else child.get_meta("standalone_frame_visible")
	if not connected: return
	var frame := Node3D.new(); frame.name = "ConnectedFrame"
	frame.set_meta("variation_exempt", true); node.add_child(frame)
	for i in 4:
		var at: Vector3 = corners[i]
		if posts[i]: member(frame, "Post%d" % i, at, at + Vector3.UP * size.y)
	for side in 4:
		if beams[side]: member(frame, "Beam%d" % side, corners[side] + Vector3.UP * (size.y - 0.12), corners[(side + 1) % 4] + Vector3.UP * (size.y - 0.12))
	Timber.rebuild(frame)
	Illustration.apply(frame, false, true)
