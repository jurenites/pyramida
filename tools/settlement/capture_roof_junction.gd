extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Frame = preload("res://scripts/settlement/connected_frames.gd")
const Depot = preload("res://scripts/settlement/stone_storage_view.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var canvas := SubViewport.new(); canvas.size = Vector2i(1600, 720); canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(canvas)
	var bg := ColorRect.new(); bg.color = Depot.Palette.SAND_SURFACE; bg.size = canvas.size; canvas.add_child(bg)
	for panel in 2:
		var holder := SubViewportContainer.new(); holder.position.x = panel * 800; canvas.add_child(holder)
		var view := SubViewport.new(); view.size = Vector2i(800, 640); view.own_world_3d = true; view.transparent_bg = true
		view.msaa_3d = Viewport.MSAA_4X; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; holder.add_child(view)
		var model = Model.new(); var views := {}
		var kind := "house"
		var cells := [Vector3i(0, 0, -2), Vector3i.ZERO, Vector3i(0, 0, 2), Vector3i(2, 0, 0)]
		for cell: Vector3i in cells:
			var direction := 1 if cell.x == 2 else 0
			model.buildings[cell] = {"kind": kind, "direction": direction}
			var node := Assets.create(kind); node.position = Vector3(cell); node.rotation.y = -direction * PI / 2; view.add_child(node); views[cell] = node
			node.set_meta("cell", cell); node.set_meta("asset", "house")
			var neighbours: Array = []
			for side: Vector3i in Model.Houses.SIDES:
				if cell + side * 2 in cells: neighbours.append(side)
			preload("res://scripts/settlement/house_shell.gd").apply(node, neighbours, [])
		preload("res://scripts/settlement/house_posts.gd").sync(model, views)
		preload("res://scripts/settlement/house_roofs.gd").sync(model, views)
		var ground := MeshInstance3D.new(); ground.mesh = Depot.pad_mesh(); ground.scale = Vector3(20, 1, 20); ground.position.y = -Depot.PAD_HEIGHT / 2
		ground.material_override = Depot.Stone.material(); view.add_child(ground)
		var environment := WorldEnvironment.new(); environment.environment = Environment.new()
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_energy = 0.7; view.add_child(environment)
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55, -25, 0); light.light_energy = 0.8
		Assets.Illustration.configure_sun(light, 30); view.add_child(light)
		var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 8.3
		view.add_child(camera); var target := Vector3(0.65, 1.0, 0); camera.position = target + (Vector3(7, 7, 10) if panel == 0 else Vector3(0.2, 14, 0.4)); camera.look_at(target)
		var label := Label.new(); label.text = "Overlapping roof planes" if panel == 0 else "Generated T-shaped roof"
		label.position = Vector2(panel * 800, 660); label.size = Vector2(800, 40); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24); label.add_theme_color_override("font_color", Color("64452f")); canvas.add_child(label)
	for i in 12: await process_frame
	canvas.get_texture().get_image().save_png("res://artifacts/settlement/procedural-roof-planes.png")
	print("Saved artifacts/settlement/procedural-roof-planes.png")
	canvas.queue_free(); await process_frame; quit()
