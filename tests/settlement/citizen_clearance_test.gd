extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func fixture(count := 3):
	var world = Model.new()
	for x in range(-7, 8):
		for z in range(-7, 8): world.ground[Vector3i(x, 0, z)] = true
	for id in count:
		world.workers.append({"id": id, "cell": Vector3i.ZERO, "position": Vector3.ZERO,
			"route": [], "route_index": 0, "job": {}, "cargo": "", "status": "idle", "distance": 0.0,
			"hunger": 0.0, "role": "idle", "life_stage": "child" if id == 2 else "adult", "growth_seconds": 0.0})
	world.rebuild_navigation()
	return world

func run_for(world, seconds: float) -> void:
	for step in ceili(seconds / 0.05): world.tick(0.05)

func separated(world) -> bool:
	for a in world.workers:
		for b in world.workers:
			if a.id != b.id and a.position.distance_to(b.position) < 0.64: return false
	return true

func _initialize() -> void:
	var world = fixture(8)
	run_for(world, 3.0)
	check(separated(world), "Stacked adults and a child walk to distinct resting positions")
	for worker in world.workers:
		check(world.navigation.walkable(worker.cell), "Dispersal stays on a walkable surface")
	# Multiple player orders may cross and briefly share their exact destination.
	world = fixture(2)
	world.workers[0].cell = Vector3i(-3, 0, 0)
	world.workers[1].cell = Vector3i(3, 0, 0)
	for worker in world.workers:
		worker.position = Nav.point(worker.cell)
		check(world.order_move(worker.id, Vector3i.ZERO), "Shared move target is accepted")
	run_for(world, 4.0)
	check(separated(world) and world.workers.all(func(w): return w.job.is_empty()), "Shared arrival resolves without cancelling travel or deadlocking")
	# Room clearance includes offset edges, and routes cannot cut diagonally through them.
	world = fixture(1)
	world.buildings[Vector3i.ZERO] = {"kind": "house", "direction": 0, "placement_offset": Vector3(0.18, 0, -0.18)}
	world.rebuild_navigation()
	var route: Array[Vector3i] = world.navigation.route(Vector3i(-4, 0, 0), Vector3i(4, 0, 0))
	check(not route.is_empty(), "A route around the house exists")
	for cell in route: check(world.navigation.walkable(cell), "Route never enters a building's clearance footprint")
	for index in range(1, route.size()):
		var a := route[index - 1]
		var b := route[index]
		if a.x != b.x and a.z != b.z:
			check(world.navigation.walkable(Vector3i(a.x, a.y, b.z)) and world.navigation.walkable(Vector3i(b.x, b.y, a.z)), "Diagonal route keeps both building corners clear")
	run_for(world, 2.0)
	check(world.navigation.walkable(world.workers[0].cell) and world.workers[0].position.distance_to(Vector3.ZERO) > 1.5, "Resident inside a newly completed building walks out")
	var access: Array[Vector3i] = world.navigation.route(Vector3i(-4, 0, 0), Vector3i.ZERO)
	check(not access.is_empty() and world.navigation.at_access(access.back(), Vector3i.ZERO), "Building interactions stop at an accessible perimeter")
	world.navigation.update_ground({Vector3i.ZERO: true}, {})
	check(world.navigation.edges[Vector3i.ZERO].is_empty(), "Streaming cannot reopen a building footprint")
	var chunk := Vector2i(3, 0)
	var generated: Dictionary = world.Generator.generate_chunk(world.world_seed, chunk)
	world.Chunks.integrate(world, chunk, generated)
	for cell: Vector3i in generated.nature:
		check(not world.navigation.walkable(cell) and world.navigation.edges.get(cell, []).is_empty(), "Newly streamed natural obstacles also block walking")
	# Construction may interrupt an already-issued route; retain the move order.
	world = fixture(1)
	world.workers[0].cell = Vector3i(-4, 0, 0)
	world.workers[0].position = Nav.point(world.workers[0].cell)
	world.order_move(0, Vector3i(4, 0, 0))
	world.buildings[Vector3i.ZERO] = {"kind": "house", "direction": 0}
	world.rebuild_navigation()
	run_for(world, 8.0)
	check(world.workers[0].cell == Vector3i(4, 0, 0), "Existing travel replans around a newly completed obstacle")
	# Several workers use separate access cells during a long work application.
	world = fixture(2)
	world.buildings[Vector3i.ZERO] = {"kind": "sawmill", "direction": 0}
	world.rebuild_navigation()
	for worker in world.workers:
		worker.cell = Vector3i(-4, 0, worker.id)
		worker.position = Nav.point(worker.cell)
		worker.cargo = "log"
		worker.job = {"kind": "process", "target": Vector3i.ZERO, "phase": "travel", "output": "plank", "labour": world.Jobs.Labour.new(20.0)}
		world.Jobs._set_route(world, worker, world.navigation.route(worker.cell, Vector3i.ZERO), "walking")
	run_for(world, 5.0)
	check(separated(world) and world.workers.all(func(w): return w.job.get("phase") == "work"), "Concurrent workers keep separate reachable work positions")
	# Saved escape/dispersal routes continue smoothly and retain independent jobs.
	world = fixture(3)
	world.tick(0.05)
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "A save during separation restores")
	# Corrupt the decoded form using a temporary worker edit, then encode normally.
	world.workers[1].clearance_index = 999
	var corrupt: Dictionary = JSON.parse_string(JSON.stringify(world.snapshot()))
	check(not Model.new().restore(corrupt), "Invalid saved separation index is rejected")
	world.workers[1].clearance_index = 1
	run_for(world, 2.0)
	run_for(restored, 2.0)
	for id in world.workers.size():
		check(world.workers[id].position.is_equal_approx(restored.workers[id].position), "Saved separation matches uninterrupted movement")
	# Equal x/z on different floors must not trigger crowd avoidance.
	world = fixture(2)
	world.platforms[Vector3i.UP] = true
	world.workers[1].cell = Vector3i.UP
	world.workers[1].position = Nav.point(Vector3i.UP)
	world.rebuild_navigation()
	run_for(world, 2.0)
	check(world.workers[0].cell == Vector3i.ZERO and world.workers[1].cell == Vector3i.UP, "Separate floors do not repel each other")
	# With no spare reachable cell, wait safely instead of teleporting or looping.
	world = fixture(2)
	world.ground = {Vector3i.ZERO: true}
	world.rebuild_navigation()
	run_for(world, 1.0)
	check(world.workers.all(func(w): return w.position == Vector3.ZERO), "A full isolated surface never pushes residents into unsupported space")
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: citizen spacing, shared arrivals, building clearance, streaming, save/load and separate floors")
	quit(int(not failures.is_empty()))
