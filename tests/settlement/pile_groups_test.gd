extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Piles = preload("res://scripts/settlement/pile_groups.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const HUD = preload("res://scripts/settlement/hud.gd")
const Tooltip = preload("res://scripts/settlement/object_tooltip.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var model = Model.new()
	model.setup()
	model.stores.clear()
	model.add_store(Vector3i.ZERO, {"log": 4, "food": 2})
	check(Piles.outline(Piles.members(model, Vector3i.ZERO)).size() == 4, "One room plot has four corners")
	model.add_store(Vector3i(2, 0, 0), {"stone": 3})
	check(Piles.outline(Piles.members(model, Vector3i.ZERO)).size() == 4, "Two plots make a rectangle with four corners")
	var hud = HUD.new()
	check(hud._tooltip_key({"kind": "stockpile", "cell": Vector3i.ZERO}, model) == hud._tooltip_key({"kind": "stockpile", "cell": Vector3i(2, 0, 0)}, model), "Hovering another plot of the selected pile shares one tooltip")
	hud.free()
	var total := Piles.totals(model, Vector3i.ZERO)
	check(total.capacity == 64 and total.amounts == {"log": 4, "food": 2, "stone": 3}, "Connected plots sum capacity and goods without duplicating stock")
	check(model.resource_total("stone") == 3, "Global count still counts physical stores once")
	check(Tooltip.describe(model, {"cell": Vector3i.ZERO, "kind": "stockpile"}).rows == Tooltip.describe(model, {"cell": Vector3i(2, 0, 0), "kind": "stockpile"}).rows, "Either plot inspects the same combined pile")
	model.add_store(Vector3i(0, 0, 2))
	check(Piles.outline(Piles.members(model, Vector3i.ZERO)).size() == 6, "L-shaped extension retains six boundary turns")
	model.add_store(Vector3i(2, 0, 2))
	check(Piles.outline(Piles.members(model, Vector3i.ZERO)).size() == 4, "Two by two plots remove every internal corner")
	model.add_store(Vector3i(4, 0, 4))
	model.add_store(Vector3i(0, 1, 0))
	model.add_store(Vector3i(-2, 0, 0))
	model.buildings[Vector3i(-2, 0, 0)] = {"kind": "log_shed", "direction": 0}
	check(Piles.members(model, Vector3i.ZERO).size() == 4, "Diagonal plots, other floors and storage buildings do not merge")
	var view = View.new()
	root.add_child(view)
	view.setup(model)
	var stones := 0
	for cell in Piles.members(model, Vector3i.ZERO):
		for index in 4:
			stones += int(view.store_views[cell].get_node("CornerStone%d" % index).visible)
	check(stones == 4, "Rendered two by two pile has only four stones")
	var copy = Model.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Connected piles save and load")
	check(Piles.totals(copy, Vector3i.ZERO) == Piles.totals(model, Vector3i.ZERO), "Saved inventories and combined capacity survive reload")
	model.stores.erase(Vector3i(2, 0, 2))
	model.revision += 1
	view.sync(model, 0, -1)
	stones = 0
	for cell in Piles.members(model, Vector3i.ZERO):
		for index in 4: stones += int(view.store_views[cell].get_node("CornerStone%d" % index).visible)
	check(stones == 6, "Removing a plot restores newly exposed corner stones")
	view.free()
	var offset = Model.new()
	offset.add_store(Vector3i.ZERO)
	offset.add_store(Vector3i(2, 0, 1))
	check(Piles.members(offset, Vector3i.ZERO).size() == 2 and Piles.outline(Piles.members(offset, Vector3i.ZERO)).size() == 8, "Half-room staggered extension retains its true perimeter")
	var build = Model.new()
	build.setup()
	build.deposits.clear()
	build.trees.clear()
	build.stores.values()[0].store("stone", 1)
	check(build.request_build("stockpile", Vector3i(-4, 0, 2)), "Pile can extend the initial plot edge to edge")
	var plan: Dictionary = build.plans[build.next_plan_id - 1]
	check(plan.required == 1 and plan.materials == {"stone": 1}, "New pile costs one stone")
	check(not build.request_build("stockpile", Vector3i(-5, 0, 2)), "Half-overlapping plots remain rejected")
	for worker in build.workers: build.set_role(worker.id, "idle")
	build.order_build(0, plan.id)
	for step in 600:
		build.tick(0.05)
		if build.stores.has(Vector3i(-4, 0, 2)): break
	check(build.stores.has(Vector3i(-4, 0, 2)) and build.resource_total("stone") == 0, "Citizen physically delivers one stone and completes the extension")
	check(Piles.members(build, Vector3i(-6, 0, 2)).size() == 2, "Completed extension joins the existing pile")
	check(build.request_build("stockpile", Vector3i(0, 0, 0)), "Legacy plan fixture queues")
	var old_plan: Dictionary = build.plans[build.next_plan_id - 1]
	old_plan.required = 2
	old_plan.materials = {"log": 2}
	check(copy.restore(JSON.parse_string(JSON.stringify(build.snapshot()))), "Old two-timber pile plans remain loadable")
	check(copy.plans[old_plan.id].required == 2 and copy.plans[old_plan.id].materials == {"log": 2}, "Old in-flight construction keeps its saved cost")
	if failures.is_empty(): print("PASS: %d pile footprint, corners, storage, construction and save checks" % checks)
	for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
