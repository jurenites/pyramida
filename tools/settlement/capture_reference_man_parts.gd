extends SceneTree
const Character = preload("res://data/settlement/reference_man.tscn")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 650)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("eee3cc")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.55
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 0.8
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 3.9
	viewport.add_child(camera)
	camera.position = Vector3(0, 1.6, 8)
	camera.look_at(Vector3(0, 0.5, 0))
	var ui := CanvasLayer.new()
	viewport.add_child(ui)
	caption(ui, "LOW-POLY / SEPARATE MESHES", Vector2(42, 28), 25)
	caption(ui, "Soft shoulders / bending elbows / removable wrap", Vector2(42, 66), 18)
	for index in 3:
		var actor := Character.instantiate()
		viewport.add_child(actor)
		actor.position.x = (index - 1) * 1.2
		actor.rotation.y = PI + 0.25
		actor.pose(0.0, false)
		if index == 1: actor.set_shorts_visible(false)
		if index == 2: actor.get_node("Surface").hide()
		for part in actor.find_children("*", "MeshInstance3D", true, false):
			var paint: StandardMaterial3D = part.mesh.surface_get_material(0).duplicate()
			paint.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			part.material_override = paint
		caption(ui, ["DRESSED", "BODY", "WRAP"][index], Vector2(170 + index * 369, 530), 19)
	for frame in 3: await process_frame
	RenderingServer.force_draw()
	assert(viewport.get_texture().get_image().save_png("res://artifacts/settlement/reference-man-parts.png") == OK)
	print("PASS: captured low-poly body and separate shorts")
	quit()
func caption(parent: Node, text_: String, at: Vector2, size_: int) -> void:
	var label := Label.new()
	label.text = text_; label.position = at
	label.add_theme_font_size_override("font_size", size_)
	label.add_theme_color_override("font_color", Color("4b4037"))
	parent.add_child(label)
