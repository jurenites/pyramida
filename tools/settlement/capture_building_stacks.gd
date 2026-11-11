extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new(); viewport.size = Vector2i(1200, 900); viewport.own_world_3d = true; viewport.msaa_3d = Viewport.MSAA_4X; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var environment := WorldEnvironment.new(); var sky := Environment.new(); sky.background_mode = Environment.BG_COLOR; sky.background_color = Color("fff1cf"); environment.environment = sky; viewport.add_child(environment)
	var model := Model.new(); model.streaming_enabled = false
	for x in range(-8, 9):
		for z in range(-8, 9): model.ground[Vector3i(x, 0, z)] = true
	model.buildings[Vector3i(2, 0, 0)] = {"kind": "mill", "direction": 0, "reviewed": true}
	for cell in [Vector3i(-2, 0, 0), Vector3i(-2, 1, 0), Vector3i(-2, 2, 0), Vector3i(2, 5, 0)]:
		model.buildings[cell] = {"kind": "log_shed", "direction": 0, "reviewed": true}
		model.stores[cell] = model.Inventory.new()
		model.stores[cell].store("log", 3)
	model.rebuild_navigation()
	var view := View.new(); view.fog_enabled = false; viewport.add_child(view); view.setup(model)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -25, 0); Assets.Illustration.configure_sun(sun, 30); viewport.add_child(sun)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 11; viewport.add_child(camera); camera.position = Vector3(10, 9, 15); camera.look_at(Vector3(0, 2.8, 0))
	for frame in 16: await process_frame
	viewport.get_texture().get_image().save_png("res://artifacts/settlement/building-stacks.png")
	viewport.queue_free(); await process_frame; print("Saved building-stacks.png"); quit()
