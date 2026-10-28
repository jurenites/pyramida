extends SceneTree
func _initialize() -> void: call_deferred("run")
func place(game,shape: String,x: int,z: int,y: int,color: int,door: Array,normal: Array) -> void:
	game.model.queue[0]={"shape":shape,"color":color,"door":door,"normal":normal}
	assert(game.model.drop(x,z,0,false,y))
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	for level in 3:
		place(game,"small_square",0,0,level,level,[0,0,0],[0,0,-1])
		place(game,"room_domino",2,0,level,4,[0,0,1],[-1,0,0])
		place(game,"elevator",0,2,level,0,[0,0,0],[0,0,-1])
	game.set_holding(false); game.view_mode=1; game.zoom=game.MIN_ZOOM; game.refresh()
	game.camera.position=Vector3(-6,6,-8)
	game.camera.look_at(Vector3(1.5,1.3,1.5)); game.camera.size=6.4
	game.begin_move(7,game.camera.unproject_position(Vector3(2.4,2.99,0.4)))
	game.position_route_cost()
	for node in game.geometry.get_children():
		if not str(node.name).begins_with("Room"): node.hide()
	for child in game.canvas.get_children():
		if child!=game.overlay and child!=game.route_cost: child.hide()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/room-routes.png")
	print("CAPTURE room-routes cost ",game.selected_route.get("cost",-1))
	game.free(); quit()
