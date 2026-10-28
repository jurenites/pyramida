extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
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
	game.rig.focus = Vector3(0, 7, 0)
	game.rig.zoom = 100
	game.rig.yaw = -0.55
	game.rig.pitch = 0.85
	var water_preview := OS.get_cmdline_user_args().has("--water")
	if water_preview:
		game.rig.focus = Vector3(-4, 1, 0)
		game.rig.zoom = 20
		game.selected_object = {"cell": Vector3i(-4, 0, 0), "kind": "puddle"}
		preload("res://scripts/settlement/hydrology.gd").tick(game.model, 94)
	var sand_preview := OS.get_cmdline_user_args().has("--sand")
	if sand_preview:
		game.rig.focus = Vector3(2, 0, 0)
		game.rig.zoom = 18
	game.rig.update_camera()
	for index in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://artifacts/sand-colour.png" if sand_preview else ("res://artifacts/rainwater-collection.png" if water_preview else "res://artifacts/world-generation.png")
	var result := root.get_texture().get_image().save_png(output)
	print("PASS: captured flat desert and buttes" if result == OK else "FAIL: capture")
	quit(int(result != OK))
