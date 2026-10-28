extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.speed = 0
	game.capture = true
	game.set_process(false)
	game.fog.hide()
	game.world.fog_enabled = false
	game.hud.hide()
	var model = game.model
	for collection in [model.trees, model.deposits, model.stores, model.gardens, model.wells, model.water_sources, model.buildings, model.plans]: collection.clear()
	var puddles := {}
	for index in 4: puddles[Vector3i(index * 3 - 4, 0, 0)] = "puddle"
	model.Hydrology.populate(model, puddles)
	for index in 4:
		var cell := Vector3i(index * 3 - 4, 0, 0)
		for tier in (index + 1 if index < 3 else 2):
			model.request_build("well", cell)
			model._complete_plan(model.plans.values().back())
		if index == 3:
			model.request_build("house", cell)
			model._complete_plan(model.plans.values().back())
	model.rebuild_navigation()
	game.world.sync(model, 0, -1)
	for actor in game.world.actors: actor.hide()
	game.rig.focus = Vector3(0.5, 0.5, 0)
	game.rig.zoom = 12
	game.rig.yaw = 0.15
	game.rig.pitch = 0.7
	game.rig.update_camera()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/well-tiers.png")
	print("PASS: captured hole, masonry, roof and waterworks" if result == OK else "FAIL: well capture")
	game.free()
	quit(int(result != OK))
