extends SceneTree
const Planting = preload("res://scripts/settlement/planting.gd")
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
	var world = game.model
	for collection in [world.trees, world.deposits, world.stores, world.gardens, world.wells, world.water_sources, world.buildings, world.plans, world.soil_beds]: collection.clear()
	var seeds := ["seed_vegetables", "seed_tree", "seed_bush", "seed_grass", "seed_palm"]
	for index in seeds.size():
		var x := (index - 2) * 4
		var seed_cell := Vector3i(x, 0, 4)
		world.request_build(seeds[index], seed_cell)
		for z in [-3, 1]:
			var cell := Vector3i(x, 0, z)
			Planting.complete(world, {"kind": seeds[index], "cell": cell})
			if world.trees.has(cell):
				world.trees[cell].seed_growth = 0.35 if z == 1 else 1.0
				if z == -3: world.trees[cell].inventory.store("log", 3)
			if world.deposits.has(cell):
				world.deposits[cell].seed_growth = 0.35 if z == 1 else 1.0
				if z == -3:
					world.deposits[cell].inventory.capacity = 3
					world.deposits[cell].inventory.store("food", 3)
			if world.gardens.has(cell):
				world.gardens[cell].growth = 8.0 if z == 1 else 0.0
				world.gardens[cell].food = 0 if z == 1 else 3
	world.rebuild_navigation()
	world.time = 0.20 * preload("res://scripts/gameplay_settings.gd").SIMULATION_DAY_SECONDS
	game.world.sync(world, 0, -1)
	for actor in game.world.actors: actor.hide()
	game.Illustration.update(game.world_container.material, world.time)
	game.rig.focus = Vector3(3.8, 0.8, 0.5)
	game.rig.zoom = 23
	game.rig.yaw = 0.15
	game.rig.pitch = 0.68
	game.rig.update_camera()
	game.hud.show_category("nature")
	game.hud.build_panel.show()
	game.hud.update(world, -1, 1)
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/seed-planting.png")
	print("PASS: captured seed orders, young and mature plants with the Nature menu" if result == OK else "FAIL: planting capture")
	game.free()
	quit(int(result != OK))
