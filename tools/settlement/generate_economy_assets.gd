extends SceneTree
const BushView = preload("res://scripts/settlement/bush_view.gd")
const StoneView = preload("res://scripts/settlement/stone_view.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
## Original editable meshes; no reference-game assets are imported.
func box(parent: Node3D, name_: String, position_: Vector3, size_: Vector3, colour: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = name_
	var shape := BoxMesh.new()
	shape.size = size_
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour)
	material.roughness = 1.0
	mesh.material_override = material
	mesh.position = position_
	parent.add_child(mesh)
	mesh.owner = parent
	return mesh

func ball(parent: Node3D, name_: String, position_: Vector3, radius: float, colour: String) -> void:
	var mesh := box(parent, name_, position_, Vector3.ONE, colour)
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 1.7
	shape.radial_segments = 8
	shape.rings = 4
	mesh.mesh = shape

func save_asset(node: Node3D, kind: String) -> void:
	var scene := PackedScene.new()
	scene.pack(node)
	ResourceSaver.save(scene, "res://data/settlement/" + kind + ".tscn")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_scene(node, state) == OK:
		document.write_to_filesystem(state, "res://data/settlement/" + kind + ".glb")
	node.free()

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("stones"):
		generate_limestone()
		print("PASS: irregular limestone exported")
		quit()
		return
	var bush := Node3D.new()
	bush.name = "BerryBush"
	var leaves := MeshInstance3D.new()
	leaves.name = "Leaves0"
	leaves.mesh = BushView.foliage_mesh(0)
	leaves.material_override = BushView.foliage_material(0)
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	bush.add_child(leaves)
	leaves.owner = bush
	# Extra markers remain available for legacy saved eight-berry bushes.
	for i in 9:
		var position_ := BushView.berry_position(i, 0)
		ball(bush, "Berry%d" % i, position_, 0.065, "bb5845")
		bush.get_node("Berry%d" % i).visible = i < 3
	save_asset(bush, "berry")
	generate_limestone()
	var grain := Node3D.new()
	grain.name = "GrainSheaf"
	for i in 7:
		var stem := box(grain, "Straw%d" % i, Vector3((i % 3 - 1) * 0.12, 0.03, (i / 3 - 1) * 0.10), Vector3(0.08, 0.12, 0.66), "d6b956")
		stem.rotation.y = (i - 3) * 0.06
	box(grain, "Binding", Vector3.ZERO, Vector3(0.4, 0.2, 0.09), "95754d")
	save_asset(grain, "grain")
	var plank := Node3D.new()
	plank.name = "SawnPlanks"
	for i in 3:
		box(plank, "Plank%d" % i, Vector3(0, i * 0.065, 0), Vector3(0.7, 0.055, 0.22), "b98754")
	save_asset(plank, "plank")
	print("PASS: original berry, limestone and cargo meshes exported")
	quit()

func generate_limestone() -> void:
	var illustrated := StoneView.Illustration.enabled
	StoneView.Illustration.enabled = false
	var deposit := Node3D.new()
	deposit.name = "Limestone"
	StoneView.populate(deposit, Vector3i.ZERO, 1409, Economy.STONE_CAPACITY)
	save_asset(deposit, "limestone")
	for kind in ["raw_stone", "block"]:
		var cargo := Node3D.new()
		cargo.name = "DressedBlock" if kind == "block" else "RawStone"
		var stone := MeshInstance3D.new()
		stone.name = "Stone"
		stone.mesh = StoneView.block_mesh(1409) if kind == "block" else StoneView.raw_mesh(1409)
		stone.scale = Vector3.ONE * 0.45
		stone.position.y = -0.18
		stone.material_override = StoneView.material()
		cargo.add_child(stone)
		stone.owner = cargo
		save_asset(cargo, kind)
	StoneView.Illustration.enabled = illustrated
