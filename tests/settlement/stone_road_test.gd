extends SceneTree
const Road = preload("res://scripts/settlement/stone_road.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var left := Road.mesh(Vector3i.ZERO, 1729)
	check(left.surface_get_arrays(0) == Road.mesh(Vector3i.ZERO, 1729).surface_get_arrays(0), "Stable seed")
	check(left.surface_get_arrays(0) != Road.mesh(Vector3i.ZERO, 1730).surface_get_arrays(0), "Different seed produces different stones")
	check(left.get_aabb().position.y < -0.05 and left.get_aabb().end.y > 0.015 and left.get_aabb().end.y < 0.10, "Stone bases buried, shallow tops above sand")
	check(left.get_faces().size() == 9 * 84, "Every tile contains nine complete low-poly quarry stones")
	for x in range(-5, 6):
		for z in range(-5, 6):
			var sample := Road.mesh(Vector3i(x, 0, z), 1729)
			var bounds := sample.get_aabb()
			check(sample.get_meta("stone_count") == 9 and sample.get_faces().size() == 9 * 84, "No seed silently loses its extra stones")
			check(bounds.position.x >= -0.5 and bounds.end.x <= 0.5 and bounds.position.z >= -0.5 and bounds.end.z <= 0.5, "Stones do not intersect adjacent tiles")
	var node := Assets.create("road"); Road.sync(node, Vector3i.ZERO, 1729)
	var mesh: Mesh = node.get_node("Stones").mesh; Road.sync(node, Vector3i.ZERO, 1729)
	check(node.get_node("Stones").mesh == mesh, "No mesh rebuilding on inventory updates")
	node.rotate_y(PI / 2); Road.sync(node, Vector3i.ZERO, 1729)
	check((node.basis * node.get_node("Stones").basis).is_equal_approx(Basis.IDENTITY), "Rotation does not break continuous pattern")
	check(not node.get_node("Floor").visible and node.get_node("Stones").cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "No base slab; real block shadows")
	node.free()
	var world := Model.new()
	world.streaming_enabled = false
	for x in range(-3, 4):
		for z in range(-3, 4): world.ground[Vector3i(x, 0, z)] = true
	world.buildings[Vector3i.ZERO] = {"kind": "road", "direction": 0}
	world.rebuild_navigation()
	var view := View.new(); root.add_child(view); view.fog_enabled = false; view.setup(world)
	var built: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	check(built.get_node("Stones").mesh.get_meta("stone_count") == 9, "Actual completed-building renderer keeps all nine stones")
	var original: Mesh = built.get_node("Stones").mesh
	world.buildings[Vector3i.RIGHT] = {"kind": "road", "direction": 1}
	world.rebuild_navigation(); view.sync(world, 0, -1)
	check(Road.connections(world, Vector3i.ZERO) == 2 and built.get_node("Stones").mesh != original, "Completing a neighbour updates the shared boundary")
	var joined: Mesh = built.get_node("Stones").mesh
	view.sync(world, 0, -1)
	check(built.get_node("Stones").mesh == joined, "Unchanged roads retain cached geometry")
	world.buildings.erase(Vector3i.RIGHT); world.rebuild_navigation(); view.sync(world, 0, -1)
	check(built.get_node("Stones").mesh.surface_get_arrays(0) == original.surface_get_arrays(0), "Removing neighbour restores the exposed edge")
	world.terrain_shapes[Vector3i.ZERO] = [0.2, 0.2, 0.2, 0.2]
	world.terrain_revision += 1; world.rebuild_navigation(); view.sync(world, 0, -1)
	check(built.get_node("Stones").mesh.get_aabb().end.y > 0.2, "Road stones stay above the real terrain rather than disappearing below it")
	check(Model.Catalog.recipe("road") == {"stone": 1}, "Nine visible pieces still cost one Stone")
	view.free()
	if failures.is_empty(): print("PASS: shallow sandstone blocks, tile clearance, stable seeds and cached geometry")
	else:
		for failure in failures: push_error(failure)
	quit(int(not failures.is_empty()))
