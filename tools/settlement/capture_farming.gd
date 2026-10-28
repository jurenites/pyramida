extends SceneTree
const Farm = preload("res://scripts/settlement/farming.gd")
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
	game.hud.hide()
	game.fog.hide()
	game.world.fog_enabled = false
	var world = game.model
	for collection in [world.trees, world.deposits, world.stores, world.gardens, world.wells, world.water_sources, world.buildings, world.plans, world.soil_beds]: collection.clear()
	for spec in [[Vector3i(-7, 0, 1), 4, 0.0], [Vector3i(-2, 0, 1), 0, 1.0], [Vector3i(3, 1, 0), 4, 0.0]]:
		var cell: Vector3i = spec[0]
		world.buildings[cell] = {"kind": "hay_field", "direction": 0, "placement_offset": Farm.FIELD_OFFSET}
		world.gardens[cell] = {"food": spec[1], "growth": spec[2], "water": 1, "reserved": -1}
	for x in [3, 5]:
		for z in [0, 2]: world.buildings[Vector3i(x, 0, z)] = {"kind": "house", "direction": 0}
	for cell in Farm.bed_cells(Vector3i(3, 1, 0)) + Farm.bed_cells(Vector3i(-2, 0, -4)):
		world.soil_beds[cell] = {"materials": {"log": 1}}
	world.rebuild_navigation()
	world.time = 0.20 * preload("res://scripts/gameplay_settings.gd").SIMULATION_DAY_SECONDS
	game.world.sync(world, 0, -1)
	for actor in game.world.actors: actor.hide()
	game.Illustration.update(game.world_container.material, world.time)
	game.rig.focus = Vector3(1, 0.8, 0.8)
	game.rig.zoom = 17
	game.rig.yaw = -0.35
	game.rig.pitch = 0.68
	game.rig.update_camera()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/hay-fields.png")
	print("PASS: captured mature hay, cut regrowth, four soil beds and rooftop farming" if result == OK else "FAIL: farming capture")
	game.free()
	quit(int(result != OK))
