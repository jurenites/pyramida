extends SceneTree
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fixture := Fixture.new()
	for direction in 4:
		var world = fixture.fixture()
		world.buildings[Vector3i.ZERO] = {"kind": "log_shed", "direction": direction, "reviewed": true}
		world.rebuild_navigation()
		check(world.snap_cell("log_shed", "log_shed", Vector3i.ZERO) == Vector3i.UP, "Shed stacks at one metre")
		check(world.build_error("log_shed", Vector3i.UP, direction).is_empty(), "Shed accepts identical upper shed at every heading: " + world.build_error("log_shed", Vector3i.UP, direction))
		check(world.request_build("log_shed", Vector3i.UP, direction), "Queue upper shed")
		if world.plans.is_empty(): continue
		var plan: Dictionary = world.plans.values()[0]
		check(world.Planning.ready(world, plan), "Upper shed ready on the lower footprint")
		plan.installed = plan.required; plan.used = plan.materials.duplicate(); world._complete_plan(plan)
		check(world.buildings.has(Vector3i.UP), "Upper shed completes")
		check(world.request_build("log_shed", Vector3i.UP * 2, direction), "Third shed can be queued")
		check(not world.Relocation.source_error(world, Vector3i.ZERO).is_empty(), "Occupied lower shed cannot be moved away")
		check(not world.supports_build_cell(Vector3i(2, 1, 2)), "No support beyond the footprint")
		var restored := Model.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Shed stack survives save/load")
	var world = fixture.fixture()
	world.buildings[Vector3i.ZERO] = {"kind": "mill", "direction": 0, "reviewed": true}
	world.rebuild_navigation()
	check(world.snap_cell("log_shed", "mill", Vector3i.ZERO) == Vector3i(0, 5, 0), "Mill roof socket ignores blade sweep")
	check(world.request_build("log_shed", Vector3i(0, 5, 0)), "Shed can be placed above main Mill roof")
	check(not world.supports_build_cell(Vector3i(2, 5, 0)), "Mill does not support buildings outside its three-metre base")
	check(not world.supports_build_cell(Vector3i(0, 2, 0)), "Tall Mill does not create a phantom roof at two metres")
	# A narrow planned shed must not support a rotated upper shed outside its footprint.
	world = fixture.fixture()
	check(world.request_build("log_shed", Vector3i.ZERO), "Queue base shed")
	check(world.request_build("log_shed", Vector3i.UP), "Queue matching stack before base completes")
	check(not world.request_build("log_shed", Vector3i.UP * 2, 1), "Reject unsupported rotated upper footprint")
	# Completed renderer removes the lower canopy but keeps the upper roof.
	world = fixture.fixture()
	for cell in [Vector3i.ZERO, Vector3i.UP]:
		world.buildings[cell] = {"kind": "log_shed", "direction": 0, "reviewed": true}
		world.stores[cell] = world.Inventory.new()
	world.rebuild_navigation()
	var view := View.new(); root.add_child(view); view.fog_enabled = false; view.setup(world)
	check(not view.store_views[Vector3i.ZERO].get_node("Canopy").visible, "Lower shed canopy opens for upper building")
	check(view.store_views[Vector3i.UP].has_node("AssembledBuilding/Covering"), "Top shed retains its procedural canopy")
	var mill_cell := Vector3i(5, 0, 0)
	world.buildings[mill_cell] = {"kind": "mill", "direction": 0, "reviewed": true}
	world.buildings[mill_cell + Vector3i.UP * 5] = {"kind": "support", "direction": 0, "reviewed": true}
	world.rebuild_navigation(); view.sync(world, 0, -1)
	var mill: Node3D = view.entity_views["building:%s" % mill_cell]
	check(mill.get_node("StackSupport").visible and mill.get_node("StackSupport").get_child_count() > 0, "Stacked Mill displays a real bearing frame and deck")
	world.buildings.erase(mill_cell + Vector3i.UP * 5)
	world.rebuild_navigation(); view.sync(world, 0, -1)
	check(not mill.get_node("StackSupport").visible, "Unstacked Mill retains its original pitched roof silhouette")
	view.free(); fixture.free()
	print("PASS: exact roof footprints, Shed stacks, Mill roof stacking, construction and persistence" if failures.is_empty() else "FAIL: building stacking")
	quit(int(not failures.is_empty()))
