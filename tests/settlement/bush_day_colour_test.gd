extends SceneTree
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const BushView = preload("res://scripts/settlement/bush_view.gd")
const Settings = preload("res://scripts/gameplay_settings.gd")
var failures: Array[String] = []

func _initialize():
	call_deferred("run")
func run():
	if DisplayServer.get_name() == "headless":
		printerr("Run this pixel test with a rendering device, not --headless.")
		quit(1)
		return
	var output := SubViewport.new()
	output.size = Vector2i(256,128)
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var container := SubViewportContainer.new()
	container.size = Vector2(256,128)
	output.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,128)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Illustration.configure(container,viewport)
	container.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4
	camera.position.z = 3
	viewport.add_child(camera)
	var source = BushView.foliage_material(1022)
	for x in [-1,1]:
		var visual := MeshInstance3D.new()
		visual.mesh = QuadMesh.new()
		visual.position.x = x
		visual.material_override = Illustration.ungraded(source) if x == -1 else source
		viewport.add_child(visual)
	for phase in [0.125,0.43,0.5,0.75]:
		Illustration.update(container.material,phase * Settings.SIMULATION_DAY_SECONDS)
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		var image := output.get_texture().get_image()
		var bush := image.get_pixelv(Vector2i(camera.unproject_position(Vector3(-1,0,0))))
		var control := image.get_pixelv(Vector2i(camera.unproject_position(Vector3(1,0,0))))
		var tint: Vector3 = container.material.get_shader_parameter("day_tint")
		var expected_control: Color = source.albedo_color * Color(tint.x,tint.y,tint.z)
		if colour_error(bush, source.albedo_color) > 0.008:
			failures.append("Bush changes colour at phase %s: %s" % [phase,bush])
		if colour_error(control, expected_control) > 0.008:
			failures.append("Ordinary material loses grading at phase %s: %s" % [phase,control])
	output.free()
	if failures.is_empty():
		print("PASS: rendered bush colours stay unchanged at midday, evening, dusk and night; ordinary materials retain grading")
	else:
		for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))

func colour_error(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
