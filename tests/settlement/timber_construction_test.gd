extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Labour = preload("res://scripts/applied_labour.gd")
const TREE := Vector3i(-4, 0, 2)
const STORE := Vector3i(-6, 0, 2)
var failures: Array[String] = []
var checks := 0
var model: RefCounted
var view: Node3D

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _initialize() -> void: call_deferred("run")

func cut(worker_id: int) -> void:
	var worker: Dictionary = model.workers[worker_id]
	var inventory: RefCounted = model.trees[TREE].inventory
	check(inventory.reserve(worker_id, "log"), "A cutter reserves one real log")
	worker.job = {"kind": "fell", "phase": "collect", "target": TREE, "source": inventory, "labour": Labour.new(0.01)}
	model.tick_citizen_job(worker, 0.1)

func deliver(worker_id: int) -> void:
	var worker: Dictionary = model.workers[worker_id]
	worker.cell = model.navigation.access_cells(STORE)[0]
	worker.position = model.Navigation.point(worker.cell)
	model.tick_citizen_job(worker, 0.1)

func step(seconds: float) -> void: view.sync(model, seconds, -1)

func run() -> void:
	model = Model.new()
	model.setup()
	model.deposits.clear()
	model.plans.clear()
	model.gardens.clear()
	model.trees.clear()
	var inventory := Inventory.new()
	inventory.store("log", 3)
	model.trees[TREE] = {"inventory": inventory, "kind": "living", "appearance_seed": 517, "regrowth": 0.0}
	model.stores[STORE].amounts.clear()
	model.buildings[STORE] = {"kind": "log_shed", "direction": 0}
	for worker in model.workers:
		worker.life_stage = "adult"
		worker.role = "idle"
		worker.job = {}
	model.rebuild_navigation()
	view = View.new()
	root.add_child(view)
	view.setup(model)
	var Frame = preload("res://scripts/settlement/timber_frame.gd")
	var original: Node3D = view.tree_views[TREE].get_node("Segment3")
	var bark: MeshInstance3D = original.get_node("Trunk")
	cut(0); step(1); deliver(0); step(1)
	check(model.request_build("log_shed", Vector3i.ZERO, 1), "A real rotated shed plan can be built")
	var plan: Dictionary = model.plans.values()[0]
	step(0)
	var site: Node3D = view.entity_views["plan:%s" % plan.id]
	var slots: Array = Frame.slots(site)
	check(slots.size() >= plan.required, "Authored frame has full-size stock destinations")
	var worker: Dictionary = model.workers[0]
	for round_ in plan.required:
		if round_ > 0:
			cut(0); step(1); deliver(0); step(1)
		var actual: Node3D = view.store_views[STORE].get_meta("logs")[0]
		var stock_pose := actual.global_transform
		check(model.stores[STORE].reserve(0, "log"), "Builder reserves one deposited piece")
		worker.route = []; worker.route_index = 0
		worker.job = {"kind": "build", "phase": "pickup", "source": model.stores[STORE], "plan_id": plan.id, "target": STORE, "labour": Labour.new(0.01)}
		preload("res://scripts/settlement/job_system.gd").claim_material(plan, "log", 1)
		model.tick_citizen_job(worker, 0.1)
		check(view.actors[0].cargo == actual, "Pickup uses the actual pile node")
		check(actual.global_transform.is_equal_approx(stock_pose), "Pile pickup starts without a snap")
		check(model.stores[STORE].count("log") == 0, "Pickup consumes exactly one unit")
		step(0.2)
		var paused := actual.global_transform
		step(0)
		check(actual.global_transform.is_equal_approx(paused), "Pause freezes pile pickup")
		step(1)
		worker.cell = model.navigation.access_cells(plan.cell)[0]
		worker.position = model.Navigation.point(worker.cell)
		worker.route = []; worker.route_index = 0
		worker.job.phase = "work"
		worker.job.target = plan.cell
		step(0)
		var hands := actual.global_transform
		model.tick_citizen_job(worker, 0.1)
		check(plan.installed == round_ + 1, "Labour installs exactly one material")
		step(0)
		check(actual.global_transform.is_equal_approx(hands), "Frame placement starts from the hands")
		step(0.2)
		paused = actual.global_transform
		step(0)
		check(actual.global_transform.is_equal_approx(paused), "Pause freezes frame placement")
		check(actual.global_basis.get_scale().is_equal_approx(Vector3.ONE), "The placed log stays full-size")
		step(1)
		var binding: Dictionary = view.timber_motion.frames[round_]
		var frame: Node3D = view.timber_motion.frame_root(binding)
		var slot: Dictionary = view.timber_motion.frame_slot(binding)
		check(actual.get_parent() == frame and actual.transform.is_equal_approx(slot.pose), "The carried piece occupies its authored structural position")
		check(actual.is_visible_in_tree(), "Placed timber remains visible in the frame")
		if round_ == 0:
			check(actual == original and actual.get_node("Bark") == bark, "Tree, hands, pile and frame share the exact same nodes")
			var saved: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
			var loaded = Model.new()
			check(loaded.restore(saved) and loaded.plans[plan.id].installed == 1 and loaded.stores[STORE].count("log") == 0, "Save records installed timber once, without replay")
			view.appearance_revision = -1
			step(0)
			check(is_instance_valid(original) and original.get_parent() == view.timber_motion.frame_root(binding), "Appearance rebuild retains the physical installed log")
	check(not model.plans.has(plan.id) and model.buildings[plan.cell].kind == "log_shed", "Actual labour completes the building")
	check(is_instance_valid(original) and original.get_node("Bark") == bark, "Completion preserves the first actual tree section")
	check(view.timber_motion.frames.size() == plan.required and view.timber_motion.moving.is_empty(), "All delivered logs remain installed after completion")
	model.revision += 1; step(0)
	check(original.is_visible_in_tree(), "Subsequent world rebuilds keep installed logs")
	# Two builders pick up and finish work before the next rendered frame.
	check(model.request_build("log_shed", Vector3i(3, 0, 0)), "Second site accepts concurrent builders")
	var concurrent: Dictionary = model.plans.values()[0]
	model.stores[STORE].store("log", 2)
	model.revision += 1; step(0)
	var pieces: Array = []
	for id in 2:
		var builder: Dictionary = model.workers[id]
		pieces.append(view.store_views[STORE].get_meta("logs")[1 - id])
		model.stores[STORE].reserve(id, "log")
		preload("res://scripts/settlement/job_system.gd").claim_material(concurrent, "log", 1)
		builder.route = []; builder.route_index = 0
		builder.job = {"kind": "build", "phase": "pickup", "source": model.stores[STORE], "target": STORE, "plan_id": concurrent.id, "labour": Labour.new(0.01)}
		model.tick_citizen_job(builder, 0.1)
		builder.route = []; builder.route_index = 0
		builder.cell = model.navigation.access_cells(concurrent.cell)[0]
		builder.position = model.Navigation.point(builder.cell)
		builder.job.phase = "work"; builder.job.target = concurrent.cell
		model.tick_citizen_job(builder, 0.1)
	step(1)
	check(view.timber_motion.moving.size() == 2 and view.timber_motion.moving.all(func(t): return t.stage == "frame"), "Fast concurrent jobs still animate pickup before placement")
	step(0.1)
	check(not view.timber_motion.moving.is_empty(), "Concurrent placement remains animated")
	step(1)
	check(pieces[0].get_parent() == pieces[1].get_parent() and not pieces[0].transform.is_equal_approx(pieces[1].transform), "Concurrent builders retain distinct nodes and frame slots")
	model.plans.erase(concurrent.id); model.revision += 1
	step(0)
	check(not is_instance_valid(pieces[0]) and not is_instance_valid(pieces[1]), "Removing a construction site cleans up its physical frame nodes")
	check(is_instance_valid(original), "Removing another site preserves completed timber")
	view.timber_motion.frames[0].settled = false
	original.reparent(view.timber_motion, true)
	view.timber_motion.queue(original, {"stage": "frame", "binding": view.timber_motion.frames[0]})
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	check(model.restore(snapshot), "Restore can interrupt an active frame placement")
	step(0)
	check(view.timber_motion.frames.is_empty() and view.timber_motion.moving.is_empty(), "Restore clears both moving and installed references safely")
	view.free()
	if failures.is_empty(): print("PASS: %d tree-to-frame identity, construction, pause and save checks" % checks)
	else:
		for message in failures: printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))
