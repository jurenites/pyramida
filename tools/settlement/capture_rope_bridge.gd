extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1500, 1000)
	var demo = preload("res://scripts/settlement/rope_bridge_demo.gd").new(); root.add_child(demo); demo.running = false
	var found := false
	for step in 10000:
		demo.model.tick(0.05)
		var worker: Dictionary = demo.model.workers[0]
		if worker.cargo == "log" and worker.position.x > 1.0 and worker.position.x < 2.5: found = true; break
	assert(found, "A citizen must really carry a log across the completed bridge")
	demo.refresh()
	for frame in 20: await process_frame
	root.get_texture().get_image().save_png("res://artifacts/settlement/rope-bridge-prototype.png")
	print("PASS: captured actual bridge hauling")
	quit()
