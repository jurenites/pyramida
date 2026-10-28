extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.model.queue[0]={"shape":"small_pole","color":0}
	assert(game.model.drop(1,2,0,false,0))
	assert(game.model.move_transformer(Vector3i(-1,0,1)))
	for slot in 3: assert(game.model.connect_power(Vector3i(1,0,2),Vector3i.FORWARD,game.model.transformer_source(slot),slot))
	game.set_holding(false); game.refresh(); game.set_process(false); game.set_process_unhandled_input(false)
	game.camera.position=Vector3(-6,5,-7); game.camera.look_at(Vector3(0.7,1.3,1.4)); game.camera.size=6
	for neighbor in game.neighbours: neighbor.node.hide()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/parallel-transformer.png")
	game.selection_kind="transformer"; game.editor_action("move")
	game.anchor=Vector2i(0,-1); game.snap_y=0; game.refresh_preview()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/moving-transformer.png")
	print("CAPTURE parallel feeds and transformer movement")
	game.free(); quit()
