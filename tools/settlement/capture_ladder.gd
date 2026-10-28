extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1100, 720)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("e5decd")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.shadow_enabled = true
	scene.add_child(light)
	for x in [-3.0, 1.0]:
		var ladder := Assets.create("stairs")
		ladder.position.x = x
		scene.add_child(ladder)
		var base := MeshInstance3D.new()
		base.mesh = BoxMesh.new()
		base.mesh.size = Vector3(2, 0.12, 2)
		base.position = Vector3(x, -0.06, 0)
		scene.add_child(base)
	var platform := Assets.create("platform")
	platform.position = Vector3(3, preload("res://scripts/settlement/navigation.gd").LEVEL_HEIGHT, 0)
	scene.add_child(platform)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.7
	scene.add_child(camera)
	camera.position = Vector3(-6, 5.5, 10)
	camera.look_at(Vector3(0.3, 1.1, 0))
	camera.current = true
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/standalone-ladder.png")
	quit()
