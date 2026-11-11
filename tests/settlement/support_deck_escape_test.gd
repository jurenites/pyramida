extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Layout = preload("res://scripts/settlement/structure_layout.gd")
const Escape = preload("res://scripts/settlement/citizen_ledge_escape.gd")
const Structure = preload("res://scripts/settlement/structure_frame.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func fixture():
	var world = Model.new()
	for x in range(-5, 6):
		for z in range(-5, 6): world.ground[Vector3i(x, 0, z)] = true
	world.workers.append({"id": 0, "cell": Vector3i(-4, 0, 0), "position": Vector3(-4, 0, 0), "route": [], "route_index": 0,
		"job": {}, "cargo": "", "status": "idle", "distance": 0.0, "hunger": 0.0, "role": "idle", "life_stage": "adult"})
	world.rebuild_navigation()
	return world
func stack(world, count: int) -> void:
	for y in count: world.buildings[Vector3i(0, y, 0)] = {"kind": "support", "direction": 0, "reviewed": true}
	world.rebuild_navigation()
func place_worker(world, cell: Vector3i) -> Dictionary:
	var worker: Dictionary = world.workers[0]
	worker.cell = cell; worker.position = world.navigation.surface_point(cell)
	return worker
func run_escape(world, seconds := 12.0) -> void:
	for i in ceili(seconds / 0.05): world.Citizens.tick(world, world.workers[0], 0.05)
func test_decks() -> void:
	var world = fixture(); stack(world, 10)
	for y in 10:
		check(Layout.has_deck(world, Vector3i(0, y, 0)) == (y % 2 == 1), "Default deck on module %d matches even pattern" % (y + 1))
		check(world.navigation.walkable(Vector3i(0, y + 1, 0)) == (y % 2 == 1), "Navigation matches deck on module %d" % (y + 1))
	check(world.build_error("support", Vector3i.ZERO).is_empty(), "Existing open frame accepts Support")
	check(not world.build_error("support", Vector3i.ZERO, 0, Vector3.ZERO, 77).is_empty(), "Moving a plan cannot replace an existing frame")
	world.buildings[Vector3i(3, 0, 0)] = {"kind": "support", "direction": 0}
	world.rebuild_navigation()
	check(not world.Relocation.destination_error(world, Vector3i(3, 0, 0), Vector3i.ZERO, 0, Vector3.ZERO).is_empty(), "Relocation cannot merge paid supports through free restoration")
	check(world.request_build("support", Vector3i.ZERO), "Placing Support restores its deck")
	check(world.plans.is_empty() and world.next_plan_id == 1 and world.construction_materials.is_empty(), "Restoration is immediate with no resource cost or construction")
	for y in 10:
		check(Layout.has_deck(world, Vector3i(0, y, 0)) == (y % 2 == 0), "Restoration shifts column to odd modules")
		check(world.navigation.walkable(Vector3i(0, y + 1, 0)) == (y % 2 == 0), "Shifted navigation has two metres of headroom")
	check(not world.request_build("support", Vector3i.ZERO), "Repeated restoration is a no-op")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Deck phase saves and loads")
	check(Layout.has_deck(restored, Vector3i.ZERO) and not Layout.has_deck(restored, Vector3i.UP), "Reload keeps chosen phase")
	check(world.request_build("support", Vector3i.UP), "Restore another level to choose the opposite pattern")
	place_worker(world, Vector3i(0, 2, 0))
	check(not world.request_build("support", Vector3i.ZERO), "Cannot remove a floor beneath a citizen")
	check(Layout.has_deck(world, Vector3i.UP), "Rejected change preserves existing decks")
	world = fixture(); stack(world, 2)
	world.buildings[Vector3i(0, 2, 0)] = {"kind": "stair", "direction": 0}
	world.rebuild_navigation()
	check(not Layout.has_deck(world, Vector3i.UP), "Support beneath stairs has no deck")
	check(not world.request_build("support", Vector3i.UP), "Restoration cannot put a deck through stairs")
	check(not world.navigation.surfaces.has(Vector3i(0, 2, 0)), "Open stair base grants no invisible floor")
	var views := {}
	for cell: Vector3i in world.buildings:
		var node := Assets.create(world.buildings[cell].kind)
		node.set_meta("asset", world.buildings[cell].kind); node.set_meta("cell", cell)
		root.add_child(node); views[cell] = node
	Structure.sync(world, views)
	check(not views[Vector3i.UP].get_node("ConnectedStructure").has_node("Deck"), "Rendered support under stair omits deck")
	for node in views.values(): node.free()
	var preview := Assets.create("support")
	Structure.preview_deck(preview, true)
	check(preview.get_node("RestoreDeck").visible, "Free restoration previews the deck")
	Structure.preview_deck(preview, false)
	check(not preview.get_node("RestoreDeck").visible, "Normal stacking restores full support preview")
	preview.free()
	world = fixture(); stack(world, 2)
	place_worker(world, Vector3i(0, 2, 0))
	check(world.request_build("support", Vector3i(0, 2, 0)), "Third module can be planned above retained second floor")
	var plan: Dictionary = world.plans[world.next_plan_id - 1]
	check(world.Planning.ready(world, plan), "Builder may stand on a floor that the new frame preserves")
	world._complete_plan(plan)
	check(world.navigation.walkable(Vector3i(0, 2, 0)), "Third module preserves its builder's floor and headroom")
func test_escape() -> void:
	var world = fixture(); stack(world, 2)
	var worker := place_worker(world, Vector3i(0, 2, 0))
	worker.cargo = "log"; worker.cargo_amount = 2
	var original: Vector3 = worker.position
	world.Citizens.tick(world, worker, 0.05)
	check(worker.has("rescue_route") and worker.position.distance_to(original) < 0.11, "Disconnected roof starts a gradual escape")
	var actor = preload("res://scripts/settlement/worker_view.gd").new()
	root.add_child(actor); actor.setup(0)
	actor.sync(worker, 0.05, false, null, world.navigation)
	check(actor.position.is_finite(), "Climbing citizen renders with carried cargo")
	actor.free()
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Mid-climb save loads")
	var invalid = Model.new()
	worker.rescue_index = 999
	check(not invalid.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Malformed rescue progress is rejected")
	worker.rescue_index = 1
	run_escape(restored)
	check(restored.workers[0].cell.y == 0 and not restored.workers[0].has("rescue_route"), "Saved climb finishes down a two-metre ledge")
	check(restored.workers[0].cargo == "log" and restored.workers[0].cargo_amount == 2, "Escape preserves carried resources")
	world = fixture(); stack(world, 4)
	worker = place_worker(world, Vector3i(0, 4, 0))
	run_escape(world, 2.0)
	check(worker.cell == Vector3i(0, 4, 0) and not worker.has("rescue_route"), "Four-metre drop is not an escape route")
	world = fixture()
	world.ground.clear()
	world.ground[Vector3i.ZERO] = true
	for x in range(1, 5):
		for z in range(-2, 3): world.ground[Vector3i(x, 2, z)] = true
	world.rebuild_navigation(); worker = place_worker(world, Vector3i.ZERO)
	run_escape(world)
	check(worker.cell.y == 2, "Citizen climbs up a two-metre ledge to leave an isolated hollow")
	world = fixture(); stack(world, 2)
	worker = place_worker(world, Vector3i(0, 2, 0))
	for d in world.DIRECTIONS:
		world.buildings[d] = {"kind": "house", "direction": 0, "house_tier": 1}
	world.rebuild_navigation()
	check(Escape.find_route(world, worker).is_empty(), "Escape never crosses solid adjacent buildings")
	world = fixture(); worker = world.workers[0]
	world.Citizens.tick(world, worker, 0.05)
	check(not worker.has("rescue_route"), "Connected citizens keep ordinary movement")
	world = fixture(); stack(world, 2)
	worker = place_worker(world, Vector3i(0, 2, 0))
	worker.job = {"kind": "process", "target": worker.cell, "phase": "work", "output": "plank", "labour": world.Jobs.Labour.new(20.0)}
	var labour = worker.job.labour
	run_escape(world)
	check(worker.cell.y == 0 and worker.job.is_empty() and labour.applied_seconds == 0.0, "Recovery releases unreachable work instead of performing it from the ground")

func test_picking() -> void:
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-deck-picking-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.model = fixture(); stack(game.model, 4)
	game.model.exploration.reveal(Vector3.ZERO)
	game.world.last_revision = -1
	game.world.sync(game.model, 0, -1)
	game._set_tool("support")
	var camera: Camera3D = game.rig.camera
	camera.global_position = Vector3(7, 5, 7)
	camera.look_at(Vector3(0, 1, 0))
	for frame in 3: await physics_frame
	var side: Dictionary = game.placement_at(camera.unproject_position(Vector3(0.49, 0.5, 0.1)), false)
	check(side.get("cell") == Vector3i.ZERO, "Aiming at open frame side targets its existing module")
	var top: Dictionary = game.placement_at(camera.unproject_position(Vector3(0, 4, 0)), false)
	check(top.get("cell") == Vector3i(0, 4, 0), "Aiming at stack top still adds a new support")
	game.chunk_loader.finish()
	game.free()
	await process_frame

func run() -> void:
	test_decks()
	test_escape()
	await test_picking()
	print("PASS: %d alternating deck, free restoration, headroom and ledge escape checks" % checks if failures.is_empty() else "FAIL: support/deck escape")
	quit(int(not failures.is_empty()))
