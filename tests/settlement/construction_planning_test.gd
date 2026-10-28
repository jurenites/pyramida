extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Game = preload("res://scripts/settlement/settlement.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fresh():
	var world = Model.new()
	world.setup()
	for field in ["buildings", "stores", "gardens", "wells", "trees", "deposits", "water_sources", "platforms", "stairs", "plans"]: world.get(field).clear()
	for worker: Dictionary in world.workers:
		worker.cell = Vector3i(-10, 0, -10)
		worker.job = {}
	world.rebuild_navigation()
	return world

func queue(world, kind: String, cell: Vector3i) -> Dictionary:
	check(world.request_build(kind, cell), "Queue %s at %s: %s" % [kind, cell, world.last_message])
	return world.plans.get(world.next_plan_id - 1, {})

func _initialize() -> void: call_deferred("run")

func check_opacity(node: Node3D, future: bool) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		check(is_equal_approx(mesh.transparency, View.Construction.PLAN_TRANSPARENCY if future else 0.0), "%s opacity matches its construction state" % mesh.name)
		if future:
			check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Future %s casts no solid shadow" % mesh.name)

func run() -> void:
	var world = fresh()
	var lower := queue(world, "platform", Vector3i(0, 1, 0))
	var upper := queue(world, "platform", Vector3i(0, 2, 0))
	var decks: Dictionary = world.Planning.platforms(world)
	check(decks == {Vector3i(0, 2, 0): 2}, "Two unbuilt platforms project as a single 2 m tier-2 deck")
	check(world.snap_cell("house", "platform", upper.cell).y == world.snap_cell("house", "house", Vector3i.ZERO).y, "Tier-2 deck aligns with the standard house roof")
	check(not world.request_build("house", lower.cell), "Disappearing middle floor cannot receive a building")
	check(not world.request_build("house", Vector3i.ZERO), "Planned posts reserve their full volume")
	check(not world.request_build("house", Vector3i(1, 2, 0)), "Partial planned support cannot carry a whole building")
	var house := queue(world, "house", upper.cell)
	check(world.platforms.is_empty() and not world.navigation.surfaces.has(upper.cell), "Plans add neither real platforms nor walking floors")
	check(world.Planning.ready(world, lower) and not world.Planning.ready(world, upper) and not world.Planning.ready(world, house), "Builders must complete the foundation first")
	check(world.work_cells("platform", upper.cell).is_empty() and world.work_cells("house", house.cell).is_empty(), "Workers cannot claim elevated work through unfinished support")
	var view = View.new()
	root.add_child(view)
	view.setup(world)
	check(view.entity_views["plan:%s" % lower.id].has_meta("construction_parts"), "Inspection retains normal construction stages")
	view.planning = true
	view.sync(world, 0, -1)
	check(not view.entity_views.has("plan:%s" % lower.id), "Construction view hides the merged intermediate deck")
	var upper_node: Node3D = view.entity_views["plan:%s" % upper.id]
	check(upper_node.get_meta("platform_tier") == 2 and not upper_node.has_meta("construction_parts"), "Merged plan displays the finished tier-2 asset")
	check(upper_node.get_meta("collider").collision_layer == 2, "Projected deck remains available to construction picking")
	var house_node: Node3D = view.entity_views["plan:%s" % house.id]
	check(house_node.get_node("BackWall").visible and house_node.get_node("Roof").visible, "Planned house shows its finished shell and roof")
	check_opacity(upper_node, true)
	check_opacity(house_node, true)
	view.planning = false
	view.sync(world, 0, -1)
	check(view.entity_views.has("plan:%s" % lower.id) and view.entity_views["plan:%s" % upper.id].has_meta("construction_parts"), "Leaving construction restores both actual worksites")
	check_opacity(view.entity_views["plan:%s" % house.id], false)
	view.free()
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Stacked plans save and reload")
	check(restored.Planning.platforms(restored) == decks and not restored.Planning.ready(restored, restored.plans[upper.id]), "Reload preserves projected merge and construction dependency")
	world._complete_plan(lower)
	check(world.Planning.ready(world, upper) and not world.Planning.ready(world, house), "Upper platform unlocks only after lower platform completion")
	world._complete_plan(upper)
	check(world.platforms == decks and world.construction_materials[upper.cell].log == 8, "Actual completion matches projected geometry and preserves both recipes")
	check(world.Planning.ready(world, house), "House unlocks on the finished deck")
	check(world.navigation.route(Vector3i(-2, 0, 0), upper.cell).is_empty(), "No implicit vertical walking connection is introduced")
	world._complete_plan(house)
	check(world.buildings.has(house.cell), "Planned building completes on the merged platform")

	world = fresh()
	lower = queue(world, "platform", Vector3i(0, 1, 0))
	upper = queue(world, "platform", Vector3i(0, 2, 0))
	check(world.delete_plan(upper.id), "Upper plan can be cancelled")
	check(world.Planning.platforms(world) == {lower.cell: 1}, "Cancelling restores the lower tier-1 deck")
	upper = queue(world, "platform", Vector3i(0, 2, 0))
	check(world.delete_plan(lower.id), "Lower plan can be cancelled")
	check(not world.Planning.ready(world, upper) and world.work_cells("platform", upper.cell).is_empty(), "Orphaned upper plan waits safely for replacement support")
	lower = queue(world, "platform", Vector3i(0, 1, 0))
	check(world.Planning.platforms(world) == {upper.cell: 2}, "Replacing the lower plan restores the merge regardless of insertion order")

	world = fresh()
	lower = queue(world, "house", Vector3i.ZERO)
	upper = queue(world, "house", Vector3i(0, 2, 0))
	var third := queue(world, "house", Vector3i(0, 4, 0))
	check(not world.Planning.ready(world, upper) and not world.Planning.ready(world, third), "Multiple building floors can be planned before any construction")
	view = View.new()
	view.planning = true
	root.add_child(view)
	view.setup(world)
	for panel in view.entity_views["plan:%s" % lower.id].get_node("Roof").get_children():
		check(not panel.visible, "Planned stacking covers the lower roof")
	for panel in view.entity_views["plan:%s" % third.id].get_node("Roof").get_children(): check(panel.visible, "Topmost planned building retains its roof")
	view.free()

	world = fresh()
	lower = queue(world, "house", Vector3i.ZERO)
	world._complete_plan(lower)
	upper = queue(world, "house", Vector3i(0, 2, 0))
	view = View.new()
	view.planning = true
	root.add_child(view)
	view.setup(world)
	var built_node: Node3D = view.entity_views["building:%s" % lower.cell]
	house_node = view.entity_views["plan:%s" % upper.id]
	check_opacity(built_node, false)
	check_opacity(house_node, true)
	for panel in built_node.get_node("Roof").get_children(): check(not panel.visible, "Completed lower floor has no covered roof in construction mode")
	for panel in house_node.get_node("Roof").get_children(): check(panel.is_visible_in_tree(), "Every future upper roof panel remains visible")
	view.planning = false
	view.sync(world, 0, -1)
	for panel in view.entity_views["building:%s" % lower.cell].get_node("Roof").get_children(): check(panel.is_visible_in_tree(), "Inspection restores the existing lower roof")
	view.planning = true
	view.sync(world, 0, -1)
	check(world.delete_plan(upper.id), "Cancel future upper floor")
	view.sync(world, 0, -1)
	built_node = view.entity_views["building:%s" % lower.cell]
	check_opacity(built_node, false)
	for panel in built_node.get_node("Roof").get_children(): check(panel.is_visible_in_tree(), "Cancelling restores the solid lower roof")
	upper = queue(world, "house", Vector3i(0, 2, 0))
	view.sync(world, 0, -1)
	world._complete_plan(upper)
	view.sync(world, 0, -1)
	check_opacity(view.entity_views["building:%s" % upper.cell], false)
	check(not view.entity_views.has("plan:%s" % upper.id), "Completed upper floor replaces its translucent preview")
	view.free()
	world = fresh()
	world.add_store(Vector3i(-6, 0, 2), {"log": 8, "food": 10})
	lower = queue(world, "platform", Vector3i(0, 1, 0))
	upper = queue(world, "platform", Vector3i(0, 2, 0))
	for worker: Dictionary in world.workers:
		worker.position = world.Navigation.point(worker.cell)
		if world.can_control(worker): world.set_role(worker.id, "builder")
	var premature_upper := false
	for step in 5000:
		world.tick(0.05)
		if not world.platforms.has(lower.cell) and world.plans.has(lower.id) and upper.installed > 0: premature_upper = true
		if world.plans.is_empty(): break
	check(not premature_upper and world.plans.is_empty(), "Automatic builders haul and finish both plans in dependency order")
	check(world.platforms == {upper.cell: 2} and world.construction_materials.get(upper.cell, {}).get("log", 0) == 8, "Physical construction produces the projected tier-2 platform")
	if failures.is_empty():
		print("PASS: %d construction planning, rendering, support, merge and persistence checks" % checks)
		quit()
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)
