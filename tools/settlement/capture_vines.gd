extends SceneTree
const Vines = preload("res://scripts/settlement/vines.gd")

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1440, 980)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-vine-capture-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.speed = 0
	game.capture = true
	game.set_process(false)
	var model = game.model
	model.trees.clear()
	model.deposits.clear()
	model.plans.clear()
	model.workers.clear()
	model.stores.clear()
	for cell in [Vector3i.ZERO, Vector3i.UP, Vector3i(2, 0, 0), Vector3i(6, 0, 0)]:
		model.buildings[cell] = {"kind": "house", "direction": 0}
	var mature := Vector3i(-2, 0, 0)
	var young := Vector3i(6, 0, 2)
	model.vines[mature] = Vines.create()
	for i in 450: model.Hydrology.tick(model, 1.0)
	model.vines[young] = Vines.create()
	for i in 27: model.Hydrology.tick(model, 1.0)
	model.rebuild_navigation()
	game.world.last_revision = -1
	game.fog.visible = false
	game.world.fog_enabled = false
	game.world.sync(model, 0, -1)
	game.hud.hide()
	game.rig.focus = Vector3(1.7, 1.3, 0)
	game.rig.zoom = 13
	game.rig.yaw = -0.65
	game.rig.pitch = 0.65
	game.rig.update_camera()
	for index in 20: await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/vine-trees.png")
	game.rig.yaw = -2.2
	game.rig.focus = Vector3(0.5, 1.4, 0)
	game.rig.zoom = 10
	game.rig.update_camera()
	for index in 12: await process_frame
	await RenderingServer.frame_post_draw
	error = maxi(error, root.get_texture().get_image().save_png("res://artifacts/vine-network.png"))
	model.weather.raining = false
	for i in 300: Vines.tick_second(model)
	game.world.sync(model, 0, -1)
	for index in 12: await process_frame
	await RenderingServer.frame_post_draw
	error = maxi(error, root.get_texture().get_image().save_png("res://artifacts/vine-trees-dry.png"))
	print("PASS: vine greenery and drought captures" if error == OK else "FAIL: vine capture")
	quit(int(error != OK))
