extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_process_unhandled_input(false)
	game.zoom=game.MIN_ZOOM
	for rotation in [0,2]:
		game.yaw=rotation; game.anchor=Vector2i.ZERO
		game.refresh()
		for i in 12: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/block_city/entrance-%s.png" % ["green" if rotation==0 else "yellow"])
	game.free()
	quit()
