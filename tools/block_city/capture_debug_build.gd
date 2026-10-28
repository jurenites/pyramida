extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_process_unhandled_input(false)
	game.model.queue[0]={"shape":"bar","color":0}
	assert(game.model.drop(0,0))
	game.select_debug_shape("bar")
	game.yaw=1; game.snap_y=1; game.anchor=Vector2i.ZERO
	game.zoom=game.MIN_ZOOM; game.refresh()
	root.min_size=Vector2i.ZERO
	for dimensions in [Vector2i(1100,760),Vector2i(800,600)]:
		root.size=dimensions
		for i in 8: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/block_city/debug-build-%d.png" % dimensions.x)
		print("CAPTURE debug-build-",dimensions.x)
	game.free(); quit()
