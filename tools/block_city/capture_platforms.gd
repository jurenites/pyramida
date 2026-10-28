extends SceneTree
func _initialize() -> void: call_deferred("run")
func place(game,shape: String,x: int,z: int,yaw:=0,y:=-100) -> void:
	game.model.queue[0]={"shape":shape,"color":game.model.turn%5}
	assert(game.model.drop(x,z,yaw,false,y))
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	place(game,"rectangle",0,0); place(game,"rectangle",0,0)
	place(game,"domino",-1,1,0,1)
	place(game,"room_domino",-1,1,0,2)
	game.set_holding(false); game.view_mode=1; game.zoom=game.MIN_ZOOM; game.refresh()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/platform-palette.png")
	game.canvas.hide()
	for node in game.geometry.get_children():
		if not str(node.name).begins_with("Room"): node.hide()
	game.camera.position=Vector3(-5,3.5,-4)
	game.camera.look_at(Vector3(0.4,1.3,1.5)); game.camera.size=5.3
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/side-platform.png")
	print("CAPTURE side-platform and platform-palette")
	game.free(); quit()
