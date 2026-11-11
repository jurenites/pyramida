extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,800)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	game.model.defer_analysis=false
	for x in 3:
		for z in 3:
			if z==2 or (x==2 and z==0): continue
			var shape: String="stairs" if x==0 and z==1 else ("stairs_quarter" if x==1 and z==1 else "cube")
			game.model.queue[0]={"shape":shape,"color":0}
			assert(game.model.drop(x,z,0,false,0))
	game.model.queue[0]={"shape":"room_domino","color":0,"cells":[[0,0,0],[1,0,0]],"door":[0,0,0],"normal":[0,0,1]}
	assert(game.model.drop(0,0,0,false,1))
	game.set_holding(false)
	game.set_process(false)
	for mode in [2,0]:
		game.view_mode=mode; game.refresh()
		for i in 20: await process_frame
		game.camera.position=Vector3(4,6,6)
		game.camera.look_at(Vector3(1.35,0.65,1.3)); game.camera.size=4.9
		for neighbour in game.neighbours: neighbour.node.hide()
		for child in game.canvas.get_children(): child.hide()
		for i in 3: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/block_city/stair-prefabs-%s.png" % ("cutaway" if mode==2 else "roofed"))
	print("CAPTURE both stair prefabs, room connection and roof connection")
	game.free(); quit()
