extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Depot = preload("res://scripts/settlement/stone_storage_view.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view := SubViewport.new(); view.size = Vector2i(1200, 800); view.own_world_3d = true; view.msaa_3d = Viewport.MSAA_4X; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var environment := WorldEnvironment.new(); var sky := Environment.new(); sky.background_mode = Environment.BG_COLOR; sky.background_color = Depot.Palette.SAND_SURFACE; environment.environment = sky; view.add_child(environment)
	var floor_ := MeshInstance3D.new(); floor_.mesh = Depot.pad_mesh(); floor_.scale = Vector3(50, 1, 50); floor_.position.y = -Depot.PAD_HEIGHT / 2; floor_.material_override = Depot.Stone.material(); view.add_child(floor_)
	view.add_child(Assets.create("claypit"))
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -25, 0); Assets.Illustration.configure_sun(sun, 30); view.add_child(sun)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 3.8; view.add_child(camera); camera.position = Vector3(6, 6, 8); camera.look_at(Vector3.ZERO)
	for frame in 16: await process_frame
	view.get_texture().get_image().save_png("res://artifacts/settlement/claypit-basin.png")
	print("Saved artifacts/settlement/claypit-basin.png"); view.queue_free(); await process_frame; quit()
