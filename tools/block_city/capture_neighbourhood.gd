extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,850)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	game.model.queue[0]={"shape":"small_square","color":0}
	assert(game.model.drop(0,0,0,false,0))
	game.set_holding(false); game.refresh()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/neighbourhood-paths.png")
	game.camera.position=Vector3(-11,7,1)
	game.camera.look_at(Vector3(-4.5,1.5,1)); game.camera.size=5.5
	for neighbour in game.neighbours:
		for mesh in neighbour.node.get_children(): mesh.transparency=0
	for child in game.canvas.get_children(): child.hide()
	for i in 3: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/neighbour-windows.png")
	print("CAPTURE neighborhood paths and windows")
	game.free(); quit()
