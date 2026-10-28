extends SceneTree
## Render the actual 3D worker animation in eight camera-relative directions.
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const Worker = preload("res://scripts/settlement/worker_view.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var joint_preview := OS.get_cmdline_user_args().has("joints")
	var frame_folder := "/tmp/pyramida-joint-frames" if joint_preview else "/tmp/pyramida-walk-frames"
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
	camera.size = 4.0 if joint_preview else 5.6
	scene.add_child(camera)
	camera.position = Vector3(0, 3, 8)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var ui := CanvasLayer.new()
	root.add_child(ui)
	caption(ui, "PYRAMIDA / ELBOWS + KNEES" if joint_preview else "PYRAMIDA / EIGHT-DIRECTION WALK", Vector2(40, 26), 26)
	var actors: Array = []
	for index in (3 if joint_preview else 8):
		var anchor := Node3D.new()
		scene.add_child(anchor)
		var actor := Worker.new()
		anchor.add_child(actor)
		actor.setup(1)
		var centre := camera.global_basis.x * ((index % 4 - 1.5) * 1.75) + camera.global_basis.y * (0.3 - floori(index / 4.0) * 2.05)
		if joint_preview:
			centre = camera.global_basis.x * ((index - 1) * 1.8) - camera.global_basis.y * 0.5
		var back := camera.global_basis.z
		back.y = 0
		var direction := back.normalized().rotated(Vector3.UP, index * PI / 4.0)
		var citizen := {"position": Vector3.ZERO, "cargo": "", "status": "walking", "appearance": 0 if joint_preview else index % 4, "cloth_color": index % 5}
		actor.sync(citizen, 0.0, false, camera)
		anchor.position = centre - actor.position
		actors.append({"actor": actor, "citizen": citizen, "direction": direction, "centre": centre})
		var point := camera.unproject_position(centre)
		caption(ui, ["FRONT", "FRONT / RIGHT", "RIGHT", "BACK / RIGHT", "BACK", "BACK / LEFT", "LEFT", "FRONT / LEFT"][index], point + Vector2(-65, 20), 14)
	DirAccess.make_dir_recursive_absolute(frame_folder)
	for frame in 96:
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
				image.save_png("res://artifacts/citizen-joints.png" if joint_preview else "res://artifacts/citizen-walk.png")
	print("PASS: rendered 32 frames of eight-direction citizen walking")
	quit()

func caption(ui: Node, text_: String, position_: Vector2, size_: int) -> void:
	var label := Label.new()
	label.text = text_
	label.position = position_
	label.add_theme_color_override("font_color", Color("4b4037"))
	label.add_theme_font_size_override("font_size", size_)
	ui.add_child(label)
