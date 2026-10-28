extends SceneTree
const Land=preload("res://scripts/block_city/land.gd")
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.model.queue[0]={"shape":"small_square","color":0}
	assert(game.model.drop(0,0,0,false,0))
	game.elevation=0.55; game.orbit=-2.4; game.orbit_target=game.orbit
	game.refresh()
	game.set_process(false); game.set_process_unhandled_input(false)
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/floating-city-block.png")
	game.hovered_plot=Land.at(game.model.config,Vector2(3.5,1.5),game.model.owned_plots)
	game.purchase_button.show(); game.update_land_hover(game.purchase_button.position+game.purchase_button.size*0.5)
	game.overlay.queue_redraw()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/sidewalk-purchase.png")
	game.purchase_hovered_plot()
	assert(game.model.owns_cell(Vector3i(3,0,1)))
	game.model.queue[0]={"shape":"cube","color":0}; assert(game.model.drop(3,1,0,false,0)); game.refresh()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/sidewalk-infill.png")
	print("CAPTURE floating city and sidewalk purchase")
	game.free(); quit()
