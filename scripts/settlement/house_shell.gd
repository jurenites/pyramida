extends RefCounted
## Joined rooms open their common wall; boundary portals use shared timber stock.
const Frame = preload("res://scripts/settlement/connected_frames.gd")
const WALLS := ["PlasterWall", "PlasterWall2", "BackWall", "DoorSide", "DoorSide2", "DoorLintel"]

static func apply(asset: Node3D, neighbours: Array, _doors: Array) -> void:
	var signature := [neighbours, asset.rotation.y]
	if asset.get_meta("house_join_signature", []) == signature: return
	asset.set_meta("house_join_signature", signature.duplicate(true))
	if asset.has_node("JoinedWalls"): asset.get_node("JoinedWalls").free()
	for mesh: MeshInstance3D in asset.find_children("*", "MeshInstance3D", true, false):
		if mesh.has_meta("join_original_visible"):
			mesh.visible = mesh.get_meta("join_original_visible")
			mesh.remove_meta("join_original_visible")
	for name_: String in WALLS:
		var wall := asset.get_node_or_null(name_) as Node3D
		if wall != null: wall.visible = true
	if neighbours.is_empty(): return
	var joins := Node3D.new(); joins.name = "JoinedWalls"
	joins.set_meta("variation_exempt", true); asset.add_child(joins)
	for side: Vector3i in neighbours:
		var local := asset.basis.inverse() * Vector3(side)
		var names: Array
		if absf(local.x) > 0.5: names = ["PlasterWall2" if local.x > 0 else "PlasterWall"]
		else: names = ["DoorSide", "DoorSide2", "DoorLintel"] if local.z > 0 else ["BackWall"]
		for name_: String in names:
			if asset.has_node(name_): asset.get_node(name_).visible = false
		# Authored timber along this wall is replaced by the single shared portal.
		for mesh: MeshInstance3D in asset.find_children("*", "MeshInstance3D", true, false):
			if joins.is_ancestor_of(mesh): continue
			if asset.has_node("SharedPosts") and asset.get_node("SharedPosts").is_ancestor_of(mesh): continue
			if not mesh.has_meta("timber_stock") and mesh.get_meta("source_component", "") not in WALLS: continue
			var pose := mesh.transform
			var parent := mesh.get_parent() as Node3D
			while parent != asset:
				pose = parent.transform * pose; parent = parent.get_parent() as Node3D
			var bounds: AABB = pose * mesh.mesh.get_aabb()
			var axis := 0 if absf(local.x) > 0.5 else 2
			var on_seam: bool = bounds.position[axis] > 0.65 if local[axis] > 0 else bounds.end[axis] < -0.65
			if on_seam:
				if not mesh.has_meta("join_original_visible"): mesh.set_meta("join_original_visible", mesh.get_meta("post_original_visible", mesh.visible))
				mesh.visible = false
		if side.x < 0 or side.z < 0: continue
		var normal := local.snapped(Vector3.ONE)
		var along := Vector3(-normal.z, 0, normal.x)
		Frame.member(joins, "Beam_%d_%d" % [side.x, side.z], normal - along * 0.9 + Vector3.UP * 1.84, normal + along * 0.9 + Vector3.UP * 1.84)
		var floor_ := MeshInstance3D.new(); floor_.name = "Threshold"
		var mesh := BoxMesh.new(); mesh.size = Vector3(0.30, 0.015, 1.55) if absf(normal.x) > 0.5 else Vector3(1.55, 0.015, 0.30)
		floor_.mesh = mesh; floor_.position = normal + Vector3.UP * 0.014
		var carpet := asset.get_node_or_null("EntranceCarpet") as MeshInstance3D
		if carpet != null: floor_.material_override = carpet.get_active_material(0)
		joins.add_child(floor_)
	Frame.Timber.rebuild(joins)
	Frame.Illustration.apply(joins, false, true)
