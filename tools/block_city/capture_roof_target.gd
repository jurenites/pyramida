extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	for item in [["rectangle",0,0,0],["bar",0,0,1],["bar",0,0,2]]:
		game.model.queue[0]={"shape":item[0],"color":0}
		assert(game.model.drop(item[1],item[2],0,false,item[3]))
	game.select_debug_shape("room_domino"); game.yaw=0; game.view_mode=0; game.refresh()
	game.camera.position=Vector3(7,8,6)
	game.camera.look_at(Vector3(1,1,1.5)); game.camera.size=7
	game.position_anchor(game.camera.unproject_position(Vector3(0.5,2.99,0.5)))
	game.position_anchor(game.camera.unproject_position(Vector3(1.5,0.99,1.5)))
	assert(game.preview.ok and game.preview.origin==Vector3i(1,1,1))
	game.overlay.queue_redraw()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/lower-roof-target.png")
	print("CAPTURE lower-roof-target")
	game.free(); quit()
