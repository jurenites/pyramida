extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var model = Model.new()
	model.setup(1409, "easy")
	var view := View.new()
	root.add_child(view)
	view.setup(model)
	var chunk: Node3D = view.scenery.chunks[Vector2i.ZERO]
	var cell: Vector3i = model.gardens.keys()[0]
	var grass: Node3D = view.garden_views[cell]
	var tuft: MeshInstance3D = grass.get_node("Plants/Blade0")
	var mesh := tuft.mesh
	model.revision += 1
	view.sync(model, 0, -1)
	check(view.garden_views[cell] == grass and tuft.mesh == mesh, "Inventory change preserves grass entities and geometry")
	check(view.scenery.chunks[Vector2i.ZERO] == chunk, "Inventory change preserves terrain and collision")
	check(mesh.surface_get_array_len(0) == 3, "Each leaf is a single geometric triangle")
	check(tuft.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Grass remains shadow-free")
	for terrain in view.scenery.chunks.values():
		check(not terrain.has_node("Grass"), "No decorative grass buffers are allocated")
	# Reveal/hide and cutaway must still invalidate cached visibility.
	view.fog_enabled = true
	view.sync(model, 0, -1)
	var hidden_tree: Node3D
	for node: Node3D in view.tree_views.values():
		if not node.visible:
			hidden_tree = node
			break
	check(hidden_tree != null, "Fixture includes an undiscovered tree")
	var visibility_changes := [0]
	if hidden_tree != null:
		hidden_tree.visibility_changed.connect(func(): visibility_changes[0] += 1)
	model.revision += 1
	view.sync(model, 0, -1)
	check(visibility_changes[0] == 0, "Inventory reconciliation never reveals and re-hides undiscovered trees")
	# Seedlings grow between general revisions; mature trees leave the frame list.
	var sapling_cell: Vector3i = model.trees.keys()[0]
	var sapling: Dictionary = model.trees[sapling_cell]
	sapling.seed_growth = 0.25
	model.revision += 1
	view.sync(model, 0, -1)
	check(sapling_cell in view.growing_trees, "Seedling enters the animation list")
	var sapling_node: Node3D = view.tree_views[sapling_cell]
	var old_scale := sapling_node.scale.y
	sapling.seed_growth = 0.5
	view.sync(model, 0, -1)
	check(sapling_node.scale.y > old_scale, "Seedling grows without an inventory revision")
	sapling.seed_growth = 1.0
	model.revision += 1
	view.sync(model, 0, -1)
	check(sapling_node.scale == Vector3.ONE and sapling_cell not in view.growing_trees, "Mature tree receives its final pose and leaves the animation list")
	sapling.inventory.amounts.log = 2
	model.revision += 1
	view.sync(model, 0, -1)
	check(not sapling_node.get_node("Segment3").visible, "Harvesting a mature tree still updates its segments")
	model.exploration.reveal(Vector3(-12, 0, -12))
	view.sync(model, 0, -1)
	var tree: Node3D = view.entity_views["tree:%s" % model.trees.keys()[0]]
	view.display_level = -1
	view.cutaway = true
	view.sync(model, 0, -1)
	check(not tree.visible and tree.get_meta("collider").collision_layer == 0, "Cutaway hides both model and picking")
	view.last_revision = -1
	view.sync(model, 0, -1)
	check(not tree.visible and tree.get_meta("collider").collision_layer == 0, "Forced view reconciliation reapplies cached cutaway")
	view.cutaway = false
	view.fog_enabled = false
	view.sync(model, 0, -1)
	check(tree.visible and tree.get_meta("collider").collision_layer != 0, "Visibility and picking restore together")
	# Construction mode must not replace unrelated scenery or completed buildings.
	var identities := {}
	for key: String in view.entity_views:
		if key.begins_with("tree:") or key.begins_with("deposit:") or key.begins_with("building:"):
			identities[key] = view.entity_views[key].get_instance_id()
	for planning in [true, false]:
		view.planning = planning
		view.sync(model, 0, -1)
		for key: String in identities:
			check(view.entity_views[key].get_instance_id() == identities[key], "Construction toggle retains %s" % key)
	model.Soil.prepare(model, {"kind": "house", "cell": Vector3i(4, 0, 4)})
	view.sync(model, 0, -1)
	check(view.garden_views[cell] == grass and tuft.mesh == mesh, "Levelling retains resource grass geometry")
	view.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: scenery cache invalidation, resource grass, fog, cutaway and indexed cutouts")
	quit(int(not failures.is_empty()))
