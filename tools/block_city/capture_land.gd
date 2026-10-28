extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process(false); game.set_process_unhandled_input(false)
	game.model.queue[0]={"shape":"small_square","color":2}
	assert(game.model.drop(0,0,0,false,0))
	game.refresh()
	game.update_land_hover(game.camera.unproject_position(Vector3(-4.5,1,-5.5)))
	assert(game.hovered_plot>=0)
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/land-purchase.png")
	game.purchase_hovered_plot()
	game.model.purchase_plot(3)
	game.model.queue[0]={"shape":"rectangle","color":1}
	assert(game.model.drop(-6,0,0,false,0))
	game.refresh()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/land-expanded.png")
	print("CAPTURE land purchase and construction")
	game.free(); quit()
