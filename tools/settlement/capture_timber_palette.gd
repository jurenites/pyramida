extends SceneTree
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Palette = Kit.Appearance.TimberPalette
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
const View = preload("res://scripts/settlement/structure_workshop_view.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1500, 900)
	root.msaa_3d = Viewport.MSAA_4X
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("fff1df")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	scene.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	scene.add_child(light)
	for index in 3:
		var x := (index - 1) * 3.3
		var species: String = Palette.SPECIES[index]
		var platform := Workspace.instance("platform", Vector3(x, 1, -0.7))
		Kit.Appearance.set_timber_species(platform, species)
		Kit.draw(scene, platform)
		for kind in ["log", "plank"]:
			var part := {"kind": kind, "at": Vector3(x, 0, 1.1 if kind == "log" else 1.7), "rotation": Vector3.ZERO, "timber_species": species}
			Kit.draw(scene, part)
		var label := Label3D.new()
		label.text = Palette.LABELS[index]
		label.font_size = 52
		label.pixel_size = 0.008
		label.modulate = Color("594536")
		label.outline_size = 0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(x, 0.1, 2.3)
		scene.add_child(label)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11
	camera.position = Vector3(5, 8, 15)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 0.2, 0.5))
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/timber-palette.png")
	print("PASS: timber palette preview")
	quit()
