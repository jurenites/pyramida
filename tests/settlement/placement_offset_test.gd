extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Controller = preload("res://scripts/settlement/settlement.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var model = Model.new()
	model.setup()
	model.trees.clear()
	model.deposits.clear()
	model.water_sources.clear()
	var controller = Controller.new()
	controller.model = model
	controller.tool = "windmill"
	var chosen := Vector3(0.127, 0, -0.093)
	var placement: Dictionary = controller._placement_result(Vector3i.ZERO, "ground", chosen + Vector3.UP * 10, Vector3.DOWN)
	check(placement.offset == Vector3.ZERO, "New construction is centred on the grid socket")
	var nearby: Dictionary = controller._placement_result(Vector3i.ZERO, "ground", chosen + Vector3(0.013, 10, 0), Vector3.DOWN)
	check(nearby.offset == placement.offset, "Sub-grid cursor movement cannot shift a building")
	var roof: Dictionary = controller._placement_result(Vector3i.UP, "house", Vector3(0.1, 6, 0), Vector3(0, -1, 0.02).normalized())
	check(roof.cell == Vector3i.UP and roof.offset == Vector3.ZERO, "Elevated placement retains the exact target socket")
	check(model.placement_offset("house", Vector3i.ZERO, Vector3(10, 0, -10)) == Vector3.ZERO, "New houses have no cursor deviation")
	check(Catalog.valid_placement_offset("house", Vector3(Catalog.PLACEMENT_MARGIN, 0, -Catalog.PLACEMENT_MARGIN)), "Single-precision offsets at the margin remain valid")
	check(model.placement_offset("stairs", Vector3i.ZERO, chosen) == Vector3.ZERO, "Ladder connection geometry stays aligned")
	check(model.request_build("windmill", Vector3i.ZERO, 1, chosen), "Legacy explicit offset remains supported")
	var id: int = model.next_plan_id - 1
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Unfinished offset construction survives JSON save")
	check(restored.plans[id].placement_offset.is_equal_approx(chosen), "Saved plan remembers the chosen offset")
	var view = View.new()
	root.add_child(view)
	view.setup(restored)
	var upper_cell := Vector3i(0, int(Catalog.building_height("windmill")), 0)
	var site: Node3D = view.entity_views["plan:%s" % id]
	check(site.position.is_equal_approx(chosen), "Construction site uses the cursor offset")
	check(not site.get_node("Roof").visible and not site.get_node("StackSupport").visible, "Windmill preview has no generic roof or scaffolding")
	restored._complete_plan(restored.plans[id])
	view.sync(restored, 0, -1)
	var mill: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	check(mill.position.is_equal_approx(chosen) and is_equal_approx(mill.rotation.y, -PI * 0.5), "Completion keeps offset and rotation independently")
	check(mill.get_meta("collider").global_position.is_equal_approx(chosen), "Picking collider follows the visual offset")
	check(not mill.get_node("Roof").visible and not mill.get_node("StackSupport").visible and not mill.get_node("Floor").visible, "Standalone windmill keeps its uncluttered silhouette")
	check(not restored.navigation.surfaces.has(upper_cell), "Open building has no invisible walking floor")
	restored.platforms[upper_cell + Vector3i(2, 0, 0)] = 1
	restored.rebuild_navigation()
	check(restored.request_build("house", upper_cell, 0, Vector3(-0.12, 0, 0.08)), "Another building can still be planned on the windmill: " + restored.last_message)
	view.sync(restored, 0, -1)
	check(mill.get_node("Roof").visible and mill.get_node("StackSupport").visible, "Supports and deck appear only when upper construction is queued")
	check(restored.navigation.surfaces.has(upper_cell), "New visible deck becomes walkable")
	var resources: int = restored.resource_total("log")
	var upper_id: int = restored.next_plan_id - 1
	restored._complete_plan(restored.plans[upper_id])
	view.sync(restored, 0, -1)
	check(mill.get_node("StackSupport").visible and restored.resource_total("log") == resources, "Upper completion retains free supports")
	var upper: Node3D = view.entity_views["building:%s" % upper_cell]
	check(upper.position.is_equal_approx(Nav.point(upper_cell) + Vector3(-0.12, 0, 0.08)), "Each floor remembers its own offset")
	var loaded = Model.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(restored.snapshot()))), "Completed offset stack saves and reloads")
	check(loaded.buildings[Vector3i.ZERO].placement_offset.is_equal_approx(chosen), "Completed windmill keeps its exact saved offset")
	check(loaded.needs_stack_support(Vector3i.ZERO), "Support is restored from the saved stack")
	loaded.buildings.erase(upper_cell)
	loaded.stores.erase(upper_cell)
	loaded.rebuild_navigation()
	view.last_revision = -1
	view.sync(loaded, 0, -1)
	check(not mill.get_node("StackSupport").visible and not mill.get_node("Roof").visible, "Removing upper construction restores the bare building")
	check(loaded.request_build("house", upper_cell), "Can replan upper construction")
	loaded.plans.clear()
	loaded.rebuild_navigation()
	view.sync(loaded, 0, -1)
	check(not mill.get_node("StackSupport").visible, "Cancelling the upper plan removes unnecessary supports")
	var legacy := model.snapshot()
	for pair: Array in legacy.world.v:
		if pair[0] == "plans":
			for plan_pair: Array in pair[1].v:
				plan_pair[1].v = plan_pair[1].v.filter(func(field): return field[0] != "placement_offset")
	check(loaded.restore(legacy), "Older plans without offsets remain compatible")
	check(loaded.plans[id].get("placement_offset", Vector3.ZERO) == Vector3.ZERO, "Older plans stay centered")
	for invalid in [Vector3(INF, 0, 0), Vector3(0, 0.1, 0), Vector3(0.19, 0, 0)]:
		check(not model.request_build("house", Vector3i(4, 0, 0), 0, invalid), "Reject invalid offset at construction boundary")
		var bad := restored.snapshot()
		for pair: Array in bad.world.v:
			if pair[0] == "buildings":
				pair[1].v[0][1].v.append(["placement_offset", {"type": "position", "v": [invalid.x, invalid.y, invalid.z]}])
		check(not loaded.restore(bad), "Reject invalid saved building offset")
	controller.free()
	view.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d cursor placement, support, collider and save checks" % checks)
		quit()
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
