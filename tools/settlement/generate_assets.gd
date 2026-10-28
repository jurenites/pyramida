extends SceneTree
## Reproducible original mesh kit. Exports editable Godot scenes and Blender GLBs.
const OUT := "res://data/settlement/"
const WOOD := Color("74513e")
const END_GRAIN := Color("bb9166")
const PLANK := Color("b28b60")
const STONE := Color("d8c5a2")
const CHALK := Color("eee2c8")
const CLAY := Color("ba674d")
const DARK := Color("403b36")
const LEAF := Color("728462")
const SOIL := Color("665341")
var materials: Dictionary = {}
var meshes := 0
const Catalog = preload("res://data/settlement/catalog.gd")
const RoofAssets = preload("res://tools/settlement/roof_assets.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var kinds := ["platform", "landing", "stairs", "stockpile", "garden", "well", "tree", "dead_tree", "palm", "rock", "log", "house", "sawmill", "bed", "table", "bench", "urn", "support", "citizen_0", "citizen_1", "citizen_2", "citizen_3"]
	kinds.append_array(["ceramic_roof_tile", "metal_roof_sheet"])
	for kind in Catalog.COSTS:
		if kind not in kinds:
			kinds.append(kind)
	var requested := OS.get_cmdline_user_args()
	if not requested.is_empty():
		kinds = kinds.filter(func(kind): return kind in requested)
	for kind in kinds:
		var asset := Node3D.new()
		asset.name = kind.to_pascal_case()
		match kind:
			"ceramic_roof_tile":
				RoofAssets.ceramic_tile(asset)
				meshes += 1
			"metal_roof_sheet":
				RoofAssets.metal_sheet(asset)
				meshes += 5
			"platform":
				platform(asset)
				for child: Node3D in asset.get_children():
					if str(child.name).begins_with("FloorPlank") or str(child.name).begins_with("Peg"): continue
					child.position.y /= 2.4
					child.basis = child.basis.scaled(Vector3(1, 1.0 / 2.4, 1))
			"landing": landing(asset)
			"stairs": stairs(asset)
			"stockpile": stockpile(asset)
			"stone_storage": stone_storage(asset)
			"garden": garden(asset)
			"well": well(asset)
			"tree": tree(asset)
			"dead_tree": tree(asset, true)
			"palm": palm(asset)
			"rock": rock(asset)
			"log": log_mesh(asset)
			"house": house(asset)
			"sawmill": sawmill(asset)
			"bed": bed(asset)
			"table": table(asset)
			"bench": bench(asset)
			"urn": pot(asset, Vector3.ZERO, 0.38)
			"support": support(asset)
			_:
				if kind.begins_with("citizen"):
					citizen(asset, int(kind.right(1)))
				else:
					catalog_building(asset, kind)
		if kind in Catalog.ROOFS and kind not in ["log_shed", "hay_barn", "stone_storage"]:
			automatic_roof(asset, kind)
		if kind == "house":
			entrance_carpet(asset)
			for wall_name in ["PlasterWall", "PlasterWall2", "BackWall", "DoorSide", "DoorSide2", "DoorLintel"]:
				var wall := asset.get_node(wall_name) as MeshInstance3D
				darken_inside(wall, Vector3(-wall.position.x, 0, -wall.position.z).normalized())
		# Keep authored horizontal dimensions; shorten architecture and its sockets together.
		if (kind in Catalog.ROOFS and kind not in ["windmill", "log_shed", "hay_barn", "stone_storage"]) or kind in ["landing", "support", "stairs"]:
			for child: Node3D in asset.get_children():
				child.position.y *= Catalog.LEVEL_HEIGHT / 2.4
				child.scale.y *= Catalog.LEVEL_HEIGHT / 2.4
		if kind == "well": preload("res://scripts/settlement/timber_kit.gd").well_shape(asset, false)
		if kind in Catalog.COSTS: preload("res://scripts/settlement/timber_kit.gd").rebuild(asset)
		if kind == "stairs": preload("res://scripts/settlement/timber_kit.gd").fit_ladder(asset, Catalog.LEVEL_HEIGHT)
		add_anchors(asset, kind)
		own(asset, asset)
		var scene := PackedScene.new()
		assert(scene.pack(asset) == OK)
		assert(ResourceSaver.save(scene, OUT + kind + ".tscn") == OK)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_scene(asset, state) == OK)
		assert(document.write_to_filesystem(state, OUT + kind + ".glb") == OK)
		asset.free()
	print("PASS: exported %d original 3D assets as TSCN + GLB (%d meshes)" % [kinds.size(), meshes])
	quit()

func own(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		own(child, root_node)

func automatic_roof(parent: Node3D, kind: String) -> void:
	if kind == "windmill":
		var floor_node := box(parent, "Floor", Vector3(0, -0.06, 0), Vector3(2, 0.12, 2), CHALK)
		floor_node.visible = false
		for name_ in ["Roof", "StackSupport"]:
			var marker := Node3D.new()
			marker.name = name_
			marker.visible = false
			parent.add_child(marker)
		return
	# The cap is presentation, never an extra construction plan or material recipe.
	for child in parent.get_children():
		if str(child.name).begins_with("Roof") or child.name in ["BarnRoof", "MillCap"]:
			child.free()
	if kind in ["house", "school", "pantry", "workshop"]:
		for child: Node3D in parent.get_children():
			if str(child.name).begins_with("PlasterWall") or str(child.name).begins_with("DoorSide") or child.name == "BackWall":
				child.position.y *= 1.995 / 1.7 * 0.94
				child.scale.y *= 1.995 / 1.7 * 0.94
	elif kind in ["log_shed", "hay_barn", "stone_storage"]:
		for child: Node3D in parent.get_children():
			if str(child.name).begins_with("BarnPost"):
				child.position.y *= 2.256 / 2.3
				child.scale.y *= 2.256 / 2.3
	else:
		var support := Node3D.new()
		support.name = "StackSupport"
		support.visible = false
		parent.add_child(support)
		for x in [-0.86, 0.86]:
			for z in [-0.86, 0.86]:
				box(support, "Post", Vector3(x, 1.128, z), Vector3(0.12, 2.256, 0.12), WOOD)
	# Each new storey supplies its own floor where the previous cap used to sit.
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(2.0, 0.144, 2.0)
	var floor_node := mesh(parent, "Floor", floor_mesh, Vector3(0, -0.072, 0), CHALK)
	floor_node.visible = kind in Catalog.NATURAL_ROOFS
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.visible = kind in Catalog.NATURAL_ROOFS
	parent.add_child(roof)
	# Four half-grid panels preserve exposed roof on offset stacks.
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			var cap_mesh := BoxMesh.new()
			cap_mesh.size = Vector3(1.0, 0.144, 1.0)
			mesh(roof, "Cap", cap_mesh, Vector3(x, 2.328, z), CLAY)

func material(colour: Color) -> StandardMaterial3D:
	if materials.has(colour):
		return materials[colour]
	var value := StandardMaterial3D.new()
	value.albedo_color = colour
	value.roughness = 0.92
	materials[colour] = value
	return value

func mesh(parent: Node3D, name_: String, shape: Mesh, position_: Vector3, colour: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = shape
	node.material_override = material(colour)
	node.position = position_
	# Stable readable names let roof/wall transforms include repeated beams and posts.
	parent.add_child(node, true)
	meshes += 1
	return node

func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(b)

func box(parent: Node3D, name_: String, centre: Vector3, size: Vector3, colour: Color, bevel := 0.06) -> MeshInstance3D:
	# Clipped corners and a thin bevel catch the light without textures.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var half := size * 0.5
	var cut := minf(bevel, minf(half.x, half.z) * 0.35)
	var points: Array[Vector2] = [Vector2(-half.x + cut, -half.z), Vector2(half.x - cut, -half.z),
		Vector2(half.x, -half.z + cut), Vector2(half.x, half.z - cut), Vector2(half.x - cut, half.z),
		Vector2(-half.x + cut, half.z), Vector2(-half.x, half.z - cut), Vector2(-half.x, -half.z + cut)]
	var rings: Array = []
	var inset := minf(0.04, half.y * 0.3)
	for layer in 4:
		var ring: Array[Vector3] = []
		var y: float = [-half.y, -half.y + inset, half.y - inset, half.y][layer]
		for point: Vector2 in points:
			var factor := 0.94 if layer == 0 or layer == 3 else 1.0
			ring.append(Vector3(point.x * factor, y, point.y * factor))
		rings.append(ring)
	for layer in 3:
		for index in 8:
			var next := (index + 1) % 8
			triangle(tool, rings[layer][index], rings[layer + 1][index], rings[layer + 1][next])
			triangle(tool, rings[layer][index], rings[layer + 1][next], rings[layer][next])
	for index in 8:
		var next := (index + 1) % 8
		triangle(tool, Vector3(0, half.y, 0), rings[3][next], rings[3][index])
		triangle(tool, Vector3(0, -half.y, 0), rings[0][index], rings[0][next])
	tool.generate_normals()
	return mesh(parent, name_, tool.commit(), centre, colour)

func cylinder(parent: Node3D, name_: String, centre: Vector3, radius: float, height: float, colour: Color, top := -1.0, sides := 8) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	return mesh(parent, name_, shape, centre, colour)

func beam(parent: Node3D, name_: String, start: Vector3, finish: Vector3, width: float, colour := WOOD) -> MeshInstance3D:
	var node := box(parent, name_, (start + finish) * 0.5, Vector3(width, start.distance_to(finish), width), colour, 0.025)
	var direction := (finish - start).normalized()
	node.quaternion = Quaternion(Vector3.UP, direction)
	return node

func foliage(parent: Node3D, name_: String, centre: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 7
	sphere.rings = 3
	var arrays := sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for index in indices:
		tool.add_vertex(vertices[index] * size)
	tool.generate_normals()
	return mesh(parent, name_, tool.commit(), centre, colour)

func support(parent: Node3D) -> void:
	for x in [-0.83, 0.83]:
		for z in [-0.83, 0.83]:
			box(parent, "StoneFoot", Vector3(x, -2.25, z), Vector3(0.38, 0.30, 0.38), STONE)
			beam(parent, "Post", Vector3(x, -2.13, z), Vector3(x, -0.12, z), 0.16)
			for y in [-0.45, -1.9]:
				box(parent, "RopeJoint", Vector3(x, y, z), Vector3(0.19, 0.075, 0.19), END_GRAIN)
	for z in [-0.83, 0.83]:
		beam(parent, "CrossBrace", Vector3(-0.82, -1.55, z), Vector3(0.82, -0.28, z), 0.09)
		beam(parent, "RimBeam", Vector3(-0.98, -0.16, z), Vector3(0.98, -0.16, z), 0.18)

func platform(parent: Node3D) -> void:
	support(parent)
	for index in 8:
		box(parent, "FloorPlank_%02d" % index, Vector3(0, -0.055, -0.875 + index * 0.25), Vector3(1.98, 0.11, 0.238), PLANK.lightened((index % 3) * 0.035))
	for x in [-0.83, 0.83]:
		for z in [-0.83, 0.83]:
			cylinder(parent, "Peg", Vector3(x, 0.005, z), 0.024, 0.013, DARK, -1, 6)

func stairs(parent: Node3D) -> void:
	# A freestanding one-cell ladder. The climb ends at this cell's edge,
	# before crossing onto the neighbouring deck; no deck cutout is needed.
	for x in [-0.78, 0.78]:
		for z in [-0.72, 0.72]:
			box(parent, "LadderFoot", Vector3(x, 0.1, z), Vector3(0.32, 0.2, 0.32), STONE)
			box(parent, "LadderSupport", Vector3(x, 1.2, z), Vector3(0.12, 2.4, 0.12), WOOD)
	for z in [-0.72, 0.72]:
		beam(parent, "LadderBrace", Vector3(-0.78, 0.22, z), Vector3(0.78, 2.28, z), 0.09)
		box(parent, "LadderTopBeam", Vector3(0, 2.31, z), Vector3(1.72, 0.14, 0.12), WOOD)
	for step in 12:
		var y := (step + 1) * 0.2
		var x := -1.0 + y / 2.4 * 1.92
		box(parent, "LadderRung_%02d" % step, Vector3(x, y - 0.04, 0), Vector3(0.14, 0.08, 0.98), PLANK, 0.02)
	for z in [-0.49, 0.49]:
		beam(parent, "LadderRail", Vector3(-0.94, 0.06, z), Vector3(0.94, 2.34, z), 0.1)

func log_mesh(parent: Node3D) -> void:
	var trunk := cylinder(parent, "Bark", Vector3(0, 0.12, 0), 0.115, 0.9, WOOD)
	trunk.rotation.z = PI / 2
	for x in [-0.453, 0.453]:
		var end := cylinder(parent, "CutEnd", Vector3(x, 0.12, 0), 0.084, 0.012, END_GRAIN)
		end.rotation.z = PI / 2

func stone_storage(parent: Node3D) -> void:
	box(parent, "Floor", Vector3(0, 0.035, 0), Vector3(3, 0.07, 3), Color("514337"))
	for x in [-1.40, 1.40]:
		for z in [-1.40, 1.40]:
			box(parent, "Post", Vector3(x, 1, z), Vector3(0.20, 2, 0.20), WOOD)
	var beams := Node3D.new()
	beams.name = "Beams"
	parent.add_child(beams)
	for side in [-1.40, 1.40]:
		box(beams, "RailX", Vector3(0, 1.87, side), Vector3(3, 0.22, 0.20), WOOD)
		box(beams, "RailZ", Vector3(side, 1.87, 0), Vector3(0.20, 0.22, 3), WOOD)
	var enclosure := Node3D.new()
	enclosure.name = "Enclosure"
	parent.add_child(enclosure)
	for index in 12:
		var axis := -1.32 + index * 0.24
		if absf(axis) > 0.5:
			box(enclosure, "FrontPlank", Vector3(axis, 0.96, 1.42), Vector3(0.22, 1.80, 0.12), PLANK)
		box(enclosure, "RoofPlank", Vector3(axis, 1.94, 0), Vector3(0.24, 0.12, 3), WOOD.lightened(0.10 if index % 2 else 0.17))
	# Open storage sides retain one central roof support each.
	for centre in [Vector3(0, 1, -1.40), Vector3(-1.40, 1, 0), Vector3(1.40, 1, 0)]:
		box(enclosure, "CentreSupport", centre, Vector3(0.20, 2, 0.20), WOOD)
	box(enclosure, "DoorLintel", Vector3(0, 1.78, 1.42), Vector3(1, 0.24, 0.16), WOOD)
	for wall: MeshInstance3D in enclosure.get_children():
		if "Plank" in str(wall.name) and not str(wall.name).begins_with("Roof"):
			darken_inside(wall, Vector3(-wall.position.x, 0, -wall.position.z).normalized())

func stockpile(parent: Node3D) -> void:
	# A full room-sized patch, without a raised pallet or internal boundary rails.
	var patch := BoxMesh.new()
	patch.size = Vector3(2.0, 0.02, 2.0)
	mesh(parent, "GroundPatch", patch, Vector3(0, 0.005, 0), Color("dfc99e"))
	var corners = preload("res://scripts/settlement/pile_groups.gd").CORNERS
	for index in 4:
		var corner: Vector3 = Vector3(corners[index]) * 0.86
		corner.y = 0.10
		var stone := foliage(parent, "CornerStone%d" % index, corner, Vector3(0.28, 0.22, 0.28), STONE.darkened(0.2))
		stone.rotation.y = index * 0.7

func garden(parent: Node3D) -> void:
	box(parent, "Soil", Vector3(0, 0.16, 0), Vector3(1.6, 0.28, 1.6), SOIL)
	for x in [-0.84, 0.84]:
		box(parent, "RaisedBedSide", Vector3(x, 0.2, 0), Vector3(0.10, 0.4, 1.8), PLANK)
	for z in [-0.84, 0.84]:
		box(parent, "RaisedBedEnd", Vector3(0, 0.2, z), Vector3(1.8, 0.4, 0.10), WOOD)
	var plants := Node3D.new()
	plants.name = "Plants"
	parent.add_child(plants)
	for x in [-0.48, 0.0, 0.48]:
		for z in [-0.5, 0.0, 0.5]:
			for leaf in 3:
				var node := foliage(plants, "Leaf", Vector3(x + sin(leaf * 2.1) * 0.09, 0.43 + leaf * 0.045, z), Vector3(0.30, 0.22, 0.32), LEAF.lightened(leaf * 0.06))
				node.rotation.y = leaf * 1.1
			foliage(plants, "Fruit", Vector3(x + 0.08, 0.48, z + 0.12), Vector3.ONE * 0.12, CLAY)
	pot(parent, Vector3(0.73, 0.35, 0.73), 0.12)

func soil_bed(parent: Node3D) -> void:
	var soil := BoxMesh.new()
	soil.size = Vector3(2.0, 0.10, 2.0)
	mesh(parent, "Soil", soil, Vector3(0, 0.05, 0), SOIL)

func hay_field(parent: Node3D) -> void:
	# The cut bed is a flat, opaque painted patch just above the ground.
	var soil := BoxMesh.new()
	soil.size = Vector3(3.94, 0.012, 3.94)
	mesh(parent, "Soil", soil, Vector3(0, 0.006, 0), Color("e8d5a4"))
	for side in [-1.97, 1.97]:
		box(parent, "EdgePlank", Vector3(side, 0.055, 0), Vector3(0.06, 0.09, 4.0), PLANK, 0.01)
		box(parent, "EdgePlank", Vector3(0, 0.055, side), Vector3(3.88, 0.09, 0.06), PLANK, 0.01)
	for side in 4:
		for slot in 4:
			var peg := box(parent, "EdgePeg", Vector3.ZERO, Vector3(0.06, 0.26, 0.06), WOOD, 0.01)
			peg.set_meta("hay_peg_side", side)
			peg.set_meta("hay_peg_slot", slot)
	for corner in 4:
		var peg := box(parent, "EdgePeg", Vector3.ZERO, Vector3(0.06, 0.26, 0.06), WOOD, 0.01)
		peg.set_meta("hay_peg_side", corner % 2)
		peg.set_meta("hay_peg_slot", 4)
		peg.set_meta("hay_peg_corner", corner)
	preload("res://scripts/settlement/hay_field_view.gd").arrange_pegs(parent, Vector3i.ZERO, 0)
	var plants := Node3D.new()
	plants.name = "Plants"
	plants.position.y = 0.012
	parent.add_child(plants)
	# Adult knees are at 0.185 m. Four flush quarters read as one crop surface,
	# but each can disappear independently when its bundle is gathered.
	var canopy := BoxMesh.new()
	canopy.size = Vector3(1.97, 0.173, 1.97)
	var arrays := canopy.surface_get_arrays(0)
	var colours := PackedColorArray()
	for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		colours.append(Color("ffca76") if normal.y > 0.5 else Color("efb45e"))
	arrays[Mesh.ARRAY_COLOR] = colours
	var crop_mesh := ArrayMesh.new()
	crop_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var crop_material := material(Color.WHITE).duplicate() as StandardMaterial3D
	crop_material.vertex_color_use_as_albedo = true
	crop_material.vertex_color_is_srgb = true
	for index in 4:
		var quarter := Node3D.new()
		quarter.name = "Quarter%d" % index
		quarter.position = Vector3(-0.985 if index % 2 == 0 else 0.985, 0, -0.985 if index < 2 else 0.985)
		plants.add_child(quarter)
		var fill := mesh(quarter, "Canopy", crop_mesh, Vector3(0, 0.0865, 0), Color.WHITE)
		fill.material_override = crop_material
		var ears := SurfaceTool.new()
		ears.begin(Mesh.PRIMITIVE_TRIANGLES)
		for detail in 4:
			var seed_ := index * 4 + detail
			var centre := Vector3(-0.54 + (detail % 2) * 1.02 + sin(seed_ * 4.1) * 0.15, 0.173, -0.54 + (detail / 2) * 1.02 + cos(seed_ * 2.7) * 0.15)
			# Small crossed line silhouettes stay legible from every camera angle.
			for angle in [0.35 + seed_ * 0.7, 0.35 + seed_ * 0.7 + PI * 0.5]:
				var side_ := Vector3(cos(angle), 0, sin(angle))
				var tip := centre + Vector3.UP * 0.065 + side_ * 0.012
				triangle(ears, centre - side_ * 0.006, centre + side_ * 0.006, tip + side_ * 0.005)
				triangle(ears, centre - side_ * 0.006, tip + side_ * 0.005, tip - side_ * 0.005)
				for grain in 3:
					var middle := centre.lerp(tip, 0.48 + grain * 0.18)
					var edge := middle + side_ * (0.025 if grain % 2 == 0 else -0.025) + Vector3.UP * 0.012
					triangle(ears, middle - Vector3.UP * 0.009, edge, middle + Vector3.UP * 0.014)
		ears.generate_normals()
		var accents := mesh(quarter, "Spikelets", ears.commit(), Vector3.ZERO, Color("eab463"))
		var accent_material := accents.material_override.duplicate() as StandardMaterial3D
		accent_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		accents.material_override = accent_material

func pot(parent: Node3D, centre: Vector3, radius: float) -> void:
	cylinder(parent, "PotFoot", centre + Vector3.UP * radius * 0.12, radius * 0.5, radius * 0.24, CLAY)
	cylinder(parent, "PotBelly", centre + Vector3.UP * radius * 0.7, radius * 0.65, radius, CLAY, radius)
	cylinder(parent, "PotShoulder", centre + Vector3.UP * radius * 1.35, radius, radius * 0.4, CLAY, radius * 0.5)
	cylinder(parent, "PotRim", centre + Vector3.UP * radius * 1.62, radius * 0.55, radius * 0.14, CLAY.lightened(0.15))
	cylinder(parent, "PotOpening", centre + Vector3.UP * radius * 1.70, radius * 0.40, 0.01, DARK)

func well(parent: Node3D) -> void:
	for layer in 3:
		for index in 10:
			var angle := index * TAU / 10 + (layer % 2) * PI / 10
			var stone := box(parent, "WellStone", Vector3(cos(angle) * 0.57, 0.13 + layer * 0.24, sin(angle) * 0.57), Vector3(0.38, 0.23, 0.25), STONE.lightened((index % 3) * 0.025))
			stone.rotation.y = -angle + PI / 2
	cylinder(parent, "Water", Vector3(0, 0.35, 0), 0.45, 0.04, Color("527d7b"), -1, 20)
	for x in [-0.80, 0.80]:
		beam(parent, "WellPost", Vector3(x, 0, 0), Vector3(x, 1.8, 0), 0.13)
	beam(parent, "Axle", Vector3(-0.92, 1.5, 0), Vector3(0.92, 1.5, 0), 0.14)
	beam(parent, "Rope", Vector3(0, 0.65, 0), Vector3(0, 1.5, 0), 0.027, END_GRAIN)
	pot(parent, Vector3(0.8, 0, 0.6), 0.22)
	var canopy := box(parent, "Canopy", Vector3(0, 1.91, 0), Vector3(2.1, 0.12, 1.4), CLAY)
	canopy.rotation.z = -0.06

func tree(parent: Node3D, dead := false) -> void:
	preload("res://tools/settlement/tree_geometry.gd").build(self, parent, dead)

func palm(parent: Node3D) -> void:
	for index in 9:
		var y := index * 0.27
		var x := 0.035 * index + 0.006 * index * index
		cylinder(parent, "TrunkRing", Vector3(x, y + 0.14, 0), 0.15 - index * 0.006, 0.29, WOOD.lightened((index % 2) * 0.08), 0.13 - index * 0.006)
	var crown := Vector3(0.67, 2.55, 0)
	for index in 9:
		var angle := index * TAU / 9
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_smooth_group(-1)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-sin(angle), 0, cos(angle))
		for segment in 4:
			var t := segment / 4.0
			var u := (segment + 1) / 4.0
			var a := crown + direction * t * 1.65 + Vector3.UP * (sin(t * PI) * 0.38 - t * t * 0.55)
			var b := crown + direction * u * 1.65 + Vector3.UP * (sin(u * PI) * 0.38 - u * u * 0.55)
			var width_a := sin(t * PI) * 0.23 + 0.015
			var width_b := sin(u * PI) * 0.23
			triangle(tool, a - side * width_a, b - side * width_b, b + side * width_b)
			triangle(tool, a - side * width_a, b + side * width_b, a + side * width_a)
		tool.generate_normals()
		var node := mesh(parent, "Frond", tool.commit(), Vector3.ZERO, LEAF.darkened((index % 2) * 0.12))
		var mat := material(LEAF.darkened((index % 2) * 0.12)).duplicate() as StandardMaterial3D
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = mat

func rock(parent: Node3D) -> void:
	for index in 4:
		var node := box(parent, "Limestone", Vector3(sin(index * 2.4) * 0.42, 0.23 + index * 0.06, cos(index * 2.4) * 0.3), Vector3(0.7, 0.55 + index * 0.12, 0.65), STONE.darkened(index * 0.025), 0.2)
		node.rotation = Vector3(0.05 * index, index * 0.7, 0.06 * index)

func house(parent: Node3D) -> void:
	for x in [-0.83, 0.83]:
		box(parent, "PlasterWall", Vector3(x, 0.85, 0), Vector3(0.18, 1.7, 1.75), CHALK)
	box(parent, "BackWall", Vector3(0, 0.85, -0.8), Vector3(1.5, 1.7, 0.18), STONE)
	for x in [-0.62, 0.62]:
		box(parent, "DoorSide", Vector3(x, 0.85, 0.8), Vector3(0.45, 1.7, 0.18), CHALK)
	box(parent, "DoorLintel", Vector3(0, 1.57, 0.8), Vector3(0.8, 0.26, 0.22), WOOD)
	for index in 9:
		box(parent, "RoofBeam", Vector3(-0.92 + index * 0.23, 1.8, 0), Vector3(0.17, 0.16, 2.1), WOOD)
	box(parent, "RoofEarth", Vector3(0, 1.93, 0), Vector3(1.95, 0.13, 1.95), CLAY)
	pot(parent, Vector3(-0.58, 0, 0.64), 0.18)
	# The plaster/roof module ends exactly at the 2.4 m stacking socket.
	for child: Node3D in parent.get_children():
		child.position.y *= 2.4 / 1.995
		child.scale.y *= 2.4 / 1.995

func darken_inside(wall: MeshInstance3D, inward: Vector3) -> void:
	# Colour the existing inward faces, so no extra lining can protrude or z-fight.
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for index in vertices.size(): indices.append(index)
	var result := ArrayMesh.new()
	for interior in [false, true]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for triangle_index in range(0, indices.size(), 3):
			var normal := normals[indices[triangle_index]]
			var faces_inside := normal.dot(inward) > 0.25 or normal.y < -0.5
			if faces_inside != interior: continue
			for corner in 3:
				var index := indices[triangle_index + corner]
				surface.set_normal(normals[index])
				surface.add_vertex(vertices[index])
		surface.set_material(material(Color("514039")) if interior else wall.material_override)
		surface.commit(result)
	wall.mesh = result
	wall.material_override = null

func entrance_carpet(parent: Node3D) -> void:
	# Cover the full floor module, including thresholds and joined-room seams.
	var shape := BoxMesh.new()
	shape.size = Vector3(2.0, 0.018, 2.0)
	var carpet := mesh(parent, "EntranceCarpet", shape, Vector3(0, 0.015, 0), Color("30191b"))
	carpet.set_meta("keep_lighting", true)
	carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cloth := carpet.material_override as StandardMaterial3D
	cloth.roughness = 1.0
	cloth.metallic_specular = 0.0

func table(parent: Node3D) -> void:
	box(parent, "TableTop", Vector3(0, 0.63, 0), Vector3(1.1, 0.10, 0.65), PLANK)
	for x in [-0.4, 0.4]:
		for z in [-0.23, 0.23]:
			beam(parent, "TableLeg", Vector3(x, 0, z), Vector3(x, 0.6, z), 0.08)
	pot(parent, Vector3(0.15, 0.68, 0), 0.09)

func bench(parent: Node3D) -> void:
	box(parent, "Seat", Vector3(0, 0.35, 0), Vector3(1.1, 0.1, 0.30), PLANK)
	for x in [-0.4, 0.4]:
		box(parent, "BenchLeg", Vector3(x, 0.15, 0), Vector3(0.1, 0.3, 0.25), WOOD)

func bed(parent: Node3D) -> void:
	box(parent, "Frame", Vector3(0, 0.18, 0), Vector3(0.72, 0.22, 1.45), WOOD)
	box(parent, "Mattress", Vector3(0, 0.35, 0), Vector3(0.67, 0.15, 1.38), END_GRAIN)
	box(parent, "Blanket", Vector3(0, 0.44, 0.2), Vector3(0.69, 0.06, 0.95), Color("537c83"))
	box(parent, "Pillow", Vector3(0, 0.46, -0.48), Vector3(0.5, 0.12, 0.29), CHALK)

func sawmill(parent: Node3D) -> void:
	table(parent)
	for x in [-0.75, 0.75]:
		beam(parent, "SawFrame", Vector3(x, 0, 0), Vector3(x, 1.5, 0), 0.13)
	beam(parent, "Crossbar", Vector3(-0.75, 1.5, 0), Vector3(0.75, 1.5, 0), 0.13)
	box(parent, "SawBlade", Vector3(0, 1.05, 0), Vector3(0.045, 0.85, 0.2), Color("687c7d"))
	var log_node := Node3D.new()
	parent.add_child(log_node)
	log_node.position.y = 0.7
	log_mesh(log_node)

# Featureless silhouettes and simple colour blocks remain legible at game zoom.
const CLOTH_PALETTE := [Color("518e9a"), Color("cc765c"), Color("d3ad53"), Color("869c70"), Color("9583ad")]

func bean(parent: Node3D, name_: String, centre: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 10
	var result := mesh(parent, name_, shape, centre, colour)
	result.scale = size
	return result

func pill(parent: Node3D, name_: String, centre: Vector3, radius: float, height: float, colour: Color) -> MeshInstance3D:
	# A cylinder with hemispherical caps, not a stretched sphere with tapered ends.
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	shape.radial_segments = 16
	shape.rings = 8
	return mesh(parent, name_, shape, centre, colour)

func attached_arm(parent: Node3D, colour: Color) -> void:
	# Overlapping round ends hide the hinge; the upper cap stays inside the shoulder.
	pill(parent, "PillArm", Vector3(0, -0.0675, 0), 0.063, 0.261, colour)
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position.y = -0.135
	parent.add_child(elbow)
	pill(elbow, "Forearm", Vector3(0, -0.0575, 0), 0.06, 0.235, colour)

func jointed_leg(parent: Node3D, colour: Color) -> void:
	pill(parent, "PillLeg", Vector3(0, -0.0525, 0), 0.073, 0.251, colour)
	var knee := Node3D.new()
	knee.name = "Knee"
	knee.position.y = -0.105
	parent.add_child(knee)
	pill(knee, "Shin", Vector3(0, -0.0475, 0), 0.072, 0.239, colour)

func garment(node: MeshInstance3D) -> void:
	node.set_meta("citizen_cloth", true)

func citizen(parent: Node3D, variant: int) -> void:
	var skin: Color = [Color("66513a"), Color("78583f"), Color("543b2c"), Color("674938")][variant]
	var cloth: Color = CLOTH_PALETTE[variant]
	bean(parent, "Body", Vector3(0, 0.53, 0), Vector3(0.42, 0.57, 0.30), skin)
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 0.96
	parent.add_child(head)
	bean(head, "HeadShape", Vector3.ZERO, Vector3(0.30, 0.35, 0.27), skin)
	# No eyes, nose, mouth or ears: hair and clothing carry the identity.
	var hair := Color("211c18")
	var cap := bean(head, "HairCap", Vector3(-0.015, 0.12, 0.025), Vector3(0.32, 0.14, 0.29), hair)
	cap.rotation.z = -0.18
	if variant % 2 == 1:
		bean(head, "SideBun", Vector3(0.15, 0.12, 0.06), Vector3(0.19, 0.21, 0.20), hair)
	else:
		var tuft := bean(head, "HairTuft", Vector3(-0.07, 0.17, 0.01), Vector3(0.15, 0.13, 0.22), hair)
		tuft.rotation.z = -0.4
	# A single solid clothing colour identifies each citizen at game zoom.
	if variant in [1, 3]:
		garment(bean(parent, "DressTop" if variant == 1 else "Top", Vector3(0, 0.63, 0), Vector3(0.44, 0.35, 0.32), cloth))
		var skirt := cylinder(parent, "DressSkirt" if variant == 1 else "Skirt", Vector3(0, 0.36, 0), 0.27, 0.40, cloth, 0.19, 16)
		skirt.scale.z = 0.72
		garment(skirt)
		if variant == 1:
			parent.get_node("DressTop").position.y = 0.56
			parent.get_node("DressTop").scale = Vector3(0.46, 0.50, 0.34)
		if variant == 3:
			# Exposed waist separates the top and skirt without tiny decorative detail.
			parent.get_node("Top").position.y = 0.67
			parent.get_node("Top").scale.y = 0.28
			parent.get_node("Skirt").position.y = 0.31
			parent.get_node("Skirt").scale.y = 0.80
	elif variant == 2:
		var wrap := cylinder(parent, "RobeSkirt", Vector3(0, 0.35, 0), 0.23, 0.32, cloth, 0.20, 16)
		wrap.scale.z = 0.76
		garment(wrap)
		# Diagonal wrap joins the waist to only the left shoulder, front and back.
		for z in [-0.12, 0.12]:
			var sash := bean(parent, "DiagonalRobe", Vector3(-0.015, 0.61, z), Vector3(0.20, 0.52, 0.08), cloth)
			sash.rotation.z = -0.48
			garment(sash)
		garment(bean(parent, "CoveredShoulder", Vector3(-0.185, 0.73, 0), Vector3(0.19, 0.18, 0.27), cloth))
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LeftLeg" if side == -1 else "RightLeg"
		leg.position = Vector3(side * 0.11, 0.29, 0)
		parent.add_child(leg)
		jointed_leg(leg, skin)
		if variant == 0:
			garment(pill(leg, "Shorts", Vector3(0, 0.015, 0), 0.105, 0.22, cloth))
		var arm := Node3D.new()
		arm.name = "LeftArm" if side == -1 else "RightArm"
		bean(parent, "LeftShoulder" if side == -1 else "RightShoulder", Vector3(side * 0.15, 0.70, 0), Vector3(0.22, 0.15, 0.24), skin)
		arm.position = Vector3(side * 0.18, 0.70, 0)
		parent.add_child(arm)
		attached_arm(arm, skin)
	if variant == 0:
		garment(bean(parent, "ShortsWaist", Vector3(0, 0.35, 0), Vector3(0.43, 0.21, 0.31), cloth))
	var cargo := Node3D.new()
	cargo.name = "CargoSocket"
	cargo.position = Vector3(0, 0.53, -0.36)
	parent.add_child(cargo)

func add_anchors(asset: Node3D, kind: String) -> void:
	if kind in ["ceramic_roof_tile", "metal_roof_sheet"]: return
	if kind.begins_with("citizen") or kind in ["tree", "dead_tree"]:
		return
	var points := {"AccessFront": Vector3(0, 0, 0.95)}
	if kind == "platform" or kind == "landing":
		points = {"WalkCentre": Vector3.ZERO, "NorthEdge": Vector3(0, 0, -1), "SouthEdge": Vector3(0, 0, 1), "WestEdge": Vector3(-1, 0, 0), "EastEdge": Vector3(1, 0, 0)}
	elif kind == "stairs":
		points = {"LowerEntrance": Vector3(-1, 0, 0), "UpperEntrance": Vector3(1, Catalog.LEVEL_HEIGHT, 0)}
	elif kind == "stone_storage":
		points["AccessFront"] = Vector3(0, 0, 2)
	elif kind == "soil_bed":
		points["AccessFront"] = Vector3(0, 0, 0.48)
	elif kind == "garden":
		points["WaterIn"] = Vector3(0.8, 0.4, 0.8)
	elif kind == "well":
		points["WaterOut"] = Vector3(0.8, 0.4, 0.6)
	if kind in Catalog.ROOFS:
		points["RoofSocket"] = Vector3(0, Catalog.building_height(kind), 0)
	for name_ in points:
		var anchor := Marker3D.new()
		anchor.name = name_
		anchor.position = points[name_]
		asset.add_child(anchor)

func landing(parent: Node3D) -> void:
	# An open stairwell prevents the ascending citizen from passing through a deck.
	platform(parent)
	for index in range(2, 6):
		var plank := parent.get_node("FloorPlank_%02d" % index) as MeshInstance3D
		plank.scale.x = 0.48
		plank.position.x = 0.51

func catalog_building(parent: Node3D, kind: String) -> void:
	match kind:
		"soil_bed": soil_bed(parent)
		"hay_field": hay_field(parent)
		"road":
			for x in 4:
				for z in 4:
					box(parent, "Paving", Vector3(-0.74 + x * 0.49, 0.025, -0.74 + z * 0.49), Vector3(0.47, 0.05, 0.47), STONE)
		"windmill": windmill(parent)
		"mine_camp":
			rock(parent)
			for x in [-0.65, 0.65]:
				beam(parent, "PitFrame", Vector3(x, 0, 0.55), Vector3(x, 1.55, 0.55), 0.16)
			beam(parent, "PitLintel", Vector3(-0.85, 1.57, 0.55), Vector3(0.85, 1.57, 0.55), 0.16)
			box(parent, "DarkEntrance", Vector3(0, 0.5, 0.2), Vector3(0.9, 1, 0.08), DARK)
			beam(parent, "PickHandle", Vector3(0.7, 0, 0.8), Vector3(0.9, 1.15, 0.7), 0.06)
			beam(parent, "PickHead", Vector3(0.6, 1, 0.7), Vector3(1, 1.17, 0.7), 0.07, DARK)
		"masonry":
			table(parent)
			for index in 5:
				box(parent, "CutStone", Vector3(-0.6 + (index % 3) * 0.43, 0.2 + (index / 3) * 0.40, -0.55), Vector3(0.40, 0.39, 0.40), STONE)
			box(parent, "WorkStone", Vector3(0, 0.9, 0), Vector3(0.6, 0.4, 0.5), CHALK)
			beam(parent, "Chisel", Vector3(0.3, 0.72, 0.1), Vector3(0.3, 1.2, 0.1), 0.04, DARK)
		"log_shed": log_shed(parent)
		"hay_barn": hay_barn(parent)
		_:
			house(parent)
			match kind:
				"school":
					box(parent, "SchoolSign", Vector3(0, 1.55, 0.96), Vector3(0.75, 0.36, 0.06), Color("537c83"))
					box(parent, "BookLeft", Vector3(-0.14, 1.55, 1.0), Vector3(0.22, 0.23, 0.025), CHALK)
					box(parent, "BookRight", Vector3(0.14, 1.55, 1.0), Vector3(0.22, 0.23, 0.025), CHALK)
				"pantry":
					for x in [-0.55, 0.55]:
						pot(parent, Vector3(x, 0, 0.58), 0.26)
				"workshop":
					box(parent, "WorkshopAwning", Vector3(0, 1.75, 0.79), Vector3(1.6, 0.10, 0.42), Color("537c83"))
					beam(parent, "HammerHandle", Vector3(0.5, 0.5, 0.95), Vector3(0.5, 1.35, 0.95), 0.065)
					box(parent, "HammerHead", Vector3(0.5, 1.3, 0.95), Vector3(0.32, 0.16, 0.12), DARK)

func windmill(parent: Node3D) -> void:
	# Open post mill: the shaft and grinding stones remain visible from every side.
	millstone(parent, "Bedstone", Vector3(0, 0.15, 0), 0.64, 0.18, 0.30, STONE)
	var runner := Node3D.new()
	runner.name = "Runner"
	runner.position.y = 0.44
	parent.add_child(runner)
	millstone(runner, "GrindingStone", Vector3.ZERO, 0.61, 0.18, 0.24, CHALK)
	box(runner, "StoneKey", Vector3(0.40, 0.125, 0), Vector3(0.27, 0.025, 0.06), STONE)
	var chair := Node3D.new()
	chair.name = "Chair"
	chair.position = Vector3(0, 0, 0.93)
	parent.add_child(chair)
	box(chair, "Seat", Vector3(0, 0.40, 0), Vector3(0.48, 0.09, 0.45), PLANK)
	for x in [-0.18, 0.18]:
		for z in [-0.16, 0.16]:
			beam(chair, "ChairLeg", Vector3(x, 0, z), Vector3(x, 0.40, z), 0.065)
		beam(chair, "BackPost", Vector3(x, 0.40, 0.16), Vector3(x, 0.84, 0.16), 0.06)
	box(chair, "ChairBack", Vector3(0, 0.74, 0.16), Vector3(0.44, 0.19, 0.065), PLANK)
	var manual := Node3D.new()
	manual.name = "ManualDrive"
	parent.add_child(manual)
	beam(manual, "Spindle", Vector3(0, 0.35, 0), Vector3(0, 1.06, 0), 0.13)
	beam(manual, "Lever", Vector3(-0.90, 0.95, 0), Vector3(0.90, 0.95, 0), 0.11)
	for x in [-0.87, 0.87]:
		beam(manual, "HandGrip", Vector3(x, 0.95, -0.19), Vector3(x, 0.95, 0.19), 0.07, END_GRAIN)
	var tower := Node3D.new()
	tower.name = "WindTower"
	parent.add_child(tower)
	for x in [-0.72, 0.72]:
		for z in [-0.64, 0.64]:
			beam(tower, "Post", Vector3(x, 0, z), Vector3(x * 0.88, 2.72, z * 0.88), 0.16)
	for z in [-0.57, 0.57]:
		beam(tower, "CrossBeam", Vector3(-0.76, 2.25, z), Vector3(0.76, 2.25, z), 0.17)
	for x in [-0.64, 0.64]:
		beam(tower, "SideBeam", Vector3(x, 2.25, -0.70), Vector3(x, 2.25, 0.70), 0.16)
		beam(tower, "KneeBrace", Vector3(x, 1.76, -0.58), Vector3(x, 2.25, -0.10), 0.10)
	beam(tower, "CentralShaft", Vector3(0, 0.42, 0), Vector3(0, 3.04, 0), 0.16)
	box(tower, "GearHousing", Vector3(0, 2.72, -0.02), Vector3(1.24, 0.82, 1.20), WOOD)
	# Two sloping timber/earth planes form the steep triangular roof in the references.
	for side in [-1, 1]:
		var roof := box(tower, "RoofSlope", Vector3(side * 0.43, 3.04, -0.02), Vector3(1.38, 0.09, 1.66), CLAY)
		roof.rotation.z = -side * 0.91
		beam(tower, "GableRafter", Vector3(side * 0.87, 2.51, 0.84), Vector3(0, 3.60, 0.84), 0.10, END_GRAIN)
	beam(tower, "Ridge", Vector3(0, 3.60, -0.91), Vector3(0, 3.60, 0.91), 0.08, END_GRAIN)
	beam(tower, "RotorAxle", Vector3(0, 3.04, 0), Vector3(0, 3.04, 0.98), 0.15)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0, 3.04, 1.0)
	rotor.scale = Vector3(3, 3, 1)
	tower.add_child(rotor)
	for index in 4:
		var sail := Node3D.new()
		sail.name = "Sail%d" % index
		sail.rotation.z = index * PI * 0.5 + PI * 0.25
		rotor.add_child(sail)
		beam(sail, "Spoke", Vector3.ZERO, Vector3(0, 0.94, 0), 0.065)
		box(sail, "LinenSail", Vector3(0.15, 0.62, 0), Vector3(0.29, 0.58, 0.035), CHALK)
		beam(sail, "OuterFrame", Vector3(0.30, 0.32, 0.025), Vector3(0.30, 0.94, 0.025), 0.035, PLANK)
		for y in [0.33, 0.63, 0.92]:
			beam(sail, "SailRib", Vector3(0, y, 0.03), Vector3(0.31, y, 0.03), 0.035, PLANK)
	var hub := cylinder(rotor, "Hub", Vector3(0, 0, 0.065), 0.13, 0.10, WOOD)
	hub.rotation.x = PI * 0.5

func millstone(parent: Node3D, name_: String, centre: Vector3, radius: float, eye: float, height: float, colour: Color) -> MeshInstance3D:
	# Four annular surfaces: the grain eye is actual open geometry, never a painted dot.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for index in 32:
		var a := TAU * index / 32.0
		var b := TAU * (index + 1) / 32.0
		var outer_a := Vector3(cos(a) * radius, 0, sin(a) * radius)
		var outer_b := Vector3(cos(b) * radius, 0, sin(b) * radius)
		var inner_a := Vector3(cos(a) * eye, 0, sin(a) * eye)
		var inner_b := Vector3(cos(b) * eye, 0, sin(b) * eye)
		var up := Vector3.UP * height * 0.5
		var face := 0
		for quad in [[outer_a + up, outer_b + up, inner_b + up, inner_a + up],
			[inner_a - up, inner_b - up, outer_b - up, outer_a - up],
			[outer_a - up, outer_b - up, outer_b + up, outer_a + up],
			[inner_b - up, inner_a - up, inner_a + up, inner_b + up]]:
			tool.set_color(Color(0.42, 0.38, 0.32) if face == 3 else Color.WHITE)
			face += 1
			triangle(tool, quad[0], quad[1], quad[2])
			triangle(tool, quad[0], quad[2], quad[3])
	tool.generate_normals()
	var result := mesh(parent, name_, tool.commit(), centre, colour)
	var stone_material := material(colour).duplicate() as StandardMaterial3D
	stone_material.vertex_color_use_as_albedo = true
	stone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.material_override = stone_material
	return result

func log_shed(parent: Node3D) -> void:
	# Small open rain shelter, authored directly in metres: 1 x 2 x 1.5.
	for x in [-0.40, 0.40]:
		for z in [-0.82, 0.82]:
			beam(parent, "ShedPost", Vector3(x, 0, z), Vector3(x, 1.0, z), 0.11)
		beam(parent, "SideRail", Vector3(x, 0.96, -0.89), Vector3(x, 0.96, 0.89), 0.10)

	for z in [-0.82, 0.82]:
		beam(parent, "RoofBearer", Vector3(-0.45, 1.375, z), Vector3(0.45, 0.979, z), 0.07)
		beam(parent, "HighRiser", Vector3(-0.40, 0.99, z), Vector3(-0.40, 1.34, z), 0.08)
		beam(parent, "EndRail", Vector3(-0.44, 0.96, z), Vector3(0.44, 0.96, z), 0.10)
		box(parent, "LogSleeper", Vector3(0, 0.065, z * 0.73), Vector3(0.84, 0.13, 0.13), WOOD)
	var canopy := Node3D.new()
	canopy.name = "Canopy"
	parent.add_child(canopy)
	# Broad overlapping courses create the reference's stepped eave on one pitch.
	for index in 5:
		var x := -0.39 + index * 0.195
		var course := box(canopy, "RoofCourse%d" % index, Vector3(x, 1.245 - 0.44 * x, 0), Vector3(0.24, 0.07, 2.0), CLAY.darkened((index % 2) * 0.045), 0.015)
		course.rotation.z = -atan(0.44)

func hay_barn(parent: Node3D) -> void:
	# Half of a square pyramid, cut through its apex on the +X joining edge.
	for x in [-0.44, 0.44]:
		for z in [-0.90, 0.90]:
			beam(parent, ("JoinPost" if x > 0 else "OuterPost") + ("Front" if z > 0 else "Back"), Vector3(x, 0, z), Vector3(x, 0.97, z), 0.10)
	for z in [-0.90, 0.90]:
		beam(parent, "EndRail", Vector3(-0.46, 0.95, z), Vector3(0.46, 0.95, z), 0.08)
	beam(parent, "OuterRail", Vector3(-0.44, 0.95, -0.93), Vector3(-0.44, 0.95, 0.93), 0.08)
	var canopy := Node3D.new()
	canopy.name = "Canopy"
	parent.add_child(canopy)
	var peak := Vector3(0.50, 1.46, 0)
	var corners := [Vector3(0.50, 0.98, -1), Vector3(-0.50, 0.98, -1), Vector3(-0.50, 0.98, 1), Vector3(0.50, 0.98, 1)]
	for index in 3:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		triangle(tool, peak, corners[index], corners[index + 1])
		tool.generate_normals()
		var face := mesh(canopy, "RoofFace%d" % index, tool.commit(), Vector3.ZERO, CLAY)
		var paint := material(CLAY).duplicate() as StandardMaterial3D
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		face.material_override = paint
	for index in 4:
		beam(parent, "SeamRafter%d" % index if index in [0, 3] else "HipRafter%d" % index, peak, corners[index] * Vector3(0.96, 1, 0.96), 0.055, END_GRAIN)
