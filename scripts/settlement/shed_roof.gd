extends RefCounted
const Boards = preload("res://scripts/settlement/roof_boards.gd")
const Timber = preload("res://scripts/settlement/roof_timber.gd")
const Style = preload("res://scripts/settlement/illustration_style.gd")
const EAVE := 1.16

static func surface() -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, EAVE + 1, -1); var b := Vector3(0.5, EAVE, -1)
	var c := Vector3(0.5, EAVE, 1); var d := Vector3(-0.5, EAVE + 1, 1)
	for point: Vector3 in [a, b, c, a, c, d]: tool.add_vertex(point)
	return tool.commit()

static func sync(node: Node3D, seed_: int) -> void:
	var canopy := node.get_node_or_null("Canopy") as Node3D
	var signature := [seed_, node.get_meta("frame_join_signature", [])]
	if canopy == null or node.get_meta("shed_roof_signature", []) == signature: return
	node.set_meta("shed_roof_signature", signature.duplicate(true))
	if canopy.has_node("GeneratedRoof"): canopy.get_node("GeneratedRoof").free()
	for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if canopy.is_ancestor_of(part) or str(part.get_meta("source_component", "")).begins_with("Canopy/RoofCourse"):
			part.visible = false
	var roof := MeshInstance3D.new(); roof.name = "GeneratedRoof"
	roof.mesh = Boards.mesh(surface(), Vector2i.ZERO, {"shed": true}, seed_, "log_shed", EAVE)
	roof.transform = canopy.transform.affine_inverse()
	roof.set_meta("source_component", "Canopy/RoofCourse0"); roof.set_meta("construction_role", "roof_cover"); roof.set_meta("variation_exempt", true)
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color("c19361"); paint.vertex_color_use_as_albedo = true
	roof.material_override = Style.shadowed(paint)
	canopy.add_child(roof)
	Timber.fit(node, func(at: Vector3): return EAVE + 0.5 - at.x - 0.11)
