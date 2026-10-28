extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game); game.set_process_unhandled_input(false)
	game.model.queue[0]={"shape":"rectangle","color":4}; assert(game.model.drop(1,0))
	game.model.queue[0]={"shape":"domino","color":0}; assert(game.model.drop(0,1))
	game.set_holding(false); game.view_mode=1; game.refresh()
	game.canvas.hide()
	for node in game.geometry.get_children():
		if not str(node.name).begins_with("Room"): node.hide()
	game.camera.position=Vector3(-4,4,-3)
	game.camera.look_at(Vector3(1.5,0.4,1.5)); game.camera.size=4.7
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/entrance-connections.png")
	print("CAPTURE entrance-connections")
	game.free(); quit()
