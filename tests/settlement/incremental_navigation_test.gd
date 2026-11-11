extends SceneTree
const Nav = preload("res://scripts/settlement/navigation.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	var nav = Nav.new()
	var ground := {}
	for x in range(-8, 9):
		for z in range(-8, 9): ground[Vector3i(x, 0, z)] = true
	var shapes := {}
	var stairs := {}
	var ramps := {}
	nav.rebuild(ground, stairs)
	var distant: Array = nav.edges[Vector3i(-7, 0, -7)]
	for stage in 10:
		match stage:
			0: nav.blocked[Vector3i.ZERO] = true
			1: nav.blocked.erase(Vector3i.ZERO)
			2: shapes[Vector3i.RIGHT] = [0.0, 0.3, 0.3, 0.0, 0.15]
			3: shapes.clear(); ground.erase(Vector3i.RIGHT)
			4: ground[Vector3i.RIGHT] = true; ground[Vector3i(2, 2, 0)] = true; stairs[Vector3i.ZERO] = 0
			5: stairs.clear(); ramps[Vector3i.ZERO] = Vector3i(2, 2, 0)
			6: ramps.clear(); nav.room_paths = {Vector3i.ZERO: {Vector3i(2, 2, 0): [Vector3.ZERO, Vector3(2, 2, 0)]}, Vector3i(2, 2, 0): {Vector3i.ZERO: [Vector3(2, 2, 0), Vector3.ZERO]}}
			7: nav.room_paths.clear(); nav.room_nodes[Vector3i.ZERO] = 1; nav.room_edges[Vector3i.ZERO] = [Vector3i.RIGHT]
			8: nav.room_nodes.clear(); nav.room_edges.clear(); ground.erase(Vector3i(2, 2, 0))
			9: nav.roads[Vector3i.RIGHT] = true
		nav.rebuild(ground, stairs, ramps, shapes)
		check(is_same(distant, nav.edges[Vector3i(-7, 0, -7)]), "Distant terrain edges are retained at stage %d" % stage)
		var fresh = Nav.new()
		for field in ["blocked", "roads", "room_nodes", "room_edges", "room_paths", "room_heights", "access_overrides"]:
			fresh.set(field, nav.get(field).duplicate(true))
		fresh.rebuild(ground, stairs, ramps, shapes)
		check(nav.edges.size() == fresh.edges.size(), "Removed surfaces leave no stale edges")
		for cell in fresh.edges:
			var actual: Array = nav.edges.get(cell, []).duplicate()
			var expected: Array = fresh.edges[cell].duplicate()
			check(actual.size() == expected.size() and actual.all(func(next): return next in expected), "Local rebuild matches fresh graph at %s, stage %d" % [cell, stage])
			for next in expected:
				check(is_equal_approx(nav.edge_distance(cell, next), fresh.edge_distance(cell, next)), "Cached edge lengths match fresh geometry")
		for start in [Vector3i.ZERO, Vector3i(-4, 0, -4), Vector3i(2, 2, 0)]:
			for finish in [Vector3i.RIGHT, Vector3i(4, 0, 4), Vector3i(2, 2, 0)]:
				check(nav.can_reach(start, finish) == not fresh.route(start, finish).is_empty(), "Connectivity checks match real routes")
	# Streaming an adjacent slope invalidates lengths measured before that edit.
	var old_distance: float = nav.edge_distance(Vector3i.ZERO, Vector3i.RIGHT)
	shapes[Vector3i.RIGHT] = [0.3, 0.3, 0.3, 0.3, 0.3]
	nav.update_ground({Vector3i.RIGHT: true}, {}, shapes)
	check(nav.edge_distance(Vector3i.ZERO, Vector3i.RIGHT) > old_distance, "Streamed geometry invalidates cached edge lengths")
	# Quarry caches include neighbouring formations and mining, and return copies.
	var world = Model.new()
	world.ground = ground
	for base in [Vector3i.ZERO, Vector3i.RIGHT]:
		var capacity: int = world.Economy.StoneVolume.capacity(base, world.world_seed)
		world.deposits[base] = world.Chunks.entry("limestone", "stone", capacity)
	var tops: Array = world.rock_surfaces(Vector3i.ZERO)
	var expected_tops := tops.duplicate()
	tops.clear()
	check(world.rock_surface_cache[Vector3i.ZERO].surfaces == expected_tops, "Callers cannot mutate cached quarry surfaces")
	for base in [Vector3i.ZERO, Vector3i.RIGHT]:
		world.deposits[base].inventory.amounts.stone = 1
		var cached: Array = world.rock_surfaces(Vector3i.ZERO)
		world.rock_surface_cache.clear()
		check(cached == world.rock_surfaces(Vector3i.ZERO), "Mining this or a neighbouring quarry invalidates cached tops")
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: local graph rebuilds, connector removal, connectivity and quarry cache invalidation")
	quit(int(not failures.is_empty()))
