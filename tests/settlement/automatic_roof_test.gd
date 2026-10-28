extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func finish(model, kind: String, cell: Vector3i) -> void:
	check(model.request_build(kind, cell), "Queue %s at %s: %s" % [kind, cell, model.last_message])
	if model.plans.has(model.next_plan_id - 1):
		model._complete_plan(model.plans[model.next_plan_id - 1])

func caps(node: Node3D) -> int:
	var count := 0
	for panel: Node3D in node.get_node("Roof").get_children():
		count += int(panel.visible)
	return count

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model = Model.new()
	model.setup()
	model.deposits.clear()
	model.trees.clear()
	model.water_sources.clear()
	for kind: String in Catalog.ROOFS:
		model.buildings.clear()
		model.stores.clear()
		model.wells.clear()
		model.plans.clear()
		model.rebuild_navigation()
		finish(model, kind, Vector3i.ZERO)
		check(model.supports_build_cell(Vector3i.UP), "%s can support another floor" % kind)
		check(model.snap_cell("house", kind, Vector3i.ZERO) == (Vector3i.ZERO if kind == "well" else Vector3i.UP), "%s wraps a utility or snaps to the next floor" % kind)
		check(model.request_build("house", Vector3i.UP), "%s supports another building" % kind)
		check(model.plans[model.next_plan_id - 1].materials == Catalog.recipe("house"), "Only the new building costs resources")
		var asset := Assets.create(kind)
		check(asset.has_node("Roof") and is_equal_approx(asset.get_node("RoofSocket").position.y, 2.0), "%s has a shorter roof and socket" % kind)
		for mesh: MeshInstance3D in asset.find_children("*", "MeshInstance3D", true, false):
			var transform_ := mesh.transform
			var parent := mesh.get_parent() as Node3D
			while parent != asset:
				transform_ = parent.transform * transform_
				parent = parent.get_parent() as Node3D
			var bounds := transform_ * mesh.mesh.get_aabb()
			check(bounds.end.y <= 2.001, "%s geometry fits below the next building" % kind)
		asset.free()
	model.buildings.clear()
	model.plans.clear()
	model.stores.clear()
	model.wells.clear()
	model.rebuild_navigation()
	finish(model, "house", Vector3i.ZERO)
	var view = View.new()
	root.add_child(view)
	view.setup(model)
	var lower: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	var identity := lower.get_instance_id()
	check(caps(lower) == 4, "Completed standalone building gets its roof automatically")
	var resources: int = model.resource_total("log")
	check(model.request_build("workshop", Vector3i.UP), "Mixed stack can be planned")
	view.sync(model, 0, -1)
	check(caps(lower) == 4, "Planning does not remove the existing roof")
	model._complete_plan(model.plans[model.next_plan_id - 1])
	view.sync(model, 0, -1)
	check(caps(lower) == 0 and caps(view.entity_views["building:%s" % Vector3i.UP]) == 4, "Roof moves to top of completed stack")
	check(lower.get_instance_id() == identity and model.resource_total("log") == resources and model.plans.is_empty(), "Roof relocation adds no plan, cost or lower-building rebuild")
	check(model.navigation.route(Vector3i(-2, 0, 0), Vector3i(0, 2, 0)).is_empty(), "Roof stacking does not grant magical vertical walking")
	model.buildings.erase(Vector3i.UP)
	model.rebuild_navigation()
	view.sync(model, 0, -1)
	check(caps(lower) == 4, "Roof returns when the upper building disappears")
	finish(model, "house", Vector3i(2, 0, 0))
	finish(model, "house", Vector3i(1, 1, 0))
	view.sync(model, 0, -1)
	check(caps(lower) == 2 and caps(view.entity_views["building:%s" % Vector3i(2, 0, 0)]) == 2, "Offset stack retains the exposed halves of both lower roofs")
	var saved := model.snapshot()
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))), "Stack saves and reloads")
	check(restored.roof_panel_covered(Vector3i.ZERO, Vector3(0.5, 0, 0.5)), "Roof coverage is derived again after reload")
	# An old citizen halfway up a ladder keeps the same progress after height migration.
	model.workers[0].position = Vector3(0, 1.2, 0)
	var legacy := model.snapshot()
	legacy.world.v = legacy.world.v.filter(func(pair): return pair[0] != "level_height")
	check(restored.restore(JSON.parse_string(JSON.stringify(legacy))), "Old floor-height save loads")
	check(is_equal_approx(restored.workers[0].position.y, 1.0), "Old in-flight vertical position scales to the shorter floor")
	var again = Model.new()
	check(again.restore(JSON.parse_string(JSON.stringify(restored.snapshot()))) and is_equal_approx(again.workers[0].position.y, 1.0), "Height migration is applied only once")
	view.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d automatic roof, stack, geometry and save checks" % checks)
		quit()
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
