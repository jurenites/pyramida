extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func run() -> void:
	var game = Scene.instantiate()
	game.launch_to_menu = false
	game.capture = true
	root.add_child(game)
	game.set_process(false)
	game.model.trees.clear()
	game.model.deposits.clear()
	game.model.water_sources.clear()
	game.model.trees[Vector3i.ZERO] = Chunks.entry("living", "log", 3)
	game.model.trees[Vector3i(1, 0, -2)] = Chunks.entry("dead", "log", 3)
	game.model.rebuild_navigation()
	game.world.sync(game.model, 0, -1)
	game.rig.focus = Vector3.ZERO
	game.rig.update_camera()
	for frame in 3: await physics_frame
	var camera: Camera3D = game.rig.camera
	var mouse := camera.unproject_position(Vector3.UP * 3.5)
	var origin := camera.project_ray_origin(mouse)
	var ray := camera.project_ray_normal(mouse)
	var space: PhysicsDirectSpaceState3D = game.viewport.world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + ray * 300, 1)
	var hit := space.intersect_ray(query)
	check(not hit.is_empty() and hit.collider.get_meta("kind", "") == "tree", "Cursor ray first hits a tree canopy")
	var trees: Array[RID] = []
	for node: Node3D in game.world.tree_views.values(): trees.append(node.get_meta("collider").get_rid())
	query.exclude = trees
	var surface := space.intersect_ray(query)
	check(not surface.is_empty() and surface.collider.has_meta("terrain"), "The surface behind the canopy is real terrain")
	var target: Vector3i = game.model.surface_at(roundi(surface.position.x / Nav.CELL_SIZE), roundi(surface.position.z / Nav.CELL_SIZE))
	check(target != Vector3i.ZERO, "The cursor points behind the tree rather than at its base")
	game.model.exploration.reveal(Nav.point(target))
	for kind in ["house", "platform", "stairs"]:
		game._set_tool(kind)
		var placement: Dictionary = game.placement_at(mouse)
		check(placement.get("cell") == target + (Vector3i.UP if kind == "platform" else Vector3i.ZERO) and placement.get("support") == "ground", kind + " picks ground through overlapping canopies")
	game._set_tool("inspect")
	check(game.object_at(mouse).get("kind") == "tree", "Trees remain selectable for inspection")
	check(not game.model.build_error("house", Vector3i.ZERO).is_empty(), "Placement still rejects a footprint occupied by a tree")
	# Put a genuine roof behind the same canopy; picking must retain stacking.
	var roof_point: Vector3 = Plane(Vector3.UP, Nav.LEVEL_HEIGHT).intersects_ray(origin, ray)
	var roof_cell := Vector3i(roundi(roof_point.x / Nav.CELL_SIZE), 0, roundi(roof_point.z / Nav.CELL_SIZE))
	game.model.trees.erase(Vector3i(1, 0, -2))
	game.model.buildings[roof_cell] = {"kind": "house", "direction": 0}
	game.model.rebuild_navigation()
	game.world.sync(game.model, 0, -1)
	for frame in 2: await physics_frame
	game._set_tool("house")
	var roof: Dictionary = game.placement_at(mouse)
	check(roof.get("support") == "house" and roof.get("cell", Vector3i.ZERO).y == 1, "A roof behind a canopy remains a valid stacking surface")
	game.model.exploration.cells.clear()
	check(game.placement_at(mouse).is_empty(), "Looking through trees does not reveal unexplored placement")
	game.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d placement tree picking checks" % checks)
	quit(int(not failures.is_empty()))
