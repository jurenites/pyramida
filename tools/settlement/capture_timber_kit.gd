extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const View = preload("res://scripts/settlement/structure_workshop_view.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 1000)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("fff1cf")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	scene.add_child(light)
	View.box(scene, Vector3(100, 0.02, 100), Vector3(0, -0.04, 0), Color("f5e5c7"))
	for spec in [["platform", Vector3(-4, 1, -2)], ["platform", Vector3(-1, 2, -2)], ["sawmill", Vector3(2, 0, -2)], ["house", Vector3(5, 0, -2)], ["log_shed", Vector3(-4, 0, 2)], ["log", Vector3(-1.5, 0, 2)], ["plank", Vector3(0, 0.05, 2)], ["tree", Vector3(-6.5, 0, -1)], ["citizen_0", Vector3(1.6, 0, 2)]]:
		var asset := Assets.create(spec[0])
		asset.position = spec[1]
		scene.add_child(asset)
		if spec[0] == "platform": preload("res://scripts/settlement/platform_tiers.gd").sync(asset, int(spec[1].y))
		if spec[0] == "sawmill": preload("res://scripts/settlement/sawmill_view.gd").sync(asset, 3)
		if spec[0] == "plank":
			for child in asset.get_children():
				if child.name != "Plank0": child.hide()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14
	camera.position = Vector3(8, 9, 16)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))
	root.msaa_3d = Viewport.MSAA_4X
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/standard-timber-buildings.png")
	print("PASS: standard timber comparison capture")
	quit()
