extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	for i in 12: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/"+name+".png")
func run() -> void:
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_process_unhandled_input(false)
	game.model.queue[0]={"shape":"rectangle","color":0}
	game.model.drop(0,0)
	game.model.queue[0]={"shape":"domino","color":3}
	game.yaw=1; game.anchor=Vector2i(0,1); game.snap_y=0; game.carve_hall=true
	game.zoom=game.MIN_ZOOM
	game.refresh()
	await capture("hall-cut-preview")
	game.drop()
	game.set_holding(false)
	game.view_mode=1; game.refresh()
	await capture("hall-cut-interior")
	game.free()
	quit()
