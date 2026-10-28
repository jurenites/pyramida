extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	for y in 2:
		game.model.queue[0]={"shape":"small_square","color":2}
		assert(game.model.drop(0,0,0,false,y))
	assert(game.model.connect_power(Vector3i.ZERO,Vector3i.FORWARD,{},0))
	var source: Dictionary={"cell":[0,0,0],"normal":[0,0,-1],"slot":0}
	assert(game.model.connect_power(Vector3i(0,1,0),Vector3i.LEFT,source,1))
	game.set_holding(false); game.view_mode=0; game.refresh()
	game.camera.position=Vector3(-6,3.5,-2)
	game.camera.look_at(Vector3(0.65,1.55,0.65)); game.camera.size=5.5
	for neighbour in game.neighbours: neighbour.node.hide()
	for child in game.canvas.get_children(): child.hide()
	for i in 12: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/wall-power.png")
	print("CAPTURE wall power")
	game.free(); quit()
