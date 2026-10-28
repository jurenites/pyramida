extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_process_unhandled_input(false)
	root.min_size=Vector2i.ZERO
	for dimensions in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size=Vector2i(Vector2(dimensions)*root.content_scale_factor)
		for i in 12: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/block_city/resize-%dx%d.png" % [dimensions.x,dimensions.y])
		print("CAPTURE ",game.get_viewport().get_visible_rect().size)
	game.free()
	quit()
