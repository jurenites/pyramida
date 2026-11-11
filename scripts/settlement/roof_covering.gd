extends RefCounted
## Physical short roofing stock: tapered thatch sheaves and hollow clay tiles.
const Kit = preload("res://scripts/settlement/roof_kit.gd")
static func imbrex() -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Five broad facets describe a curved shell with visible thin end walls.
	for segment in 5:
		var a := -PI / 2 + segment * PI / 5; var b := a + PI / 5
		var points: Array = []
		for x in [-0.22, 0.22]:
			var taper := 0.90 if x < 0 else 1.0
			for r in [0.165, 0.139]:
				for angle in [a,b]: points.append(Vector3(x, cos(angle) * r * 0.78, sin(angle) * r * taper))
		var centre := Vector3.ZERO
		for p: Vector3 in points: centre += p / 8
		for face in [[0,1,5,4],[2,6,7,3],[0,2,3,1],[4,5,7,6],[0,4,6,2],[1,3,7,5]]:
			var polygon: Array = []
			for index in face: polygon.append(points[index])
			Kit.polygon(tool, polygon, centre)
	return tool.commit()

static func hay() -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Dense straw inside each sheaf closes pinholes between the loose surface stalks.
	var core := [Vector3(-0.30,-0.055,-0.145),Vector3(-0.30,-0.055,0.145),Vector3(0.30,-0.055,0.145),Vector3(0.32,-0.055,-0.145),Vector3(-0.30,-0.012,-0.145),Vector3(-0.30,-0.012,0.145),Vector3(0.30,-0.012,0.145),Vector3(0.32,-0.012,-0.145)]
	for face in [[0,1,2,3],[4,7,6,5],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
		var polygon: Array = []
		for index in face: polygon.append(core[index])
		Kit.polygon(tool,polygon,Vector3(0,-0.035,0))
	# Unequal tapered stalk clusters leave a ragged fringe at each overlapping course.
	for stalk in 7:
		var z := (stalk - 3) * 0.039
		var tip := 0.29 + 0.028 * sin(stalk * 7.3)
		var back := -0.29 + 0.019 * cos(stalk * 4.2)
		var y := 0.025 * sin(stalk * 3.1)
		var rings: Array = []
		for end in 2:
			var ring: Array = []
			for corner in 5:
				var angle := TAU * corner / 5
				var radius := 0.032 if end == 1 else 0.014
				ring.append(Vector3(tip if end == 1 else back, y + sin(angle) * radius, z + cos(angle) * radius))
			rings.append(ring)
		var centre := Vector3(0, y, z)
		for ring: Array in rings: Kit.polygon(tool, ring, centre)
		for corner in 5: Kit.polygon(tool, [rings[0][corner],rings[0][(corner+1)%5],rings[1][(corner+1)%5],rings[1][corner]], centre)
	return tool.commit()

static func poses(kind: String, axis: int, side: int, ridge: float, column: int, eave: float, seed_: int) -> Array:
	var result: Array = []; var across := 2 - axis
	var down := Vector3.ZERO; down[across] = side; down.y = -1; down = down.normalized()
	var normal := Vector3.ZERO; normal[across] = side; normal.y = 1; normal = normal.normalized()
	var hay_ := kind == "hay"; var step := 0.24 if hay_ else 0.27
	for row in 5:
		var rng := RandomNumberGenerator.new(); rng.seed = hash([seed_, axis, side, ridge, column, row])
		var at := Vector3.ZERO; at[across] = ridge; at.y = eave + 1
		at += down * (0.20 + row * 0.30)
		at[axis] = (column + 0.5 + (0.5 if hay_ and row % 2 else 0.0)) * step
		at += normal * (0.045 + (4-row) * (0.022 if hay_ else 0.032))
		var basis := Basis(down, normal, down.cross(normal))
		basis = Basis(normal, rng.randf_range(-0.045,0.045) if hay_ else rng.randf_range(-0.009,0.009)) * basis
		basis.x *= rng.randf_range(0.92,1.14) if hay_ else 1.0
		basis.y *= 1.35 if hay_ else 1.0
		result.append({"pose":Transform3D(basis,at), "shade":rng.randf_range(0.86,1.08) if hay_ else rng.randf_range(0.94,1.05)})
	return result

static func ridge(root: Node3D, a: Vector2, b: Vector2, y: float, kind: String, material: Material) -> void:
	var direction := Vector3(b.x-a.x, 0, b.y-a.y).normalized()
	for index in 3:
		var part := MeshInstance3D.new(); part.name = "RidgeCover_%d_%d_%d_%d_%d" % [roundi(a.x),roundi(a.y),roundi(b.x),roundi(b.y),index]
		part.mesh = hay() if kind == "hay" else imbrex()
		part.material_override = material
		var point := a.lerp(b, (index + 0.5) / 3.0)
		part.transform = Transform3D(Basis(direction * 0.9, Vector3.UP * (2.8 if kind == "hay" else 1.0), direction.cross(Vector3.UP) * 1.7), Vector3(point.x, y + 0.17, point.y))
		part.set_meta("source_component", "ThatchSheaf" if kind == "hay" else "Imbrex")
		root.add_child(part)
