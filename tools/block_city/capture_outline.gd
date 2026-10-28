extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	game.select_debug_shape("rectangle")
	game.anchor=Vector2i.ZERO; game.yaw=0; game.refresh()
	game.geometry.hide()
	for child in game.canvas.get_children():
		if child!=game.overlay: child.hide()
	game.underground=true # Hide the pole's overlay in this isolated shape capture.
	game.camera.position=Vector3(-5,5,-7)
	game.camera.look_at(Vector3(1,0.5,1.5)); game.camera.size=5.2
	game.overlay.queue_redraw()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/block_city/room-outline.png")
	print("CAPTURE room-outline")
	game.free(); quit()
