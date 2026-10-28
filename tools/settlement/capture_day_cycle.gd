extends SceneTree
const Settings = preload("res://scripts/gameplay_settings.gd")
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1280, 900)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.speed = 0
	game.rig.focus = Vector3(-1, 1.5, 0)
	game.rig.zoom = 26
	game.rig.pitch = 0.8
	for sample in [{"name": "morning", "phase": 0.04}, {"name": "noon", "phase": 0.25}, {"name": "evening", "phase": 0.46}, {"name": "night", "phase": 0.75}]:
		game.model.time = Settings.SIMULATION_DAY_SECONDS * sample.phase
		for frame in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png("res://artifacts/day-cycle-%s.png" % sample.name)
		if error != OK:
			printerr("FAIL: day cycle capture")
			quit(1)
			return
	print("PASS: captured sunrise, noon, sunset and night")
	quit()
