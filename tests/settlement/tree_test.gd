extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const TreeView = preload("res://scripts/settlement/tree_view.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func isolated(kind: String):
	var model = Model.new()
	model.setup()
	model.deposits.clear()
	# This reservation test explicitly needs three competing adult cutters.
	for citizen in model.workers:
		citizen.life_stage = "adult"
	model.plans.clear()
	model.gardens.clear()
	model.trees.clear()
	var inventory = preload("res://scripts/settlement/inventory.gd").new()
	inventory.capacity = 3
	inventory.store("log", 3)
	model.trees[Vector3i(-4, 0, 2)] = {"inventory": inventory, "kind": kind, "regrowth": 0.0}
	model.stores[Vector3i(-6, 0, 2)].amounts = {"log": 0}
	model.buildings[Vector3i(-6, 0, 2)] = {"kind": "log_shed", "direction": 0}
	model.rebuild_navigation()
	return model

func _initialize() -> void:
	for kind in ["living", "dead"]:
		test_harvest(kind)
		test_visuals(kind)
		test_save(kind)
	test_no_regrowth()
	if failures.is_empty():
		print("PASS: %d segmented tree harvest, geometry, persistence and no-regrowth checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func test_harvest(kind: String) -> void:
	var model = isolated(kind)
	var tree: Dictionary = model.trees.values()[0]
	var observed := {3: true}
	var previous := 3
	# Stagger arrivals so each complete cut is observable. All actors compete for
	# the same three logs; reservations must not shorten the standing trunk.
	for index in 3:
		var cell := Vector3i(-2 + index * 2, 0, 1)
		model.workers[index].cell = cell
		model.workers[index].position = Navigation.point(cell)
	# Goal selection is spread across ticks; all three reserve before any cut.
	for tick in 2: model.tick(0.05)
	check(tree.inventory.reservations.size() == 3 and tree.inventory.count("log") == 3, "%s reserves all three logs without removing geometry" % kind)
	for step in 600:
		model.tick(0.05)
		var count: int = tree.inventory.count("log")
		observed[count] = true
		check(count <= previous, "%s cannot gain logs while being cut" % kind)
		previous = count
		var carried := 0
		for worker in model.workers:
			carried += int(worker.cargo == "log")
		check(count + carried + model.resource_total("log") == 3, "%s conserves three logs through cutting and carrying" % kind)
		if model.resource_total("log") == 3:
			break
	check(observed.has(2) and observed.has(1) and observed.has(0), "%s is cut top-down through all three counts" % kind)
	check(model.resource_total("log") == 3 and tree.inventory.count("log") == 0, "%s yields exactly three physically delivered logs" % kind)
	check(model.trees.is_empty(), "%s disappears after the final log" % kind)
	check(tree.inventory.reservations.is_empty(), "%s leaves no reservations after final cut" % kind)

func test_visuals(kind: String) -> void:
	var model = isolated(kind)
	var tree: Dictionary = model.trees.values()[0]
	# This section checks the authored asset; generated bounds have their own suite.
	tree.erase("appearance_seed")
	var asset := Assets.create("dead_tree" if kind == "dead" else "tree")
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	asset.add_child(body)
	asset.set_meta("collider", body)
	check(asset.has_node("AccessFront"), "%s retains an authored access point" % kind)
	check(asset.has_node("Segment3/Crown") == (kind == "living"), "Only living trees have greenery")
	for amount in [3, 2, 1]:
		tree.inventory.amounts.log = amount
		TreeView.sync(asset, tree)
		var expected_height: float = (3.15 if kind == "dead" else 3.72) if amount == 3 else 0.18 + amount * 0.88
		check(is_equal_approx(shape.shape.size.y, expected_height) and is_equal_approx(shape.position.y, expected_height * 0.5), "Picking collider shrinks with remaining trunk")
		for index in 3:
			check(asset.get_node("Segment%d" % (index + 1)).visible == (index < amount), "%s %d/3 has correct removable trunk section" % [kind, amount])
		check(asset.get_node("Stump").visible and asset.get_node("StumpCut").visible == (amount == 0), "Trunk base remains while logs can still be harvested")
		if amount > 0:
			check(asset.get_node("Segment%d/CutFace" % amount).visible, "Highest remaining section has exposed end grain")
	asset.free()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	check(document.append_from_file("res://data/settlement/%s.glb" % ("dead_tree" if kind == "dead" else "tree"), state) == OK, "%s editable GLB parses" % kind)
	var imported := document.generate_scene(state)
	check(imported.has_node("Segment1") and imported.has_node("Segment2") and imported.has_node("Segment3"), "GLB preserves removable segment names")
	imported.free()

func test_save(kind: String) -> void:
	var model = isolated(kind)
	var tree: Dictionary = model.trees.values()[0]
	tree.inventory.amounts.log = 1
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "%s partial tree restores" % kind)
	check(restored.trees.values()[0].kind == kind and restored.trees.values()[0].inventory.count("log") == 1, "Save retains type and remaining trunk")
	tree.erase("kind")
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Earlier saves without kind remain loadable")
	check(restored.trees.values()[0].get("kind", "living") == "living", "Earlier trees default to living")
	tree.kind = "unknown"
	check(not restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Invalid tree kind is rejected")

func test_no_regrowth() -> void:
	for kind in ["living", "dead"]:
		for amount in [3, 2, 1]:
			var model = isolated(kind)
			var tree: Dictionary = model.trees.values()[0]
			tree.inventory.amounts.log = amount
			# Older saves may contain a nearly completed stump regrowth timer.
			tree.regrowth = 44.9
			var restored = Model.new()
			check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "%s %d/3 tree restores before waiting" % [kind, amount])
			for world in [model, restored]:
				var workers: Array = world.workers.duplicate()
				world.workers.clear()
				world.tick(0.2)
				world.tick(200.0)
				var remaining: Dictionary = world.trees.values()[0]
				check(remaining.inventory.count("log") == amount, "%s %d/3 tree stays at its stopped stage, including after loading" % [kind, amount])
				check(is_equal_approx(remaining.regrowth, 44.9), "Legacy tree regrowth timer stays inactive")
				world.workers = workers
				for step in 1000:
					world.tick(0.05)
					if world.resource_total("log") == amount:
						break
				check(world.trees.is_empty() and world.resource_total("log") == amount, "%s %d/3 tree can only yield its remaining logs" % [kind, amount])
