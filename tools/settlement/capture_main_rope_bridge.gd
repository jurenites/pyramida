extends SceneTree
const Fixture = preload("res://scripts/settlement/rope_bridge_fixture.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1500,1000)
	var game = preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false; game.slot_directory = "/tmp/pyramida-bridge-capture"
	root.add_child(game); game.set_process(false); game.speed = 0
	game.model = Fixture.create(false); game.model.streaming_enabled = false
	game.model.exploration.reveal(Fixture.END); game.model.exploration.reveal(Fixture.SOURCE)
	game.menu.hide(); game.fog.hide(); game.world.fog_enabled = false
	game.world.sync(game.model,0,-1)
	game.rig.focus = Vector3(1,2,1); game.rig.zoom = 23; game.rig.pitch = 0.85; game.rig.update_camera()
	game.hud.update(game.model,-1,0); game.hud.show_category("structure")
	for frame in 10: await process_frame
	game.hud.buttons.rope_bridge.pressed.emit(); game.hud.build_panel.hide()
	var first: Vector2 = game.rig.camera.unproject_position(Fixture.START)
	game.bridge_editor.update(first,true); game.bridge_editor.click(first)
	for frame in 4: await process_frame
	root.get_texture().get_image().save_png("res://artifacts/settlement/rope-bridge-main-first-pair.png")
	game.bridge_editor.click(game.rig.camera.unproject_position(Fixture.END))
	assert(game.model.plans.size()==1, "Main placement queues one bridge")
	var found := false
	for step in 10000:
		game.model.tick(0.05)
		if game.model.workers[0].cargo == "log" and game.model.workers[0].position.x > 1 and game.model.workers[0].position.x < 2.5: found = true; break
	assert(found)
	game.selected_object.entity_key = "bridge:%d" % game.selected_object.bridge_id
	for frame in 20:
		game.world.sync(game.model,0.05,-1)
		game.hud.update(game.model,-1,0,game.selected_object)
		game.hud.update_selection(game.world,game.rig.camera,game.selected_object,game.model)
		game.hud.update_object_tooltips(game.world,game.rig.camera,game.model,game.selected_object)
		game.bridge_editor.update(first,false)
		await process_frame
	root.get_texture().get_image().save_png("res://artifacts/settlement/rope-bridge-main-hauling.png")
	game._clear_selection(); game.model = Fixture.create(false)
	game.model.workers.clear(); game.model.buildings.clear(); game.model.stores.clear(); game.model.ground.clear()
	for centre: Vector3i in [Vector3i(0,0,0),Vector3i(8,1,2)]:
		for cell: Vector3i in game.model.Grid.support_cells(centre): game.model.ground[cell] = true
		game.model.buildings[centre] = {"kind": "house", "direction": 0, "house_tier": 2}
		game.model.exploration.reveal(Vector3(centre))
	game.model.rebuild_navigation()
	assert(Fixture.Bridges.request(game.model,Vector3(0.75,2,0.1),Vector3(7.25,3,1.9)),game.model.last_message)
	Fixture.Bridges.complete(game.model,game.model.plans.values()[0])
	game.rig.focus = Vector3(4,1,1); game.rig.zoom = 15; game.rig.pitch = 0.85; game.rig.update_camera()
	for frame in 20:
		game.world.sync(game.model,0.05,-1); game.hud.update(game.model,-1,0)
		game.hud.update_object_tooltips(game.world,game.rig.camera,game.model,{})
		game.bridge_editor.update(first,false)
		await process_frame
	root.get_texture().get_image().save_png("res://artifacts/settlement/rope-bridge-main-roofs.png")
	game.free(); print("PASS: captured actual main-game paired landing and automatic bridge hauling"); quit()
