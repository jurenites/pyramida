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
	var source_root: Node3D = view.entity_views["stockpile:%s" % plan.cell]
	var identities: Array = view.timber_motion.frames.map(func(binding): return binding.node)
	check(model.Deconstruction.request(model, plan.cell), "Completed timber frame accepts dismantling")
	var removal: Dictionary = model.plans.values()[0]
	step(0)
	check(view.entity_views["plan:%s" % removal.id] == source_root, "Dismantling retains the actual source building root")
	check(identities.all(func(node): return is_instance_valid(node)), "Requesting removal retains all installed objects")
	worker.route = []; worker.route_index = 0
	worker.job = {"kind": "relocate", "phase": "work", "plan_id": removal.id, "target": worker.cell, "labour": removal.relocation.labour}
	model.tick_citizen_job(worker, 10.0)
	check(model.Deconstruction.is_salvage(removal) and removal.relocation.parts.count("log") == 3, "Dismantling exposes precisely the original three construction units")
	step(0)
	check(identities.all(func(node): return is_instance_valid(node) and node.is_visible_in_tree()), "Actual frame logs remain visible at the site")
	check(view.timber_motion.frames.is_empty(), "Recovered pieces no longer belong to the completed frame")
	var recovered: Array = view.timber_motion.recovery.groups[removal.id]
	var frame_poses: Array = recovered.map(func(piece): return piece.pose)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	var loaded = Model.new()
	check(loaded.restore(snapshot), "Unhauled dismantled timber saves")
	var loaded_view := View.new(); root.add_child(loaded_view); loaded_view.setup(loaded)
	check(loaded_view.timber_motion.recovery.groups[removal.id].size() == 3, "Loading reconstructs only the three unhauled pieces")
	for index in 3:
		check(loaded_view.timber_motion.recovery.groups[removal.id][index].pose.is_equal_approx(frame_poses[index]), "Loaded salvage stays at the authored frame position")
	loaded_view.free()
	view.appearance_revision = -1; step(0)
	check(identities.all(func(node): return is_instance_valid(node)), "Appearance rebuild preserves recovered originals")
	for index in 3:
		var piece: Node3D = identities[2 - index]
		var frame_pose := piece.global_transform
		check(removal.relocation.parts.reserve(0, "log"), "Hauler reserves one recovered log")
		worker.route = []; worker.route_index = 0
		worker.job = {"kind": "restock", "phase": "pickup", "source": removal.relocation.parts, "target": removal.relocation.pickup_cell, "salvage_plan_id": removal.id, "labour": Labour.new(0.6)}
		model.tick_citizen_job(worker, 0.1)
		check(view.actors[0].cargo == piece and piece.global_transform.is_equal_approx(frame_pose), "The actual frame piece starts moving into the citizen's hands without a jump")
		check(removal.relocation.parts.count("log") == 2 - index, "Each pickup removes exactly one salvage unit")
		model.Deconstruction.cleanup(model)
		step(0.2)
		var paused := piece.global_transform; step(0)
		check(piece.global_transform.is_equal_approx(paused), "Pause freezes removal from the frame")
		step(1)
		check(piece.get_parent() == view.actors[0].body.get_node("CargoSocket"), "Removed piece stays in the citizen's hands")
		deliver(0); step(1)
		check(view.store_views[STORE].get_meta("logs")[index] == piece, "The same recovered frame log reaches its shed slot")
	check(not model.plans.has(removal.id) and model.stores[STORE].count("log") == 3, "The empty removal site clears after all three logs are picked up")
	check(original == view.store_views[STORE].get_meta("logs")[2] and original.get_node("Bark") == bark, "The original tree and bark nodes complete construction and dismantling unchanged")
	check(model.request_build("log_shed", Vector3i(3, 0, 0)), "Recovered stock can build another shed")
	var reuse: Dictionary = model.plans.values()[0]
	step(0)
	model.stores[STORE].reserve(0, "log")
	preload("res://scripts/settlement/job_system.gd").claim_material(reuse, "log", 1)
	worker.route = []; worker.route_index = 0
	worker.job = {"kind": "build", "phase": "pickup", "source": model.stores[STORE], "target": STORE, "plan_id": reuse.id, "labour": Labour.new(0.01)}
	model.tick_citizen_job(worker, 0.1); step(1)
	check(view.actors[0].cargo == original, "Reusing the stock lifts the original tree piece again")
	worker.route = []; worker.route_index = 0
	worker.cell = model.navigation.access_cells(reuse.cell)[0]
	worker.position = model.Navigation.point(worker.cell)
	worker.job.phase = "work"; worker.job.target = reuse.cell
	model.tick_citizen_job(worker, 0.1); step(1)
	check(view.timber_motion.frames[0].node == original and original.is_visible_in_tree(), "The original piece becomes part of a second building")
	view.free()
	check_contents()
	if failures.is_empty(): print("PASS: %d physical timber construction, dismantling, recovery and reuse checks" % checks)
	else:
		for message in failures: printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))

func check_contents() -> void:
	model = Model.new(); model.setup()
	model.trees.clear(); model.deposits.clear(); model.plans.clear()
	model.buildings[STORE] = {"kind": "log_shed", "direction": 0}
	model.stores[STORE].amounts = {"log": 1}
	check(model.request_build("house", Vector3i.ZERO), "Authored house fixture accepts construction")
	model._complete_plan(model.plans.values()[0])
	for citizen in model.workers:
		citizen.job = {}; citizen.role = "idle"; citizen.life_stage = "adult"
	view = View.new(); root.add_child(view); view.setup(model)
	var content: Node3D = view.store_views[STORE].get_meta("logs")[0]
	var worker: Dictionary = model.workers[0]
	model.stores[STORE].reserve(0, "log")
	worker.job = {"kind": "restock", "phase": "pickup", "source": model.stores[STORE], "target": Vector3i.ZERO, "labour": Labour.new(0.6)}
	worker.route = []; worker.route_index = 0
	model.tick_citizen_job(worker, 0.1); step(1)
	worker.cell = model.navigation.access_cells(Vector3i.ZERO)[0]
	worker.position = model.Navigation.point(worker.cell)
	worker.route = []; worker.route_index = 0
	model.tick_citizen_job(worker, 0.1); step(1)
	check(view.store_views[Vector3i.ZERO].get_meta("logs")[0] == content, "House contains an actual stored log separate from its frame")
	var Frame = preload("res://scripts/settlement/timber_frame.gd")
	var house: Node3D = view.store_views[Vector3i.ZERO]
	var slots: Array = Frame.slots(house)
	var authored_bark: MeshInstance3D = slots[0].mesh
	check(slots[0].index == -1, "House exercises individual authored mesh extraction")
	var authored_pose := authored_bark.global_transform
	check(model.Deconstruction.request(model, Vector3i.ZERO), "House accepts removal")
	var removal: Dictionary = model.plans.values()[0]
	step(0)
	check(is_instance_valid(content), "Dismantling request preserves stored contents")
	worker.route = []; worker.route_index = 0
	worker.job = {"kind": "relocate", "phase": "work", "plan_id": removal.id, "target": worker.cell, "labour": removal.relocation.labour}
	model.tick_citizen_job(worker, 10); step(0)
	check(removal.relocation.parts.count("log") == 6, "Five frame logs and one stored log are recovered exactly once")
	check(is_instance_valid(authored_bark) and authored_bark.global_transform.is_equal_approx(authored_pose), "Authored bark mesh itself is extracted without a vertex jump")
	model.stores[STORE].capacity = 0
	check(not model.Deconstruction.assign_salvage(model, worker, removal), "Full storage leaves recovered stock at the frame")
	check(removal.relocation.parts.count("log") == 6 and content.is_visible_in_tree(), "Waiting for space does not consume or hide recovered timber")
	model.stores[STORE].capacity = 32
	var carried: Array = []
	for id in 2:
		var citizen: Dictionary = model.workers[id]
		removal.relocation.parts.reserve(id, "log")
		citizen.route = []; citizen.route_index = 0
		citizen.job = {"kind": "restock", "phase": "pickup", "source": removal.relocation.parts, "target": removal.relocation.pickup_cell, "salvage_plan_id": removal.id, "labour": Labour.new(0.6)}
		model.tick_citizen_job(citizen, 0.1)
		carried.append(view.actors[id].cargo)
	check(carried[0] == content and carried[1] != content, "Concurrent recovery keeps contents separate from structural stock")
	step(0.2)
	var loaded = Model.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "A save during concurrent extraction restores")
	var loaded_view := View.new(); root.add_child(loaded_view); loaded_view.setup(loaded)
	check(loaded_view.timber_motion.recovery.groups[removal.id].size() == 4 and loaded.workers[0].cargo == "log" and loaded.workers[1].cargo == "log", "Reload has four remaining pieces and two carried pieces, without duplication")
	loaded_view.free()
	for id in 2:
		deliver(id)
	step(1); step(1)
	check(view.store_views[STORE].get_meta("logs")[0] == carried[0] and view.store_views[STORE].get_meta("logs")[1] == carried[1], "Concurrent recovered pieces retain identity through delivery")
	view.free()
