extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Depot = preload("res://scripts/settlement/stone_storage_view.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var canvas := SubViewport.new(); canvas.size = Vector2i(1200, 860); canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(canvas)
	var bg := ColorRect.new(); bg.color = Depot.Palette.SAND_SURFACE; bg.size = canvas.size; canvas.add_child(bg)
	for panel in 2:
		var holder := SubViewportContainer.new(); holder.position.x = panel * 600; canvas.add_child(holder)
		var view := SubViewport.new(); view.size = Vector2i(600, 780); view.own_world_3d = true; view.transparent_bg = true; view.msaa_3d = Viewport.MSAA_4X; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; holder.add_child(view)
		var node := Assets.create("mill"); view.add_child(node)
		var floor_ := MeshInstance3D.new(); floor_.mesh = Depot.pad_mesh(); floor_.scale = Vector3(200, 1, 200); floor_.position.y = -Depot.PAD_HEIGHT / 2; floor_.material_override = Depot.Stone.material(); view.add_child(floor_)
		var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -25, 0); Assets.Illustration.configure_sun(sun, 30); view.add_child(sun)
		var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 9.5; view.add_child(camera)
		var target := Vector3(0, 3.15, 0); camera.position = target + (Vector3(0, 0.8, 12) if panel == 0 else Vector3(7, 5, 10)); camera.look_at(target)
	var label := Label.new(); label.text = "Mill · narrow blades · 3×3 footprint"; label.position = Vector2(0, 795); label.size = Vector2(1200, 40); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 25); label.add_theme_color_override("font_color", Color("64452f")); canvas.add_child(label)
	for frame in 16: await process_frame
	canvas.get_texture().get_image().save_png("res://artifacts/settlement/mill-plank-propeller.png")
	print("Saved artifacts/settlement/mill-plank-propeller.png"); canvas.queue_free(); await process_frame; quit()
