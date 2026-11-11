extends RefCounted
## Floor-centred roof solids. Dimensions below are X (width), Y (rise), Z (depth).
const SIZES := {
	"roof_corner": Vector3(1, 1, 1),
	"roof_wedge": Vector3(1, 1, 1),
	"roof_long_wedge": Vector3(1, 1, 2),
	"roof_fat_wedge": Vector3(1, 0.5, 2),
}
const TITLES := {
	"roof_corner": "Roof corner",
	"roof_wedge": "Roof wedge",
	"roof_long_wedge": "Roof long wedge",
	"roof_fat_wedge": "Roof fat wedge",
}

static func polygon(tool: SurfaceTool, points: Array, inside: Vector3) -> void:
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	if normal.dot(points[0] - inside) < 0: normal = -normal
	for i in range(1, points.size() - 1):
		var triangle: Array = [points[0], points[i], points[i + 1]]
		# Godot front faces are clockwise, with explicit outward shading normals.
		if (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).dot(normal) > 0:
			triangle.reverse()
		for point: Vector3 in triangle:
			tool.set_normal(normal)
			var shade := 0.82 + 0.18 * maxf(0, normal.dot(Vector3(-0.4, 0.8, 0.6).normalized()))
			tool.set_color(Color(shade, shade, shade))
			tool.add_vertex(point)

static func mesh(kind: String) -> ArrayMesh:
	var size: Vector3 = SIZES[kind]
	var a := Vector3(-size.x / 2, 0, -size.z / 2)
	var b := Vector3(size.x / 2, 0, -size.z / 2)
	var c := Vector3(size.x / 2, 0, size.z / 2)
	var d := Vector3(-size.x / 2, 0, size.z / 2)
	var high := a + Vector3.UP * size.y
	var faces: Array
	var inside: Vector3
	if kind == "roof_corner":
		# Oblique square pyramid: apex above one corner, not the centre.
		faces = [[a, b, c, d], [a, b, high], [b, c, high], [c, d, high], [d, a, high]]
		inside = (a + b + c + d + high) / 5.0
	else:
		# High edge follows the long side; two units may meet along that edge.
		var end := d + Vector3.UP * size.y
		faces = [[a, b, c, d], [a, b, high], [b, c, end, high], [c, d, end], [d, a, high, end]]
		inside = (a + b + c + d + high + end) / 6.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in faces: polygon(tool, face, inside)
	return tool.commit()

static func create(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = kind.to_pascal_case()
	var cap := MeshInstance3D.new()
	cap.name = "RoofSlope"
	cap.set_meta("roof_component", kind)
	cap.mesh = mesh(kind)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("985549")
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true
	cap.material_override = material
	root.add_child(cap)
	return root
