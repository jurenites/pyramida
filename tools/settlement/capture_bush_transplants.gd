extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1440, 900)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.capture = true
	root.add_child(game)
	game.set_process(false)
	game.fog.hide()
	game.world.fog_enabled = false
	var world = game.model
	for collection in [world.trees, world.deposits, world.vines, world.water_sources, world.buildings, world.soil_beds, world.plans, world.stores]: collection.clear()
	world.buildings[Vector3i(-3, 0, -3)] = {"kind": "house", "direction": 0}
	for cell in [Vector3i(-2, 0, 1), Vector3i(0, 0, 1), Vector3i(2, 0, 1)]:
		world.soil_beds[cell] = {"materials": {"log": 1}}
	world.deposits[Vector3i(-2, 0, 1)] = world.Chunks.entry("berry", "food", 3)
	world.deposits[Vector3i(0, 0, 1)] = world.Chunks.entry("berry", "food", 3)
	world.deposits[Vector3i(0, 0, 1)].inventory.amounts.food = 1
	world.uprooted_bushes.append({"berries": 2, "capacity": 3, "regrowth": 75.25, "seed_growth": 1.0})
	world.bush_discovered = true
	world.rebuild_navigation()
	world.time = 0.20 * preload("res://scripts/gameplay_settings.gd").SIMULATION_DAY_SECONDS
	game.world.sync(world, 0, -1)
	for actor in game.world.actors: actor.hide()
	game.Illustration.update(game.world_container.material, world.time)
	game.rig.focus = Vector3(1, 0.6, 0)
	game.rig.zoom = 13
	game.rig.yaw = 0.2
	game.rig.pitch = 0.68
	game.rig.update_camera()
	game.hud.show_category("nature")
	game.hud.build_panel.show()
	game.hud.update(world, -1, 1)
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/bush-transplants.png")
	print("PASS: captured collected bush menu and prepared soil" if result == OK else "FAIL: capture")
	game.free()
	quit(int(result != OK))
