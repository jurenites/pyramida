extends SceneTree
## Reuse the project's own house, shed and workshop pieces on the reviewed metre grid.
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const Reviewed = preload("res://scripts/settlement/reviewed_balance.gd")
const ROOT := "res://data/settlement/"

func box(parent: Node3D, label: String, size: Vector3, at: Vector3, colour: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour)
	material.roughness = 1
	node.material_override = material
	parent.add_child(node)
	return node

func cylinder(parent: Node3D, label: String, radius: float, height: float, at: Vector3, colour: String) -> MeshInstance3D:
	var node := box(parent, label, Vector3.ONE, at, colour)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius
	mesh.height = height; mesh.radial_segments = 12
	node.mesh = mesh
	return node

func copy_parts(parent: Node3D, source: String, prefixes: Array) -> void:
	var asset := (load(ROOT + source + ".tscn") as PackedScene).instantiate()
	for child in asset.get_children():
		if not child is Marker3D and prefixes.any(func(prefix): return str(child.name).begins_with(prefix)):
			child.owner = null
			asset.remove_child(child); parent.add_child(child)
	asset.free()

func own(node: Node, root_: Node) -> void:
	node.scene_file_path = ""
	for child in node.get_children():
		child.owner = root_
		own(child, root_)

func save_asset(node: Node3D, kind: String) -> void:
	Timber.rebuild(node)
	own(node, node)
	var scene := PackedScene.new()
	assert(scene.pack(node) == OK)
	assert(ResourceSaver.save(scene, ROOT + "reviewed_" + kind + ".tscn") == OK)
	node.free()

func shell(kind: String) -> Node3D:
	var root_ := Node3D.new()
	root_.name = kind.to_pascal_case()
	root_.set_meta("reviewed_model", true)
	var size := Reviewed.size(kind)
	box(root_, "Floor", Vector3(size.x - 0.04, 0.08, size.z - 0.04), Vector3(0, -0.04, 0), "c3a786")
	var access := Marker3D.new(); access.name = "AccessFront"; access.position.z = size.z * 0.5 + 0.5; root_.add_child(access)
	var roof_socket := Marker3D.new(); roof_socket.name = "RoofSocket"; roof_socket.position.y = size.y; root_.add_child(roof_socket)
	return root_

func canopy(root_: Node3D, kind: String) -> void:
	var size := Reviewed.size(kind)
	for x in [-size.x * 0.5 + 0.15, size.x * 0.5 - 0.15]:
		for z in [-size.z * 0.5 + 0.15, size.z * 0.5 - 0.15]:
			box(root_, "Post", Vector3(0.18, 1.82, 0.18), Vector3(x, 0.91, z), "986a4b")
	# Shingled slopes follow the house silhouette; posts keep the shed's stock.
	var roof := Node3D.new(); roof.name = "Roof"; root_.add_child(roof)
	for side in [-1, 1]:
		for course in 4:
			var fraction := (course + 0.5) / 4.0
			var panel := box(roof, "Cap", Vector3(size.x / 7.0 + 0.12, 0.07, size.z + 0.16), Vector3(side * size.x * 0.5 * fraction, 2.3 - fraction * 0.5, 0), "af644b")
			panel.rotation.z = -side * atan(1.0 / size.x)
	box(roof, "Ridge", Vector3(0.10, 0.08, size.z + 0.18), Vector3(0, 2.32, 0), "d1a775")

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("tilery"):
		var node := shell("tilery")
		box(node, "Oven", Vector3(1.5, 1.2, 1.5), Vector3(0, 0.6, -0.35), "b97356")
		box(node, "Opening", Vector3(0.7, 0.55, 0.03), Vector3(0, 0.48, 0.415), "583e35")
		box(node, "Embers", Vector3(0.5, 0.1, 0.05), Vector3(0, 0.25, 0.44), "d99157")
		preload("res://tools/settlement/oven_buildings.gd").populate(node, "tilery")
		# Visible shaping bench and curved samples distinguish it from the brick Kiln.
		box(node, "MouldingBench", Vector3(1.30, 0.10, 0.48), Vector3(0, 0.65, 1.03), "c19361")
		for x in [-0.52, 0.52]:
			preload("res://scripts/settlement/structure_frame.gd").log_member(node, "BenchLeg", Vector3(x,0,1.03),Vector3(x,0.65,1.03))
		for x in [-0.42, 0, 0.42]:
			var tile := MeshInstance3D.new(); tile.name = "TileSample"; tile.mesh = preload("res://scripts/settlement/roof_covering.gd").imbrex()
			tile.position = Vector3(x, 0.71, 1.03); tile.rotation.y = PI / 2
			var paint := StandardMaterial3D.new(); paint.albedo_color = Color("ba674d"); paint.vertex_color_use_as_albedo = true; tile.material_override = paint; node.add_child(tile)
		save_asset(node, "tilery")
		var cargo := Node3D.new(); cargo.name = "Imbrex"
		var tile := MeshInstance3D.new(); tile.name = "Imbrex"; tile.mesh = preload("res://scripts/settlement/roof_covering.gd").imbrex()
		var paint := StandardMaterial3D.new(); paint.albedo_color = Color("ba674d"); paint.vertex_color_use_as_albedo = true; tile.material_override = paint; cargo.add_child(tile)
		save_asset(cargo, "imbrex")
		print("PASS: Tilery and physical Imbrex stock"); quit(); return
	if OS.get_cmdline_user_args().has("structure"):
		for kind in ["support", "stair"]:
			var node := shell(kind); node.get_node("Floor").free()
			preload("res://scripts/settlement/structure_frame.gd").populate(node, kind)
			save_asset(node, kind)
		print("PASS: open log Support and diagonal plank Stair")
		quit()
		return
	if OS.get_cmdline_user_args().has("depot"):
		save_asset(depot_model(), "stone_storage")
		print("PASS: Depot with two 3 X 3 storage layers")
		quit()
		return
	if OS.get_cmdline_user_args().has("barn"):
		save_asset(barn_model(), "hay_barn")
		print("PASS: Barn with modular pointed roof")
		quit()
		return
	for kind in ["sawmill", "masonry", "mill", "bakery", "pottery_workshop", "kiln", "quarry", "claypit", "mine", "brickyard", "support", "stair", "road"]:
		if OS.get_cmdline_user_args().has("mill") and kind != "mill": continue
		if OS.get_cmdline_user_args().has("ovens") and kind not in ["bakery", "kiln"]: continue
		if OS.get_cmdline_user_args().has("masonry") and kind != "masonry": continue
		if OS.get_cmdline_user_args().has("claypit") and kind != "claypit": continue
		var node := shell(kind)
		match kind:
			"sawmill":
				copy_parts(node, "sawmill", ["Table", "Saw", "Crank", "Fly", "Work", "Log", "Axle"])
				canopy(node, kind)
			"masonry":
				preload("res://tools/settlement/masonry_model.gd").populate(node)
			"pottery_workshop":
				copy_parts(node, "masonry", ["Table", "Pot"])
				cylinder(node, "Wheel", 0.38, 0.08, Vector3(0, 0.94, 0), "d1a775")
				box(node, "Sink", Vector3(0.5, 0.45, 0.5), Vector3(-0.55, 0.5, -0.8), "eebf8a")
				box(node, "Water", Vector3(0.38, 0.02, 0.38), Vector3(-0.55, 0.74, -0.8), "6caaca")
				canopy(node, kind)
			"mill":
				node.free()
				node = preload("res://tools/settlement/mill_model.gd").create()
			"bakery", "kiln":
				box(node, "Oven", Vector3(1.5, 1.2, 1.5), Vector3(0, 0.6, -0.35), "b97356" if kind == "kiln" else "eebf8a")
				box(node, "Opening", Vector3(0.7, 0.55, 0.03), Vector3(0, 0.48, 0.415), "583e35")
				box(node, "Embers", Vector3(0.5, 0.1, 0.05), Vector3(0, 0.25, 0.44), "d99157")
				box(node, "Chimney", Vector3(0.40, 0.65, 0.40), Vector3(0.45, 1.5, -0.75), "b97356")
				if kind == "bakery": copy_parts(node, "bread", ["Bread", "Loaf"])
				preload("res://tools/settlement/oven_buildings.gd").populate(node, kind)
			"quarry":
				for i in 3:
					var stone := (load(ROOT + "raw_stone.tscn") as PackedScene).instantiate() as Node3D
					stone.position = Vector3(-0.7 + i * 0.7, 0.25, -0.65); node.add_child(stone)
				box(node, "ToolHandle", Vector3(0.1, 1.0, 0.1), Vector3(0.8, 0.5, 0.6), "986a4b")
			"claypit":
				preload("res://tools/settlement/claypit_model.gd").populate(node)
			"mine":
				box(node, "Excavation", Vector3(2.3, 0.03, 2.3), Vector3(0, 0.02, 0), "584d44")
				for x in [-1.1, 1.1]: box(node, "Post", Vector3(0.18, 1.8, 0.18), Vector3(x, 0.9, 0), "986a4b")
				box(node, "Crossbar", Vector3(2.5, 0.18, 0.18), Vector3(0, 1.8, 0), "986a4b")
				cylinder(node, "Winch", 0.25, 0.40, Vector3(0, 1.3, 0), "d1a775")
			"brickyard":
				for x in [-1.35, 1.35]:
					for z in [-1.35, 1.35]: box(node, "Post", Vector3(0.18, 1.8, 0.18), Vector3(x, 0.9, z), "986a4b")
				for z in [-1.35, 1.35]: box(node, "Rail", Vector3(2.8, 0.15, 0.15), Vector3(0, 0.5, z), "986a4b")
			"support":
				node.get_node("Floor").free()
				preload("res://scripts/settlement/structure_frame.gd").populate(node, kind)
			"stair":
				node.get_node("Floor").free()
				preload("res://scripts/settlement/structure_frame.gd").populate(node, kind)
			"road": pass
		Timber.rebuild(node)
		save_asset(node, kind)
	if OS.get_cmdline_user_args().has("claypit"):
		print("PASS: Claypit with bordered puddle basin")
		quit(); return
	if OS.get_cmdline_user_args().has("masonry"):
		print("PASS: open Masonry with central station and cloth shade")
		quit(); return
	if OS.get_cmdline_user_args().has("ovens"):
		print("PASS: enclosed Bakery with Hay roof and enclosed Kiln")
		quit(); return
	if OS.get_cmdline_user_args().has("mill"):
		print("PASS: Mill with long, narrow white blades and 3 X 3 footprint")
		quit()
		return
	save_asset(barn_model(), "hay_barn")
	save_asset(depot_model(), "stone_storage")
	for kind in ["flour", "clay", "brick", "ore"]:
		var node := Node3D.new(); node.name = kind.to_pascal_case()
		if kind == "flour":
			cylinder(node, "Sack", 0.22, 0.40, Vector3.ZERO, "f0dfb8")
			cylinder(node, "Tie", 0.11, 0.06, Vector3(0, 0.20, 0), "986a4b")
		elif kind == "brick": box(node, "Brick", Vector3(0.45, 0.20, 0.25), Vector3.ZERO, "b97356")
		else:
			copy_parts(node, "raw_stone", ["Stone"])
			var material := StandardMaterial3D.new(); material.albedo_color = Color("b08063" if kind == "clay" else "716b68")
			(node.get_node("Stone") as MeshInstance3D).material_override = material
		save_asset(node, kind)
	print("PASS: 14 reviewed buildings and 4 resource models")
	quit()

func barn_model() -> Node3D:
	var barn := Node3D.new()
	barn.name = "Barn"
	barn.set_meta("reviewed_model", true)
	# Same approved timber and one-metre storage body, without the Shed's lean-to roof.
	copy_parts(barn, "log_shed", ["ShedPost", "SideRail", "EndRail", "LogSleeper"])
	var roof := Node3D.new()
	roof.name = "Canopy"
	barn.add_child(roof)
	preload("res://scripts/settlement/barn_roof.gd").populate(roof, 0)
	var access := Marker3D.new()
	access.name = "AccessFront"
	access.position = Vector3(0, 0, 1.5)
	barn.add_child(access)
	var socket := Marker3D.new()
	socket.name = "RoofSocket"
	socket.position.y = 1
	barn.add_child(socket)
	return barn

func depot_model() -> Node3D:
	var depot := Node3D.new(); depot.name = "Depot"
	depot.set_meta("reviewed_model", true)
	depot.set_meta("depot_grid", true)
	var depot_view = preload("res://scripts/settlement/stone_storage_view.gd")
	var floor_ := box(depot, "Floor", Vector3(3, depot_view.PAD_HEIGHT, 3), Vector3(0, depot_view.PAD_HEIGHT / 2, 0), "fef1cf")
	floor_.mesh = depot_view.pad_mesh()
	floor_.material_override = depot_view.Stone.material()
	floor_.set_meta("keep_lighting", true)
	for x in [-1.38, 1.38]:
		for z in [-1.38, 1.38]:
			box(depot, "Post%s%s" % ["Left" if x < 0 else "Right", "Back" if z < 0 else "Front"], Vector3(0.16, 2, 0.16), Vector3(x, 1, z), "c58769")
	for level in [1.87]:
		for side in [-1, 1]:
			var prefix := "Upper" if level > 1 else "Middle"
			box(depot, prefix + ("BackRail" if side < 0 else "FrontRail"), Vector3(2.92, 0.12, 0.14), Vector3(0, level, side * 1.38), "b27359")
			box(depot, prefix + ("LeftRail" if side < 0 else "RightRail"), Vector3(0.14, 0.12, 2.92), Vector3(side * 1.38, level, 0), "c58769")
	var access := Marker3D.new(); access.name = "AccessFront"; access.position.z = 2; depot.add_child(access)
	var roof := Marker3D.new(); roof.name = "RoofSocket"; roof.position.y = 2; depot.add_child(roof)
	return depot
