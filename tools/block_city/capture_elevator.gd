extends SceneTree
func _initialize() -> void: call_deferred("run")
func place(game,shape: String,x: int,z: int,y:=0,door: Array=[],normal: Array=[]) -> void:
	game.model.queue[0]={"shape":shape,"color":game.model.turn%5}
	if not door.is_empty(): game.model.queue[0].merge({"door":door,"normal":normal})
	assert(game.model.drop(x,z,0,false,y))
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	for level in 3:
		place(game,"elevator",0,1,level)
		place(game,"cube",0,0,level)
		place(game,"rectangle",1,0,level,[0,0,0],[-1,0,0])
	game.set_holding(false); game.view_mode=1; game.zoom=game.MIN_ZOOM; game.refresh()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/elevator-palette.png")
	game.canvas.hide()
	for node in game.geometry.get_children():
		if not str(node.name).begins_with("Room"): node.hide()
	game.camera.position=Vector3(-4,5,-6)
	game.camera.look_at(Vector3(1,1.3,1.5)); game.camera.size=5.8
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/elevator-shaft.png")
	for node in game.geometry.get_children(): node.visible=str(node.name)=="Room0"
	game.camera.position=Vector3(-1.7,1.8,-2.5)
	game.camera.look_at(Vector3(0.5,0.5,1.5)); game.camera.size=1.9
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/elevator-cabin.png")
	print("CAPTURE elevator-palette, elevator-shaft and elevator-cabin")
	game.free(); quit()
