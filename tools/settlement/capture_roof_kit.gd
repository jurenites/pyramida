extends SceneTree
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
func _initialize() -> void: call_deferred("run")
func panel(canvas: SubViewport, at: Vector2, size: Vector2i, title: String, nodes: Array, target: Vector3, zoom: float) -> void:
	var holder := SubViewportContainer.new(); holder.position = at; canvas.add_child(holder)
	var view := SubViewport.new(); view.size = size; view.own_world_3d = true; view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; holder.add_child(view)
	for node: Node3D in nodes: view.add_child(node)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = zoom
	view.add_child(camera); camera.position = target + Vector3(6, 5, 7); camera.look_at(target)
	var label := Label.new(); label.text = title; label.position = at + Vector2(0, size.y)
	label.size = Vector2(size.x, 36); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22); label.add_theme_color_override("font_color", Color("64452f")); canvas.add_child(label)
func barn() -> Node3D:
	var node := Assets.create("hay_barn")
	for z in [-0.55, 0.05, 0.55]:
		var hay := Assets.create("grain"); hay.position = Vector3(0, 0.23, z); node.add_child(hay)
	return node
func run() -> void:
	var canvas := SubViewport.new(); canvas.size = Vector2i(1440, 900); canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(canvas)
	var background := ColorRect.new(); background.color = Color("fef1cf"); background.size = canvas.size; canvas.add_child(background)
	panel(canvas, Vector2.ZERO, Vector2i(600, 440), "Barn · 1 X 2 X 1 + roof", [barn()], Vector3(0, 0.85, 0), 3.5)
	var house := Assets.create("house")
	var attached := barn(); attached.position.x = 1.5
	panel(canvas, Vector2(600, 0), Vector2i(840, 440), "House + Barn · 2 X 3 footprint", [house, attached], Vector3(0.4, 0.9, 0), 5.4)
	var i := 0
	for kind: String in preload("res://scripts/settlement/roof_kit.gd").SIZES:
		var dimensions: String = {"roof_corner": "1 X 1 X 1", "roof_wedge": "1 X 1 X 1", "roof_long_wedge": "1 X 2 X 1", "roof_fat_wedge": "1 X 2 X 0.5"}[kind]
		panel(canvas, Vector2(i * 360, 505), Vector2i(360, 315), Kit.title(kind) + "\n" + dimensions, [Kit.create(kind)], Vector3(0, 0.4, 0), 2.7)
		i += 1
	for frame in 10: await process_frame
	canvas.get_texture().get_image().save_png("res://artifacts/settlement/barn-roof-kit.png")
	print("Saved artifacts/settlement/barn-roof-kit.png")
	canvas.queue_free(); await process_frame; quit()
