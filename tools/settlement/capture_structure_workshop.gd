extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	workshop.scene_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workshop.load_example()
	for frame in 12:
		await process_frame
	workshop.hover_mesh.visible = false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/structure-workshop.png")
	var Shape = preload("res://scripts/settlement/structure_blueprint.gd")
	var file := FileAccess.open("res://data/structures/stacking-example.pyrstructure", FileAccess.WRITE)
	file.store_string(JSON.stringify(Shape.document(workshop.draft, workshop.instances, workshop.workspace_state()), "\t"))
	file.close()
	workshop.right_tabs.current_tab = 2
	for frame in 4:
		await process_frame
	workshop.hover_mesh.visible = false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/structure-workshop-work.png")
	workshop.set_mode(0)
	workshop.draft = Shape.preset(4)
	workshop.edit_level = -1
	workshop._refresh()
	workshop.fit_view()
	for frame in 12:
		await process_frame
	workshop.hover_mesh.visible = false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/structure-workshop-cellar.png")
	workshop.draft = Shape.preset(0)
	workshop.manual_level = false
	workshop.edit_level = 0
	workshop._refresh()
	workshop.fit_view()
	workshop._pick(workshop.camera.unproject_position(Vector3(0, 1, 0)))
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/structure-workshop-roof.png")
	workshop.free()
	print("PASS: rendered structure workshop and underground authoring view")
	quit()
