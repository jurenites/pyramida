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
	var grass: MultiMeshInstance3D = chunk.get_node("Grass")
	var batch := grass.multimesh
	var remote: MultiMeshInstance3D = view.scenery.chunks[Vector2i(-2, -2)].get_node("Grass")
	var remote_batch := remote.multimesh
	model.revision += 1
	view.sync(model, 0, -1)
	check(grass.multimesh == batch and remote.multimesh == remote_batch, "Inventory change preserves grass buffers")
	check(view.scenery.chunks[Vector2i.ZERO] == chunk, "Inventory change preserves terrain and collision")
	check(view.scenery.grass_mesh.surface_get_array_len(0) == 15, "Indexed cutout uses 15 vertices instead of 27")
	check(grass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Grass remains shadow-free")
	# A footprint edit affects only its own chunk; removal restores the tufts.
	var count := batch.visible_instance_count
	model.buildings[Vector3i(4, 0, 4)] = {"kind": "house", "direction": 0}
	model.revision += 1
	view.sync(model, 0, -1)
	check(grass.multimesh != batch and grass.multimesh.visible_instance_count < count, "Construction clears its precise footprint")
	check(remote.multimesh == remote_batch, "Local construction does not upload remote grass again")
	model.buildings.erase(Vector3i(4, 0, 4))
	model.revision += 1
	view.sync(model, 0, -1)
	check(grass.multimesh.visible_instance_count == count, "Removing a building restores natural grass")
	# Reveal/hide and cutaway must still invalidate cached visibility.
	view.fog_enabled = true
	view.sync(model, 0, -1)
	check(remote.multimesh.instance_count == 0, "Fog hides undiscovered grass")
	model.exploration.reveal(Vector3(-12, 0, -12))
	view.sync(model, 0, -1)
	check(remote.multimesh.instance_count > 0, "Exploration refreshes cached grass")
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
	batch = grass.multimesh
	model.Soil.prepare(model, {"kind": "house", "cell": Vector3i(4, 0, 4)})
	view.sync(model, 0, -1)
	grass = view.scenery.chunks[Vector2i.ZERO].get_node("Grass")
	check(grass.multimesh != batch, "Levelling updates grass height even without a new footprint")
	view.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: scenery cache invalidation, local grass updates, fog, cutaway and indexed cutouts")
	quit(int(not failures.is_empty()))
