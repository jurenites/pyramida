extends RefCounted
## Mesh feature edges and screen-space area hits, preserving nested source poses.
const Kit = preload("res://scripts/settlement/structure_parts.gd")
static var edge_cache: Dictionary = {}

static func mesh_edges(mesh: Mesh) -> Array:
	if edge_cache.has(mesh): return edge_cache[mesh]
	var triangles := mesh.get_faces()
	var edges := {}
	for face in range(0, triangles.size(), 3):
		var normal := (triangles[face + 1] - triangles[face]).cross(triangles[face + 2] - triangles[face]).normalized()
		if normal.is_zero_approx(): continue
		for side in 3:
			var a := triangles[face + side]
			var b := triangles[face + (side + 1) % 3]
			# Weld duplicated UV/material/normal vertices without changing geometry.
			var qa := Vector3i((a * 100000).round())
			var qb := Vector3i((b * 100000).round())
			var key := [qa, qb] if qa < qb else [qb, qa]
			if not edges.has(key): edges[key] = {"a": a, "b": b, "normals": []}
			edges[key].normals.append(normal)
	var result: Array = edges.values()
	edge_cache[mesh] = result
	return result

static func outline(part: Dictionary, camera: Camera3D) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	for geometry: Dictionary in Kit.part_geometry(part):
		var pose: Transform3D = Kit.transform(part) * geometry.transform
		var normal_pose := pose.basis.inverse().transposed()
		for edge: Dictionary in mesh_edges(geometry.mesh):
			var a: Vector3 = pose * edge.a
			var b: Vector3 = pose * edge.b
			var view: Vector3 = camera.global_basis.z if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else camera.global_position - (a + b) * 0.5
			var normals: Array = edge.normals
			var first: Vector3 = (normal_pose * normals[0]).normalized()
			var visible_edge := normals.size() == 1
			for index in range(1, normals.size()):
				var other: Vector3 = (normal_pose * normals[index]).normalized()
				# Keep hard corners and curved silhouettes; omit coplanar diagonals.
				if first.dot(other) < cos(deg_to_rad(30)) or (first.dot(other) < 0.9999 and first.dot(view) * other.dot(view) <= 0):
					visible_edge = true
			if visible_edge: result.append(PackedVector3Array([a, b]))
	return result

static func intersects(part: Dictionary, rect: Rect2, camera: Camera3D) -> bool:
	var window := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	for geometry: Dictionary in Kit.part_geometry(part):
		var pose: Transform3D = Kit.transform(part) * geometry.transform
		var faces: PackedVector3Array = geometry.mesh.get_faces()
		for face in range(0, faces.size(), 3):
			var triangle := PackedVector2Array()
			for corner in 3:
				var point: Vector3 = pose * faces[face + corner]
				if camera.is_position_behind(point): break
				triangle.append(camera.unproject_position(point))
			if triangle.size() != 3: continue
			if not Geometry2D.intersect_polygons(triangle, window).is_empty(): return true
	return false
