extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_process_unhandled_input(false)
	for i in 3:
		game.model.queue[0]={"shape":"cube","color":i}
		game.model.drop(0,0)
	game.model.connect_power(Vector3i.ZERO,Vector3i.FORWARD)
	game.model.connect_power(Vector3i(0,1,0),Vector3i.FORWARD,{"cell":[0,0,0],"normal":[0,0,-1]})
	game.set_holding(false)
	game.zoom=game.MIN_ZOOM
	game.refresh()
	for i in 15: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/interaction.png")
	game.free()
	quit()
