extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void:
	var world = Model.new()
	for x in range(-5, 6):
		for z in range(-5, 6):
			world.ground[Vector3i(x, 1, z)] = true
			world.terrain_heights[Vector2i(x, z)] = 1
	world.rebuild_navigation()
	var base := Vector3i(0, 1, 0)
	check(Nav.point(base).y == 1.0, "One grid height is one metre")
	check(world.request_build("house", base), "House can start on a one-metre cliff")
	world._complete_plan(world.plans[world.next_plan_id - 1])
	check(world.snap_cell("house", "house", base).y == 3, "House roof remains two metres above its foundation")
	check(not world.request_build("house", base + Vector3i.UP), "Half-storey placement cannot intersect the existing house")
	check(world.request_build("house", base + Grid.STOREY), "House stacks on the roof of a raised house")
	var nav = Nav.new()
	var approach := Vector3i(-2, 0, 0)
	var upper := Vector3i(2, 1, 0)
	nav.rebuild({approach: true, Vector3i.ZERO: true, upper: true}, {Vector3i.ZERO: 0})
	check(nav.route(approach, upper).size() == 2, "Ladder reaches a one-metre landing")
	check(is_equal_approx(nav.edge_distance(approach, upper), 2.0 + sqrt(5.0)), "Half-height ladder cost follows its actual rise")
	var source = Model.new()
	source.setup()
	source.buildings[Vector3i(4, 2, 4)] = {"kind": "house", "direction": 0}
	var vine_root := Vector3i(4, 2, 6)
	source.vines[vine_root] = preload("res://scripts/settlement/vines.gd").create()
	source.vines[vine_root].nodes = [Vector3i(4, 2, 5)]
	source.vines[vine_root].parents = [-1]
	source.rebuild_navigation()
	var saved := source.snapshot()
	for pair in saved.world.v:
		if pair[0] == "grid_version": pair[1] = 2
		if pair[0] == "level_height": pair[1] = 2.0
	saved.world = legacy_cells(saved.world)
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))), "Old two-metre-grid save migrates")
	check(restored.buildings.has(Vector3i(4, 2, 4)), "Old building retains its physical elevation")
	check(restored.ground == source.ground, "Migration preserves physical terrain heights")
	check(restored.vines.has(vine_root) and restored.vines[vine_root].nodes == source.vines[vine_root].nodes, "Migration preserves metre-addressed vine growth on raised rooms")
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: metre-grid placement, stacking, ladders and migration")
	quit(int(not failures.is_empty()))
func legacy_cells(value: Variant) -> Variant:
	if value is Array:
		if value.size() == 2 and value[0] is String and value[0] == "nodes": return value.duplicate(true)
		var result: Array = []
		for item in value: result.append(legacy_cells(item))
		return result
	if value is Dictionary:
		if value.get("type") == "cell": return {"type": "cell", "v": [value.v[0], int(value.v[1] / 2), value.v[2]]}
		var result := {}
		for key in value: result[key] = legacy_cells(value[key])
		return result
	return value
