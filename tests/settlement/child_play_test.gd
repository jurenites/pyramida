extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Play = preload("res://scripts/settlement/child_play.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func fixture(cells: Array):
	var world = Model.new()
	for centre: Vector3i in cells:
		for x in range(-8, 9):
			for z in range(-8, 9): world.ground[centre + Vector3i(x, 0, z)] = true
	for cell: Vector3i in cells:
		var id: int = world.workers.size()
		world.workers.append({"id": id, "cell": cell, "position": Nav.point(cell),
			"route": [], "route_index": 0, "job": {}, "cargo": "", "status": "growing up", "distance": 0.0,
			"hunger": 0.0, "role": "auto", "life_stage": "child", "growth_seconds": 0.0,
			"appearance": id % 4, "cloth_color": id % 5, "assigned_plan_id": -1})
	world.rebuild_navigation()
	return world

func run_for(world, seconds: float, fed := false) -> void:
	for step in ceili(seconds / 0.05):
		if fed:
			for kid in world.workers: kid.hunger = 0.0
		world.tick(0.05)

func _initialize() -> void:
	test_tag_and_circling()
	test_locality()
	test_obstacles_and_floors()
	test_needs_and_age()
	test_save_and_time()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: local tag, circling, catcher boost/transfer, breaks, obstacles, hunger, adulthood and deterministic saves")
	quit(int(not failures.is_empty()))

func test_tag_and_circling() -> void:
	var world = fixture([Vector3i.ZERO, Vector3i(2, 0, 0), Vector3i(0, 0, 2), Vector3i(-2, 0, 0)])
	run_for(world, 7.0)
	check(world.child_play.games.is_empty(), "Children have quiet time before a game")
	run_for(world, 1.1)
	check(world.child_play.games.size() == 1 and world.child_players.size() == 4, "Nearby kids form one game")
	if world.child_play.games.is_empty(): return
	var game: Dictionary = world.child_play.games[0]
	var total_turn := 0.0
	var centre: Vector3 = world.navigation.surface_point(game.anchor)
	var previous: Vector3 = world.workers[1].position - centre
	var bounded := true
	var clear := true
	for step in 300:
		var catcher: int = game.catcher
		for kid in world.workers:
			check(is_equal_approx(Play.speed(world, kid), Play.RUN_SPEED + (0.2 if kid.id == catcher else 0.0)), "Only catcher gets the exact 0.2 speed bonus")
		world.tick(0.05)
		var radial: Vector3 = world.workers[1].position - centre
		if previous.length() > 0.5 and radial.length() > 0.5:
			total_turn += atan2(previous.x * radial.z - previous.z * radial.x, previous.x * radial.x + previous.z * radial.z)
		previous = radial
		for kid in world.workers:
			bounded = bounded and kid.position.distance_to(centre) <= Play.PLAY_RADIUS + 0.001
			clear = clear and world.navigation.walkable(kid.cell)
	check(game.tags > 0, "Natural pursuit catches another child and transfers the role")
	check(absf(total_turn) > PI, "Children circle together instead of only jittering between cells")
	check(bounded and clear, "All play stays within its local walkable area")
	check(world.workers.all(func(k): return k.job.is_empty() and k.distance > 10.0), "Play moves real children without giving them adult jobs")
	var tags: int = game.tags
	# Force contact during immunity to ensure no rapid back-and-forth tagging.
	game.tag_ready = world.time + Play.TAG_GRACE
	world.workers[0].position = world.workers[1].position
	world.workers[0].cell = world.workers[1].cell
	world.tick(0.05)
	check(game.tags == tags, "Tag grace prevents immediate ping-pong")
	run_for(world, 4.0, true)
	check(world.child_play.games.is_empty(), "A round ends and children take a break")
	run_for(world, 15.0, true)
	check(not world.child_play.games.is_empty(), "Nearby kids can start another game after resting")

func test_locality() -> void:
	var stacked = fixture([Vector3i.ZERO, Vector3i.ZERO, Vector3i.ZERO, Vector3i.ZERO])
	stacked.child_play.next_scan = 0.0
	run_for(stacked, 3.0)
	for a in stacked.workers:
		for b in stacked.workers:
			if a.id != b.id: check(a.position.distance_to(b.position) > 0.1, "Playing children separate even when spawned at identical coordinates")
	var pair = fixture([Vector3i.ZERO, Vector3i(2, 0, 0)])
	pair.child_play.next_scan = 0.0
	run_for(pair, 16.0)
	check(pair.child_play.games.size() == 1 and pair.child_play.games[0].tags > 0, "Two children can chase and catch each other without a larger flock")
	var world = fixture([Vector3i.ZERO, Vector3i(2, 0, 0), Vector3i(100, 0, 0), Vector3i(102, 0, 0)])
	world.child_play.next_scan = 0.0
	world.tick(0.05)
	check(world.child_play.games.size() == 2, "Distant groups play independent local games")
	check(world.child_players[0] != world.child_players[2], "Distant kids never share a catcher")
	var local = fixture([Vector3i.ZERO, Vector3i(2, 0, 0)])
	local.child_play.next_scan = 0.0
	local.tick(0.05)
	for step in 160:
		world.tick(0.05)
		local.tick(0.05)
	for id in 2:
		check(world.workers[id].position.is_equal_approx(local.workers[id].position), "Faraway games exert no steering influence on local kids")
	world = fixture([Vector3i.ZERO, Vector3i(100, 0, 0)])
	world.child_play.next_scan = 0.0
	run_for(world, 10.0)
	check(world.child_play.games.is_empty(), "Isolated children never pursue distant children")
	check(world.workers[1].position.distance_to(Vector3(100, 0, 0)) < 5.0, "Solitary kids wander locally rather than returning across the map")
	var cells: Array = []
	for x in 5:
		for z in 3: cells.append(Vector3i(x, 0, z))
	world = fixture(cells)
	world.child_play.next_scan = 0.0
	world.tick(0.05)
	var claimed := {}
	for game: Dictionary in world.child_play.games:
		check(game.members.size() <= Play.MAX_PLAYERS, "A crowd splits into small games")
		for id: int in game.members:
			check(not claimed.has(id), "A child belongs to only one game")
			claimed[id] = true

func test_obstacles_and_floors() -> void:
	var world = fixture([Vector3i(-2, 0, 0), Vector3i(2, 0, 0)])
	for z in range(-8, 9): world.ground.erase(Vector3i(0, 0, z))
	world.rebuild_navigation()
	world.child_play.next_scan = 0.0
	world.tick(0.05)
	check(world.child_play.games.is_empty(), "Nearby but disconnected children cannot form a game")
	world = fixture([Vector3i.ZERO, Vector3i.UP])
	world.child_play.next_scan = 0.0
	world.tick(0.05)
	check(world.child_play.games.is_empty(), "Children on separate floors cannot tag through a ceiling")
	world = fixture([Vector3i(-3, 0, 0), Vector3i(-3, 0, 2), Vector3i(-2, 0, -2)])
	world.buildings[Vector3i.ZERO] = {"kind": "house", "direction": 0}
	world.rebuild_navigation()
	world.child_play.next_scan = 0.0
	var safe := true
	for step in 300:
		world.tick(0.05)
		for kid in world.workers:
			safe = safe and not (absf(kid.position.x) < 1.2 and absf(kid.position.z) < 1.2)
	check(safe, "Chasing and fleeing never cross the solid building footprint")

func test_needs_and_age() -> void:
	var world = fixture([Vector3i.ZERO, Vector3i(2, 0, 0), Vector3i(0, 0, 2)])
	world.add_store(Vector3i(-4, 0, 0), {"food": 5})
	world.child_play.next_scan = 0.0
	world.tick(0.05)
	world.workers[0].hunger = 30.0
	world.tick(0.05)
	check(not world.child_players.has(0), "Hunger immediately leaves play")
	run_for(world, 0.5)
	check(world.workers[0].job.get("kind") == "eat", "Hungry child goes to get food instead of being trapped in play")
	world.workers[1].growth_seconds = world.Citizens.adulthood_seconds()
	run_for(world, 0.1)
	check(world.Citizens.is_adult(world.workers[1]) and not world.child_players.has(1), "Growing up removes the child from the game")
	check(world.child_play.games.is_empty(), "A game ends when fewer than two eligible kids remain")

func test_save_and_time() -> void:
	var world = fixture([Vector3i.ZERO, Vector3i(2, 0, 0), Vector3i(0, 0, 2)])
	world.child_play.next_scan = 0.0
	run_for(world, 3.0)
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "An active game saves and restores")
	var initial: Dictionary = world.snapshot()
	world.tick(0.0)
	check(world.snapshot() == initial, "No simulation time means no movement, aging or tag changes")
	for step in 240:
		world.tick(0.05)
		restored.tick(0.05)
		var a: Dictionary = world.child_play.games[0]
		var b: Dictionary = restored.child_play.games[0]
		check(a.catcher == b.catcher and a.tags == b.tags and a.members == b.members and is_equal_approx(a.tag_ready, b.tag_ready) and is_equal_approx(a.until, b.until), "Saved catcher and round timing remain deterministic")
		for id in 3: check(world.workers[id].position.is_equal_approx(restored.workers[id].position), "Saved pursuit continues on the same path")
	world.child_play.games[0].catcher = 99
	check(not Model.new().restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Invalid saved catcher is rejected")
