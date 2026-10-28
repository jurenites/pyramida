extends SceneTree
const Generator = preload("res://scripts/settlement/nature_generator.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Trees = preload("res://scripts/settlement/tree_view.gd")
const Bush = preload("res://scripts/settlement/bush_view.gd")
const Identity = preload("res://scripts/settlement/nature_identity.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for palm in [false, true]:
		var shapes := {}
		for seed_value in 100:
			var points := Generator.skeleton(seed_value, palm)
			check(points == Generator.skeleton(seed_value, palm), "Same seed gives identical joints")
			shapes[points] = true
			var previous := Vector3.UP
			for index in range(1, points.size()):
				var direction := (points[index] - points[index - 1]).normalized()
				var limit: float = Generator.DEFAULT_PROFILE.palm_lean if palm else Generator.DEFAULT_PROFILE.trunk_lean
				check(rad_to_deg(Vector3.UP.angle_to(direction)) <= limit + 0.001, "Trunk respects lean limit")
				check(rad_to_deg(previous.angle_to(direction)) <= Generator.DEFAULT_PROFILE.joint_bend + 0.001, "Consecutive joints respect bend limit")
				previous = direction
		check(shapes.size() == 100, "One hundred seeds give one hundred shapes")
	var straight := Generator.DEFAULT_PROFILE.duplicate()
	straight.joint_bend = 0.0
	for point in Generator.skeleton(55, true, straight):
		check(is_zero_approx(point.x) and is_zero_approx(point.z), "Zero bend produces an upright trunk")
	for kind in ["living", "dead", "palm"]: test_tree(kind)
	test_plain_trunks()
	test_identity()
	test_workbench()
	test_normals()
	for seed_value in 20:
		check(Bush.foliage_mesh(seed_value).get_faces() != Bush.foliage_mesh(seed_value + 7).get_faces(), "Bush shapes no longer repeat every seven seeds")
	for seed_value in 180: Bush.foliage_mesh(seed_value)
	check(Bush.meshes.size() <= Bush.MESH_CACHE_LIMIT, "Bush cache stays bounded during streaming")
	if failures.is_empty(): print("PASS: %d procedural nature, bend, harvest and persistence checks" % checks)
	else:
		for message in failures: printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))

func test_tree(kind: String) -> void:
	var node := Assets.create({"living": "tree", "dead": "dead_tree", "palm": "palm"}[kind])
	var inventory := Inventory.new()
	inventory.store("log", 3)
	var tree := {"kind": kind, "inventory": inventory, "appearance_seed": 517}
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	body.add_child(collider)
	node.add_child(body)
	node.set_meta("collider", body)
	var original_mesh: Mesh
	var previous_height := INF
	for amount in [3, 2, 1, 0]:
		inventory.amounts.log = amount
		Trees.sync(node, tree)
		check(collider.shape.size.y < previous_height, "Generated picking bounds shrink after each cut")
		previous_height = collider.shape.size.y
		for index in 3: check(node.get_node("Segment%d" % (index + 1)).visible == (index < amount), "Generated logs disappear top-down")
		check(node.get_node("StumpCut").visible == (amount == 0), "Generated stump retains end grain")
		if original_mesh == null: original_mesh = node.get_node("Segment1/Trunk").mesh
		else: check(node.get_node("Segment1/Trunk").mesh == original_mesh, "Harvest does not regenerate surviving geometry")
		var bounds := AABB(collider.position - collider.shape.size * 0.5, collider.shape.size).grow(0.0001)
		for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var transform_ := part.transform
			var shown := part.visible
			var parent := part.get_parent()
			while parent != node:
				shown = shown and parent.visible
				transform_ = parent.transform * transform_
				parent = parent.get_parent()
			if shown:
				for vertex in part.mesh.get_faces(): check(bounds.has_point(transform_ * vertex), "Picking encloses all visible bent geometry")
	node.free()

func test_identity() -> void:
	var model = Model.new()
	model.setup()
	var cell: Vector3i = model.trees.keys()[0]
	var seed_value: int = model.trees[cell].appearance_seed
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Generated plants save and restore")
	check(restored.trees[cell].appearance_seed == seed_value, "Saved shape is identical")
	var moved: Dictionary = restored.trees[cell]
	Identity.ensure(moved, cell + Vector3i(10, 0, 10), model.world_seed)
	check(moved.appearance_seed == seed_value, "Moving a plant keeps its identity")
	var chunk := Vector2i(8, -8)
	model.Chunks.integrate(model, chunk, model.Generator.generate_chunk(model.world_seed, chunk))
	var remote: Vector3i
	for candidate: Vector3i in model.trees:
		if model.Chunks.chunk_for(candidate) == chunk: remote = candidate; break
	check(remote != Vector3i.ZERO, "Streaming fixture has a tree")
	if remote != Vector3i.ZERO:
		model.trees[remote].appearance_seed = 123456
		model.Chunks.unload_chunk(model, chunk)
		model.Chunks.integrate(model, chunk, model.Generator.generate_chunk(model.world_seed, chunk))
		check(model.trees[remote].appearance_seed == 123456, "Streaming preserves a relocated identity")
	var bush: Dictionary
	for deposit: Dictionary in model.deposits.values():
		if deposit.kind == "berry": bush = deposit; break
	var payload: Dictionary = model.BushTransplants.pack(bush)
	check(model.BushTransplants.unpack(payload).appearance_seed == bush.appearance_seed, "Collected bushes retain shape identity")

func test_workbench() -> void:
	var preview = load("res://scenes/settlement/NatureGenerator.tscn").instantiate()
	root.add_child(preview)
	var tree: Node3D = preview.samples.get_child(0)
	var before: PackedVector3Array = tree.get_meta("nature_skeleton")
	preview.profile.joint_bend = 0.0
	var buttons: Array[Node] = preview.find_children("*", "Button", true, false)
	check(buttons.size() == 1, "Workbench exposes Generate")
	buttons[0].pressed.emit()
	var after: PackedVector3Array = preview.samples.get_child(0).get_meta("nature_skeleton")
	check(before != after, "Generate applies edited limits")
	for point in after: check(is_zero_approx(point.x) and is_zero_approx(point.z), "Preview obeys zero bend")
	check(Generator.DEFAULT_PROFILE.joint_bend == 9, "Preview controls do not mutate game defaults")
	preview.free()

func test_normals() -> void:
	var node := Node3D.new()
	Generator.tube(node, "Tube", PackedVector3Array([Vector3.ZERO, Vector3.UP]), 0.2, 0.2, Color.WHITE)
	var arrays: Array = node.get_child(0).mesh.surface_get_arrays(0)
	for index in arrays[Mesh.ARRAY_VERTEX].size():
		var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
		var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][index]
		check(normal.dot(Vector3(vertex.x, 0, vertex.z)) > 0, "Trunk normals point outward")
	node.free()

func test_plain_trunks() -> void:
	for tree_kind in ["living", "dead"]:
		for seed_value in [17, 517, 9182]:
			var tree_node := Node3D.new()
			Generator.populate(tree_node, tree_kind, seed_value)
			check(tree_node.find_children("*Root*", "MeshInstance3D", true, false).is_empty(), "Tree enters soil without exposed roots")
			var joint_points: PackedVector3Array = tree_node.get_meta("nature_skeleton")
			var stock_radius: float = Generator.Timber.LOG_DIAMETER * 0.5
			var base_mesh: Mesh = tree_node.get_node("Stump").mesh
			for vertex_point in base_mesh.get_faces():
				check(absf(Vector2(vertex_point.x, vertex_point.z).length() - stock_radius) < stock_radius * 0.031, "Ground entry has no flared base")
			for segment_index in 3:
				var trunk_mesh: Mesh = tree_node.get_node("Segment%d/Trunk" % (segment_index + 1)).mesh
				for vertex_point in trunk_mesh.get_faces():
					for joint_index in range(segment_index * 2, segment_index * 2 + 3):
						var joint_point := joint_points[joint_index]
						if not is_equal_approx(vertex_point.y, joint_point.y): continue
						var ring_radius := Vector2(vertex_point.x - joint_point.x, vertex_point.z - joint_point.z).length()
						check(ring_radius >= stock_radius * 0.91 and ring_radius <= stock_radius * 1.031, "All trunk rings stay close to loose log diameter")
			tree_node.free()
