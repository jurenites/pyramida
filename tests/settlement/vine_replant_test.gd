extends SceneTree
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Vines = preload("res://scripts/settlement/vines.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func reload_world(world):
	var restored := Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Vine move survives save/load")
	return restored
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fixture := Fixture.new(); var world = fixture.fixture()
	var source := Vector3i(-3, 0, 0); var target := Vector3i(3, 0, 0)
	world.vines[source] = Vines.create(); world.vines[source].health = 0.75; world.vines[source].water = 90.0
	world.vines[source].nodes = [source]; world.vines[source].parents = [-1]
	check(not Model.Catalog.CATEGORIES.has("nature"), "No Nature construction category")
	check(world.Relocation.request(world, source, target, 0, Vector3(0.3, 0, -0.2)), "Direct Move accepts destination: " + world.last_message)
	if world.plans.is_empty(): fixture.free(); quit(1); return
	var id: int = world.next_plan_id - 1
	check(world.vines.has(source) and world.vine_roots == 0, "Root remains in place until uprooted")
	check(world.Relocation.portable_plant(world.plans[id]), "Move uses physical plant carry")
	world = reload_world(world)
	check(world.order_build(0, id), "Adult accepts vine relocation")
	for i in 500:
		fixture.step(world)
		if world.workers[0].has("plant_plan_id"): break
	check(world.workers[0].get("plant_plan_id", -1) == id and not world.vines.has(source), "Adult uproots and carries existing root")
	world = reload_world(world)
	var view := View.new(); root.add_child(view); view.fog_enabled = false; view.setup(world)
	check(view.actors[0].plant_cargo != null and view.actors[0].plant_cargo.get_child_count() > 0, "Carried vine has visible root model")
	view.free()
	for i in 500:
		fixture.step(world)
		if not world.plans.has(id): break
	check(not world.plans.has(id) and world.vines.has(target), "Adult walks to destination and replants")
	if world.vines.has(target):
		var vine: Dictionary = world.vines[target]
		check(vine.health == 0.75 and vine.water == 90.0, "Root retains health and water")
		check(vine.nodes.is_empty() and vine.parents.is_empty() and vine.radius == Vines.START_RADIUS, "Vine regrows against its new surroundings")
		check(vine.placement_offset.is_equal_approx(Vector3(0.3, 0, -0.2)), "Root keeps chosen free position")
	check(world.vine_roots == 0 and world.vines.size() == 1, "Moving neither creates nor consumes spare roots")
	world = reload_world(world)
	fixture.free()
	print("PASS: direct vine Move, physical carry, exact replant position, save/load and root conservation" if failures.is_empty() else "FAIL: vine relocation")
	quit(int(not failures.is_empty()))
