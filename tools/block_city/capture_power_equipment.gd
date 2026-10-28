extends SceneTree
const Cable=preload("res://scripts/block_city/cable.gd")
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	for item in [["small_pole",0,2],["cube",1,0],["cube",2,1]]:
		game.model.queue[0]={"shape":item[0],"color":0}
		assert(game.model.drop(item[1],item[2],0,false,0))
	assert(game.model.connect_power(Vector3i(0,0,2),Vector3i.FORWARD,game.model.transformer_source(0),0))
	assert(game.model.connect_power(Vector3i(1,0,0),Vector3i.BACK,{"device":"pole","cell":[0,0,2],"normal":[0,0,-1],"slot":1},0))
	assert(game.model.connect_power(Vector3i(2,0,1),Vector3i.BACK,{"device":"pole","cell":[0,0,2],"normal":[0,0,-1],"slot":2},1))
	game.refresh()
	for i in 120:
		await process_frame
		if game.analysis_thread==null and game.analysis_pending.is_empty() and game.room_redraw_queue.is_empty(): break
	game.set_process(false); game.set_process_unhandled_input(false)
	game.view_mode=1; game.refresh()
	game.camera.position=Vector3(-6,6,-7); game.camera.look_at(Vector3(0.7,1.6,0.7)); game.camera.size=7
	for n in game.neighbours: n.node.hide()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/power-equipment.png")
	print("CAPTURE starter transformer and small pole")
	game.free(); quit()
