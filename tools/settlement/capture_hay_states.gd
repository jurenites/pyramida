extends SceneTree
## Compare crop height and quarter clearing with real citizen geometry.
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Worker = preload("res://scripts/settlement/worker_view.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output := SubViewport.new()
	output.size = Vector2i(1440, 620)
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var world = preload("res://scripts/settlement/world_model.gd").new()
	world.world_seed = 4815
	for index in 3:
		var container := SubViewportContainer.new()
		container.position = Vector2(index * 480, 0)
		container.size = Vector2(480, 620)
		container.stretch = true
		output.add_child(container)
		var viewport := SubViewport.new()
		viewport.world_3d = World3D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		Illustration.configure(container, viewport)
		container.add_child(viewport)
		var scene := Node3D.new()
		viewport.add_child(scene)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("fff2d0")
		scene.add_child(environment)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.size = 6.2
		scene.add_child(camera)
		camera.position = Vector3(5, 5, 7)
		camera.look_at(Vector3(0, 0.15, 0))
		camera.current = true
		var field := Assets.create("hay_field")
		scene.add_child(field)
		var cell := Vector3i(index * 8, 0, 0)
		world.buildings[cell] = {"kind": "hay_field", "direction": 0}
		preload("res://scripts/settlement/hay_field_view.gd").sync(world, cell, field)
		View.sync_hay_quarters(field.get_node("Plants"), {"food": [4, 3, 0][index], "growth": 0.0, "standing_quarters": [15, 7, 0][index]})
		var worker := Worker.new()
		scene.add_child(worker)
		worker.setup(0)
		var point := Vector3(0.4, 0, 0.55)
		worker.previous_position = point - Vector3(0.05, 0, 0)
		worker.sync({"position": point, "cargo": "", "status": "idle", "appearance": 0, "cloth_color": 0, "life_stage": "adult"}, 0.1, false, camera)
		worker.position = point
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var result := output.get_texture().get_image().save_png("res://artifacts/hay-field-states.png")
	print("PASS: grown, quarter-cut and harvested hay with adult knee reference" if result == OK else "FAIL: hay capture")
	quit(int(result != OK))
