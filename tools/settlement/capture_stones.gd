extends SceneTree
const Stone = preload("res://scripts/settlement/stone_view.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var masonry := OS.get_cmdline_user_args().has("masonry")
	var variants := OS.get_cmdline_user_args().has("variants")
	var volume := variants or OS.get_cmdline_user_args().has("volume")
	var outcrops := volume or OS.get_cmdline_user_args().has("outcrops")
	root.size = Vector2i(1600, 800)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
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
	environment.environment.background_color = Color("fef1cf")
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35 if outcrops else -55, -35, 0)
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 30
	light.shadow_bias = 0.2
	light.shadow_normal_bias = 0.7
	scene.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("fef1cf")
	floor_mesh.material_override = floor_material
	scene.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	scene.add_child(camera)
	camera.position = Vector3(8, 11, 11) if volume else Vector3(8, 7, 11)
	camera.look_at(Vector3(0, 1.4 if volume else (1.1 if outcrops else 0.5), 0))
	camera.current = true
	var variant_cells: Array[Vector3i] = []
	var seen_profiles: Array = []
	if variants:
		for candidate in 100:
			var cell := Vector3i(candidate * 7, 0, 3)
			var profile: Array = Stone.Volume.sections(cell, 1409)[0].heights
			if profile in seen_profiles: continue
			seen_profiles.append(profile)
			variant_cells.append(cell)
			if variant_cells.size() == 3: break
	for index in 3:
		var pile := Node3D.new()
		scene.add_child(pile)
		pile.position = camera.basis.x * ((index - 1) * (4.0 if volume else 3.3))
		var inventory = Inventory.new()
		inventory.capacity = 6
		if volume:
			inventory.capacity = Stone.Volume.capacity(variant_cells[index] if variants else Vector3i(0, 0, 3), 1409)
			inventory.store("stone", inventory.capacity if variants else [inventory.capacity, inventory.capacity - 32, roundi(inventory.capacity * 0.5)][index])
		else:
			inventory.store("stone", 6 if outcrops else [6, 5, 2][index])
		Stone.sync(pile, variant_cells[index] if variants else Vector3i(0 if volume else index * 7, 0, 3), 1409, inventory, false if outcrops else (not masonry or index > 0))
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://artifacts/stone-outcrops.png" if outcrops else ("res://artifacts/stone-masonry.png" if masonry else "res://artifacts/stone-piles.png")
	if volume: output = "res://artifacts/stone-volume.png"
	if variants: output = "res://artifacts/stone-solid-examples.png"
	var error := root.get_texture().get_image().save_png(output)
	print("PASS: captured stone piles" if error == OK else "FAIL: stone capture")
	quit(int(error != OK))
