extends SceneTree
const Character = preload("res://data/settlement/reference_man.tscn")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var canvas := SubViewport.new()
	canvas.size = Vector2i(1400, 730)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("eee3cc"); background.size = Vector2(1400, 730)
	canvas.add_child(background)
	var entries := []
	for index in 2:
		var holder := SubViewportContainer.new()
		holder.position = Vector2(index * 700, 105)
		holder.size = Vector2(700, 570)
		canvas.add_child(holder)
		var view := SubViewport.new()
		view.size = Vector2i(700, 570); view.own_world_3d = true
		view.msaa_3d = Viewport.MSAA_4X
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		holder.add_child(view)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("eee3cc")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.8
		view.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-65, -25, 0)
		light.light_energy = 0.6; light.shadow_enabled = true
		light.shadow_bias = 0.05
		light.shadow_normal_bias = 0.05
		light.directional_shadow_max_distance = 12.0
		view.add_child(light)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new(); plane.size = Vector2(20, 20)
		ground.mesh = plane
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var paint := StandardMaterial3D.new(); paint.albedo_color = Color("e6dcc5")
		paint.roughness = 1
		ground.material_override = paint
		view.add_child(ground)
		var lines := SurfaceTool.new(); lines.begin(Mesh.PRIMITIVE_LINES)
		var line_paint := StandardMaterial3D.new()
		line_paint.albedo_color = Color("c7bda7")
		line_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lines.set_material(line_paint)
		for mark in range(-30, 31):
			var at := mark / 3.0
			lines.add_vertex(Vector3(-10, 0.001, at)); lines.add_vertex(Vector3(10, 0.001, at))
			lines.add_vertex(Vector3(at, 0.001, -10)); lines.add_vertex(Vector3(at, 0.001, 10))
		var grid := MeshInstance3D.new(); grid.mesh = lines.commit(); view.add_child(grid)
		grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var traveller := Node3D.new(); view.add_child(traveller)
		var actor := Character.instantiate(); traveller.add_child(actor)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.65
		view.add_child(camera)
		var offset := Vector3(-2.7, 1.55, -4.6) if index == 0 else Vector3(4.6, 1.3, 0)
		entries.append({"traveller": traveller, "actor": actor, "camera": camera, "offset": offset})
	caption(canvas, "GROUNDED WALK / NORMAL SPEED", Vector2(42, 25), 25)
	caption(canvas, "Small steps, planted support, spring motion in shoulders and head", Vector2(42, 65), 18)
	caption(canvas, "THREE-QUARTER", Vector2(260, 688), 16)
	caption(canvas, "SIDE", Vector2(1030, 688), 16)
	DirAccess.make_dir_recursive_absolute("/tmp/pyramida-grounded-walk")
	for frame in 108:
		var cycle := frame / 27.0
		for entry in entries:
			entry.actor.pose(cycle, true, 1.0 / 30.0)
			entry.traveller.position.z = -cycle * entry.actor.Gait.stride_length
			entry.camera.position = entry.traveller.position + entry.offset
			entry.camera.look_at(entry.traveller.position + Vector3(0, 0.50, 0))
		await process_frame
		RenderingServer.force_draw()
		if frame < 54: continue
		var image := canvas.get_texture().get_image()
		image.save_png("/tmp/pyramida-grounded-walk/%02d.png" % (frame - 54))
		if frame == 62: image.save_png("res://artifacts/settlement/reference-man-grounded.png")
	print("PASS: captured normal-speed walking over fixed world grid")
	quit()
func caption(parent: Node, text_: String, at: Vector2, size_: int) -> void:
	var label := Label.new(); label.text = text_; label.position = at
	label.add_theme_font_size_override("font_size", size_)
	label.add_theme_color_override("font_color", Color("4b4037"))
	parent.add_child(label)
