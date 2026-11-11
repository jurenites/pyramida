extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Structure = preload("res://scripts/settlement/structure_frame.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Depot = preload("res://scripts/settlement/stone_storage_view.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var canvas := SubViewport.new(); canvas.size = Vector2i(1600, 680); canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(canvas)
	var bg := ColorRect.new(); bg.color = Depot.Palette.SAND_SURFACE; bg.size = canvas.size; canvas.add_child(bg)
	var layouts := [[["hay_barn", Vector3i.ZERO]], [["bakery", Vector3i.ZERO]], [["kiln", Vector3i.ZERO]]]
	for panel in 3:
		var holder := SubViewportContainer.new(); holder.position.x = panel * 533; canvas.add_child(holder)
		var view := SubViewport.new(); view.size = Vector2i(533, 590); view.own_world_3d = true; view.transparent_bg = true; view.msaa_3d = Viewport.MSAA_4X; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; holder.add_child(view)
		var model = Model.new(); var views := {}
		for spec: Array in layouts[panel]:
			var node := Assets.create(spec[0]); node.position = Vector3(spec[1]); view.add_child(node); node.set_meta("asset", spec[0]); node.set_meta("cell", spec[1]); views[spec[1]] = node
			model.buildings[spec[1]] = {"kind": spec[0], "direction": 0}
		Structure.sync(model, views)
		if panel == 0: preload("res://scripts/settlement/barn_roof.gd").sync(views[Vector3i.ZERO], 17)
		var floor_ := MeshInstance3D.new(); floor_.mesh = Depot.pad_mesh(); floor_.scale = Vector3(15, 1, 15); floor_.position.y = -Depot.PAD_HEIGHT / 2; floor_.material_override = Depot.Stone.material(); view.add_child(floor_)
		var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -25, 0); Assets.Illustration.configure_sun(sun, 30); view.add_child(sun)
		var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 5.2; view.add_child(camera)
		var target := Vector3(0, 1.45, 0); camera.position = target + Vector3(7, 6, 10); camera.look_at(target)
		var label := Label.new(); label.text = ["Barn · planks", "Bakery · hay", "Kiln · planks"][panel]; label.position = Vector2(panel * 533, 610); label.size = Vector2(533, 40); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 23); label.add_theme_color_override("font_color", Color("64452f")); canvas.add_child(label)
	for frame in 16: await process_frame
	canvas.get_texture().get_image().save_png("res://artifacts/settlement/barn-bakery-kiln.png")
	print("Saved artifacts/settlement/barn-bakery-kiln.png"); canvas.queue_free(); await process_frame; quit()
