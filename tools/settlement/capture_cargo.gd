extends SceneTree
## Render actual runtime cargo and exported meshes for visual verification.
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Worker = preload("res://scripts/settlement/worker_view.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1200, 760)
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("eee3cc")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.45
	scene.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.7
	scene.add_child(camera)
	camera.position = Vector3(0, 4.1, 8)
	camera.look_at(Vector3(0, 0.65, 0))
	camera.current = true
	var kinds := ["log", "food_crate", "water_bucket"]
	var resources := ["log", "food", "water"]
	for index in 3:
		var x := (index - 1) * 2.5
		var asset := Assets.create(kinds[index])
		asset.position = Vector3(x, 0.10, 1.0)
		asset.scale = Vector3.ONE * 1.8
		scene.add_child(asset)
		var worker := Worker.new()
		scene.add_child(worker)
		worker.setup(index)
		worker.sync({"position": Vector3(x, 0, -0.7), "cargo": resources[index], "status": "carrying"}, 0, false)
		worker.body.rotation.y = PI + 0.3
	var ui := CanvasLayer.new()
	root.add_child(ui)
	var title := Label.new()
	title.text = "PYRAMIDA  /  PHYSICAL CARGO"
	title.position = Vector2(40, 30)
	title.add_theme_color_override("font_color", Color("423b32"))
	title.add_theme_font_size_override("font_size", 30)
	ui.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Original editable 3D assets · shown on the actual citizen cargo socket"
	subtitle.position = Vector2(40, 78)
	subtitle.add_theme_color_override("font_color", Color("665746"))
	ui.add_child(subtitle)
	for index in 3:
		var caption := Label.new()
		caption.text = ["TIMBER", "HARVEST CRATE", "WATER BUCKET"][index]
		caption.position = Vector2(camera.unproject_position(Vector3((index - 1) * 2.5, 0, 0)).x - 155, 650)
		caption.custom_minimum_size.x = 310
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_color", Color("423b32"))
		caption.add_theme_font_size_override("font_size", 23)
		ui.add_child(caption)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/cargo-assets.png")
	print("PASS: cargo render saved" if error == OK else "FAIL: cargo render could not be saved")
	quit(int(error != OK))
