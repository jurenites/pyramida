extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.speed = 0
	game.capture = true
	game.set_process(false)
	game.hud.hide()
	game.fog.hide()
	game.world.fog_enabled = false
	var world = game.model
	world.time = 0.20 * preload("res://scripts/gameplay_settings.gd").SIMULATION_DAY_SECONDS
	game.world.sync(world, 0, -1)
	game.Illustration.update(game.world_container.material, world.time)
	game.rig.focus = Vector3(1, 0.3, 3)
	game.rig.zoom = 24
	game.rig.yaw = -0.35
	game.rig.pitch = 0.68
	game.rig.update_camera()
	await save("grass-opening.png")
	# A close view of the same resource asset, showing 15, 10, 5 and zero full-height leaves.
	for collection in [world.trees, world.deposits, world.stores, world.gardens, world.wells, world.water_sources, world.buildings, world.plans, world.soil_beds, world.vines]: collection.clear()
	for spec in [[Vector3i(-3, 0, 0), 3, 0.0], [Vector3i(-1, 0, 0), 2, 0.0], [Vector3i(1, 0, 0), 1, 0.0], [Vector3i(3, 0, 0), 0, 12.0]]:
		world.gardens[spec[0]] = {"species": "grass", "water": 0, "growth": spec[2], "food": spec[1], "reserved": -1}
	world.revision += 1
	world.rebuild_navigation()
	game.world.sync(world, 0, -1)
	for actor in game.world.actors: actor.hide()
	game.rig.focus = Vector3(0, 0.1, 0)
	game.rig.zoom = 8.5
	game.rig.yaw = -0.15
	game.rig.pitch = 0.55
	game.rig.update_camera()
	await save("grass-resource-stages.png")
	if "--wind" in OS.get_cmdline_user_args():
		var directory := "/tmp/pyramida-grass-wind"
		DirAccess.make_dir_recursive_absolute(directory)
		for frame in 40:
			await create_timer(0.13).timeout
			await RenderingServer.frame_post_draw
			var screenshot := root.get_texture().get_image()
			var size := screenshot.get_size()
			var strip := screenshot.get_region(Rect2i(Vector2i(Vector2(size) * Vector2(0.16, 0.36)), Vector2i(Vector2(size) * Vector2(0.68, 0.22))))
			strip.save_png(directory + "/%02d.png" % frame)
		print("PASS: captured forty wind frames")
	game.free()
	quit()
func save(filename: String) -> void:
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/settlement/" + filename
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var screenshot := root.get_texture().get_image()
	if filename == "grass-resource-stages.png":
		# Frame the four resource states without the surrounding empty terrain.
		var size := screenshot.get_size()
		screenshot = screenshot.get_region(Rect2i(Vector2i(Vector2(size) * Vector2(0.16, 0.36)), Vector2i(Vector2(size) * Vector2(0.68, 0.22))))
	var result := screenshot.save_png(path)
	print("PASS: " + filename if result == OK else "FAIL: " + filename)
