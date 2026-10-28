extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Terrain = preload("res://scripts/settlement/terrain_mesh.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model = Model.new()
	model.setup()
	preload("res://tests/settlement/terrace_fixture.gd").add_to(model)
	var view = View.new()
	root.add_child(view)
	view.setup(model)
	var terrain: Array[Node] = view.scenery.find_children("RockChunk_*", "MeshInstance3D", true, false)
	check(not terrain.is_empty(), "Terrain cells are batched into chunk meshes")
	for chunk: MeshInstance3D in terrain:
		check(clockwise_faces_match_normals(chunk.mesh), "Terrain fronts agree with outward normals, keeping low-sun shadow bias outside the soil")
	var treads := SurfaceTool.new()
	treads.begin(Mesh.PRIMITIVE_TRIANGLES)
	Terrain.quad(treads, Vector3.ZERO, Vector3.LEFT, Vector3.BACK, Vector3.UP, Color.WHITE)
	Terrain.quad(treads, Vector3.ZERO, Vector3.LEFT, Vector3.DOWN, Vector3.FORWARD, Color.WHITE)
	check(clockwise_faces_match_normals(treads.commit()), "Tread tops and risers both face their outward normal")
	check(view.scenery.find_children("GroundTiles", "MultiMeshInstance3D", true, false).is_empty(), "Terrain caps have no duplicate coplanar planes")
	var store: Node3D = view.store_views[Vector3i(-6, 0, 2)]
	var store_id := store.get_instance_id()
	var platform: Node3D = view.entity_views["platform:%s" % Vector3i(2, 1, 0)]
	var platform_id := platform.get_instance_id()
	model.stores[Vector3i(-6, 0, 2)].amounts.log = 2
	model.revision += 1
	view.sync(model, 0, -1)
	check(view.store_views[Vector3i(-6, 0, 2)].get_instance_id() == store_id, "Inventory change preserves storage mesh and collider identity")
	check(view.entity_views["platform:%s" % Vector3i(2, 1, 0)].get_instance_id() == platform_id, "Inventory change does not rebuild unrelated platforms")
	var visible_logs := 0
	for node: Node3D in store.get_meta("logs"):
		visible_logs += int(node.visible)
	check(visible_logs == 2, "Log pool shows the exact visible stock count")
	var landing: Node3D = view.entity_views["platform:%s" % Vector3i(0, 1, 0)]
	var landing_id := landing.get_instance_id()
	model.stairs.clear()
	model.rebuild_navigation()
	view.sync(model, 0, -1)
	check(view.entity_views["platform:%s" % Vector3i(0, 1, 0)].get_instance_id() == landing_id, "Removing a standalone ladder preserves the neighbouring full deck")
	check(view.entity_views["platform:%s" % Vector3i(2, 1, 0)].get_instance_id() == platform_id, "Unchanged platform survives topology changes")
	check(not view.entity_views.has("stairs:%s" % Vector3i(-2, 0, 0)), "Removed connectors leave no stale scene objects")
	view.cutaway = true
	view.display_level = 0
	view.sync(model, 0, -1)
	check(not platform.visible and platform.get_meta("collider").collision_layer == 0, "Cutaway hides both geometry and picking colliders")
	model.platforms[Vector3i(8, 2, 0)] = true
	model.rebuild_navigation()
	view.sync(model, 0, -1)
	var upper: Node3D = view.entity_views["platform:%s" % Vector3i(8, 2, 0)]
	check(not upper.visible and upper.get_meta("collider").collision_layer == 0, "New objects obey the active cutaway immediately")
	view.cutaway = false
	view.sync(model, 0, -1)
	check(platform.visible and platform.get_meta("collider").collision_layer == 1, "Leaving cutaway restores picking")
	for plan in model.plans.values():
		check(view.entity_views["plan:%s" % plan.id].get_meta("collider").collision_layer == 2, "Construction sites use a separate selection layer")
	for resource in ["food", "water"]:
		model.workers[0].cargo = resource
		view.sync(model, 0, 0)
		var cargo: Node3D = view.actors[0].cargo
		check(cargo.name == ("FoodCrate" if resource == "food" else "WaterBucket"), "Worker displays distinct %s cargo" % resource)
		check(cargo.get_parent().name == "CargoSocket", "Cargo attaches to authored character socket")
		var kind := "food_crate" if resource == "food" else "water_bucket"
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		check(document.append_from_file("res://data/settlement/%s.glb" % kind, state) == OK, "Editable %s GLB parses" % kind)
		var imported := document.generate_scene(state)
		check(imported != null, "Exported cargo contains an actual scene")
		if imported != null:
			imported.free()
	view.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d incremental rendering, instancing and cargo checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func clockwise_faces_match_normals(mesh: ArrayMesh) -> bool:
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := vertices.size() if indices.is_empty() else indices.size()
		for offset in range(0, count, 3):
			var a := offset if indices.is_empty() else indices[offset]
			var b := offset + 1 if indices.is_empty() else indices[offset + 1]
			var c := offset + 2 if indices.is_empty() else indices[offset + 2]
			var cross_product := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			if cross_product.dot(normals[a]) >= 0.0:
				return false
	return true
