extends RefCounted
## Cut/arrange copies of the existing authored roofing pieces, not flat replacement assets.
const SOURCES := {"house": "Roof/Cap2", "log_shed": "Canopy/RoofCourse0"}
static var sources := {}

static func source(kind: String) -> Dictionary:
	if kind in ["hay", "imbrex"] and not sources.has(kind):
		var covering = preload("res://scripts/settlement/roof_covering.gd")
		var mesh_: ArrayMesh = covering.hay() if kind == "hay" else covering.imbrex()
		sources[kind] = {"mesh": mesh_, "bounds": mesh_.get_aabb(), "component": "ThatchSheaf" if kind == "hay" else "Imbrex", "thickness": 0.14, "width": 0.28, "step": 0.24 if kind == "hay" else 0.27}
	if not sources.has(kind):
		var root := (load("res://data/settlement/%s.tscn" % kind) as PackedScene).instantiate()
		var part := root.get_node(SOURCES[kind]) as MeshInstance3D
		sources[kind] = {"mesh": part.mesh, "bounds": part.mesh.get_aabb(), "component": SOURCES[kind],
			"thickness": 0.12 if kind == "house" else 0.07, "width": 0.39 if kind == "house" else 0.34,
			"step": 1.0 / 3.0 if kind == "house" else 2.0 / 7.0}
		root.free()
	return sources[kind]

static func variation(seed_: int, axis: int, side: int, ridge: float, column: int) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = hash([seed_, axis, side, roundi(ridge * 1000), column])
	return {"angle": rng.randf_range(-0.022, 0.022), "length": rng.randf_range(1.53, 1.63),
		"shade": rng.randf_range(0.94, 1.04), "lift": 0.045 * posmod(column, 2)}

static func board_pose(kind: String, axis: int, side: int, ridge: float, column: int, eave: float, style: Dictionary) -> Transform3D:
	var stock := source(kind); var across := 2 - axis
	var down := Vector3.ZERO; down[across] = side; down.y = -1; down = down.normalized()
	var up := Vector3.ZERO; up[across] = side; up.y = 1; up = up.normalized()
	var size: Vector3 = stock.bounds.size
	var basis := Basis(down * style.length / size.x, up * stock.thickness / size.y, down.cross(up) * stock.width / size.z) if kind in ["house", "hay"] else Basis(up.cross(down) * stock.width / size.x, up * stock.thickness / size.y, down * style.length / size.z)
	basis = Basis(up, style.angle) * basis
	var at := Vector3.ZERO; at[axis] = (column + 0.5) * stock.step; at[across] = ridge + side * 0.5; at.y = eave + 0.5
	at += up * (-stock.thickness / 2 + style.lift)
	return Transform3D(basis, at - basis * stock.bounds.get_center())

static func faces(kind: String, pose: Transform3D) -> Array:
	var result: Array = []; var mesh: Mesh = source(kind).mesh
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface); var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		for i in range(0, indices.size() if not indices.is_empty() else vertices.size(), 3):
			var face: Array = []
			for j in 3: face.append(pose * vertices[indices[i + j] if not indices.is_empty() else i + j])
			result.append(face)
	return result

static func clip(faces_: Array, normal: Vector3, origin: Vector3, margin: float) -> Array:
	var result: Array = []; var intersections := {}
	for face: Array in faces_:
		var cut: Array = []; var previous: Vector3 = face.back()
		var before := normal.dot(previous - origin) + margin
		for point: Vector3 in face:
			var distance := normal.dot(point - origin) + margin
			if (distance >= 0) != (before >= 0):
				var crossing := previous.lerp(point, before / (before - distance)); cut.append(crossing)
				intersections[Vector3i((crossing * 100000).round())] = crossing
			if distance >= 0: cut.append(point)
			previous = point; before = distance
		if cut.size() >= 3: result.append(cut)
	if intersections.size() >= 3:
		var cap: Array = intersections.values(); var centre := Vector3.ZERO
		for point: Vector3 in cap: centre += point
		centre /= cap.size()
		var u := normal.cross(Vector3.UP).normalized(); var v := normal.cross(u)
		cap.sort_custom(func(a, b): return atan2((a-centre).dot(v), (a-centre).dot(u)) < atan2((b-centre).dot(v), (b-centre).dot(u)))
		result.append(cap)
	return result

static func emit(tool: SurfaceTool, faces_: Array, shade: float) -> void:
	var inside := Vector3.ZERO; var count := 0
	for face: Array in faces_:
		for point: Vector3 in face: inside += point; count += 1
	if count == 0: return
	inside /= count
	for face: Array in faces_:
		for i in range(1, face.size() - 1):
			var a: Vector3 = face[0]; var b: Vector3 = face[i]; var c: Vector3 = face[i + 1]
			var normal := (b - a).cross(c - a)
			if normal.length_squared() < 0.000000001: continue
			if normal.dot((a + b + c) / 3 - inside) < 0: normal = -normal
			normal = normal.normalized(); var triangle := [a, b, c]
			if (b - a).cross(c - a).dot(normal) > 0: triangle.reverse()
			var value := shade * (0.80 + 0.20 * maxf(0, normal.dot(Vector3(-0.4, 0.8, 0.6).normalized())))
			for point: Vector3 in triangle:
				tool.set_normal(normal); tool.set_color(Color(value, value, value)); tool.add_vertex(point)

static func exterior_margin(a: Vector3, b: Vector3, tile: Vector2i, shape: Dictionary) -> float:
	if shape.get("shed", false):
		if (is_equal_approx(a.x, b.x) and is_equal_approx(absf(a.x), 0.5)) or (is_equal_approx(a.z, b.z) and is_equal_approx(absf(a.z), 1)): return 0.13
		return 0.0
	for axis in [0, 2]:
		var i: int = axis / 2
		for sign_ in [-1, 1]:
			var edge: float = tile[i] + (1 if sign_ > 0 else 0); var neighbour := tile; neighbour[i] += sign_
			if is_equal_approx(a[axis], edge) and is_equal_approx(b[axis], edge) and not shape.tiles.has(neighbour) and not shape.get("covered", {}).has(neighbour): return 0.13
	return 0.0

static func mesh(surface: ArrayMesh, tile: Vector2i, shape: Dictionary, seed_: int, kind := "house", eave := 1.85) -> ArrayMesh:
	var vertices: PackedVector3Array = surface.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stock := source(kind)
	for i in range(0, vertices.size(), 3):
		var triangle := [vertices[i], vertices[i + 1], vertices[i + 2]]
		var normal: Vector3 = (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).normalized()
		if normal.y < 0: normal = -normal
		if normal.y < 0.1: continue
		var axis := 2 if absf(normal.x) > absf(normal.z) else 0; var across := 2 - axis
		var side := 1 if normal[across] >= 0 else -1
		var centre: Vector3 = (triangle[0] + triangle[1] + triangle[2]) / 3
		var ridge := snappedf(centre[across] + side * (centre.y - eave - 1), 0.001)
		var low: float = minf(triangle[0][axis], minf(triangle[1][axis], triangle[2][axis]))
		var high: float = maxf(triangle[0][axis], maxf(triangle[1][axis], triangle[2][axis]))
		for column in range(floori(low / stock.step) - 1, ceili(high / stock.step) + 1):
			var style := variation(seed_, axis, side, ridge, column)
			var pieces_poses: Array = preload("res://scripts/settlement/roof_covering.gd").poses(kind, axis, side, ridge, column, eave, seed_) if kind in ["hay", "imbrex"] else [{"pose":board_pose(kind, axis, side, ridge, column, eave, style), "shade":style.shade}]
			for piece: Dictionary in pieces_poses:
				var pieces := faces(kind, piece.pose)
				for edge in 3:
					var a: Vector3 = triangle[edge]; var b: Vector3 = triangle[(edge + 1) % 3]
					var inward := Vector3(a.z - b.z, 0, b.x - a.x).normalized()
					if inward.dot(centre - a) < 0: inward = -inward
					pieces = clip(pieces, inward, a, exterior_margin(a, b, tile, shape))
					if pieces.is_empty(): break
				emit(tool, pieces, piece.shade)
	return tool.commit()
