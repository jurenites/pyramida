extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.model.queue[0]={"shape":"rectangle","color":2,"door":[0,0,0],"normal":[0,0,-1]}
	assert(game.model.drop(0,0,0,false,0))
	game.model.queue[0]={"shape":"bar","color":1,"door":[0,0,0],"normal":[1,0,0]}
	assert(game.model.drop(2,0,0,false,0))
	assert(game.model.connect_power(Vector3i.ZERO,Vector3i.FORWARD))
	game.refresh()
	for i in 180:
		await process_frame
		if game.analysis_thread==null and game.analysis_pending.is_empty() and game.room_redraw_queue.is_empty(): break
	game.set_process(false); game.set_process_unhandled_input(false)
	for mode in [0,1,2]:
		game.view_mode=mode; game.view_button.mode=mode; game.view_button.queue_redraw(); game.refresh()
		game.camera.position=Vector3(6,6,-8); game.camera.look_at(Vector3(1.5,0.45,1.5)); game.camera.size=5.6
		for neighbor in game.neighbours: neighbor.node.hide()
		for i in 8: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/block_city/concrete-lighting-%d.png" % mode)
	print("CAPTURE concrete, warm windows and cutaway lighting")
	game.free(); quit()
