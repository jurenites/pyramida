extends SceneTree
const Roofs = preload("res://scripts/settlement/house_roofs.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func node_for(cell: Vector3i, direction := 0) -> Node3D:
	var node := Assets.create("house"); node.position = Vector3(cell); node.rotation.y = -direction * PI / 2
	node.set_meta("cell", cell); node.set_meta("asset", "house"); root.add_child(node)
	return node
func check_seam(a: Node3D, b: Node3D, axis: int) -> void:
	# The underlying roof planes must meet exactly. Decorative boards may lap
	# across those planes, so test the topology independently of their trim.
	var first := Vector2i(a.position.x, a.position.z); var second := Vector2i(b.position.x, b.position.z)
	var tiles := {}; var rooms: Array = []
	for node in [a, b]:
		var at := Vector2(node.position.x, node.position.z)
		rooms.append({"at": at, "axis": 1 if posmod(roundi(node.rotation.y / (PI / 2)), 2) == 0 else 0})
		for x in 2:
			for z in 2: tiles[Vector2i(at) + Vector2i(x - 1, z - 1)] = true
	var shape := Roofs.profile(tiles, rooms)
	var heights := []
	for at: Vector2i in [first, second]:
		var points := {}
		for x in 2:
			for z in 2:
				for point: Vector3 in Roofs.tile_mesh(at + Vector2i(x - 1, z - 1), shape).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					if is_equal_approx(point[axis], 1.0): points[Roofs.Frame.key(point)] = true
		heights.append(points)
	check(not heights[0].is_empty() and heights[0] == heights[1], "Underlying roof planes meet exactly")
func run() -> void:
	Assets.Appearance.directory = "/tmp/pyramida-roof-source-%d" % Time.get_ticks_usec()
	for axis in [0, 2]:
		for direction in 4:
			var model = Model.new(); var second := Vector3i.ZERO; second[axis] = 2
			model.buildings[Vector3i.ZERO] = {"kind": "house", "direction": direction}
			var incoming := 1 if axis == 0 else 2
			model.buildings[second] = {"kind": "house", "direction": incoming}
			var a := node_for(Vector3i.ZERO, direction); var b := node_for(second, incoming)
			var views := {Vector3i.ZERO: a, second: b}
			# Simulate an authored roof assembly and a high ridge component.
			var custom := Assets.Appearance.source("house", "Roof/Cap2"); custom.position.y = 2.5; a.add_child(custom)
			Roofs.sync(model, views)
			check(a.has_node("JoinedRoof") and b.has_node("JoinedRoof"), "Both rooms share the roof")
			check(not custom.visible and not a.get_node("Roof/Cap").visible, "Original and custom roof pieces are hidden")
			check_seam(a, b, axis)
			var roof := a.get_node("JoinedRoof"); Roofs.sync(model, views)
			check(a.get_node("JoinedRoof") == roof, "Inventory-only updates reuse roof geometry")
			model.buildings.erase(second); views.erase(second); b.free()
			# Runtime restores canonical panels before joining is reconciled.
			for panel: Node3D in a.get_node("Roof").get_children(): panel.visible = true
			Roofs.sync(model, views)
			check(a.has_node("JoinedRoof") and not custom.visible and not a.get_node("Roof/Cap").visible, "Removal regenerates a procedural standalone roof")
			a.free()
	# Widening must never choose a new ridge axis from the bounding rectangle.
	for direction in 4:
		var axis := 1 if direction % 2 == 0 else 0
		var rooms: Array = [{"at": Vector2.ZERO, "axis": axis}, {"at": Vector2(2, 0), "axis": axis}]
		var layout := Roofs.profile({}, rooms)
		for room: Dictionary in rooms:
			var along := Vector2.ZERO; along[axis] = 0.75
			check(is_equal_approx(Roofs.height_at(room.at + along, layout), Roofs.EAVE + 1), "Original ridge direction is retained")
	var pair := Roofs.profile({}, [{"at": Vector2.ZERO, "axis": 1}, {"at": Vector2(2, 0), "axis": 1}])
	check(is_equal_approx(Roofs.height_at(Vector2(1, 0), pair), Roofs.EAVE), "Parallel ridges meet in a shared valley")
	var turn := Roofs.profile({}, [{"at": Vector2.ZERO, "axis": 1}, {"at": Vector2(2, 0), "axis": 0}])
	check(is_equal_approx(Roofs.height_at(Vector2(1, 0), turn), Roofs.EAVE + 1), "Branch ridge crosses the wall at full height")
	check(Roofs.component(Roofs.heights(Vector2i(0, -1), turn)).kind == "roof_junction", "Concave corner joins the two roof planes")
	check(Roofs.component(Roofs.heights(Vector2i(0, -1), pair)).kind == "roof_wedge", "Straight slope uses the unit diagonal wedge")
	var independent = Model.new()
	independent.buildings[Vector3i.ZERO] = {"kind": "house", "direction": 0}
	independent.buildings[Vector3i(2, 0, 0)] = {"kind": "house", "direction": 0}
	var free_a := node_for(Vector3i.ZERO); var free_b := node_for(Vector3i(2, 0, 0))
	var independent_views := {Vector3i.ZERO: free_a, Vector3i(2, 0, 0): free_b}
	Roofs.sync(independent, independent_views)
	check(free_a.has_node("JoinedRoof") and free_b.has_node("JoinedRoof") and Model.Houses.members(independent, Vector3i.ZERO).size() == 1, "Separate buildings each get their own procedural roof")
	independent.buildings[Vector3i(2, 0, 0)].direction = 1; free_b.rotation.y = -PI / 2
	Roofs.sync(independent, independent_views)
	check(free_a.has_node("JoinedRoof") and free_b.has_node("JoinedRoof"), "Turning the doorway into the wall establishes the roof connection")
	var custom_door := Assets.Appearance.source("house", "DoorSide")
	custom_door.position = Vector3(-0.62, 0.94, 0.8); free_b.add_child(custom_door)
	preload("res://scripts/settlement/house_shell.gd").apply(free_b, [Vector3i.LEFT], [])
	check(not custom_door.visible, "Blueprint doorway pieces open at the connection too")
	preload("res://scripts/settlement/house_shell.gd").apply(free_b, [], [])
	check(custom_door.visible, "Blueprint doorway returns when the connection is removed")
	free_a.free(); free_b.free()
	var tiles := {}
	for x in 4:
		for z in 4:
			if x < 2 or z < 2: tiles[Vector2i(x, z)] = true
	var shape := Roofs.profile(tiles, [{"at": Vector2(1, 1), "axis": 1}, {"at": Vector2(3, 1), "axis": 0}, {"at": Vector2(1, 3), "axis": 1}])
	check(shape.edges.size() == 16, "L-shaped roof follows the outline")
	for tile: Vector2i in tiles:
		var mesh := Roofs.tile_mesh(tile, shape)
		for point: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			check(not (point.x > 2.13 and point.z > 2.13), "Roof does not bridge the empty notch")
	# A perpendicular wing intersects the main roof all the way to its ridge.
	for rotation in 4:
		var spin := Transform2D(rotation * PI / 2, Vector2.ZERO)
		var rooms: Array = []; var roof_tiles := {}
		for at: Vector2 in [Vector2(0, -2), Vector2.ZERO, Vector2(0, 2), Vector2(2, 0)]:
			var rotated: Vector2 = (spin * at).round()
			rooms.append({"at": rotated, "axis": ((0 if at.x == 2 else 1) + rotation) % 2})
			for x in 2:
				for z in 2: roof_tiles[Vector2i(rotated) + Vector2i(x - 1, z - 1)] = true
		var tee := Roofs.profile(roof_tiles, rooms)
		for along in [0.0, 0.5, 1.0, 1.5, 2.0]:
			check(is_equal_approx(Roofs.height_at(spin * Vector2(along, 0), tee), Roofs.EAVE + 1), "T ridge is continuous through the junction")
		for along in [0.0, 0.25, 0.5, 0.75, 1.0]:
			check(is_equal_approx(Roofs.height_at(spin * Vector2(along, -along), tee), Roofs.EAVE + 1 - along), "T valley is a smooth diagonal, without a dip or wall")
		check(not roof_tiles.has(Vector2i((spin * Vector2(2.5, 2.5)).floor())), "T leaves empty corners uncovered")
		var ridge_length := 0.0
		for tile: Vector2i in roof_tiles:
			for segment: Array in Roofs.ridge_segments(tile, tee): ridge_length += segment[0].distance_to(segment[1])
		check(is_equal_approx(ridge_length, 9), "Ridge trim spans the full six metre main wing and three metre branch")
	# Exercise the real view integration, upper-floor coverage and save/load.
	var fixture := Fixture.new(); var world = fixture.fixture()
	fixture.finish(world, "house", Vector3i.ZERO); fixture.finish(world, "house", Vector3i(2, 0, 0))
	world.buildings[Vector3i(2, 0, 0)].direction = 1
	fixture.finish(world, "house", Vector3i(0, 0, -2)); fixture.finish(world, "house", Vector3i(0, 0, 2))
	check(Model.Houses.members(world, Vector3i.ZERO).size() == 4, "T wings are one building through door-to-wall connections")
	var view := View.new(); root.add_child(view); view.setup(world)
	var left: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	check(left.has_node("JoinedRoof"), "Runtime builds the shared roof")
	fixture.finish(world, "house", Vector3i.ZERO) # Reinforce to Tier 2 before stacking.
	fixture.finish(world, "house", Vector3i(0, 2, 0)); view.sync(world, 0, -1)
	check(not left.has_node("JoinedRoof"), "Upper storey removes the covered lower roof")
	var right: Node3D = view.entity_views["building:%s" % Vector3i(2, 0, 0)]
	check(right.has_node("JoinedRoof"), "Uncovered neighbour keeps its roof")
	var restored = Model.new(); check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Roof layout saves with existing room data")
	var restored_view := View.new(); root.add_child(restored_view); restored_view.setup(restored)
	check(restored_view.entity_views["building:%s" % Vector3i(2, 0, 0)].has_node("JoinedRoof"), "Shared roof reconstructs on load")
	var loaded_right: Node3D = restored_view.entity_views["building:%s" % Vector3i(2, 0, 0)]
	for mesh: MeshInstance3D in right.get_node("JoinedRoof").get_children():
		var loaded_mesh: MeshInstance3D = loaded_right.get_node("JoinedRoof").get_node(str(mesh.name))
		check(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == loaded_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Procedural plank pattern survives save/load exactly")
	world.buildings.erase(Vector3i(0, 2, 0)); world.stores.erase(Vector3i(0, 2, 0)); world.rebuild_navigation(); view.sync(world, 0, -1)
	check(left.has_node("JoinedRoof"), "Removing upper storey restores joined roof")
	view.free(); restored_view.free(); fixture.free()
	print("PASS: shared roofs, seams, rotations, removal, custom parts, L outline, stacking and save/load" if failures.is_empty() else "FAIL: shared roofs")
	quit(0 if failures.is_empty() else 1)
