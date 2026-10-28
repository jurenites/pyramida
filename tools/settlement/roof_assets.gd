extends RefCounted
## Reusable roof coverings in metres. Exported meshes remain editable source assets.

static func material(hex: String, metal := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(hex)
	result.roughness = 0.72 if metal else 0.94
	result.metallic = 0.45 if metal else 0.0
	return result

static func face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var vertices := [a, c, b, a, d, c]
	if normal.dot(outward) < 0:
		normal = -normal
		vertices = [a, b, c, a, c, d]
	for point: Vector3 in vertices:
		tool.set_normal(normal)
		tool.add_vertex(point)

static func tile_point(angle: float, end: int, inside := false) -> Vector3:
	# Narrow head slips under the wider tail of the next overlapping tile.
	var width := 0.112 if end == 0 else 0.14
	var rise := 0.07 if end == 0 else 0.085
	return Vector3(cos(angle) * width, sin(angle) * rise + (0.0 if inside else 0.018), -0.23 if end == 0 else 0.23)

static func ceramic_tile(root: Node3D) -> void:
	var mesh := ArrayMesh.new()
	# Broad painted bands preserve the curved silhouette in unshaded presentation.
	for band in 3:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for step in range(band * 4, band * 4 + 4):
			var a := step * PI / 12.0
			var b := (step + 1) * PI / 12.0
			face(tool, tile_point(a, 0), tile_point(a, 1), tile_point(b, 1), tile_point(b, 0), Vector3(cos((a + b) / 2), 1, 0))
		tool.set_material(material(["b96b4b", "cf835b", "ac5b40"][band]))
		tool.commit(mesh)
	var lining := SurfaceTool.new()
	lining.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in 12:
		var a := step * PI / 12.0
		var b := (step + 1) * PI / 12.0
		face(lining, tile_point(a, 0, true), tile_point(a, 1, true), tile_point(b, 1, true), tile_point(b, 0, true), Vector3.DOWN)
		for end in 2:
			face(lining, tile_point(a, end), tile_point(b, end), tile_point(b, end, true), tile_point(a, end, true), Vector3.FORWARD if end == 0 else Vector3.BACK)
	for angle in [0.0, PI]:
		face(lining, tile_point(angle, 0), tile_point(angle, 1), tile_point(angle, 1, true), tile_point(angle, 0, true), Vector3.RIGHT if angle == 0 else Vector3.LEFT)
	lining.set_material(material("955037"))
	lining.commit(mesh)
	var tile := MeshInstance3D.new()
	tile.name = "CeramicTile"
	tile.mesh = mesh
	root.add_child(tile)

static func box(root: Node3D, name_: String, size: Vector3, at: Vector3, colour: String) -> void:
	var node := MeshInstance3D.new()
	node.name = name_
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(colour, true)
	node.position = at
	root.add_child(node)

static func metal_sheet(root: Node3D) -> void:
	# Simple single-pitch panel, with restrained standing seams and folded eaves.
	# The complete assembly can be rotated to any pitch in the asset editor.
	var slope := Node3D.new()
	slope.name = "Slope"
	root.add_child(slope)
	box(slope, "Sheet", Vector3(1.0, 0.018, 1.4), Vector3(0, 0.009, 0), "566267")
	for side in [-1, 1]:
		box(slope, "SeamLeft" if side < 0 else "SeamRight", Vector3(0.022, 0.035, 1.4), Vector3(side * 0.484, 0.0355, 0), "778084")
		box(slope, "HeadFold" if side < 0 else "EaveFold", Vector3(1, 0.03, 0.025), Vector3(0, 0.015, side * 0.6875), "424e53")
	slope.rotation.x = deg_to_rad(25)
	slope.position.y = sin(slope.rotation.x) * 0.7
