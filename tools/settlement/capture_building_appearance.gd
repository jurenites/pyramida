extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	workshop.pieces.activate()
	for kind in ["well", "stairs", "stockpile", "platform"]:
		workshop.pieces.open_building(kind)
		workshop.pieces.leave()
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pyramida-blueprint-%s.png" % kind)
	workshop.free()
	print("PASS: rendered standard building editor")
	quit()
