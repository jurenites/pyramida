extends SceneTree
const Vines = preload("res://scripts/settlement/vines.gd")
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
	for collection in [world.trees, world.deposits, world.stores, world.gardens, world.wells, world.water_sources, world.buildings, world.plans, world.soil_beds, world.vines]: collection.clear()
	world.buildings[Vector3i.ZERO] = {"kind": "house", "direction": 0}
	world.buildings[Vector3i.UP] = {"kind": "house", "direction": 0}
	var cell := Vector3i(-1, 0, 1)
	world.vines[cell] = Vines.create()
	world.vines[cell].placement_offset = Vector3(-0.27, 0, 0.34)
	world.vines[Vector3i(-4, 0, 2)] = Vines.create()
	world.vines[Vector3i(-4, 0, 2)].wild = true
	world.vine_discovered = true
	world.vine_roots = 0
	world.rebuild_navigation()
	world.Hydrology.tick(world, 450)
	world.time = 0.20 * preload("res://scripts/gameplay_settings.gd").SIMULATION_DAY_SECONDS
	game.world.sync(world, 0, -1)
	for actor in game.world.actors: actor.hide()
	game.Illustration.update(game.world_container.material, world.time)
	game.rig.focus = Vector3(1, 1.5, 0)
	game.rig.zoom = 13
	game.rig.yaw = 0.7
	game.rig.pitch = 0.58
	game.rig.update_camera()
	game.hud.show_category("nature")
	game.hud.build_panel.show()
	game.hud.update(world, -1, 1, {"cell": Vector3i(-4, 0, 2), "kind": "vine_tree", "entity_key": "vine:%s" % Vector3i(-4, 0, 2)})
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/vine-roots-menu.png")
	print("PASS: captured wild roots, corner growth and exhausted menu" if result == OK else "FAIL: capture")
	game.free()
	quit(int(result != OK))
