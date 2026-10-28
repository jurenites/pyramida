extends RefCounted
## Disposable, seeded imperfections on placed geometry. Authoring stays exact.
const Catalog = preload("res://data/settlement/catalog.gd")
const MAX_DEVIATION := 0.1
const EXCLUDED_BRANCHES := ["EconomyStock", "ConstructionCorners", "ConstructionFrame", "Rotor", "Plants"]

static func applies(kind: String) -> bool:
	return kind in Catalog.COSTS and not Catalog.DEFINITIONS.get(kind, {}).get("living", false) and kind not in ["garden", "hay_field", "soil_bed"]

static func apply(root: Node3D, kind: String, cell: Vector3i, world_seed: int) -> void:
	if not applies(kind): return
	var identity := "%d|%s|%d,%d,%d" % [world_seed, kind, cell.x, cell.y, cell.z]
	for part: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null or _excluded(root, part): continue
		var profile := _profile(part, kind)
		if profile.is_empty(): continue
		var pose := _pose(root, part)
		var stamp := [identity, pose, profile]
		var previous: Dictionary = part.get_meta("building_variation", {})
		if previous.get("mesh") == part.mesh and previous.get("stamp") == stamp: continue
		# A tier upgrade may replace the mesh. Always start from that fresh source;
		# cursor movement instead reuses the original, never accumulating offsets.
		var source: Mesh = previous.source if previous.get("mesh") == part.mesh else part.mesh
		var path := str(root.get_path_to(part))
		var varied := _mesh(source, pose, identity, path, profile)
		part.mesh = varied
		part.set_meta("building_variation", {"source": source, "mesh": varied, "stamp": stamp})

static func _excluded(root: Node3D, part: Node3D) -> bool:
	var ancestor: Node = part
	while ancestor != root:
		if str(ancestor.name) in EXCLUDED_BRANCHES or ancestor.get_meta("variation_exempt", false): return true
		ancestor = ancestor.get_parent()
	return false

static func _profile(part: MeshInstance3D, kind: String) -> String:
	var label := str(part.name).to_lower()
	if part.has_meta("timber_stock"): return str(part.get_meta("timber_stock"))
	if kind == "road": return "paving"
	if label.begins_with("wellstone") or label.begins_with("cornerstone") or label.begins_with("stonefoot"): return "stone"
	if "wall" in label or label.begins_with("doorside") or label.begins_with("cap"): return "shell"
	return ""

static func _pose(root: Node3D, part: Node3D) -> Transform3D:
	var result := part.transform
	var parent := part.get_parent() as Node3D
	while parent != root:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result

static func _rng(identity: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = identity.sha256_text().substr(0, 15).hex_to_int()
	return rng

static func _mesh(source: Mesh, pose: Transform3D, identity: String, path: String, profile: String) -> ArrayMesh:
	var rng := _rng(identity + "|" + ("shell" if profile == "shell" else path))
	var bounds := pose * source.get_aabb()
	var centre := bounds.get_center()
	var shift := Vector3.ZERO
	var turn := Basis.IDENTITY
	var corners: Array[Vector3] = []
	if profile in ["log", "plank"]:
		# Rigid stock retains its length, thickness and diameter. Separate board
		# courses acquire staggered ends, like hand-laid walkway planks.
		var along_x := bounds.size.x >= bounds.size.z
		var long_shift := rng.randf_range(-0.075, 0.075) if profile == "plank" else rng.randf_range(-0.018, 0.018)
		var cross_shift := rng.randf_range(-0.008, 0.008)
		shift = Vector3(long_shift, 0, cross_shift) if along_x else Vector3(cross_shift, 0, long_shift)
		var radius := maxf(Vector2(bounds.size.x, bounds.size.z).length() * 0.5, 0.01)
		turn = Basis(Vector3.UP, rng.randf_range(-0.012, 0.012) / maxf(1.0, radius))
	else:
		var amount := 0.045 if profile == "shell" else 0.018
		# Narrow paving pieces need less crosswise movement to avoid overlaps.
		var limit := Vector3(amount, 0, amount)
		if profile == "paving":
			limit.x = minf(0.08, bounds.size.x * 0.10)
			limit.z = minf(0.08, bounds.size.z * 0.10)
		for corner in 4:
			corners.append(Vector3(rng.randf_range(-limit.x, limit.x), 0, rng.randf_range(-limit.z, limit.z)))
		# Walls and adjacent roof caps share one field, avoiding cracks between
		# pieces. The standard room is two metres wide; outside it clamp gently.
		if profile == "shell": bounds = AABB(Vector3(-1, 0, -1), Vector3(2, 1, 2))
	var result := ArrayMesh.new()
	var inverse := pose.affine_inverse()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in vertices.size():
			var point := pose * vertices[index]
			var displacement: Vector3
			var derivative := turn
			if corners.is_empty():
				displacement = turn * (point - centre) + centre + shift - point
			else:
				var u := clampf((point.x - bounds.position.x) / maxf(bounds.size.x, 0.001), 0, 1)
				var v := clampf((point.z - bounds.position.z) / maxf(bounds.size.z, 0.001), 0, 1)
				displacement = corners[0].lerp(corners[1], u).lerp(corners[2].lerp(corners[3], u), v)
				var dx := Vector3.RIGHT
				var dz := Vector3.BACK
				if point.x >= bounds.position.x and point.x <= bounds.end.x:
					dx += (corners[1] - corners[0]).lerp(corners[3] - corners[2], v) / maxf(bounds.size.x, 0.001)
				if point.z >= bounds.position.z and point.z <= bounds.end.z:
					dz += (corners[2] - corners[0]).lerp(corners[3] - corners[1], u) / maxf(bounds.size.z, 0.001)
				derivative = Basis(dx, Vector3.UP, dz)
			vertices[index] = inverse * (point + displacement)
			if index < normals.size():
				normals[index] = (pose.basis.transposed() * derivative.inverse().transposed() * pose.basis.inverse().transposed() * normals[index]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		var primitive: int = source.surface_get_primitive_type(surface) if source is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		result.add_surface_from_arrays(primitive, arrays)
		result.surface_set_material(surface, source.surface_get_material(surface))
	return result
