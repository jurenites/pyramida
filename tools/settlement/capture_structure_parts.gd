extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Kit = preload("res://scripts/settlement/structure_parts.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	workshop.draft.name = "Log cabin"
	workshop.pieces.parts = Kit.cabin()
	workshop.pieces.activate()
	for frame in 12: await process_frame
	workshop.pieces.leave()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pyramida-blueprint-pieces.png")
	workshop.free()
	print("PASS: rendered individual log, plank and hay construction")
	quit()
