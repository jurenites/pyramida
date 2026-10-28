extends RefCounted
## Reuse the authored masonry and canopy; storage units determine the silhouette.
const Illustration = preload("res://scripts/settlement/illustration_style.gd")

static func sync(node: Node3D, count: int, water: int, capacity: int, wrapped := false) -> void:
	var tier := clampi(count, 1, 3)
	for child in node.get_children():
		if child is MeshInstance3D and not child.has_meta("well_transform"):
			child.set_meta("well_transform", child.transform)
		if not child.has_meta("well_transform"): continue
		child.transform = child.get_meta("well_transform")
		var part := str(child.name)
		if part.begins_with("WellStone"):
			child.visible = tier >= 2 or wrapped
		elif part in ["WellPost", "WellPost2", "Axle", "Rope", "Canopy"] or part.begins_with("Pot"):
			child.visible = tier >= 3 and not wrapped
	if not node.has_node("WellHole"):
		var hole := MeshInstance3D.new()
		hole.name = "WellHole"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.32
		mesh.bottom_radius = 0.32
		mesh.height = 0.025
		mesh.radial_segments = 12
		hole.mesh = mesh
		hole.position.y = 0.025
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("4c5040")
		hole.material_override = Illustration.flat(material)
		node.add_child(hole)
	node.get_node("WellHole").position.y = 0.025 if tier == 1 and not wrapped else (0.28 if not wrapped else 0.30)
	node.get_node("WellHole").scale = Vector3.ONE if tier == 1 and not wrapped else Vector3(0.7, 1, 0.7)
	var surface := node.get_node_or_null("Water") as MeshInstance3D
	if surface != null:
		surface.visible = water > 0
		surface.position.y = 0.045 if tier == 1 and not wrapped else (0.30 if not wrapped else 0.32)
		surface.scale.x *= lerpf(0.8, 1.0, float(water) / maxi(1, capacity))
		surface.scale.z *= lerpf(0.8, 1.0, float(water) / maxi(1, capacity))
	var body: StaticBody3D = node.get_meta("collider") if node.has_meta("collider") else null
	if body != null and not wrapped:
		var collision := body.get_child(0) as CollisionShape3D
		var height := [0.15, 0.42, 1.85][tier - 1] as float
		collision.shape.size = Vector3(0.95, height, 0.95)
		collision.position.y = height * 0.5

static func wrap(node: Node3D) -> void:
	# A roofed utility with an open front and visible water, without a house door.
	for spec in [["BackWall", Vector3(1.9, 1.7, 0.15), Vector3(0, 0.85, -0.85)],
		["SideWall", Vector3(0.15, 1.0, 1.7), Vector3(-0.85, 0.5, 0)],
		["SideWall2", Vector3(0.15, 1.0, 1.7), Vector3(0.85, 0.5, 0)]]:
		var piece := MeshInstance3D.new()
		piece.name = spec[0]
		var mesh := BoxMesh.new()
		mesh.size = spec[1]
		piece.mesh = mesh
		piece.position = spec[2]
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("d9c9a4")
		material.roughness = 1.0
		piece.material_override = Illustration.flat(material)
		node.add_child(piece)
	var frame := node.get_node("StackSupport")
	frame.name = "UtilityFrame"
	frame.show()
	node.get_node("Roof").show()
	sync(node, 2, 3, 6, true)
