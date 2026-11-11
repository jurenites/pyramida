extends SceneTree
const Nav = preload("res://scripts/settlement/navigation.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void:
	test_access_searches()
	test_streaming_cache()
	test_journey()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: bounded access searches, local cache invalidation, persistent journeys and completed-building obstructions")
	quit(int(not failures.is_empty()))
func ground() -> Dictionary:
	var result := {}
	for x in range(-10, 11):
		for z in range(-10, 11): result[Vector3i(x, 0, z)] = true
	return result
func test_access_searches() -> void:
	var nav = Nav.new()
	for x in range(-1, 2):
		for z in range(-1, 2): nav.blocked[Vector3i(x, 0, z)] = true
	nav.rebuild(ground(), {})
	var route: Array = nav.route(Vector3i.ZERO, Vector3i.ZERO)
	check(route.size() == 1 and nav.nodes_expanded == 0, "A building's own storage needs no perimeter-to-perimeter searches")
	for finish in [Vector3i(6, 0, 4), Vector3i(-6, 0, 0), Vector3i.ZERO]:
		var expected := INF
		for a in nav.access_cells(Vector3i.ZERO):
			for b in nav.access_cells(finish):
				var candidate: Array = nav._route(a, b)
				if not candidate.is_empty(): expected = minf(expected, nav.distance(candidate))
		check(is_equal_approx(nav.distance(nav.route(Vector3i.ZERO, finish)), expected), "Pruned entrance comparisons preserve the exhaustive result")
func test_streaming_cache() -> void:
	var nav = Nav.new()
	nav.rebuild(ground(), {})
	var expected: Array = nav.route(Vector3i.ZERO, Vector3i(2, 0, 0))
	var built: int = nav.searches_built
	var expanded: int = nav.nodes_expanded
	nav.update_ground({Vector3i(50, 0, 50): true}, {})
	check(nav.route(Vector3i.ZERO, Vector3i(2, 0, 0)) == expected and nav.searches_built == built and nav.nodes_expanded == expanded, "Distant streamed terrain preserves the local search")
	nav.update_ground({}, {Vector3i.RIGHT: true})
	var detour: Array = nav.route(Vector3i.ZERO, Vector3i(2, 0, 0))
	check(not detour.is_empty() and Vector3i.RIGHT not in detour and nav.searches_built == built + 1, "An intersecting edit invalidates the affected search")
func test_journey() -> void:
	var world = Model.new()
	world.ground = ground()
	world.exploration.reveal(Vector3.ZERO)
	world.workers.append({"id": 0, "cell": Vector3i(-6, 0, 0), "position": Vector3(-6, 0, 0),
		"route": [], "route_index": 0, "job": {}, "cargo": "", "status": "idle", "distance": 0.0,
		"hunger": 0.0, "role": "idle", "life_stage": "adult"})
	world.rebuild_navigation()
	check(world.order_move(0, Vector3i(6, 0, 0)), "Citizen starts a journey")
	var worker: Dictionary = world.workers[0]
	var route: Array = worker.route.duplicate()
	var revision: int = world.navigation.revision
	var searches: int = world.navigation.searches_built
	check(world.request_build("house", Vector3i.ZERO), "Blueprint can be placed across the route")
	var plan_id: int = world.next_plan_id - 1
	check(world.navigation.revision == revision and world.navigation.walkable(Vector3i.ZERO), "Blueprint does not rebuild or block the walking graph")
	check(world.move_plan(plan_id, Vector3i(0, 0, 3), 0, Vector3.ZERO), "Blueprint can be retargeted")
	check(world.navigation.revision == revision and worker.route == route, "Retargeting another job preserves the journey")
	check(world.delete_plan(plan_id) and world.navigation.revision == revision, "Cancelling a blueprint leaves navigation intact")
	for i in 10: world.tick(0.05)
	check(worker.route == route and world.navigation.searches_built == searches, "Movement follows its stored route without new searches")
	check(world.order_move(0, Vector3i(-6, 0, 5)) and worker.route.back() == Vector3i(-6, 0, 5), "Player destination changes replace the route immediately")
	check(world.order_move(0, Vector3i(6, 0, 0)), "Citizen resumes the crossing journey")
	check(world.request_build("house", Vector3i.ZERO), "Queue the crossing building again")
	world._complete_plan(world.plans[world.next_plan_id - 1])
	check(world.navigation.revision > revision and not world.navigation.walkable(Vector3i.ZERO), "Completing construction changes the physical graph")
	var reached := false
	for i in 400:
		world.tick(0.05)
		check(not world.navigation.blocked.has(worker.cell), "Citizen never enters the completed building")
		if worker.cell == Vector3i(6, 0, 0): reached = true; break
	check(reached, "Interrupted route detours to its original destination")
