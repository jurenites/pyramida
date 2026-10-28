extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	workshop.load_example()
	workshop.place_copy()
	workshop.selected_instance = 1
	workshop.rng.seed = 783
	workshop.upgrade("ac")
	workshop.upgrade("dish")
	workshop.instances[0].ladders.append({"cell": Vector3i(0, 0, 1), "side": Vector3i.BACK})
	workshop.brush = 3
	workshop._refresh()
	workshop.fit_view()
	workshop.zoom = 6.5
	workshop._camera_update()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/blueprint-map.png")
	workshop.free()
	print("PASS: blueprint map capture")
	quit()
