extends SceneTree
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const Worker = preload("res://scripts/settlement/worker_view.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1400, 760)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(container)
	var viewport := SubViewport.new()
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Illustration.configure(container, viewport)
	container.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("eee3cc")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 0.8
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.6
	scene.add_child(camera)
	camera.position = Vector3(0, 2.4, 8)
	camera.look_at(Vector3(0, 0.6, 0))
	camera.current = true
	var ui := CanvasLayer.new()
	root.add_child(ui)
	caption(ui, "PYRAMIDA / CITIZENS", Vector2(48, 35), 32)
	caption(ui, "Featureless faces / flat colour shapes / fine irregular edges", Vector2(48, 85), 20)
	for index in 5:
		var worker := Worker.new()
		scene.add_child(worker)
		worker.setup(index)
		var position_ := Vector3((index - 2) * 1.22, 0, 0)
		worker.previous_position = position_
		worker.sync({"position": position_,
			"cargo": "", "status": "idle", "appearance": index % 4, "cloth_color": index % 5,
			"life_stage": "child" if index == 4 else "adult"}, 0, false)
		worker.position = position_
		worker.body.rotation.y = PI + 0.25
		var point := camera.unproject_position(Vector3((index - 2) * 1.22, 0, 0))
		caption(ui, ["SHORTS", "DRESS", "ONE SHOULDER", "TOP + SKIRT", "CHILD / NPC"][index], Vector2(point.x - 85, 520), 14)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/citizen-illustration.png")
	print("PASS: citizen family render" if error == OK else "FAIL: citizen capture")
	quit(int(error != OK))

func caption(ui: Node, text_: String, position_: Vector2, size_: int) -> void:
	var label := Label.new()
	label.text = text_
	if size_ == 14:
		label.custom_minimum_size.x = 170
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = position_
	label.add_theme_color_override("font_color", Color("4b4037"))
	label.add_theme_font_size_override("font_size", size_)
	ui.add_child(label)
