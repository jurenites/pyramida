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
	for index in 3:
		var cell := Vector3i(index * 3 - 3, 0, 0)
		model.add_store(cell)
		model.stores[cell].store("pottery", 8)
		if index > 0: model.buildings[cell] = {"kind": "goods_rack" if index == 1 else "small_warehouse", "direction": 0}
	model.rebuild_navigation()
	game.world.sync(model, 0, -1)
	for actor in game.world.actors: actor.hide()
	game.rig.focus = Vector3(0, 0.4, 0)
	game.rig.zoom = 8
	game.rig.yaw = 0.45
	game.rig.pitch = 0.7
	game.rig.update_camera()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/pottery-warehouse.png")
	print("PASS: captured pile, pottery rack and small warehouse" if result == OK else "FAIL: warehouse capture")
	game.free()
	quit(int(result != OK))
