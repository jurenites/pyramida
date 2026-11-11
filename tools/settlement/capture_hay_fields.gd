extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Fields = preload("res://scripts/settlement/hay_field_view.gd")
const Surface = preload("res://scripts/settlement/hay_surface.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1500, 950)
	root.msaa_3d = Viewport.MSAA_4X
	var model = Model.new()
	model.soil_enabled = true
	for x in range(-12, 13):
		for z in range(-8, 10): model.ground[Vector3i(x, 0, z)] = true
	model.Soil.rebuild(model)
	model.rebuild_navigation()
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("fef1cf")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	scene.add_child(light)
	for cell: Vector3i in [Vector3i(-4, 0, -1), Vector3i(2, 0, -1)]:
		model.buildings[cell] = {"kind": "hay_field", "direction": 0, "placement_offset": model.Farming.FIELD_OFFSET}
		model.gardens[cell] = {"water": 1, "growth": 0.0, "food": 0, "reserved": -1}
	model.Farming.tick_crops(model, model.Farming.GROW_SECONDS)
	model.Farming.cut_quarter(model.gardens[Vector3i(-4, 0, -1)], 2)
	model.Farming.cut_quarter(model.gardens[Vector3i(-4, 0, -1)], 3)
	model.Farming.water_crop(model, Vector3i(-4, 0, -1))
	model.Farming.tick_crops(model, 9.0)
	model.gardens[Vector3i(-4, 0, -1)].quarter_growth[2] = 0.0
	var covered := Vector3i(2, 0, -1)
	model.Farming.remember_field(model, covered)
	model.buildings[covered] = {"kind": "house", "direction": 0}
	model.Soil.prepare(model, {"kind": "house", "cell": covered})
	model.rebuild_navigation()
	model.Farming.tick_crops(model, 0.0)
	preload("res://scripts/settlement/terrain_mesh.gd").build(scene, model)
	var house := Assets.create("house")
	house.position = Vector3(covered)
	scene.add_child(house)
	for cell: Vector3i in model.gardens:
		var field := Assets.create("hay_field")
		field.position = Vector3(cell) + model.Farming.FIELD_OFFSET
		scene.add_child(field)
		Fields.sync(model, cell, field)
		Surface.sync(model, cell, field)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.4
	camera.position = Vector3(8, 9, 13)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 0.3, 0.5))
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/settlement/hay-terrain-quarters.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	root.get_texture().get_image().save_png(path)
	print("PASS: captured terrain-fitted stalks, harvested/regrowing quarters and building coverage")
	quit()
