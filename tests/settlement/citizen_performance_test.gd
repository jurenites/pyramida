extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Jobs = preload("res://scripts/settlement/job_system.gd")
class RoadOracle extends AStar3D:
	func _estimate_cost(_from: int, _to: int) -> float:
		return 0.0

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	test_local_search()
	test_connectivity()
	test_road_costs()
	test_decisions()
	test_fairness()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: local search bounds, streamed connectivity, citizen decision budgets and retry recovery")
	quit(int(not failures.is_empty()))

func test_local_search() -> void:
	var nav = Navigation.new()
	var surfaces := {}
	for x in range(-50, 51):
		for z in range(-50, 51): surfaces[Vector3i(x, 0, z)] = true
	surfaces[Vector3i.UP] = true
	nav.rebuild(surfaces, {})
	check(nav.route(Vector3i.ZERO, Vector3i.RIGHT).size() == 2, "Nearby path exists")
	check(nav.nodes_expanded < 20, "Nearby goal never floods a 10,000-cell map")
	var expanded: int = nav.nodes_expanded
	check(nav.route(Vector3i.ZERO, Vector3i.UP).is_empty(), "Unconnected roof is unreachable")
	check(nav.nodes_expanded == expanded, "Disconnected goal needs no search")
	var far: Array[Vector3i] = nav.route(Vector3i.ZERO, Vector3i(4, 0, 4))
	check(is_equal_approx(nav.distance(far), sqrt(2.0) * 4.0), "Resumed frontier finds the optimal later destination")
	check(nav.searches_built == 1 and nav.nodes_expanded < 200, "Later goal extends one local search")
	expanded = nav.nodes_expanded
	nav.route(Vector3i.ZERO, Vector3i.RIGHT)
	check(nav.nodes_expanded == expanded, "Repeated destination uses settled result")

func test_connectivity() -> void:
	var nav = Navigation.new()
	var a := Vector3i.ZERO
	var bridge := Vector3i.RIGHT
	var b := Vector3i(2, 0, 0)
	nav.rebuild({a: true, b: true}, {})
	check(nav.route(a, b).is_empty(), "Separate streamed islands start disconnected")
	nav.update_ground({bridge: true}, {})
	check(nav.route(a, b).size() == 3, "Streamed bridge merges existing components")
	nav.update_ground({}, {bridge: true})
	var expanded: int = nav.nodes_expanded
	check(nav.route(a, b).is_empty() and nav.nodes_expanded == expanded, "Unloading bridge splits components and invalidates routes")
	nav.update_ground({bridge: true}, {})
	check(nav.route(b, a).size() == 3, "Reloading restores connectivity both ways")

func fixture():
	var world = Model.new()
	for x in range(-3, 10):
		for z in range(-3, 4): world.ground[Vector3i(x, 0, z)] = true
	world.add_store(Vector3i.ZERO, {"log": 18, "food": 5})
	for id in 6:
		var cell := Vector3i(id, 0, 2)
		world.workers.append({"id": id, "cell": cell, "position": Navigation.point(cell),
			"route": [], "route_index": 0, "job": {}, "cargo": "", "status": "idle",
			"distance": 0.0, "hunger": 0.0, "role": "builder", "life_stage": "adult"})
	world.rebuild_navigation()
	world.exploration.update(world.workers)
	return world

func test_decisions() -> void:
	var world = fixture()
	for step in 10:
		var before: int = world.job_decisions
		world.tick(0.05)
		check(world.job_decisions - before <= Jobs.DECISIONS_PER_TICK, "Goal decisions stay within tick budget")
	check(world.job_decisions == 6, "Six idle citizens each decide once, spread over ticks")
	# Even unrelated world changes cannot trigger every-tick retries.
	world.revision += 1
	world.tick(0.05)
	var decisions: int = world.job_decisions
	world.revision += 1
	world.tick(0.05)
	check(world.job_decisions - decisions <= 2, "World events preserve the decision budget")
	# A direct player command bypasses the idle delay and spent autonomous budget.
	check(world.request_build("house", Vector3i(6, 0, 0)), "Construction fixture accepted")
	world.decision_candidates.clear()
	check(world.order_build(0, world.next_plan_id - 1), "Player building order accepted immediately")
	check(world.workers[0].job.get("kind") == "build", "Player order starts during idle cooldown")
	var position: Vector3 = world.workers[0].position
	world.tick(0.05)
	check(world.workers[0].position.distance_to(position) > 0, "Existing movement continues every tick")
	# A carrier preserves cargo while waiting, then wakes when space is freed.
	world = fixture()
	world.workers.resize(1)
	var worker: Dictionary = world.workers[0]
	# Piles accept stone; legacy logs in this fixture cannot be replenished.
	world.stores[Vector3i.ZERO].store("stone")
	world.stores[Vector3i.ZERO].capacity = world.stores[Vector3i.ZERO].total()
	worker.cargo = "stone"
	worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Jobs.Labour.new(0.6)}
	world.tick(0.05)
	check(worker.has("retry_at"), "Blocked storage schedules a retry")
	for step in 10: world.tick(0.05)
	check(world.job_decisions == 0 and worker.cargo == "stone", "Blocked carrier does not rescan each tick or lose cargo")
	world.stores[Vector3i.ZERO].amounts.stone -= 1
	world.revision += 1
	world.tick(0.05)
	check(worker.route.size() > 1 and not worker.has("retry_at"), "Inventory change wakes carrier and commits a route")
	for step in 80: world.tick(0.05)
	check(worker.cargo.is_empty() and world.deliveries == 1, "Recovered carrier physically delivers its cargo")

func test_fairness() -> void:
	var world = fixture()
	for id in range(6, 30):
		var worker: Dictionary = world.workers[0].duplicate(true)
		worker.id = id
		world.workers.append(worker)
	for step in 20:
		world.revision += 1
		world.tick(0.05)
	for worker: Dictionary in world.workers:
		check(worker.has("decision_last_at"), "Frequent changes cannot starve citizen %d" % worker.id)

func test_road_costs() -> void:
	var nav = Navigation.new()
	var surfaces := {}
	var oracle := RoadOracle.new()
	var ids := {}
	for x in 15:
		for z in 5:
			var cell := Vector3i(x, 0, z)
			surfaces[cell] = true
			if z == 1: nav.roads[cell] = true
			ids[cell] = ids.size()
			oracle.add_point(ids[cell], Navigation.point(cell), 1.0 / 1.35 if nav.roads.has(cell) else 1.0)
	nav.rebuild(surfaces, {})
	for cell: Vector3i in nav.edges:
		for neighbour: Vector3i in nav.edges[cell]:
			if not oracle.are_points_connected(ids[cell], ids[neighbour]):
				oracle.connect_points(ids[cell], ids[neighbour])
	# Query nonmonotonic distances to exercise both frontier extension and reuse.
	for target in [Vector3i(2, 0, 0), Vector3i(14, 0, 4), Vector3i(6, 0, 0), Vector3i(12, 0, 1)]:
		var route: Array[Vector3i] = nav.route(Vector3i.ZERO, target)
		var expected := oracle.get_id_path(ids[Vector3i.ZERO], ids[target])
		var actual_cost := 0.0
		var expected_cost := 0.0
		for index in range(1, route.size()):
			actual_cost += nav.edge_distance(route[index - 1], route[index]) / (1.35 if nav.roads.has(route[index]) else 1.0)
		for index in range(1, expected.size()):
			expected_cost += oracle.get_point_position(expected[index - 1]).distance_to(oracle.get_point_position(expected[index])) * oracle.get_point_weight_scale(expected[index])
		check(is_equal_approx(actual_cost, expected_cost), "Resumed search retains optimal road weights for %s" % target)
