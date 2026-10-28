extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const SCENE_PATH := "res://scenes/settlement/Terraces.tscn"
const Nav = preload("res://scripts/settlement/navigation.gd")
const Mask = preload("res://scripts/exploration_mask.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
func run() -> void:
	var model = Model.new()
	model.setup()
	var initial: int = model.exploration.cells.size()
	check(initial > 0 and initial < 2500, "Opening reveals only the family neighbourhood")
	for worker: Dictionary in model.workers:
		check(model.exploration.contains(worker.position), "Every citizen contributes initial sight")
	check(not model.exploration.contains(Vector3(30, 0, 30)), "Distant land starts unknown")
	var revision: int = model.exploration.revision
	model.exploration.update(model.workers)
	check(model.exploration.revision == revision, "Stationary citizens do not repaint the fog texture")
	var start: Vector3 = model.workers[0].position
	for x in range(-4, 25):
		model.workers[0].position = Vector3(x, 0, 4)
		model.exploration.update(model.workers)
	check(model.exploration.contains(Vector3(24, 0, 4)), "Movement opens new land")
	check(model.exploration.contains(start), "Explored land stays visible after leaving")
	check(model.exploration.contains(Vector3(24, 20, 4)), "Reveal covers a world column without confusing upper floors")
	# Keep worker position consistent for the save validator.
	model.workers[0].cell = Vector3i(roundi(24 / Nav.CELL_SIZE), 0, roundi(4 / Nav.CELL_SIZE))
	model.workers[0].position = Nav.point(model.workers[0].cell)
	model.exploration.update(model.workers)
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Exploration save restores")
	check(restored.exploration.cells == model.exploration.cells, "Exact explored footprint survives JSON reload")
	check(not restored.exploration.contains(Vector3(30, 0, 30)), "Reload does not reveal the whole map")
	var legacy := model.snapshot()
	legacy.world.v = legacy.world.v.filter(func(pair): return pair[0] != "explored")
	check(restored.restore(legacy), "Pre-fog version 4 save still loads")
	check(restored.exploration.contains(Nav.point(restored.stores.keys()[0])), "Old save retains sight of established storage")
	for invalid in [null, [[999999, 0]], [[0, 0], [0, 0]], [[0.5, 0]], [["0", 0]]]:
		var broken := model.snapshot()
		for pair: Array in broken.world.v:
			if pair[0] == "explored": pair[1] = invalid
		check(not restored.restore(broken), "Malformed exploration rejected before mutating restored state")
	var remote := Vector3(400, 0, -320)
	model.exploration.reveal(remote)
	check(model.exploration.contains(remote), "Discovery continues beyond the original bounded map")
	var original := {}
	Mask.reveal(original, Vector3.ZERO, 4)
	check(original.has(Vector2i(0, 0)) and not original.has(Vector2i(8, 8)), "Shared reveal preserves the older circular geometry")
	if OS.get_cmdline_user_args().has("--model-only"):
		finish()
		return
	var game = load(SCENE_PATH).instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.speed = 0
	await process_frame
	await physics_frame
	check(game.fog.visible and game.world.fog_enabled, "Playable settlement uses fog rendering")
	var far_cell: Vector3i = game.model.trees.keys().filter(func(cell): return not game.model.exploration.contains(Nav.point(cell)) and not game.model.navigation.route(game.model.workers[0].cell, cell).is_empty())[0]
	var key := "tree:%s" % far_cell
	var tree: Node3D = game.world.entity_views[key]
	check(not tree.visible and tree.get_meta("collider").collision_layer == 0, "Unknown resources are invisible and cannot intercept inspection")
	game.rig.focus = Nav.point(far_cell)
	game.rig.update_camera()
	var mouse: Vector2 = game.rig.camera.unproject_position(Nav.point(far_cell))
	game._set_tool("inspect")
	var target: Dictionary = game.command_target_at(mouse)
	check(target.get("explore", false) and not target.has("kind"), "Fog click exposes no resource identity")
	game.selected_workers.assign([0])
	game.command_at(mouse)
	check(game.model.workers[0].get("role") == "idle" and game.model.workers[0].job.get("kind") == "move", "Fog click issues exploration, not hidden woodcutting")
	game._set_tool("house")
	check(game.placement_at(mouse).is_empty(), "Construction previews cannot expose unexplored land")
	var worker: Dictionary = game.model.workers[1]
	check(not Model.Jobs._assign_collection(game.model, worker, far_cell, "log", "fell"), "Autonomous harvesting cannot target undiscovered resources")
	game.model.exploration.reveal(Nav.point(far_cell))
	game.fog.sync(game.model, true)
	game.world.sync(game.model, 0, -1)
	await physics_frame
	check(tree.visible and tree.get_meta("collider").collision_layer == 1, "Arriving reveals the resource and enables inspection")
	game.world.cutaway = true
	game.world.display_level = -1
	game.world.sync(game.model, 0, -1)
	check(not tree.visible, "Exploration does not override cutaway visibility")
	game.world.cutaway = false
	game.world.sync(game.model, 0, -1)
	check(tree.visible, "Disabling cutaway restores an explored resource")
	var first_fog: int = game.fog.model_id
	var other = Model.new()
	other.setup()
	game.fog.sync(other, true)
	check(game.fog.model_id != first_fog and not other.exploration.contains(Nav.point(far_cell)), "Switching settlements cannot leak another world's exploration")
	game._open_menu(false)
	check(not game.fog.visible and not game.world.fog_enabled, "Home preview stays fully visible and does not explore the playable world")
	game.queue_free()
	await process_frame
	finish()

func finish() -> void:
	if failures.is_empty():
		print("PASS: %d exploration, save migration, fog rendering and hidden-command checks" % checks)
		quit()
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
