extends SceneTree
const Site = preload("res://scripts/settlement/construction_site_view.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Labour = preload("res://scripts/applied_labour.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func progress(node: Node3D, plan: Dictionary, ratio: float) -> void:
	var materials: float = ratio * plan.required
	plan.installed = floori(materials)
	var labour := Labour.new(2.0)
	labour.apply(0, (materials - plan.installed) * 2.0)
	Site.sync(node, plan, [{"job": {"kind": "build", "plan_id": plan.id, "labour": labour}}])

func visible_parts(node: Node3D) -> Array:
	return node.get_meta("construction_parts").filter(func(part): return part.mesh.visible)

func test_catalog() -> void:
	for kind: String in Catalog.COSTS:
		if kind in Catalog.SEEDS:
			check(not Site.applies({"kind": kind}), "Seeds use a seed marker rather than a timber frame")
			continue
		var node := Assets.create(kind)
		root.add_child(node)
		var plan := {"id": 1, "kind": kind, "required": Catalog.COSTS[kind], "installed": 0}
		Site.sync(node, plan, [])
		check(node.get_node("ConstructionCorners").get_child_count() == 4, kind + " starts with four branch markers")
		check(visible_parts(node).is_empty(), kind + " has no unearned ghost geometry")
		var corners := node.get_node("ConstructionCorners")
		for branch: Node3D in corners.get_children():
			check(branch.is_visible_in_tree(), kind + " marks every corner before work")
		var parts: Array = node.get_meta("construction_parts")
		for index in parts.size():
			progress(node, plan, parts[index].threshold)
			check(visible_parts(node).size() == index + 1, kind + " reveals exactly the next piece at its work threshold")
			if index > 0: check(parts[index].stage >= parts[index - 1].stage, kind + " follows structural stage order")
		check(node.get_node("ConstructionCorners") == corners, kind + " reuses the site without duplicate markers")
		if node.has_node("StackSupport"):
			check(not node.get_node("StackSupport").visible, kind + " does not invent an upper-floor support")
		node.free()

func test_house_sequence() -> void:
	var node := Assets.create("house")
	root.add_child(node)
	var plan := {"id": 1, "kind": "house", "required": 5, "installed": 0}
	progress(node, plan, 0.15)
	check(visible_parts(node).size() == 2 and visible_parts(node).all(func(part): return part.stage == 0), "Two individual posts appear before horizontal timber")
	progress(node, plan, 0.30)
	check(visible_parts(node).size() == 4, "Four vertical posts finish first")
	progress(node, plan, 0.50)
	check(visible_parts(node).size() == 8 and not node.get_node("BackWall").visible, "Open frame has four posts and four beams with no walls")
	progress(node, plan, 0.85)
	check(node.get_node("BackWall").visible and not node.get_node("Roof/Cap").visible, "Walls precede every roof panel")
	progress(node, plan, 0.90)
	check(node.get_node("Roof").get_children().filter(func(mesh): return mesh.visible).size() == 1, "Roof panels install individually at the end")
	for part in visible_parts(node):
		if part.stage == 2: continue # Preserve authored exceptions such as the thin entrance carpet.
		check(part.mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Installed pieces cast ground shadows")
	plan.relocation = {"stage": "dismantle"}
	Site.sync(node, plan, [])
	check(visible_parts(node).is_empty(), "Relocation destination stays as stakes while the source is dismantled")
	plan.relocation.stage = "rebuild"
	progress(node, plan, 0.50)
	check(visible_parts(node).size() == 8, "Relocated buildings use the same staged frame during rebuilding")
	node.free()

func test_runtime_and_save() -> void:
	var model = Model.new()
	model.setup()
	model.trees.clear()
	model.deposits.clear()
	model.water_sources.clear()
	check(model.request_build("house", Vector3i.ZERO, 1, Vector3(0.12, 0, -0.08)), "Offset rotated site can be queued")
	var plan: Dictionary = model.plans.values()[0]
	var key := "plan:%s" % plan.id
	var view = View.new()
	root.add_child(view)
	view.setup(model)
	var site: Node3D = view.entity_views[key]
	check(site.position.is_equal_approx(Vector3(0.12, 0, -0.08)) and is_equal_approx(site.rotation.y, -PI / 2), "Markers, frame and authored pieces inherit exact placement")
	check(site.get_meta("collider").collision_layer == 2, "Empty marked site remains inspectable")
	var worker: Dictionary = model.workers[0]
	worker.job = {"kind": "build", "phase": "work", "plan_id": plan.id, "target": Vector3i.ZERO, "labour": Labour.new(2.0)}
	worker.job.labour.apply(0, 1.0)
	view.sync(model, 0, -1)
	check(visible_parts(site).size() == 1, "Active work reveals a post without a model revision")
	plan.installed = 2
	plan.used = {"log": 2}
	model.revision += 1
	view.sync(model, 0, -1)
	var count := visible_parts(site).size()
	check(count == 8, "Installed materials plus active work form the open frame")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Partial construction and labour survive JSON")
	var loaded = View.new()
	root.add_child(loaded)
	loaded.setup(restored)
	check(visible_parts(loaded.entity_views[key]).size() == count, "Reload reconstructs exactly the same built pieces")
	var frame_identity: int = site.get_node("ConstructionFrame").get_instance_id()
	model.revision += 1
	view.sync(model, 0, -1)
	check(site.get_node("ConstructionFrame").get_instance_id() == frame_identity, "Unrelated revisions preserve construction geometry")
	model._complete_plan(plan)
	worker.job = {}
	view.sync(model, 0, -1)
	var finished: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	check(not view.entity_views.has(key) and not finished.has_node("ConstructionCorners"), "Completion removes branch markers and temporary frame")
	check(finished.get_node("Roof").get_children().all(func(mesh): return mesh.visible), "Completion retains the full automatic roof")
	check(not Site.applies({"kind": "house", "deconstruction": true}) and not Site.applies({"kind": "tree"}), "Removal and replanting retain their separate visuals")
	loaded.free()
	view.free()

func run() -> void:
	test_catalog()
	test_house_sequence()
	test_runtime_and_save()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d staged construction visual checks" % checks)
	quit(int(not failures.is_empty()))
