extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	for y in 3:
		for x in 3:
			game.model.queue[0]={"shape":"domino","color":0}
			assert(game.model.drop(x,0,0,false,y))
	game.model.queue[0]={"shape":"room_domino","color":0}
	assert(game.model.drop(0,0,1,false,0))
	game.view_mode=1; game.select_utility("pipe"); game.select_floor(0); game.refresh()
	var net=game.Utilities
	var center: Dictionary=net.node(Vector3i(1,0,0),Vector3i.FORWARD,"wall")
	assert(net.add(game.model,"pipe",[center,net.node(Vector3i(0,0,0),Vector3i.FORWARD,"wall")]))
	assert(net.add(game.model,"pipe",[center,net.node(Vector3i(2,0,0),Vector3i.FORWARD,"wall")]))
	assert(net.add(game.model,"pipe",[center,net.node(Vector3i(1,1,0),Vector3i.FORWARD,"wall")]))
	game.refresh(); game.set_process(false); game.set_process_unhandled_input(false)
	game.camera.position=Vector3(-6,5,-7); game.camera.look_at(Vector3(1.3,0.8,0.9)); game.camera.size=5.6
	for neighbor in game.neighbours: neighbor.node.hide()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/hall-frame-infill.png")
	game.forced_floor=-100; game.refresh(); game.camera.size=4.6
	game.camera.position=Vector3(-5,3,-6); game.camera.look_at(Vector3(1.4,1.4,0.7))
	for neighbor in game.neighbours: neighbor.node.hide()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/pipe-fittings.png")
	game.utility_vent_notes[0].save_to_wav("/tmp/block-city-vent-metal.wav")
	print("CAPTURE hall frame infill and pipe fittings")
	game.free(); quit()
