extends RefCounted
const Boards = preload("res://scripts/settlement/roof_boards.gd")
const Kit = preload("res://scripts/settlement/roof_kit.gd")
const Style = preload("res://scripts/settlement/illustration_style.gd")
const EAVE := 1.12

static func surface() -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var source := Kit.mesh("roof_corner").surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	for side in 2:
		var pose := Transform3D(Basis(Vector3.UP, PI / 2 if side == 0 else 0.0), Vector3(0, EAVE, -0.5 if side == 0 else 0.5))
		for i in range(0, vertices.size(), 3):
			if normals[i].y <= 0.1: continue
			for j in 3: tool.add_vertex(pose * vertices[i + j])
	return tool.commit()

static func populate(canopy: Node3D, seed_: int) -> void:
	var roof := MeshInstance3D.new(); roof.name = "PlankRoof"
	roof.mesh = Boards.mesh(surface(), Vector2i.ZERO, {"shed": true}, seed_, "log_shed", EAVE)
	roof.set_meta("source_component", "Canopy/RoofCourse0"); roof.set_meta("roof_material", "plank"); roof.set_meta("variation_exempt", true)
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color("c19361"); paint.vertex_color_use_as_albedo = true; roof.material_override = paint
	canopy.add_child(roof)

static func sync(node: Node3D, seed_: int) -> void:
	var canopy := node.get_node_or_null("Canopy") as Node3D
	if canopy == null or node.get_meta("barn_roof_seed", -1) == seed_: return
	node.set_meta("barn_roof_seed", seed_)
	for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if canopy.is_ancestor_of(part) or str(part.get_meta("source_component", "")).begins_with("Canopy/"): part.visible = false
	if canopy.has_node("GeneratedRoof"): canopy.get_node("GeneratedRoof").free()
	var roof := Node3D.new(); roof.name = "GeneratedRoof"; roof.transform = canopy.transform.affine_inverse(); canopy.add_child(roof)
	populate(roof, seed_); Style.apply(roof, false, true)
