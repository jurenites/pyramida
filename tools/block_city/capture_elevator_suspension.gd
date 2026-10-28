extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	for y in 3:
		game.model.queue[0]={"shape":"elevator","color":0}
		assert(game.model.drop(1,1,0,false,y))
	game.set_holding(false); game.view_mode=2; game.refresh()
	game.camera.position=Vector3(-2,4,-5)
	game.camera.look_at(Vector3(1.5,1.3,1.5)); game.camera.size=4.1
	for neighbour in game.neighbours: neighbour.node.hide()
	for child in game.canvas.get_children(): child.hide()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/elevator-suspension.png")
	print("CAPTURE elevator suspension and counterweight")
	game.free(); quit()
