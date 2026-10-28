extends SceneTree
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

func fresh():
	var model = Model.new()
	model.setup()
	model.trees.clear()
	model.deposits.clear()
	model.water_sources.clear()
	for worker in model.workers: model.set_role(worker.id, "idle")
	model.rebuild_navigation()
	return model

func reload_world(model):
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Loose materials and overlapping replacement save together")
	return restored

func test_replacement_and_reuse() -> void:
	var model = fresh()
	check(model.request_build("house", Vector3i.ZERO), "Queue original building")
	var id: int = model.next_plan_id - 1
	var plan: Dictionary = model.plans[id]
	plan.installed = 2
	plan.used = {"log": 2}
	model.stores.clear() # The replacement must fetch its material from the cancelled site.
	check(model.delete_plan(id), "Cancel partially installed building immediately")
	check(model.plans[id].relocation.parts.count("log") == 2, "Installed logs remain at the original site")
	check(not model.Relocation.locked(model, Vector3i.ZERO), "Loose materials do not lock the cell")
	check(model.request_build("log_shed", Vector3i.ZERO), "A different building can overlap the loose materials immediately")
	var replacement: int = model.next_plan_id - 1
	model = reload_world(model)
	check(model.order_build(0, replacement), "Builder can work on the replacement")
	check(model.workers[0].job.get("source") == model.plans[id].relocation.parts, "Replacement reuses the loose inventory directly")
	model = reload_world(model)
	for tick in 600:
		if model.workers[0].cargo == "log": break
		model.workers[0].hunger = 0
		model.tick(0.05)
	check(model.workers[0].cargo == "log" and model.plans[id].relocation.parts.count("log") == 1, "Pickup transfers exactly one log without duplication")
	check(model.delete_plan(replacement), "Replacement can also be cancelled")
	check(model.build_error("house", Vector3i.ZERO).is_empty(), "Repeated cancellation leaves the space free")

func test_delivered_and_incoming() -> void:
	var model = fresh()
	model.request_build("house", Vector3i.ZERO)
	var id: int = model.next_plan_id - 1
	var plan: Dictionary = model.plans[id]
	plan.reserved = 1
	plan.claims = {"log": 1}
	var worker: Dictionary = model.workers[0]
	worker.cargo = "log"
	worker.job = {"kind": "build", "plan_id": id, "resource": "log", "phase": "work", "target": Vector3i.ZERO, "labour": Labour.new(2.0)}
	check(model.delete_plan(id), "Cancel after delivery but before installation")
	check(worker.cargo.is_empty() and worker.job.is_empty(), "Delivered cargo is released from the stopped builder")
	check(model.plans[id].relocation.parts.count("log") == 1, "Delivered uninstalled material remains on site")
	model = reload_world(model)
	check(model.request_build("house", Vector3i.ZERO), "Delivered cargo does not reserve the site")
	var next_id: int = model.next_plan_id - 1
	model.plans[next_id].reserved = 1
	model.plans[next_id].claims = {"log": 1}
	worker = model.workers[0]
	worker.cargo = "log"
	worker.job = {"kind": "build", "plan_id": next_id, "resource": "log", "phase": "travel", "target": Vector3i.ZERO, "labour": Labour.new(2.0)}
	model.delete_plan(next_id)
	check(worker.cargo == "log" and worker.job.kind == "restock", "In-transit cargo remains with its carrier")
	check(not model.plans.has(next_id) and model.plans[id].relocation.parts.count("log") == 1, "Incoming cargo is not duplicated into loose materials")

func test_visuals() -> void:
	var model = fresh()
	var view = View.new()
	root.add_child(view)
	view.setup(model)
	for kind in ["house", "platform", "stairs"]:
		var cell := Vector3i.UP if kind == "platform" else Vector3i.ZERO
		check(model.request_build(kind, cell), "Queue %s visual" % kind)
		var id: int = model.next_plan_id - 1
		model.plans[id].installed = 1
		model.plans[id].used = {"log": 1}
		view.sync(model, 0, -1)
		model.delete_plan(id)
		for planning_mode in [false, true]:
			view.planning = planning_mode
			view.sync(model, 0, -1)
			var node: Node3D = view.entity_views["plan:%s" % id]
			check(node.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s leaves no construction or stockpile shell" % kind)
			check(view.entity_views.has("parts:%s:log:0" % id), "%s keeps its physical log in both modes" % kind)
		check(model.plans[id].relocation.pickup_cell == Vector3i.ZERO, "Loose materials remain on the supporting floor")
	view.free()

func run() -> void:
	test_replacement_and_reuse()
	test_delivered_and_incoming()
	test_visuals()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d construction cancellation checks" % checks)
	quit(int(not failures.is_empty()))
