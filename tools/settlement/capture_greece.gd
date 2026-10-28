extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 980)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-greece-capture-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.speed = 0
	game.capture = true
	game.set_process(false)
	var model = preload("res://scripts/settlement/world_model.gd").new()
	model.setup(1409, "easy")
	game.model = model
	game.world.last_revision = -1
	game.fog.visible = false
	game.world.fog_enabled = false
	game.world.sync(model, 0, -1)
	game.hud.hide()
	game.rig.focus = Vector3(8, 0, 0)
	game.rig.zoom = 54
	game.rig.yaw = -0.55
	game.rig.pitch = 0.85
	game.rig.update_camera()
	for index in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/greece-coast.png")
	game.rig.focus = Vector3(-2, 0, 0)
	game.rig.zoom = 17
	game.rig.update_camera()
	for index in 12: await process_frame
	await RenderingServer.frame_post_draw
	result = maxi(result, root.get_texture().get_image().save_png("res://artifacts/greece-grass.png"))
	print("PASS: captured Greece coast and grass" if result == OK else "FAIL: capture")
	quit(int(result != OK))
