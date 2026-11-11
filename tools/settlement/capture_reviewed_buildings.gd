extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Reviewed = preload("res://scripts/settlement/reviewed_balance.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var canvas := SubViewport.new(); canvas.size = Vector2i(1500, 1040)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var background := ColorRect.new(); background.color = Color("fef1cf"); background.size = canvas.size; canvas.add_child(background)
	var i := 0
	for row: Dictionary in Reviewed.data.buildings:
		var panel := SubViewportContainer.new(); panel.position = Vector2((i % 5) * 300, (i / 5) * 260); panel.size = Vector2(300, 210); canvas.add_child(panel)
		var view := SubViewport.new(); view.size = Vector2i(300, 210); view.own_world_3d = true; view.transparent_bg = true; view.msaa_3d = Viewport.MSAA_4X; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; panel.add_child(view)
		var node := Assets.create(row.id); view.add_child(node)
		var environment := WorldEnvironment.new(); environment.environment = Environment.new()
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE; environment.environment.ambient_light_energy = 0.8; view.add_child(environment)
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55, -25, 0); light.light_energy = 0.8; view.add_child(light)
		var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 5.1
		camera.position = Vector3(5, 4.5, 7); view.add_child(camera); camera.look_at(Vector3(0, 0.8, 0))
		var label := Label.new(); label.text = "%s   %d X %d X %d" % [row.name, row.size_m[0], row.size_m[1], row.size_m[2]]
		label.add_theme_color_override("font_color", Color("64452f")); label.add_theme_font_size_override("font_size", 19)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.position = panel.position + Vector2(0, 214); label.size = Vector2(300, 34); canvas.add_child(label)
		i += 1
	for frame in 12: await process_frame
	var path := "res://artifacts/settlement/reviewed-buildings.png"
	canvas.get_texture().get_image().save_png(path)
	print("Saved " + path)
	canvas.queue_free(); await process_frame
	quit()
