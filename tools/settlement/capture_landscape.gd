extends SceneTree
## In-engine visual review of generated terraces and harvestable outcrops.
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 980)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.speed = 0
	game.capture = true
	game.set_process(false)
	game.fog.visible = false
	game.world.fog_enabled = false
	game.world.sync(game.model, 0, -1)
	game.hud.hide()
	game.rig.focus = Vector3(-24, 2, -24)
	game.rig.zoom = 31
	game.rig.yaw = -0.6
	game.rig.pitch = 0.68
	game.rig.update_camera()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/settlement/terraced-landscape.png")
	print("PASS: captured terraced landscape" if error == OK else "FAIL: landscape capture")
	quit(int(error != OK))
