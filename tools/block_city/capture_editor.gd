extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	for y in 2:
		for x in 2:
			game.model.queue[0]={"shape":"room_domino" if x==0 else "domino","color":2}
			assert(game.model.drop(x,0,0,false,y))
	game.refresh()
	game.select_hit(2); game.select_hit(2); game.group_selection()
	game.camera.position=Vector3(-4,4.5,-5)
	game.camera.look_at(Vector3(1,1.2,1)); game.camera.size=6
	for neighbour in game.neighbours: neighbour.node.hide()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/editor-group.png")
	game.editor_action("copy")
	assert(game.preview.ok)
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/editor-copy-floor.png")
	print("CAPTURE hierarchical editor and floor copy")
	game.free(); quit()
