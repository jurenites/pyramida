extends RefCounted
## Three silhouettes retain the authored saw bench and its access markers.
const Illustration = preload("res://scripts/settlement/illustration_style.gd")

static func piece(parent: Node3D, label: String, size: Vector3, at: Vector3, colour: String, tilt := 0.0) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.rotation.z = tilt
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour)
	node.material_override = Illustration.flat(material)
	parent.add_child(node)

static func sync(node: Node3D, tier: int) -> void:
	if not node.has_node("Sawhorses"):
		var horses := Node3D.new()
		horses.name = "Sawhorses"
		node.add_child(horses)
		for z in [-0.5, 0.5]:
			for angle in [-0.65, 0.65]:
				piece(horses, "CrossedLeg", Vector3(0.12, 0.88, 0.14), Vector3(0, 0.36, z), "886044", angle)
		piece(horses, "Timber", Vector3(0.24, 0.22, 1.65), Vector3(0, 0.71, 0), "bb935d")
		piece(horses, "HandSaw", Vector3(0.72, 0.045, 0.12), Vector3(0.23, 0.85, 0), "656b63", -0.18)
		var shell := Node3D.new()
		shell.name = "SawShed"
		node.add_child(shell)
		for x in [-0.84, 0.84]:
			piece(shell, "TimberSide", Vector3(0.1, 0.68, 1.65), Vector3(x, 0.42, 0), "a47a4c")
		piece(shell, "RearBoards", Vector3(1.75, 1.45, 0.1), Vector3(0, 0.8, -0.86), "a47a4c")
		piece(shell, "Lintel", Vector3(1.9, 0.18, 0.14), Vector3(0, 1.72, 0.86), "775238")
		for index in 3:
			piece(shell, "PlankStack", Vector3(0.38, 0.08, 1.2), Vector3(0.59, 0.16 + index * 0.10, 0.1), "dbb57c")
		preload("res://scripts/settlement/timber_kit.gd").rebuild(horses)
		preload("res://scripts/settlement/timber_kit.gd").rebuild(shell)
		Illustration.apply(horses)
		Illustration.apply(shell)
	for child in node.get_children():
		if child is MeshInstance3D and str(child.name) != "Floor": child.visible = tier >= 2
		if str(child.name).begins_with("@Node3D"): child.visible = tier >= 2
	node.get_node("Sawhorses").visible = tier == 1
	node.get_node("SawShed").visible = tier == 3
	node.get_node("Roof").visible = tier == 3
	node.get_node("StackSupport").visible = tier == 3
