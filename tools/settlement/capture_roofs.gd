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
	game.fog.visible = false
	game.world.fog_enabled = false
	game.hud.hide()
	var model = game.model
	model.trees.clear()
	model.deposits.clear()
	model.stores.clear()
	model.gardens.clear()
	model.wells.clear()
	model.water_sources.clear()
	model.buildings.clear()
	model.plans.clear()
	model.buildings[Vector3i(-4, 0, 0)] = {"kind": "house", "direction": 0}
	model.buildings[Vector3i(0, 0, 0)] = {"kind": "house", "direction": 0}
	model.buildings[Vector3i(0, 1, 0)] = {"kind": "school", "direction": 0}
	model.buildings[Vector3i(4, 0, 0)] = {"kind": "sawmill", "direction": 0}
	model.buildings[Vector3i(4, 1, 0)] = {"kind": "workshop", "direction": 0}
	model.buildings[Vector3i(4, 2, 0)] = {"kind": "house", "direction": 0}
	model.buildings[Vector3i(-4, 0, 4)] = {"kind": "windmill", "direction": 0}
	model.buildings[Vector3i(0, 0, 4)] = {"kind": "house", "direction": 0}
	model.buildings[Vector3i(2, 0, 4)] = {"kind": "house", "direction": 0}
	model.buildings[Vector3i(1, 1, 4)] = {"kind": "house", "direction": 0}
	model.rebuild_navigation()
	game.world.sync(model, 0, -1)
	game.rig.focus = Vector3(0, 1.8, 1.5)
	game.rig.zoom = 17
	game.rig.yaw = -0.55
	game.rig.pitch = 0.65
	game.rig.update_camera()
	for index in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/automatic-roofs.png")
	print("PASS: captured shorter buildings and automatic roofs" if result == OK else "FAIL: capture")
	quit(int(result != OK))
