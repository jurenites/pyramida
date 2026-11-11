extends SceneTree
const Character = preload("res://data/settlement/reference_man.tscn")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1400, 850)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("75849c")
	viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 5.4
	viewport.add_child(camera)
	camera.position = Vector3(0, 2.0, 8)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var actors: Array = []
	var ui := CanvasLayer.new()
	viewport.add_child(ui)
	caption(ui, "MALE REFERENCE STUDY", Vector2(45, 24), 24)
	caption(ui, "STANDING", Vector2(45, 75), 16)
	caption(ui, "WALKING / SLOW MOTION", Vector2(45, 450), 16)
	for row in 2:
		for column in 4:
			var anchor := Node3D.new()
			viewport.add_child(anchor)
			anchor.position = camera.basis.x * ((column - 1.5) * 1.25) + camera.basis.y * (0.10 if row == 0 else -1.32)
			var actor := Character.instantiate()
			anchor.add_child(actor)
			actor.rotation.y = [PI, PI * 0.75, PI * 0.5, 0.0][column]
			actor.pose(0.74, row == 1)
			actors.append(actor)
			if row == 0: caption(ui, ["FRONT", "THREE-QUARTER", "SIDE", "BACK"][column], Vector2(155 + column * 324, 415), 15)
	DirAccess.make_dir_recursive_absolute("/tmp/pyramida-reference-man/frames")
	for frame in 120:
		for index in actors.size(): actors[index].pose(float(frame) / 60.0, index >= 4, 0.9 / 60.0)
		await process_frame
		RenderingServer.force_draw()
		var image := viewport.get_texture().get_image()
		if frame < 60: continue
		assert(image.save_png("/tmp/pyramida-reference-man/frames/%02d.png" % (frame - 60)) == OK)
		if frame == 104: image.save_png("res://artifacts/settlement/reference-man-study.png")
	print("PASS: captured male standing and walking from four angles")
	quit()
func caption(parent: Node, text_: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text_; label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e9e3cf"))
	parent.add_child(label)
