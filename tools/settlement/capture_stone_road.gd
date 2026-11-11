extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Depot = preload("res://scripts/settlement/stone_storage_view.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const WorldView = preload("res://scripts/settlement/world_view.gd")
const Road = preload("res://scripts/settlement/stone_road.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view := SubViewport.new(); view.size = Vector2i(1200, 800); view.own_world_3d = true; view.msaa_3d = Viewport.MSAA_4X; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var environment := WorldEnvironment.new(); var sky := Environment.new(); sky.background_mode = Environment.BG_COLOR; sky.background_color = Depot.Palette.SAND_SURFACE; environment.environment = sky; view.add_child(environment)
	var model := Model.new(); model.streaming_enabled = false; model.soil_enabled = true
	for x in range(-8, 9):
		for z in range(-8, 9): model.ground[Vector3i(x, 0, z)] = true
	for x in range(-2, 3):
		for z in range(-1, 2):
			if x > 0 and z < 0: continue
			model.buildings[Vector3i(x, 0, z)] = {"kind": "road", "direction": 0}
	model.Soil.rebuild(model); model.rebuild_navigation()
	var runtime := WorldView.new(); runtime.fog_enabled = false; view.add_child(runtime); runtime.setup(model)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -25, 0); Assets.Illustration.configure_sun(sun, 30); view.add_child(sun)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 5.2; view.add_child(camera); camera.position = Vector3(6, 5, 8); camera.look_at(Vector3.ZERO)
	for frame in 16: await process_frame
	view.get_texture().get_image().save_png("res://artifacts/settlement/sandstone-road.png")
	print("Saved artifacts/settlement/sandstone-road.png"); view.queue_free(); await process_frame; quit()
