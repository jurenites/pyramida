extends SceneTree
## Preview actual reusable assets, including overlapped rows and alternate pitches.
const Kit = preload("res://scripts/settlement/structure_parts.gd")

func _initialize() -> void: call_deferred("capture")

func caption(text: String, at: Vector2, size := 23) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_color_override("font_color", Color("4c433b"))
	label.add_theme_font_size_override("font_size", size)
	root.add_child(label)

func piece(parent: Node3D, kind: String, at: Vector3, angle := 0.0, size := 1.0) -> Node3D:
	var node := Kit.create(kind)
	parent.add_child(node)
	node.position = at
	node.rotation.x = deg_to_rad(angle)
	node.scale = Vector3.ONE * size
	return node

func capture() -> void:
	# Export at a fixed resolution, independently of the desktop's Retina scale.
	root.get_node("DisplayScale").set_process(false)
	root.content_scale_factor = 1.0
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1400, 900)
	root.content_scale_size = Vector2i(1400, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.msaa_3d = Viewport.MSAA_4X
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("eee3cc")
	scene.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.8
	scene.add_child(camera)
	camera.position = Vector3(2.5, 5.8, 9)
	camera.look_at(Vector3(0, 0.3, 0))
	camera.current = true
	var tiles := Node3D.new()
	scene.add_child(tiles)
	tiles.position = Vector3(-1.65, 0.8, -0.6)
	tiles.rotation.x = deg_to_rad(25)
	for row in 4:
		for column in 7:
			piece(tiles, "ceramic_roof_tile", Vector3((column - 3) * 0.245, (3 - row) * 0.023, (row - 1.5) * 0.34))
	piece(scene, "ceramic_roof_tile", Vector3(-1.65, 0.12, 1.6), -12, 2.4)
	for column in 2:
		piece(scene, "metal_roof_sheet", Vector3(1.05 + column * 0.97, 0.55, -0.6))
	piece(scene, "metal_roof_sheet", Vector3(1.4, 0.06, 1.5), -12, 0.7)
	caption("ROOF ASSETS", Vector2(48, 32), 30)
	caption("Ceramic roof tile", Vector2(140, 770))
	caption("Metal roof sheet", Vector2(850, 770))
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/roof-assets.png")
	print("PASS: roof assets preview saved" if error == OK else "FAIL: roof assets preview")
	quit(int(error != OK))
