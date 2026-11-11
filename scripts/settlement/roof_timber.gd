extends RefCounted
## Seat whole timber pieces below the roof. Overlap the upper stock; never stretch it.
const Frame = preload("res://scripts/settlement/timber_frame.gd")

static func excess(mesh: Mesh, pose: Transform3D, ceiling: Callable, index := -1, count := 1) -> float:
	var amount := 0.0
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		var size: int = vertices.size() / count
		for i in range(0 if index < 0 else index * size, vertices.size() if index < 0 else (index + 1) * size):
			var at := pose * vertices[i]
			amount = maxf(amount, at.y - float(ceiling.call(at)))
	return amount

static func fit(root: Node3D, ceiling: Callable) -> void:
	var loose := {}
	for part: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if part.get_meta("timber_stock", "") != "log" or part.mesh == null: continue
		if part.has_meta("roof_original_mesh"): part.mesh = part.get_meta("roof_original_mesh")
		var count := int(part.get_meta("timber_count", 0))
		if count == 0:
			if part.name == "Bark": loose[part.get_parent()] = true
			continue
		if not part.is_visible_in_tree() or part.layers == 0: continue
		var pose := Frame.relative(root, part); var drops: Array[float] = []; var changed := false
		for index in count:
			var drop := excess(part.mesh, pose, ceiling, index, count)
			drops.append(drop); changed = changed or drop > 0.0001
		if not changed: continue
		if not part.has_meta("roof_original_mesh"): part.set_meta("roof_original_mesh", part.mesh)
		var fitted := ArrayMesh.new()
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
			var size: int = vertices.size() / count
			for index in count:
				var offset := pose.basis.inverse() * Vector3.DOWN * drops[index]
				for i in range(index * size, (index + 1) * size): vertices[i] += offset
			arrays[Mesh.ARRAY_VERTEX] = vertices
			fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			fitted.surface_set_material(surface, part.mesh.surface_get_material(surface))
		part.mesh = fitted
		# The placement variation has already run. Do not vary the fitted result
		# again on the next inventory update and slowly drift through the roof.
		part.set_meta("variation_exempt", true)
	for log_: Node3D in loose:
		if log_.has_meta("roof_original_pose"): log_.transform = log_.get_meta("roof_original_pose")
		var drop := 0.0
		for part in log_.get_children():
			if part is MeshInstance3D and part.is_visible_in_tree() and part.layers != 0:
				drop = maxf(drop, excess(part.mesh, Frame.relative(root, part), ceiling))
		if drop <= 0.0001: continue
		if not log_.has_meta("roof_original_pose"): log_.set_meta("roof_original_pose", log_.transform)
		var parent_pose := Transform3D.IDENTITY if log_.get_parent() == root else Frame.relative(root, log_.get_parent())
		log_.position += parent_pose.basis.inverse() * Vector3.DOWN * drop
		log_.set_meta("variation_exempt", true)
	# Construction/deconstruction must discover the new rigid poses.
	root.remove_meta("timber_frame_slots")
