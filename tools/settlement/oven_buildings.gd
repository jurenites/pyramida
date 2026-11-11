extends RefCounted
const Frame = preload("res://scripts/settlement/structure_frame.gd")
const Boards = preload("res://scripts/settlement/roof_boards.gd")
const Kit = preload("res://scripts/settlement/roof_kit.gd")
const EAVE := 2.0

static func box(root: Node3D, label: String, at: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new(); part.name = label; part.position = at
	var mesh := BoxMesh.new(); mesh.size = size; part.mesh = mesh
	var paint := StandardMaterial3D.new(); paint.albedo_color = colour; paint.roughness = 1; part.material_override = paint
	root.add_child(part); return part

static func gable(root: Node3D, z: float, colour: Color) -> void:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.86, 1.80, z - 0.06); var b := Vector3(0.86, 1.80, z - 0.06); var c := Vector3(0, 2.80, z - 0.06)
	var d := a + Vector3(0, 0, 0.12); var e := b + Vector3(0, 0, 0.12); var f := c + Vector3(0, 0, 0.12)
	var inside := (a + b + c + d + e + f) / 6
	for face in [[a,b,c],[d,e,f],[a,b,e,d],[b,c,f,e],[c,a,d,f]]: Kit.polygon(tool, face, inside)
	var part := MeshInstance3D.new(); part.name = "Gable"; part.mesh = tool.commit()
	var paint := StandardMaterial3D.new(); paint.albedo_color = colour; paint.vertex_color_use_as_albedo = true; part.material_override = paint; root.add_child(part)

static func hay_bundle() -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ends: Array = []
	for x in [-0.5, 0.5]:
		var ring: Array = []
		for i in 6:
			var angle := TAU * i / 6
			ring.append(Vector3(x, sin(angle) * 0.072, cos(angle) * 0.5))
		ends.append(ring); Kit.polygon(tool, ring, Vector3.ZERO)
	for i in 6: Kit.polygon(tool, [ends[0][i], ends[0][(i+1)%6], ends[1][(i+1)%6], ends[1][i]], Vector3.ZERO)
	return tool.commit()

static func roof(root: Node3D, kind: String) -> void:
	var roof_ := Node3D.new(); roof_.name = "Roof"; roof_.set_meta("variation_exempt", true); root.add_child(roof_)
	var hay := kind == "bakery"; var bundle := hay_bundle() if hay else null
	var rng := RandomNumberGenerator.new(); rng.seed = 87 if hay else 41
	for side in [-1, 1]:
		for column in range(-9 if hay else -5, 10 if hay else 5):
			var part := MeshInstance3D.new(); part.name = ("HayBundle" if hay else "RoofPlank") + str(side) + "_" + str(column)
			var variation := Boards.variation(87 if hay else 41, 2, side, 0, column)
			part.mesh = bundle if hay else Boards.source("house").mesh
			part.transform = Boards.board_pose("house", 2, side, 0, column, EAVE, variation)
			if hay:
				part.basis.z *= 0.19 / 0.39; part.basis.y *= 1.4; part.position.z = column * 0.17
				part.position.y += 0.06
			part.set_meta("roof_material", "hay" if hay else "plank")
			part.set_meta("source_component", "HayBundle" if hay else "Roof/Cap2")
			var paint := StandardMaterial3D.new(); paint.albedo_color = Color("dfba6b").darkened(rng.randf_range(0, 0.09)) if hay else Color("c19361").darkened(rng.randf_range(0, 0.06)); paint.vertex_color_use_as_albedo = hay; part.material_override = paint
			roof_.add_child(part)
	if hay:
		var ridge := MeshInstance3D.new(); ridge.name = "HayRidge"
		var mesh := CylinderMesh.new(); mesh.top_radius = 0.13; mesh.bottom_radius = 0.13; mesh.height = 3.22; mesh.radial_segments = 6; ridge.mesh = mesh
		ridge.position.y = 3.02; ridge.rotation.x = PI / 2
		var paint := StandardMaterial3D.new(); paint.albedo_color = Color("c9a158"); ridge.material_override = paint; ridge.set_meta("roof_material", "hay"); roof_.add_child(ridge)
	else:
		var poses: Array[Transform3D] = []
		for z in Frame.Timber.centres(3.3, 0.7): poses.append(Transform3D(Basis(Vector3.UP, PI/2), Vector3(0, 3.16, z)))
		Frame.stock(roof_, "RidgePlanks", "plank", poses)
	# The intentional chimney penetrates the roof; the frame remains beneath it.
	box(root, "Flue", Vector3(0.48, 1.55, -0.75), Vector3(0.32, 0.70, 0.32), Color("b97356"))
	box(roof_, "Chimney", Vector3(0.48, 2.56, -0.75), Vector3(0.32, 1.32, 0.32), Color("b97356"))
	box(roof_, "ChimneyRim", Vector3(0.48, 3.22, -0.75), Vector3(0.42, 0.12, 0.42), Color("c78562"))
	box(roof_, "ChimneyOpening", Vector3(0.48, 3.285, -0.75), Vector3(0.24, 0.012, 0.24), Color("583e35"))

static func populate(root: Node3D, kind: String) -> void:
	if root.has_node("Chimney"): root.get_node("Chimney").free()
	var source := (load("res://data/settlement/house.tscn") as PackedScene).instantiate()
	var colour: Color = source.get_node("PlasterWall").get_active_material(0).albedo_color; source.free()
	var walls := Node3D.new(); walls.name = "Walls"; root.add_child(walls)
	box(walls, "LeftWall", Vector3(-0.84, 0.91, 0), Vector3(0.12, 1.82, 2.8), colour)
	box(walls, "BackWall", Vector3(0, 0.91, -1.34), Vector3(1.76, 1.82, 0.12), colour)
	for side in [-1, 1]: box(walls, "DoorSide%d" % side, Vector3(side * 0.68, 0.91, 1.34), Vector3(0.40, 1.82, 0.12), colour)
	box(walls, "DoorHeader", Vector3(0, 1.72, 1.34), Vector3(1, 0.20, 0.12), colour)
	# A small side opening exposes the workplace without removing its walls.
	box(walls, "WindowSillWall", Vector3(0.84, 0.4, 0), Vector3(0.12, 0.8, 2.8), colour)
	box(walls, "WindowHeader", Vector3(0.84, 1.585, 0), Vector3(0.12, 0.47, 2.8), colour)
	box(walls, "WindowBack", Vector3(0.84, 1.075, -0.45), Vector3(0.12, 0.55, 1.9), colour)
	box(walls, "WindowFront", Vector3(0.84, 1.075, 1.25), Vector3(0.12, 0.55, 0.3), colour)
	for z in [-1.38, 1.38]: gable(walls, z, colour)
	var frame := Node3D.new(); frame.name = "Frame"; frame.set_meta("variation_exempt", true); root.add_child(frame)
	for x in [-0.88, 0.88]:
		for z in [-1.38, 1.38]: Frame.log_member(frame, "Post", Vector3(x, 0, z), Vector3(x, 1.82, z))
	for x in [-0.88, 0.88]: Frame.log_member(frame, "SideBeam", Vector3(x, 1.72, -1.34), Vector3(x, 1.72, 1.34))
	for z in [-1.38, 1.38]: Frame.log_member(frame, "CrossBeam", Vector3(-0.88, 1.72, z), Vector3(0.88, 1.72, z))
	roof(root, kind)
