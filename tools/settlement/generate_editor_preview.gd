extends SceneTree
## Bake a deterministic visual reference using the same model/assets as gameplay.
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Settings = preload("res://scripts/gameplay_settings.gd")
func _initialize() -> void:
	call_deferred("generate")
func generate() -> void:
	var model = Model.new()
	model.setup()
	model.time = Settings.SIMULATION_DAY_SECONDS * 0.125
	var world = View.new()
	root.add_child(world)
	world.setup(model)
	world.name = "EditorPreview"
	world.scenery.name = "TerrainAndLighting"
	world.water_view.name = "SurfaceWater"
	world.architecture.name = "Settlement"
	strip_runtime(world)
	world.set_script(load("res://scripts/settlement/editor_preview.gd"))
	own_children(world, world)
	var scene := PackedScene.new()
	var error := scene.pack(world)
	if error == OK:
		error = ResourceSaver.save(scene, "res://scenes/settlement/EditorWorld.tscn")
	world.free()
	print("PASS: baked editor world preview" if error == OK else "FAIL: editor preview export")
	quit(int(error != OK))
func strip_runtime(node: Node) -> void:
	# Flatten instances before owning their children; otherwise PackedScene
	# imports the asset children a second time and produces name collisions.
	node.scene_file_path = ""
	for child in node.get_children():
		# Physics, particles and navigation overlays are runtime-only.
		if child is CollisionObject3D or child is GPUParticles3D or child is Camera3D or (child is MeshInstance3D and child.mesh == null):
			child.free()
		else:
			if str(child.name).begins_with("@"):
				child.name = "%s_%d" % [child.get_class(), child.get_index()]
			strip_runtime(child)
	for key in node.get_meta_list():
		node.remove_meta(key)
	node.set_script(null)
func own_children(node: Node, owner_: Node) -> void:
	for child in node.get_children():
		child.owner = owner_
		own_children(child, owner_)
