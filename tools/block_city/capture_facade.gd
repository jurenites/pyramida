extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	for y in 3:
		game.model.queue[0]={"shape":"rectangle","color":0,"door":[0,0,0] if y==0 else [1,0,1],"normal":[0,0,-1] if y==0 else [1,0,0]}
		assert(game.model.drop(0,0,0,false,y))
	game.set_holding(false); game.view_mode=0; game.refresh()
	game.camera.position=Vector3(-6,5,-8)
	game.camera.look_at(Vector3(1,1.3,1.5)); game.camera.size=5.6
	for neighbour in game.neighbours: neighbour.node.hide()
	for child in game.canvas.get_children(): child.hide()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/facade-base-body-crown.png")
	for neighbour in game.neighbours: neighbour.node.show()
	game.update_camera()
	for i in 4: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/facade-neighborhood.png")
	print("CAPTURE base, body and crown facades")
	game.free(); quit()
