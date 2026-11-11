extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const Generator = preload("res://scripts/settlement/nature_generator.gd")
const Trees = preload("res://scripts/settlement/tree_view.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var loose := Assets.create("log")
	var bark: MeshInstance3D = loose.get_node("Bark")
	check(is_equal_approx(bark.mesh.height, 0.9) and is_equal_approx(bark.mesh.top_radius * 2, 0.23), "Canonical log retains confirmed 0.9 m bark and 0.23 m diameter")
	var bounds := AABB()
	var first := true
	for part: MeshInstance3D in loose.find_children("*", "MeshInstance3D", true, false):
		var box := part.transform * part.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	check(is_equal_approx(bounds.size.x, Timber.LOG_LENGTH), "Stock length includes cut-end discs")
	for kind in ["tree", "dead_tree", "palm"]:
		var tree := Assets.create(kind)
		check_tree(tree, bark)
		for seed_value in [17, 517, 9182]:
			Generator.populate(tree, {"tree": "living", "dead_tree": "dead", "palm": "palm"}[kind], seed_value)
			check_tree(tree, bark)
			var points: PackedVector3Array = tree.get_meta("nature_skeleton")
			for index in 3:
				check(is_equal_approx(points[index * 2].distance_to(points[index * 2 + 2]), Timber.LOG_LENGTH), "Each generated harvest section is exactly one full stock length")
		tree.free()
	var boards := Assets.create("plank")
	for board: MeshInstance3D in boards.find_children("*", "MeshInstance3D", true, false):
		check(board.mesh == Timber.sources("plank")[0].mesh, "Bundle boards reuse the construction stock mesh")
		check(board.mesh.size.is_equal_approx(Timber.BOARD), "Boards retain 0.70 × 0.055 × 0.22 m dimensions")
		check(board.get_active_material(0).albedo_color == loose.get_node("CutEnd").get_active_material(0).albedo_color, "Sawn boards match exposed tree wood")
	boards.free()
	var platform := Assets.create("platform")
	var members := 0
	for part: MeshInstance3D in platform.find_children("*", "MeshInstance3D", true, false):
		if part.get_meta("timber_stock", "") == "log":
			check(part.get_active_material(0) == bark.get_active_material(0), "Building poles and loose logs share the same bark material")
			members += 1
	check(members > 0, "Construction fixture contains log poles")
	platform.free()
	# Exercise the production world view, not a separate display-only pile.
	var model = Model.new()
	model.setup()
	var store_cell := Vector3i(-6, 0, 2)
	model.stores[store_cell].amounts = {"log": 8, "plank": 2}
	model.buildings[store_cell] = {"kind": "log_shed", "direction": 0}
	var worker: Dictionary = model.workers[0]
	worker.life_stage = "adult"
	worker.cargo = "log"
	var view := View.new()
	root.add_child(view)
	view.setup(model)
	var carried: MeshInstance3D = view.actors[0].cargo.get_node("Bark")
	check(carried.mesh == bark.mesh and carried.get_active_material(0) == bark.get_active_material(0), "Actual citizen cargo reuses tree stock and material")
	check(carried.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Carrying never resizes the log")
	var pile: Node3D = view.store_views[store_cell]
	for item: Node3D in pile.get_meta("logs"):
		var stored: MeshInstance3D = item.get_node("Bark")
		check(stored.mesh == bark.mesh and stored.get_active_material(0) == bark.get_active_material(0), "Actual pile slots reuse tree stock and material")
		check(stored.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Storage never resizes the log")
	for bundle: Node3D in pile.get_node("EconomyStock").get_children():
		if bundle.get_meta("resource") != "plank": continue
		check(bundle.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Stored plank bundles retain physical board sizes")
	view.free()
	loose.free()
	if failures.is_empty(): print("PASS: %d timber source, harvest section, carrying, storage and building continuity checks" % checks)
	else:
		for message in failures: printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))

func check_tree(tree: Node3D, bark: MeshInstance3D) -> void:
	for index in 3:
		var part: MeshInstance3D = tree.get_node("Segment%d/Trunk" % (index + 1))
		check(part.mesh == bark.mesh, "Standing tree shares the exact cargo bark mesh")
		check(part.basis.get_scale().is_equal_approx(Vector3.ONE), "No standing log is stretched, widened or tapered")
		check(part.get_active_material(0) == bark.get_active_material(0), "Standing tree and cargo share the exact bark material")
		var cut: MeshInstance3D = tree.get_node("Segment%d/CutFace" % (index + 1))
		check(cut.mesh == Timber.sources("log")[2].mesh, "Exposed tree cuts share the cargo end-grain mesh")
