extends SceneTree
const Net=preload("res://scripts/block_city/utility_network.gd")
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process(false); game.set_process_unhandled_input(false)
	game.model.queue[0]={"shape":"rectangle","color":2,"door":[0,0,0],"normal":[0,0,-1]}
	assert(game.model.drop(0,0,0,false,0))
	game.model.queue[0]={"shape":"bar","color":1}
	assert(game.model.drop(0,0,0,false,1))
	game.model.connect_power(Vector3i.ZERO,Vector3i.FORWARD)
	var graph:=Net.graph(game.model,0,100,false)
	var a:=Net.node(Vector3i.ZERO,Vector3i.FORWARD,"wall")
	var b:=Net.node(Vector3i(1,0,0),Vector3i.RIGHT,"wall")
	var c:=Net.node(Vector3i(0,1,0),Vector3i.FORWARD,"wall")
	assert(Net.add(game.model,"power",Net.route(graph,a,c)))
	assert(Net.add(game.model,"pipe",Net.route(graph,a,b)))
	assert(Net.add(game.model,"vent",Net.route(graph,b,Net.node(Vector3i(1,0,2),Vector3i.RIGHT,"wall"))))
	game.refresh()
	for i in 120:
		game.poll_analysis(); game.flush_room_redraws()
		if game.analysis_thread==null and game.analysis_pending.is_empty(): break
		await process_frame
	game.camera.position=Vector3(6,5,-7); game.camera.look_at(Vector3(1.2,1,1)); game.camera.size=6
	for neighbor in game.neighbours: neighbor.node.hide()
	game.select_utility("pipe")
	game.utility_hover=Net.node(Vector3i(1,0,1),Vector3i.RIGHT,"wall"); game.overlay.queue_redraw()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/utility-brushes.png")
	game.select_debug_shape("room_domino"); game.select_floor(0); game.anchor=Vector2i(0,1); game.refresh_preview()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/xray-room-preview.png")
	print("CAPTURE utilities and x-ray construction preview")
	game.free(); quit()
