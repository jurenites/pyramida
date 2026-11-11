extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Depot = preload("res://scripts/settlement/stone_storage_view.gd")
const Road = preload("res://scripts/settlement/stone_road.gd")
const Well = preload("res://scripts/settlement/well_view.gd")
const Shaft = preload("res://scripts/settlement/well_shaft.gd")
func _initialize() -> void: call_deferred("run")
func view_for(canvas: SubViewport, index: int, count: int, target: Vector3, size_: float) -> SubViewport:
	var width := canvas.size.x / count
	var holder := SubViewportContainer.new(); holder.position.x = index * width; canvas.add_child(holder)
	var view := SubViewport.new(); view.size = Vector2i(width, canvas.size.y - 70); view.own_world_3d = true; view.transparent_bg = true; view.msaa_3d = Viewport.MSAA_4X; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; holder.add_child(view)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -25, 0); Assets.Illustration.configure_sun(sun, 30); view.add_child(sun)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = size_; view.add_child(camera); camera.position = target + Vector3(7, 5, 10); camera.look_at(target)
	return view
func floor_for(view: SubViewport, size_: float) -> void:
	var floor_ := MeshInstance3D.new(); floor_.mesh = Depot.pad_mesh(); floor_.scale = Vector3(size_ / 3, 1, size_ / 3); floor_.position.y = -Depot.PAD_HEIGHT / 2; floor_.material_override = Depot.Stone.material(); view.add_child(floor_)
func label_for(canvas: SubViewport, index: int, count: int, text_: String) -> void:
	var label := Label.new(); label.text = text_; label.position = Vector2(index * canvas.size.x / count, canvas.size.y - 57); label.size = Vector2(canvas.size.x / count, 40); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 24); label.add_theme_color_override("font_color", Color("64452f")); canvas.add_child(label)
func run() -> void:
	for wells in [false, true]:
		var canvas := SubViewport.new(); canvas.size = Vector2i(1600, 1000 if wells else 760); canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(canvas)
		var bg := ColorRect.new(); bg.color = Depot.Palette.SAND_SURFACE; bg.size = canvas.size; canvas.add_child(bg)
		if wells:
			for panel in 3:
				var view := view_for(canvas, panel, 3, Vector3(0, -2.0, 0), 8.4)
				floor_for(view, 1.8)
				var node := Assets.create("well"); view.add_child(node); Well.sync(node, panel + 1, 2 + panel, [3, 6, 9][panel])
				var shaft := Node3D.new(); view.add_child(shaft); Shaft.populate(shaft, panel + 1, 2 + panel, [3, 6, 9][panel])
				label_for(canvas, panel, 3, "%d m · %d/%d" % [(panel + 1) * 2, 2 + panel, [3, 6, 9][panel]])
		else:
			for panel in 2:
				var view := view_for(canvas, panel, 2, Vector3(0, 0.65 if panel == 0 else 0, 0), 5.4)
				floor_for(view, 100)
				if panel == 0: view.add_child(Assets.create("masonry"))
				else:
					for x in range(-2, 3):
						for z in range(-1, 2):
							if x > 0 and z < 0: continue
							var node := Assets.create("road"); node.position = Vector3(x, 0, z); view.add_child(node); Road.sync(node, Vector3i(x, 0, z), 1729)
				label_for(canvas, panel, 2, "Masonry" if panel == 0 else "Stone road")
		for frame in 16: await process_frame
		var path := "res://artifacts/settlement/well-depth-stages.png" if wells else "res://artifacts/settlement/masonry-stone-road.png"
		canvas.get_texture().get_image().save_png(path); print("Saved ", path); canvas.queue_free(); await process_frame
	quit()
