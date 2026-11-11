extends SceneTree
## Adult front/rear walking and child running, for comparison with the supplied movie.
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const Worker = preload("res://scripts/settlement/worker_view.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var frame_folder := "/tmp/pyramida-reference-walk-frames"
	root.size = Vector2i(1100, 740)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
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
	scene.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	scene.add_child(camera)
	camera.position = Vector3(0, 3, 8)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var ui := CanvasLayer.new()
	root.add_child(ui)
	caption(ui, "PYRAMIDA / WALK + RUN STUDY", Vector2(40, 26), 26)
	var actors: Array = []
	for index in 3:
		var anchor := Node3D.new()
		scene.add_child(anchor)
		var actor := Worker.new()
		anchor.add_child(actor)
		actor.setup(1)
		var centre := camera.global_basis.x * ((index - 1) * 1.8) - camera.global_basis.y * 0.5
		var back := camera.global_basis.z
		back.y = 0
		var direction := back.normalized().rotated(Vector3.UP, [PI / 4.0, PI, -PI / 2.0][index])
		var citizen := {"position": Vector3.ZERO, "cargo": "", "status": "walking", "appearance": 3 if index == 0 else 0, "cloth_color": index % 5, "life_stage": "child" if index == 2 else "adult"}
		actor.sync(citizen, 0.0, false, camera)
		anchor.position = centre - actor.position
		actors.append({"actor": actor, "citizen": citizen, "direction": direction, "centre": centre})
		var point := camera.unproject_position(centre)
		caption(ui, ["ADULT / WALK", "ADULT / REAR", "CHILD / RUN"][index], point + Vector2(-65, 20), 14)
	DirAccess.make_dir_recursive_absolute(frame_folder)
	for frame in 124:
		for entry in actors:
			entry.citizen.position += entry.direction * (2.25 / 30.0)
			entry.actor.sync(entry.citizen, 1.0 / 30.0, false, camera)
			# Follow each walker independently to present the gait in place.
			entry.actor.get_parent().position = entry.centre - entry.actor.position
		await process_frame
		await RenderingServer.frame_post_draw
		if frame >= 64:
			var image := root.get_texture().get_image()
			image.save_png(frame_folder + "/%02d.png" % (frame - 64))
			if frame == 70:
				image.save_png("res://artifacts/citizen-reference-walk.png")
	print("PASS: rendered 60 frames of adult walking and child running")
	quit()

func caption(ui: Node, text_: String, position_: Vector2, size_: int) -> void:
	var label := Label.new()
	label.text = text_
	label.position = position_
	label.add_theme_color_override("font_color", Color("4b4037"))
	label.add_theme_font_size_override("font_size", size_)
	ui.add_child(label)
