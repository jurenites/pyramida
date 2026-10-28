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
	place(game,"cube",0,0)
	place(game,"cube",1,0)
	place(game,"cube",1,0)
	place(game,"small_square",1,1)
	place(game,"small_square",1,1)
	game.zoom=game.MIN_ZOOM
	game.ghost.hide(); game.overlay.hide()
	for mode in 3:
		game.view_mode=mode; game.view_button.mode=mode; game.view_button.queue_redraw()
		game.refresh()
		for i in 8: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/block_city/interiors-%d.png" % mode)
		print("CAPTURE interiors-",mode)
	game.free()
	quit()
