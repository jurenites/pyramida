extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Reviewed = preload("res://scripts/settlement/reviewed_balance.gd")
const Relative = preload("res://scripts/settlement/timber_frame.gd")
const Depot = preload("res://scripts/settlement/stone_storage_view.gd")
const ORDER := ["hay_barn", "stone_storage", "brickyard", "sawmill", "mill", "bakery", "masonry", "pottery_workshop", "kiln", "quarry", "claypit", "mine", "well", "hay_field", "support", "stair", "road"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	RenderingServer.global_shader_parameter_set("settlement_daylight", 1.0)
	for page in 2:
		var canvas := SubViewport.new(); canvas.size = Vector2i(1500, 1140); canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(canvas)
		var background := ColorRect.new(); background.color = Depot.Palette.SAND_SURFACE; background.size = canvas.size; canvas.add_child(background)
		for index in range(page * 9, mini(ORDER.size(), (page + 1) * 9)):
			var kind: String = ORDER[index]; var row: Dictionary = {}
			for candidate: Dictionary in Reviewed.data.buildings:
				if candidate.id == kind: row = candidate; break
			var slot := index - page * 9
			var panel := SubViewportContainer.new(); panel.position = Vector2((slot % 3) * 500, (slot / 3) * 380); canvas.add_child(panel)
			var view := SubViewport.new(); view.size = Vector2i(500, 330); view.own_world_3d = true; view.transparent_bg = true; view.msaa_3d = Viewport.MSAA_4X; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; panel.add_child(view)
			var node := Assets.create(kind); view.add_child(node); Assets.Variation.apply(node, kind, Vector3i.ZERO, 17)
			var bounds := AABB(); var first := true
			for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				if not mesh.is_visible_in_tree() or mesh.layers == 0 or mesh.mesh == null: continue
				var box: AABB = Relative.relative(node, mesh) * mesh.mesh.get_aabb()
				bounds = box if first else bounds.merge(box); first = false
			var ground := MeshInstance3D.new(); ground.mesh = Depot.pad_mesh(); ground.scale = Vector3(15, 1, 15); ground.position.y = -Depot.PAD_HEIGHT / 2; ground.material_override = Depot.Stone.material(); view.add_child(ground)
			var environment := WorldEnvironment.new(); environment.environment = Environment.new(); environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_energy = 0.7; view.add_child(environment)
			var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -25, 0); sun.light_energy = 0.8; Assets.Illustration.configure_sun(sun, 30); view.add_child(sun)
			var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; view.add_child(camera)
			var target := bounds.get_center(); camera.position = target + Vector3(7, 7, 10); camera.look_at(target)
			var camera_bounds: AABB = camera.global_transform.affine_inverse() * bounds
			camera.size = maxf(3.0, maxf(camera_bounds.size.y, camera_bounds.size.x / (500.0 / 330.0)) * 1.22)
			var label := Label.new(); label.text = row.name; label.position = panel.position + Vector2(0, 336); label.size = Vector2(500, 36); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 25); label.add_theme_color_override("font_color", Color("64452f")); canvas.add_child(label)
		for frame in 16: await process_frame
		var path := "res://artifacts/settlement/other-buildings-%d.png" % (page + 1); canvas.get_texture().get_image().save_png(path); print("Saved " + path)
		canvas.queue_free(); await process_frame
	quit()
