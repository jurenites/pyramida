extends SceneTree
class RouteOracle extends AStar3D:
	static func travel_cost(a: Vector3, b: Vector3) -> float:
		if not is_equal_approx(a.y, b.y):
			return Vector2(2.0, preload("res://scripts/settlement/navigation.gd").LEVEL_HEIGHT).length() + 2.0
		return a.distance_to(b)

	func _compute_cost(from_id: int, to_id: int) -> float:
		return travel_cost(get_point_position(from_id), get_point_position(to_id))

const Navigation = preload("res://scripts/settlement/navigation.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	var nav = Navigation.new()
	var surfaces := {}
	for x in 8:
		for z in 8:
			for y in 2:
				surfaces[Vector3i(x, y, z)] = true
	nav.rebuild(surfaces, {Vector3i.ZERO: 0, Vector3i(5, 0, 7): 0})
	# Native A* is an independent weighted-path oracle for the heap implementation.
	var oracle := RouteOracle.new()
	var ids := {}
	for cell: Vector3i in surfaces:
		ids[cell] = ids.size()
		oracle.add_point(ids[cell], Navigation.point(cell))
	for cell: Vector3i in nav.edges:
		for neighbour: Vector3i in nav.edges[cell]:
			if not oracle.are_points_connected(ids[cell], ids[neighbour]):
				oracle.connect_points(ids[cell], ids[neighbour])
	for start in [Vector3i.ZERO, Vector3i(7, 1, 7), Vector3i(3, 0, 4)]:
		for finish: Vector3i in surfaces:
			var route: Array[Vector3i] = nav.route(start, finish)
			var points := oracle.get_point_path(ids[start], ids[finish])
			var expected := 0.0
			for index in range(1, points.size()):
				expected += RouteOracle.travel_cost(points[index - 1], points[index])
			check(not route.is_empty() and is_equal_approx(nav.distance(route), expected), "Weighted route matches native oracle: %s -> %s" % [start, finish])
	check(nav.searches_built == 3, "384 destinations reuse three source searches")
	var route: Array[Vector3i] = nav.route(Vector3i.ZERO, Vector3i(7, 1, 7))
	route.clear()
	check(not nav.route(Vector3i.ZERO, Vector3i(7, 1, 7)).is_empty(), "Callers cannot mutate cached paths")
	nav.rebuild(surfaces, {})
	check(nav.route(Vector3i.ZERO, Vector3i.UP).is_empty(), "Topology rebuild invalidates cached connected routes")
	var count: int = nav.searches_built
	check(nav.route(Vector3i.ZERO, Vector3i(7, 1, 7)).is_empty() and nav.searches_built == count, "Disconnected destinations reuse negative results")
	for cell: Vector3i in surfaces:
		nav.route(cell, Vector3i.ZERO)
	check(nav._searches.size() <= Navigation.MAX_CACHED_SOURCES, "Cache memory stays bounded across moving sources")
	check(nav.route(Vector3i(90, 0, 0), Vector3i.ZERO).is_empty(), "Unknown source is rejected")
	var square := {Vector3i.ZERO: true, Vector3i.RIGHT: true, Vector3i.BACK: true, Vector3i(1, 0, 1): true}
	nav.rebuild(square, {})
	var diagonal: Array[Vector3i] = nav.route(Vector3i.ZERO, Vector3i(1, 0, 1))
	check(diagonal.size() == 2 and is_equal_approx(nav.distance(diagonal), sqrt(2.0) * Navigation.CELL_SIZE), "Open squares use a direct diagonal at its actual travel cost")
	for corner in [Vector3i.RIGHT, Vector3i.BACK]:
		var gap := square.duplicate()
		gap.erase(corner)
		nav.rebuild(gap, {})
		check(not nav.edges[Vector3i.ZERO].has(Vector3i(1, 0, 1)), "Diagonal cannot clip a missing corner: %s" % corner)
	if failures.is_empty():
		print("PASS: %d weighted navigation and cache checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
