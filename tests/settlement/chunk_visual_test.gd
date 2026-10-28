extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func transforms(grass: MultiMeshInstance3D) -> Array:
	var result := []
	if grass.multimesh == null: return result
	for index in grass.multimesh.instance_count:
		result.append(grass.multimesh.get_instance_transform(index))
	return result
func run() -> void:
	var model = Model.new()
	model.setup()
	var view = View.new()
	root.add_child(view)
	view.setup(model)
	var origin_id: int = view.scenery.chunks[Vector2i.ZERO].get_instance_id()
	var remote := Vector2i(12, -11)
	var before := Time.get_ticks_usec()
	Chunks.integrate(model, remote, Generator.generate_chunk(model.world_seed, remote))
	view.sync(model, 0.0, -1)
	print("CHUNK_LOAD_MS: ", (Time.get_ticks_usec() - before) / 1000.0)
	check(view.scenery.chunks[Vector2i.ZERO].get_instance_id() == origin_id, "Loading distant terrain preserves existing chunk meshes and colliders")
	check(view.scenery.chunks.has(remote), "New chunk receives terrain geometry")
	var node: Node3D = view.scenery.chunks[remote]
	var original_id: int = node.get_instance_id()
	var grass: MultiMeshInstance3D = node.get_node("Grass")
	var original_grass := transforms(grass)
	check(not original_grass.is_empty(), "Remote grass uses a bounded instance batch")
	var meshes := node.find_children("RockChunk*", "MeshInstance3D", true, false)
	check(not meshes.is_empty() and meshes[0].get_child(0) is StaticBody3D, "Terrain geometry and picking collision share the same chunk")
	var vertices: PackedVector3Array = meshes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	Chunks.integrate(model, remote + Vector2i.RIGHT, Generator.generate_chunk(model.world_seed, remote + Vector2i.RIGHT))
	view.sync(model, 0.0, -1)
	check(view.scenery.chunks[remote].get_instance_id() == original_id and transforms(grass) == original_grass, "Neighbour arrival never rerolls vegetation or rebuilds a stable chunk")
	Chunks.update(model, Vector3.ZERO, 2, 0)
	view.sync(model, 0.0, -1)
	check(not view.scenery.chunks.has(remote), "Unloading frees remote render and collision nodes")
	Chunks.integrate(model, remote, Generator.generate_chunk(model.world_seed, remote))
	view.sync(model, 0.0, -1)
	node = view.scenery.chunks[remote]
	check(transforms(node.get_node("Grass")) == original_grass, "Returning restores exact grass positions, scales and rotations")
	meshes = node.find_children("RockChunk*", "MeshInstance3D", true, false)
	check(meshes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == vertices, "Unloaded neighbours do not change border faces")
	view.fog_enabled = true
	view.sync(model, 0.0, -1)
	check(transforms(node.get_node("Grass")).is_empty(), "Undiscovered grass cannot reveal the distant landscape")
	var point := Vector3((remote.x + 0.5) * Generator.CHUNK_SIZE, 0, (remote.y + 0.5) * Generator.CHUNK_SIZE)
	model.exploration.reveal(point)
	view.sync(model, 0.0, -1)
	check(not transforms(node.get_node("Grass")).is_empty(), "Exploration reveals grass beyond the original map boundary")
	var saved = Model.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) and saved.exploration.contains(point), "Distant exploration survives saving")
	view.free()
	await test_async_loading()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d incremental chunk rendering, grass and fog checks" % checks)
	quit(int(not failures.is_empty()))

func test_async_loading() -> void:
	var loader = preload("res://scripts/settlement/chunk_loader.gd").new()
	var first = Model.new()
	first.setup(1409)
	var second = Model.new()
	second.setup(773)
	var focus := Vector3(500, 0, -500)
	var chunk := Generator.chunk_at(Vector2i(500, -500))
	loader.advance(first, focus, 1)
	check(not first.loaded_chunks.has(chunk), "Worker generation cannot mutate the active model directly")
	var deadline := Time.get_ticks_msec() + 10000
	while not second.loaded_chunks.has(chunk) and Time.get_ticks_msec() < deadline:
		loader.advance(second, focus, 1)
		await create_timer(0.01).timeout
	loader.finish()
	check(second.loaded_chunks.has(chunk) and not first.loaded_chunks.has(chunk), "Switching worlds discards pending results from the previous world")
	var expected := Generator.generate_chunk(second.world_seed, chunk)
	for cell: Vector3i in expected.ground:
		check(second.ground.has(cell), "Background-generated chunk belongs to the selected seed")
	for cell: Vector3i in expected.nature:
		check(second.trees.has(cell) if expected.nature[cell] in ["tree", "dead_tree"] else second.deposits.has(cell), "Background vegetation uses the selected seed")
