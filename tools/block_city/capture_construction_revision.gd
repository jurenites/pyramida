extends SceneTree
func _initialize() -> void: call_deferred("run")
func place(game, shape: String, x: int, z: int) -> void:
	game.model.queue[0]={"shape":shape,"color":game.model.turn%5}
	assert(game.model.drop(x,z))
func run() -> void:
	root.size=Vector2i(1440,900)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_process_unhandled_input(false)
	place(game,"stairs",0,0)
	place(game,"stairs",0,0)
	place(game,"cube",1,0)
	place(game,"cube",1,0)
	place(game,"small_square",1,1)
	place(game,"small_square",1,1)
	game.set_holding(false)
	game.zoom=game.MIN_ZOOM
	for mode in [0,2]:
		game.view_mode=mode; game.view_button.mode=mode; game.view_button.queue_redraw()
		game.refresh()
		for i in 8: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/block_city/construction-revision-%d.png" % mode)
		print("CAPTURE construction-revision-",mode)
	# Close view of the connected shaft without exploding or moving storeys.
	game.view_mode=2; game.refresh()
	game.canvas.hide()
	for node in game.geometry.get_children():
		if not str(node.name).begins_with("Room"): node.hide()
	game.camera.position=Vector3(-3,2.8,-4)
	game.camera.look_at(Vector3(0.5,1.0,0.5))
	game.camera.size=3.4
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/stair-passage.png")
	game.free()
	quit()
