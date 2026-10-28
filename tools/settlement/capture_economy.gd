extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.speed = 0
	var opening := OS.get_cmdline_user_args().has("--opening")
	if not opening:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/peaceful-village.json"))
		if not data is Dictionary or not game.model.restore(data):
			printerr("FAIL: missing completed progression snapshot")
			quit(1)
			return
	game.model.time = floorf(game.model.time / 360.0) * 360.0 + 70.0
	game.rig.focus = Vector3(-5, 1, -1)
	game.rig.zoom = 28
	game.rig.yaw = -0.65
	game.rig.pitch = 0.78
	game.rig.update_camera()
	game.hud.show_category("industry")
	game.selected = 0
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/peaceful-opening.png" if opening else "res://artifacts/peaceful-village.png"
	var result := root.get_texture().get_image().save_png(path)
	print("PASS: " + path if result == OK else "FAIL: screenshot")
	quit(int(result != OK))
