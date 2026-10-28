extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 1000)
	var sandbox = load("res://scripts/settlement/building_layout_sandbox.gd").new()
	sandbox.restore_last = false
	sandbox.auto_save = false
	root.add_child(sandbox)
	sandbox.save_timer = 0
	for frame in 15: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/building-layout-sandbox.png")
	print("PASS: full-scale layout capture")
	sandbox.free()
	quit()
