extends SceneTree
const Rig = preload("res://scripts/settlement/citizen_rig.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var variant := args[0] if not args.is_empty() else "man"
	assert(variant in ["man", "woman", "child"])
	var stem := "reference_" + variant
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/tmp/pyramida-reference-%s/%s.json" % [variant, stem]))
	var body := mesh_from(data.body, [0], Color("373b60"))
	var full_body := mesh_from(data.body, [0, 1], Color("373b60"))
	var cloth_color := Color("f18480") if variant == "woman" else Color("dfa438") if variant == "child" else Color("da783b")
	var cloth := mesh_from(data.shorts, [0], cloth_color)
	# The skirt must stay coral when its inner side is visible during a step.
	if variant == "woman": cloth.surface_get_material(0).cull_mode = BaseMaterial3D.CULL_DISABLED
	assert(ResourceSaver.save(body, "res://data/settlement/citizens/%s.res" % stem) == OK)
	assert(ResourceSaver.save(full_body, "res://data/settlement/citizens/%s_unclothed.res" % stem) == OK)
	assert(ResourceSaver.save(cloth, "res://data/settlement/citizens/%s_shorts.res" % stem) == OK)
	var actor := Node3D.new()
	actor.name = "Reference" + variant.capitalize()
	actor.set_script(preload("res://scripts/settlement/reference_man_pose.gd"))
	if variant == "child": actor.Gait = load("res://data/settlement/reference_child_walk.tres")
	actor.scale = Vector3.ONE * float(data.get("scale", 1.0))
	actor.set_meta("variant", variant)
	actor.set_meta("clothed_mesh", body)
	actor.set_meta("unclothed_mesh", full_body)
	var centres: Array = []
	for p in data.centres: centres.append(Vector3(p[0], p[1], p[2]))
	Rig.populate_mesh(actor, body, centres)
	var samples := {8: [], 10: []}
	for raw in data.body.vertices:
		var point := Vector3(raw[0], raw[1], raw[2])
		if point.y > 0.061: continue
		var bone := 8 if point.x < 0 else 10
		if point not in samples[bone]: samples[bone].append(point)
	actor.set_meta("sole_samples", samples)
	var surface: MeshInstance3D = actor.get_node("Surface")
	surface.remove_meta("citizen_cloth_surface")
	attach(actor, "Shorts", cloth, true)
	for part_name: String in ["Top", "Hair"]:
		if not data.has(part_name.to_lower()): continue
		var paint := Color("11121a") if part_name == "Hair" else cloth_color
		var mesh := mesh_from(data[part_name.to_lower()], [0], paint)
		mesh.surface_get_material(0).cull_mode = BaseMaterial3D.CULL_DISABLED
		assert(ResourceSaver.save(mesh, "res://data/settlement/citizens/%s_%s.res" % [stem, part_name.to_lower()]) == OK)
		attach(actor, part_name, mesh, part_name == "Top")
	own(actor, actor)
	var scene := PackedScene.new(); assert(scene.pack(actor) == OK)
	assert(ResourceSaver.save(scene, "res://data/settlement/%s.tscn" % stem) == OK)
	# Interchange files keep the full editable body and all independent parts.
	actor.set_shorts_visible(false)
	for part: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false): part.show()
	var document := GLTFDocument.new(); var state := GLTFState.new()
	assert(document.append_from_scene(actor, state) == OK)
	assert(document.write_to_filesystem(state, "res://data/settlement/%s.glb" % stem) == OK)
	actor.free()
	print("PASS: imported ", variant, " study with independent clothing, hair and rigged GLB")
	quit()

func attach(actor: Node3D, part_name: String, mesh: Mesh, clothing: bool) -> void:
	var surface: MeshInstance3D = actor.get_node("Surface")
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.skin = surface.skin
	part.skeleton = surface.skeleton
	part.custom_aabb = surface.custom_aabb
	if clothing: part.set_meta("citizen_cloth", true)
	actor.add_child(part)

func mesh_from(data: Dictionary, surfaces: Array, color: Color) -> ArrayMesh:
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var bones := PackedInt32Array(); var weights := PackedFloat32Array(); var indices := PackedInt32Array()
	for surface in surfaces:
		for raw in data.surfaces[surface]:
			var index := int(raw)
			var p: Array = data.vertices[index]; var n: Array = data.normals[index]
			indices.append(vertices.size())
			vertices.append(Vector3(p[0], p[1], p[2])); normals.append(Vector3(n[0], n[1], n[2]))
			var tint: Array = data.colors[index]
			colors.append(Color(tint[0], tint[1], tint[2], tint[3]))
			for bone in data.bones[index]: bones.append(int(bone))
			for weight in data.weights[index]: weights.append(float(weight))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_BONES] = bones; arrays[Mesh.ARRAY_WEIGHTS] = weights; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1
	mesh.surface_set_material(0, material)
	return mesh

func own(node: Node, owner_: Node) -> void:
	for child in node.get_children():
		child.owner = owner_
		own(child, owner_)
