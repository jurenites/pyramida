extends RefCounted
## One physical corner post per connected building, including three/four-way joints.
const Houses = preload("res://scripts/settlement/house_groups.gd")
const Frame = preload("res://scripts/settlement/connected_frames.gd")
const SIGN := [Vector3i(-1, 0, -1), Vector3i(1, 0, -1), Vector3i(1, 0, 1), Vector3i(-1, 0, 1)]

static func sync(model, views: Dictionary) -> void:
	var nodes := {}
	for node: Node3D in views.values():
		var cell: Vector3i = node.get_meta("cell", Vector3i.ZERO)
		if node.get_meta("asset", "") == "house" and not node.get_meta("planned", false) and not node.has_meta("construction_parts") and Houses.is_house(model, cell): nodes[cell] = node
	var visited := {}
	for start: Vector3i in nodes:
		if visited.has(start): continue
		var rooms := Houses.members(model, start)
		var owners := {}; var inward := {}; var touching := {}
		for cell: Vector3i in rooms:
			visited[cell] = true
			if not nodes.has(cell): continue
			for sign_: Vector3i in SIGN:
				var corner := cell + sign_
				if not owners.has(corner): owners[corner] = cell
				inward[corner] = inward.get(corner, Vector3i.ZERO) - sign_
				touching[corner] = int(touching.get(corner, 0)) + 1
		for cell: Vector3i in rooms:
			if not nodes.has(cell): continue
			var node: Node3D = nodes[cell]
			var signature := [rooms, owners, touching, node.rotation.y]
			if node.get_meta("shared_post_signature", []) == signature: continue
			node.set_meta("shared_post_signature", signature.duplicate(true))
			if node.has_node("SharedPosts"): node.get_node("SharedPosts").free()
			for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				if mesh.has_meta("post_original_visible"):
					mesh.visible = mesh.get_meta("post_original_visible"); mesh.remove_meta("post_original_visible")
			if rooms.size() == 1: continue
			for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				if not mesh.has_meta("timber_stock") or mesh.mesh == null: continue
				if node.has_node("JoinedRoof") and node.get_node("JoinedRoof").is_ancestor_of(mesh): continue
				var pose := preload("res://scripts/settlement/timber_frame.gd").relative(node, mesh)
				var centre: Vector3 = (pose * mesh.mesh.get_aabb()).get_center()
				if absf(centre.x) < 0.65 or absf(centre.z) < 0.65 or centre.y < -0.1 or centre.y > 1.9: continue
				mesh.set_meta("post_original_visible", mesh.get_meta("join_original_visible", mesh.visible)); mesh.visible = false
			var posts := Node3D.new(); posts.name = "SharedPosts"; posts.set_meta("variation_exempt", true); node.add_child(posts)
			for i in 4:
				var corner: Vector3i = cell + SIGN[i]
				if owners.get(corner) != cell: continue
				# At a concave three-way corner the pillar fills the outside notch;
				# insetting it into the rooms would expose the dark interior beside it.
				var inset := 0.0 if touching[corner] == 3 else 0.12
				var at := node.basis.inverse() * (Vector3(corner - cell) + Vector3(inward[corner]).sign() * inset)
				Frame.member(posts, "Post%d" % i, at, at + Vector3.UP * 1.82)
				if touching[corner] in [2, 3] and inward[corner] != Vector3i.ZERO:
					# Close the small plaster-to-round-post gap at an inside corner.
					# These are wall-end blocks, not additional timber supports.
					var outward := -Vector3(inward[corner]).sign()
					var wall := node.get_node("PlasterWall") as MeshInstance3D
					var bounds: AABB = wall.transform * wall.mesh.get_aabb()
					var bottom := maxf(0, bounds.position.y); var top := minf(1.75, bounds.end.y)
					for axis in [0, 2]:
						if touching[corner] == 2 and is_zero_approx(outward[axis]): continue
						var infill := MeshInstance3D.new(); infill.name = "Infill%d_%d" % [i, axis]
						var box := BoxMesh.new(); box.size = Vector3(0.22, top - bottom, 0.32) if axis == 0 else Vector3(0.32, top - bottom, 0.22)
						infill.mesh = box; infill.material_override = wall.get_active_material(0)
						var point := Vector3(corner - cell) + (outward * 0.02 if touching[corner] == 3 else Vector3.ZERO)
						point[axis] = corner[axis] - cell[axis] - outward[axis] * 0.17; point.y = (top + bottom) / 2
						infill.transform = Transform3D(node.basis.inverse(), node.basis.inverse() * point)
						posts.add_child(infill)
			Frame.Timber.rebuild(posts); Frame.Illustration.apply(posts, false, true)
