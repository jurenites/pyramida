extends RefCounted
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
const Life = preload("res://scripts/settlement/structure_life.gd")
const HouseShell = preload("res://scripts/settlement/house_shell.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const COLOURS := {"stone": Color("d9b783"), "timber": Color("a7b08c"), "clay": Color("ce8061")}

static func material(colour: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = 1.0
	if colour.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result

static func box(root: Node3D, size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material(colour)
	root.add_child(node)
	return node

static func draw(root: Node3D, blueprint: Dictionary, floating: Array, preview := false, cutoff := 99, progress := 1.0) -> void:
	var ordered: Array = blueprint.cells.keys()
	ordered.sort_custom(func(a: Vector3i, b: Vector3i): return a.y < b.y)
	var index := 0
	for cell: Vector3i in ordered:
		if cell.y > cutoff:
			continue
		var colour: Color = COLOURS[blueprint.cells[cell]]
		if cell in floating:
			colour = Color("dd705d")
		if preview:
			colour.a = 0.67
		if float(index) >= progress * blueprint.cells.size():
			colour.a = 0.14
		index += 1
		var asset := Assets.create({"stone": "house", "timber": "log_shed", "clay": "workshop"}[blueprint.cells[cell]])
		root.add_child(asset)
		# One legacy room cell represents the game's two-metre building module.
		asset.scale = Vector3.ONE * 0.5
		asset.position = Vector3(cell)
		if blueprint.cells[cell] == "stone" and blueprint.cells.size() > 1:
			var neighbours: Array = []
			for side: Vector3i in Shape.SIDES:
				if blueprint.cells.has(cell + side): neighbours.append(side)
			var doors: Array = []
			for door: Dictionary in Life.doors(blueprint):
				if door.cell == cell: doors.append(door.side)
			HouseShell.apply(asset, neighbours, doors)
		if blueprint.cells.has(cell + Vector3i.UP):
			asset.get_node("Roof").visible = false
		if cell in floating:
			Assets.tint(asset, colour, preview)
		elif colour.a < 1.0:
			for mesh in asset.find_children("*", "MeshInstance3D", true, false):
				mesh.transparency = 1.0 - colour.a
	for brace: Dictionary in blueprint.braces:
		if brace.to.y > cutoff:
			continue
		# Anchor to the exterior face, so the diagonal is visible beside the wall.
		var face := Vector3(0, 0, 0.49) if brace.from.x != brace.to.x else Vector3(0.49, 0, 0)
		var a := Vector3(brace.from) + Vector3(0, 0.12, 0) + face
		var b := Vector3(brace.to) + Vector3(0, 0.06, 0) + face
		var vector := b - a
		var beam := box(root, Vector3(0.13, vector.length(), 0.13), (a + b) * 0.5, Color("64503c"))
		beam.quaternion = Quaternion(Vector3.UP, vector.normalized())

static func grid(root: Node3D, level: int, radius := 6, colour := Color("bfb6a2"), spacing := 1.0, corner_aligned := false) -> void:
	var mesh := ImmediateMesh.new()
	var mat := material(colour)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var offset := 0.0 if corner_aligned else -0.5
	for i in range(-radius, radius + 2):
		mesh.surface_add_vertex(Vector3((i + offset) * spacing, level + 0.015, (-radius + offset) * spacing))
		mesh.surface_add_vertex(Vector3((i + offset) * spacing, level + 0.015, (radius + 1 + offset) * spacing))
		mesh.surface_add_vertex(Vector3((-radius + offset) * spacing, level + 0.015, (i + offset) * spacing))
		mesh.surface_add_vertex(Vector3((radius + 1 + offset) * spacing, level + 0.015, (i + offset) * spacing))
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	root.add_child(node)

static func face_root(root: Node3D, entry: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(entry.cell)
	node.rotation.y = atan2(float(entry.side.x), float(entry.side.z))
	root.add_child(node)
	return node

static func details(root: Node3D, blueprint: Dictionary, connected: bool, cutoff := 99) -> void:
	for door: Dictionary in Life.doors(blueprint):
		if door.cell.y > cutoff: continue
		var face := face_root(root, door)
		var colour := Color("64452f") if connected else Color("f16b51")
		box(face, Vector3(0.36, 0.62, 0.035), Vector3(0, 0.32, 0.49), colour)
		box(face, Vector3(0.25, 0.53, 0.04), Vector3(0, 0.29, 0.515), Color("473e36"))
		box(face, Vector3(0.035, 0.035, 0.04), Vector3(0.075, 0.28, 0.54), Color("ffc471"))
	for entry: Dictionary in blueprint.get("ladders", []):
		if entry.cell.y > cutoff: continue
		var face := face_root(root, entry)
		for x in [-0.18, 0.18]:
			box(face, Vector3(0.045, 1.08, 0.05), Vector3(x, 0.54, 0.57), Color("9d7952"))
		for i in 6:
			box(face, Vector3(0.4, 0.035, 0.05), Vector3(0, 0.12 + i * 0.17, 0.59), Color("d6b482"))
	for entry: Dictionary in blueprint.get("utilities", []):
		if entry.cell.y > cutoff: continue
		var face := face_root(root, entry)
		face.position += face.basis * Vector3(entry.offset.x, entry.offset.y if entry.mount == "wall" else 0.18, 0.0 if entry.mount == "wall" else 0.22)
		if entry.kind == "ac":
			box(face, Vector3(0.32, 0.25, 0.17), Vector3(0, 0, 0.56), Color("e1d8b7"))
			for i in 4:
				box(face, Vector3(0.22, 0.018, 0.018), Vector3(0, -0.075 + i * 0.05, 0.655), Color("817869"))
			box(face, Vector3(0.025, 0.26, 0.025), Vector3(0.12, -0.18, 0.5), Color("9d7952"))
		else:
			box(face, Vector3(0.035, 0.3, 0.04), Vector3(0, -0.1, 0.58), Color("817869"))
			var dish := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.19
			mesh.height = 0.38
			dish.mesh = mesh
			dish.scale = Vector3(1, 1, 0.22)
			dish.position = Vector3(0, 0.08, 0.64)
			dish.rotation.x = -0.35
			dish.material_override = material(Color("e8dfc7"))
			face.add_child(dish)
			box(face, Vector3(0.025, 0.025, 0.2), Vector3(0, 0.04, 0.75), Color("817869"))
