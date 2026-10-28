extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 1000)
	Assets.Appearance.directory = "/tmp/pyramida-variation-no-overrides"
	var output := SubViewport.new()
	output.size = Vector2i(1600, 1000)
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var background := ColorRect.new()
	background.color = Color("fff1cf")
	background.size = Vector2(1600, 1000)
	output.add_child(background)
	for column in 2:
		var panel := SubViewportContainer.new()
		panel.position = Vector2(column * 800, 60)
		panel.size = Vector2(800, 940)
		output.add_child(panel)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(800, 940)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		panel.add_child(viewport)
		var scene := Node3D.new()
		viewport.add_child(scene)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("fff1cf")
		scene.add_child(environment)
		for index in 2:
			var house := Assets.create("house")
			house.position = Vector3(index * 3 - 1.5, 0, -4)
			scene.add_child(house)
			if column == 1: Assets.Variation.apply(house, "house", Vector3i(index * 6, 0, -8), 9182)
		for index in 3:
			var road := Assets.create("road")
			road.position = Vector3(index * 2 - 2, 0, 0)
			scene.add_child(road)
			if column == 1: Assets.Variation.apply(road, "road", Vector3i(index * 4, 0, 0), 9182)
		var walkway := Node3D.new()
		walkway.position = Vector3(0, 0, 3)
		scene.add_child(walkway)
		for index in 22:
			var source := Assets.create("plank")
			var board := source.get_node("Plank0") as MeshInstance3D
			source.remove_child(board)
			source.free()
			board.name = "Board%02d" % index
			board.rotation.y = PI * 0.5
			board.position = Vector3((index - 10.5) * 0.29, 0.04, 0)
			walkway.add_child(board)
		if column == 1: Assets.Variation.apply(walkway, "road", Vector3i(0, 0, 6), 9182)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 10.8
		camera.position = Vector3(8, 11, 15)
		scene.add_child(camera)
		camera.look_at(Vector3(0, 0.3, -0.5))
		var title := Label.new()
		title.text = "Authored geometry" if column == 0 else "Placed variation · up to ±0.1 m"
		title.position = Vector2(column * 800 + 30, 15)
		title.add_theme_font_size_override("font_size", 26)
		title.add_theme_color_override("font_color", Color("80503d"))
		output.add_child(title)
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var error := output.get_texture().get_image().save_png("res://artifacts/building-variation.png")
	print("PASS: captured building variation" if error == OK else "FAIL: capture")
	quit(int(error != OK))
