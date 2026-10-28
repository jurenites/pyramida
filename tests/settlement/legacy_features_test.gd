extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Settings = preload("res://scripts/gameplay_settings.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
func run() -> void:
	root.size = Vector2i(1280, 900)
	var game = Scene.instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.speed = 0
	await process_frame
	await physics_frame
	for worker in game.model.workers:
		game.model.set_role(worker.id, "idle")
	var citizen: Dictionary = game.model.workers[0]
	game._select_worker(false, game.rig.camera.unproject_position(citizen.position + Vector3.UP * 0.6))
	check(game.selected_workers == [0], "Screen picking selects an adult")
	game.hud.update(game.model, game.selected, 1)
	check(not game.hud.detail_panel.visible, "Selecting an adult keeps citizen diagnostics hidden")
	game.model.set_role(citizen.id, "woodcutter")
	game.model.tick(0.05)
	check(citizen.role == "woodcutter" and citizen.job.get("kind") == "fell", "Assigned woodcutter starts work even with the opening 18 logs")
	var second: Dictionary = game.model.workers[1]
	game._select_worker(true, game.rig.camera.unproject_position(second.position + Vector3.UP * 0.6))
	check(game.selected_workers == [0, 1], "Shift-click retains the first citizen")
	game.hud.update(game.model, game.selected, 1)
	var cell := Vector3i(4, 0, 0)
	game.model.buildings[cell] = {"kind": "sawmill", "direction": 0}
	game.model.rebuild_navigation()
	game.world.sync(game.model, 0, -1)
	await physics_frame
	await process_frame
	var node: Node3D = game.world.entity_views["building:%s" % cell]
	var mouse: Vector2 = game.rig.camera.unproject_position(node.global_position + Vector3.UP)
	check(game.command_target_at(mouse).get("cell") == cell, "Workplace picking targets the sawmill floor, not its roof")
	game.command_at(mouse)
	check(citizen.role == "sawyer" and second.role == "sawyer", "Right-click workplace assigns the selected group")
	check(citizen.job.has("target") and citizen.job.target.y == cell.y and game.model.navigation.at_access(citizen.job.target, cell), "Workplace movement targets a clear access cell on its actual floor")
	var plan_cell := Vector3i(0, 1, 0)
	check(game.model.request_build("platform", plan_cell), "Upper floor construction can be queued")
	game.world.sync(game.model, 0, -1)
	await physics_frame
	await process_frame
	var plan: Dictionary = game.model.plans.values()[0]
	node = game.world.entity_views["plan:%s" % plan.id]
	mouse = game.rig.camera.unproject_position(node.to_global(Model.Catalog.DEFINITIONS.platform.offset))
	check(game.command_target_at(mouse).get("entity_key") == "plan:%s" % plan.id, "Commands can hit transparent construction plans")
	game.command_at(mouse)
	check(citizen.role == "builder", "Upper floor plan assigns construction from a reachable work surface")
	var copy = Model.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.model.snapshot()))), "Commanded world round-trips through existing save format")
	check(copy.workers[0].role == "builder", "Assigned role survives reload")
	game.model.time = Settings.SIMULATION_DAY_SECONDS * 0.25
	game.hud.update(game.model, -1, 1)
	check(is_equal_approx(game.hud.day_icon.phase, 0.25), "Original day/night dial follows saved time")
	check(not game.hud.day_icon.is_night and game.hud.day_label.text == "1", "Day counter uses sun and number")
	game.model.time = Settings.SIMULATION_DAY_SECONDS * 0.5
	game.hud.update(game.model, -1, 4)
	check(game.hud.day_icon.is_night and game.hud.day_label.text == "1", "Dusk swaps sun for moon without changing day number")
	game.rig.yaw = 1.1
	game.rig.pitch = 0.9
	game.rig.update_camera()
	game.hud.update_selection(game.world, game.rig.camera, {})
	check(game.hud.compass._camera.basis.z.is_equal_approx(game.rig.camera.global_basis.z), "Original compass tracks camera rotation and pitch")
	var focus: Vector3 = game.rig.focus
	game.hud.root.get_node("ResetCameraCompass").pressed.emit()
	check(is_equal_approx(game.rig.yaw, -0.65) and game.rig.focus == focus, "Compass restores view orientation while preserving location")
	check(not game.hud.status_label.is_visible_in_tree(), "Bottom instruction panel stays hidden")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d restored interaction, compass and day/night checks" % checks)
		quit()
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
