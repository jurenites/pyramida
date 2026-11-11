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
	test_obstacle_removal()
	test_tree_removal()
	test_road_costs()
	test_decisions()
	test_fairness()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: local search bounds, incremental clearance, streamed connectivity, citizen decision budgets and cargo recovery")
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
	# The current first-tier House needs both Hay and Logs.
	world.add_store(Vector3i.ZERO, {"log": 18, "grain": 2, "food": 5})
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
	# Full storage leaves recoverable goods on the floor, as in normal gathering.
	world = fixture()
	world.workers.resize(1)
	var worker: Dictionary = world.workers[0]
	world.buildings[Vector3i.ZERO] = {"kind": "quarry", "direction": 0}
	world.stores[Vector3i.ZERO].amounts = {"stone": world.stores[Vector3i.ZERO].capacity}
	worker.cargo = "stone"
	worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Jobs.Labour.new(0.6)}
	world.tick(0.05)
	var drop_id: int = world.next_plan_id - 1
	check(worker.cargo.is_empty() and world.plans.has(drop_id), "Full storage leaves a physical cargo pile")
	if not world.plans.has(drop_id): return
	var pile = world.plans[drop_id].relocation.parts
	check(pile.count("stone") == 1, "Dropped cargo is conserved exactly once")
	var previous_decisions: int = world.job_decisions
	for step in 10: world.tick(0.05)
	check(world.job_decisions - previous_decisions <= 1 and worker.has("retry_at"), "Unavailable salvage uses the idle retry delay")
	check(pile.count("stone") == 1 and pile.reservations.is_empty(), "Full storage neither consumes nor reserves dropped goods")
	world.stores[Vector3i.ZERO].amounts.stone -= 1
	world.revision += 1
	world.tick(0.05)
	check(worker.job.get("source") == pile and not worker.has("retry_at"), "Inventory change wakes the worker and reserves the loose cargo")
	var navigation_revision: int = world.navigation.revision
	for step in 120: world.tick(0.05)
	check(worker.cargo.is_empty() and world.deliveries == 1 and not world.plans.has(drop_id), "Recovered cargo physically reaches storage exactly once")
	check(world.stores[Vector3i.ZERO].total() == world.stores[Vector3i.ZERO].capacity, "Recovery restores the freed storage slot")
	check(world.navigation.revision == navigation_revision, "Empty salvage cleanup preserves navigation and retained searches")

func test_tree_removal() -> void:
	var world = fixture()
	var cell := Vector3i(-2, 0, 0)
	var inventory = Model.Inventory.new()
	world.trees[cell] = {"kind": "living", "inventory": inventory, "regrowth": 0.0}
	world.rebuild_navigation()
	var surfaces: Dictionary = world.navigation.surfaces
	check(world.remove_stump(cell), "An exhausted mature tree is removed")
	check(is_same(surfaces, world.navigation.surfaces), "Final tree removal never replaces the whole surface graph")
	check(world.navigation.walkable(cell), "Final tree removal opens its ground immediately")
	# Overlapping objects can exist in legacy or manually edited saves.
	world.trees[cell] = {"kind": "living", "inventory": inventory, "regrowth": 0.0}
	world.wells[cell] = Model.Inventory.new()
	world.rebuild_navigation()
	check(world.remove_stump(cell) and world.navigation.blocked.has(cell), "Removing an overlapping tree preserves another object's blocker")
	world = fixture()
	world.trees[cell] = {"kind": "living", "inventory": inventory, "regrowth": 0.0}
	world.stairs[Vector3i.ZERO] = 0
	var landing := Vector3i.RIGHT * Navigation.Grid.CELLS_PER_ROOM + Navigation.Grid.STOREY
	world.platforms[landing] = 1
	world.rebuild_navigation()
	check(not world.navigation.edges[cell].has(landing), "A trunk on the lower landing prevents a ladder connection")
	check(world.remove_stump(cell) and world.navigation.edges[cell].has(landing), "Clearing a previously blocked landing restores the omitted ladder connection")

func test_obstacle_removal() -> void:
	var nav = Navigation.new()
	var surfaces := {}
	for x in range(-50, 51):
		for z in range(-3, 4): surfaces[Vector3i(x, 0, z)] = true
	# A blocked column divides the map; opening one trunk joins the two sides.
	for z in range(-3, 4): nav.blocked[Vector3i(0, 0, z)] = true
	nav.rebuild(surfaces, {})
	var far := Vector3i(-40, 0, 0)
	nav.route(far, far + Vector3i.RIGHT)
	var searches: int = nav.searches_built
	check(nav.route(Vector3i.LEFT, Vector3i.RIGHT).is_empty(), "Standing trunk separates the two regions")
	nav.remove_obstacle(Vector3i.ZERO)
	check(nav.route(Vector3i.LEFT, Vector3i.RIGHT).size() == 3, "Removing a trunk joins existing components immediately")
	nav.route(far, far + Vector3i.RIGHT)
	check(nav.searches_built == searches + 1, "Distant settled searches survive a local removal")
	var oracle = Navigation.new()
	oracle.blocked = nav.blocked.duplicate()
	oracle.rebuild(surfaces, {})
	for cell in surfaces:
		check(nav.edges[cell] == oracle.edges[cell], "Local clearance matches rebuilt edges at %s" % cell)
	# Cached detours must be replaced when the opened cell creates a shortcut.
	nav = Navigation.new()
	nav.blocked[Vector3i.ZERO] = true
	nav.rebuild(surfaces, {})
	var before: float = nav.distance(nav.route(Vector3i.LEFT, Vector3i.RIGHT))
	nav.remove_obstacle(Vector3i.ZERO)
	check(nav.distance(nav.route(Vector3i.LEFT, Vector3i.RIGHT)) < before, "Nearby cached detours are invalidated by a newly opened shortcut")
	# Refreshing adjacent ground must retain authored vertical/bridge edges.
	var stair := Vector3i(3, 0, 0)
	var lower := stair - Vector3i.RIGHT * Navigation.Grid.CELLS_PER_ROOM
	var upper := stair + Vector3i.RIGHT * Navigation.Grid.CELLS_PER_ROOM + Navigation.Grid.STOREY
	var ramp_end := Vector3i(-1, 1, 0)
	var bridge_end := Vector3i(20, 2, 0)
	surfaces[upper] = true
	surfaces[ramp_end] = true
	surfaces[bridge_end] = true
	var stairs := {stair: 0}
	var ramps := {Vector3i.LEFT: ramp_end}
	nav = Navigation.new()
	Model.RoomNavigation.add_path(nav, Vector3i.BACK, bridge_end, [Navigation.point(Vector3i.BACK), Navigation.point(bridge_end)])
	nav.blocked[Vector3i.ZERO] = true
	nav.rebuild(surfaces, stairs, ramps)
	nav.remove_obstacle(Vector3i.ZERO)
	check(nav.edges[lower].has(upper) and nav.edges[upper].has(lower), "Local clearance retains both directions of a nearby ladder")
	check(nav.edges[Vector3i.LEFT].has(ramp_end) and nav.edges[ramp_end].has(Vector3i.LEFT), "Local clearance retains both directions of a terrain link")
	check(nav.edges[Vector3i.BACK].has(bridge_end) and nav.edges[bridge_end].has(Vector3i.BACK), "Local clearance retains both directions of an authored bridge path")

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
