extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Depot = preload("res://scripts/settlement/stone_storage_view.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var canvas := SubViewport.new(); canvas.size = Vector2i(1500, 570); canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(canvas)
	var background := ColorRect.new(); background.color = Color("fef1cf"); background.size = canvas.size; canvas.add_child(background)
	for panel in 3:
		var holder := SubViewportContainer.new(); holder.position.x = panel * 500; canvas.add_child(holder)
		var view := SubViewport.new(); view.size = Vector2i(500, 490); view.own_world_3d = true; view.transparent_bg = true
		view.msaa_3d = Viewport.MSAA_4X; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; holder.add_child(view)
		var depot := Assets.create("stone_storage"); view.add_child(depot)
		var ground := MeshInstance3D.new(); ground.mesh = Depot.pad_mesh()
		ground.scale = Vector3(20, 1, 20); ground.position.y = -Depot.PAD_HEIGHT / 2
		ground.material_override = Depot.Stone.material(); view.add_child(ground)
		var inventory := Inventory.new(); inventory.capacity = 18; inventory.enable_slots()
		for item in panel * 9: inventory.store("stone" if item % 2 == 0 else "block")
		Depot.sync_stock(depot, inventory, Vector3i.ZERO, 37)
		var environment := WorldEnvironment.new(); environment.environment = Environment.new()
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE; environment.environment.ambient_light_energy = 0.8; view.add_child(environment)
		var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-55, -25, 0); light.light_energy = 0.8; light.shadow_enabled = true; view.add_child(light)
		var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 4.7
		view.add_child(camera); camera.position = Vector3(6, 5.3, 7); camera.look_at(Vector3(0, 0.8, 0))
		var label := Label.new(); label.text = "%d / 18" % (panel * 9); label.position = Vector2(panel * 500, 505); label.size = Vector2(500, 40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 24); label.add_theme_color_override("font_color", Color("64452f")); canvas.add_child(label)
	for frame in 10: await process_frame
	canvas.get_texture().get_image().save_png("res://artifacts/settlement/depot-storage.png")
	print("Saved artifacts/settlement/depot-storage.png")
	canvas.queue_free(); await process_frame; quit()
