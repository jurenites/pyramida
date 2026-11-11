extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Trees = preload("res://scripts/settlement/tree_view.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const Workshop = preload("res://scripts/settlement/structure_workshop_view.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 1000)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("f6ebd6")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	scene.add_child(light)
	var floor_ := Workshop.box(scene, Vector3(100, 0.02, 100), Vector3(0, -0.06, 0), Color("eee0c5"))
	floor_.material_override = Assets.Illustration.flat(floor_.material_override)
	for spec in [[-3.8, 3], [-2.2, 1]]:
		var tree := Assets.create("tree")
		tree.position.x = spec[0]
		scene.add_child(tree)
		var inventory := Inventory.new()
		inventory.store("log", spec[1])
		Trees.sync(tree, {"kind": "living", "appearance_seed": 517, "inventory": inventory})
	var citizen := Assets.create("citizen_0")
	citizen.position = Vector3(-0.5, 0, 0.7)
	scene.add_child(citizen)
	citizen.get_node("CargoSocket").add_child(Assets.create("log"))
	citizen.get_node("LeftArm").rotation.x = 0.5
	citizen.get_node("RightArm").rotation.x = 0.5
	citizen.get_node("LeftArm/Elbow").rotation.x = 1.0
	citizen.get_node("RightArm/Elbow").rotation.x = 1.0
	var pile := Assets.create("log_shed")
	pile.position = Vector3(1.5, 0, 0)
	scene.add_child(pile)
	for index in 8:
		var log_ := Assets.create("log")
		log_.rotation.y = PI * 0.5
		@warning_ignore("integer_division")
		log_.position = Vector3((index % 3 - 1) * Timber.LOG_DIAMETER, 0.10 + (index / 6) * Timber.LOG_DIAMETER, (-1 if index % 6 < 3 else 1) * (Timber.LOG_LENGTH + 0.002) * 0.5)
		pile.add_child(log_)
	var building := Assets.create("platform")
	building.position = Vector3(4, 1, 0)
	scene.add_child(building)
	preload("res://scripts/settlement/platform_tiers.gd").sync(building, 1)
	var planks := Assets.create("plank")
	planks.position = Vector3(3.1, 0.03, 1.7)
	scene.add_child(planks)
	var log_ := Assets.create("log")
	log_.position = Vector3(1.5, 0, 1.7)
	scene.add_child(log_)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.6
	camera.position = Vector3(6, 7, 13)
	scene.add_child(camera)
	camera.look_at(Vector3(0, 1, 0.5))
	root.msaa_3d = Viewport.MSAA_4X
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/settlement/timber-continuity.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	root.get_texture().get_image().save_png(path)
	print("PASS: captured tree, cut trunk, citizen cargo, pile and construction stock")
	quit()
