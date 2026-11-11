extends RefCounted
## Locate full stock in authored frames without changing their shape or source assets.
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const ORIGIN := Transform3D(Basis.IDENTITY, Vector3(0, -0.12, 0))

static func relative(root: Node3D, node: Node3D) -> Transform3D:
	var pose := node.transform
	var parent := node.get_parent()
	while parent != root:
		pose = parent.transform * pose
		parent = parent.get_parent()
	return pose

static func excluded(root: Node3D, node: Node) -> bool:
	while node != root:
		if node.name in ["ConstructionFrame", "ConstructionCorners", "StackSupport", "EconomyStock"] or node.has_meta("physical_timber") or node.has_meta("variation_exempt"): return true
		node = node.get_parent()
	return false

static func basis_from(a: Vector3, b: Vector3, c: Vector3) -> Basis:
	var x := (b - a).normalized()
	var z := x.cross(c - a).normalized()
	return Basis(x, z.cross(x), z)

static func slots(root: Node3D) -> Array[Dictionary]:
	if root.has_meta("timber_frame_slots"): return root.get_meta("timber_frame_slots")
	var result: Array[Dictionary] = []
	var source: Dictionary = Timber.sources("log")[0]
	var vertices: PackedVector3Array = source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in vertices.size(): vertices[i] = source.pose * vertices[i]
	var b := 0
	var c := 0
	for i in vertices.size():
		if vertices[0].distance_squared_to(vertices[i]) > vertices[0].distance_squared_to(vertices[b]): b = i
	for i in vertices.size():
		if (vertices[b]-vertices[0]).cross(vertices[i]-vertices[0]).length_squared() > (vertices[b]-vertices[0]).cross(vertices[c]-vertices[0]).length_squared(): c = i
	var source_basis := basis_from(vertices[0], vertices[b], vertices[c])
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if excluded(root, mesh) or mesh.get_meta("timber_stock", "") != "log": continue
		var count := int(mesh.get_meta("timber_count", 0))
		var parent_pose := relative(root, mesh)
		var loose := count == 0
		if loose:
			if mesh.name != "Bark": continue
			count = 1
		elif mesh.mesh.get_surface_count() != 3: continue
		var target: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if target.size() != vertices.size() * count: continue
		for slot in count:
			var offset := slot * vertices.size()
			var orientation := basis_from(target[offset], target[offset+b], target[offset+c]) * source_basis.transposed()
			var pose := Transform3D(orientation, target[offset] - orientation * vertices[0])
			var rigid := true
			for i in vertices.size():
				if (pose * vertices[i]).distance_to(target[offset+i]) > 0.0001: rigid = false; break
			if rigid and (parent_pose * pose).basis.get_scale().is_equal_approx(Vector3.ONE):
				result.append({"mesh": mesh, "index": -1 if loose else slot, "pose": parent_pose * pose * ORIGIN})
	# Start at the foot of upright frame members, then work up and across.
	result.sort_custom(func(a, b_):
		var upright_a: bool = absf(a.pose.basis.x.y) > 0.7
		var upright_b: bool = absf(b_.pose.basis.x.y) > 0.7
		if upright_a != upright_b: return upright_a
		return a.pose.origin.y < b_.pose.origin.y)
	root.set_meta("timber_frame_slots", result)
	return result

static func mask(slot: Dictionary) -> void:
	var node: MeshInstance3D = slot.mesh
	if slot.index == -1:
		for part in node.get_parent().get_children():
			if part is MeshInstance3D: part.layers = 0
		return
	if not node.has_meta("timber_original_mesh"):
		node.set_meta("timber_original_mesh", node.mesh)
		node.set_meta("timber_masked", {})
	var hidden: Dictionary = node.get_meta("timber_masked")
	if hidden.has(slot.index): return
	hidden[slot.index] = true
	var original: Mesh = node.get_meta("timber_original_mesh")
	if hidden.size() == int(node.get_meta("timber_count")):
		node.layers = 0
		return
	var replacement := ArrayMesh.new()
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		var per_log: int = arrays[Mesh.ARRAY_VERTEX].size() / int(node.get_meta("timber_count"))
		var indices := PackedInt32Array()
		var original_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, original_indices.size(), 3):
			@warning_ignore("integer_division")
			if hidden.has(original_indices[i] / per_log): continue
			indices.append_array(original_indices.slice(i, i + 3))
		arrays[Mesh.ARRAY_INDEX] = indices
		replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		replacement.surface_set_material(surface, original.surface_get_material(surface))
	node.mesh = replacement

static func extract(root: Node3D, slot: Dictionary, destination: Node3D) -> Node3D:
	var pose: Transform3D = root.global_transform * slot.pose
	var mesh: MeshInstance3D = slot.mesh
	var log_ := Node3D.new()
	destination.add_child(log_)
	log_.global_transform = pose
	log_.set_meta("physical_timber", true)
	log_.set_meta("variation_exempt", true)
	if slot.index == -1:
		# Loose authored logs retain their actual mesh nodes and materials.
		for part in mesh.get_parent().get_children():
			if part is MeshInstance3D:
				part.reparent(log_, true)
				part.visible = true
	else:
		# Batched assets have no individual scene node until separated. Extract
		# their shared stock meshes at the exact authored pose and keep materials.
		for index in Timber.sources("log").size():
			var source: Dictionary = Timber.sources("log")[index]
			var part := MeshInstance3D.new()
			part.name = ["Bark", "CutEnd", "CutEnd2"][index]
			part.mesh = source.mesh
			part.material_override = mesh.get_active_material(index)
			part.transform = ORIGIN.affine_inverse() * source.pose
			log_.add_child(part)
		mask(slot)
	return log_
