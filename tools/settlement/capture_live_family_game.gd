extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-live-family-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.speed = 0
	game.capture = true
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	var focus := Vector3.ZERO
	for worker: Dictionary in game.model.workers: focus += worker.position / game.model.workers.size()
	game.rig.focus = focus + Vector3.UP * 0.6
	game.rig.zoom = 7
	game.rig.yaw = -0.25
	game.rig.pitch = 0.60
	game.rig.update_camera()
	game.world.sync(game.model, 0, -1)
	game.hud.hide()
	for index in 8: await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://artifacts/settlement/live-family-game.png") == OK)
	print("PASS: captured approved citizens in the actual game scene")
	game.free()
	quit()
