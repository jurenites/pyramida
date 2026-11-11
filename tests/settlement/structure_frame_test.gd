extends SceneTree
const Structure = preload("res://scripts/settlement/structure_frame.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func add(model, views: Dictionary, kind: String, cell: Vector3i, direction := 0) -> Node3D:
	model.buildings[cell] = {"kind": kind, "direction": direction}
	var node := Assets.create(kind); node.set_meta("asset", kind); node.set_meta("cell", cell); node.position = Vector3(cell); node.rotation.y = -direction * PI / 2; root.add_child(node); views[cell] = node; return node
func count(views: Dictionary, prefix: String) -> int:
	var result := 0
	for node: Node3D in views.values():
		for part: Node3D in node.get_node("ConnectedStructure").get_children(): result += int(str(part.name).begins_with(prefix))
	return result
func run() -> void:
	Assets.Appearance.directory = "/tmp/pyramida-structure-source-%d" % Time.get_ticks_usec()
	var decks: Array = []
	for seed_ in [17, 17, 18]:
		var sample := Node3D.new(); Structure.deck(sample, seed_)
		var mesh: Mesh = sample.get_node("Deck").mesh
		var faces := mesh.get_faces(); decks.append(faces)
		for x in [-0.35, 0.0, 0.35]:
			for z in [-0.17, 0.17]:
				var covered := false
				for i in range(0, faces.size(), 3):
					if Geometry3D.ray_intersects_triangle(Vector3(x, 2, z), Vector3.DOWN, faces[i], faces[i + 1], faces[i + 2]) != null: covered = true; break
				check(not covered, "Visible gaps remain between the slightly rotated planks")
		sample.free()
	check(decks[0] == decks[1] and decks[0] != decks[2], "Plank variation is stable for a seed and differs between placements")
	for direction in 4:
		var model = Model.new(); var views := {}
		for x in 2: add(model, views, "support", Vector3i(x, 0, 0), direction)
		Structure.sync(model, views)
		check(count(views, "Post") == 4 and count(views, "Beam") == 6, "One-by-two bench has four end legs and no middle supports")
		add(model, views, "support", Vector3i(2, 0, 0), direction)
		Structure.sync(model, views)
		check(count(views, "Post") == 4, "Three modules form a long bench with only four end posts")
		check(count(views, "Beam") == 8, "No beams cross the two internal seams")
		var before: Node3D = views[Vector3i.ZERO].get_node("ConnectedStructure"); Structure.sync(model, views)
		check(views[Vector3i.ZERO].get_node("ConnectedStructure") == before, "Inventory changes do not rebuild frame")
		model.buildings.erase(Vector3i.RIGHT); views[Vector3i.RIGHT].free(); views.erase(Vector3i.RIGHT); Structure.sync(model, views)
		check(count(views, "Post") == 8 and count(views, "Beam") == 8, "Removing middle module restores two full outer frames")
		for node in views.values(): node.free()
	var square = Model.new(); var square_views := {}
	for x in 2:
		for z in 2: add(square, square_views, "support", Vector3i(x, 0, z))
	Structure.sync(square, square_views)
	check(count(square_views, "Post") == 4 and count(square_views, "Beam") == 8, "Two-by-two group retains only four corner posts and perimeter beams")
	var removed := Vector3i(1, 0, 1); square.buildings.erase(removed); square_views[removed].free(); square_views.erase(removed)
	Structure.sync(square, square_views)
	check(count(square_views, "Post") == 6, "L-shaped bench preserves its concave corner and outer end legs")
	for node in square_views.values(): node.free()
	var model = Model.new(); var views := {}
	var stair := add(model, views, "stair", Vector3i.ZERO)
	Structure.sync(model, views)
	check(count(views, "Post") == 2 and count(views, "Step") == 5 and count(views, "Rafter") == 2 and count(views, "Deck") == 0, "Open diagonal stair has two upright logs, rails and five plank steps")
	add(model, views, "support", Vector3i.UP); Structure.sync(model, views)
	check(count({0: stair}, "Post") == 4 and count({0: stair}, "Beam") == 4 and count({0: stair}, "Deck") == 0, "Upper Support completes log frame without capping the steps")
	model.buildings.erase(Vector3i.UP); views[Vector3i.UP].free(); views.erase(Vector3i.UP); Structure.sync(model, views)
	check(count(views, "Post") == 2 and count(views, "Beam") == 0, "Removing upper Support restores open stair")
	stair.free()
	var fixture := Fixture.new(); var world = fixture.fixture()
	fixture.finish(world, "stair", Vector3i.ZERO)
	check(world.snap_cell("support", "stair", Vector3i.ZERO) == Vector3i.UP, "Support snaps one metre above Stair")
	check(world.supports_build_cell(Vector3i.UP) and not world.supports_build_cell(Vector3i(1, 1, 0)), "Stair frame supports only its actual one-metre footprint")
	check(not world.navigation.surfaces.has(Vector3i.UP), "Structural Stair cap is not an invisible walkable floor")
	check(world.request_build("support", Vector3i.UP), "Support can be built over Stair: " + world.last_message)
	for plan: Dictionary in world.plans.values():
		if plan.kind == "support":
			check(world.Planning.ready(world, plan), "Builder accepts exact one-cell structural support")
			check(not world.work_cells(plan.kind, plan.cell).is_empty(), "Builder can work from below")
			plan.used = plan.materials.duplicate(); plan.installed = plan.required; world._complete_plan(plan)
	check(world.buildings.get(Vector3i.UP, {}).get("kind") == "support", "Stacked Support completes")
	check(not world.Relocation.source_error(world, Vector3i.ZERO).is_empty(), "Loaded Stair cannot be removed")
	var restored = Model.new(); check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Stacked frame saves and loads")
	var view := View.new(); root.add_child(view); view.setup(restored)
	var live: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	check(count({0: live}, "Post") == 4, "Loaded frame is rebuilt in the actual world view")
	view.queue_free(); fixture.free(); await process_frame
	test_open_stacks()
	print("PASS: diagonal Stair, stacked support, shared boundaries, removal, rotations, placement and save/load" if failures.is_empty() else "FAIL: structure frames")
	quit(0 if failures.is_empty() else 1)

func test_open_stacks() -> void:
	var fixture := Fixture.new()
	for direction in 4:
		var world = fixture.fixture(); var views := {}
		var run: Vector3i = Model.DIRECTIONS[direction]
		var lower := add(world, views, "support", Vector3i.ZERO, direction)
		world.rebuild_navigation(); Structure.sync(world, views)
		check(not world.navigation.walkable(Vector3i.ZERO), "A single low Support is not a walk-through opening")
		check(world.request_build("support", Vector3i.UP, direction), "Queue second Support")
		Structure.sync(world, views)
		check(lower.get_node("ConnectedStructure").has_node("Deck") and world.navigation.surfaces.has(Vector3i.UP), "Planning preserves the real deck and walking surface")
		var plan: Dictionary = world.plans[world.next_plan_id - 1]
		world.workers[0].cell = Vector3i.UP; world.workers[0].position = Vector3.UP
		check(not world.Planning.ready(world, plan), "Cannot remove the floor beneath a resident")
		world.workers[0].cell = -run; world.workers[0].position = Vector3(-run)
		check(world.Planning.ready(world, plan), "Upper Support is ready once its floor is clear")
		plan.used = plan.materials.duplicate(); plan.installed = plan.required; world._complete_plan(plan)
		add(world, views, "support", Vector3i.UP, direction); Structure.sync(world, views)
		check(not lower.get_node("ConnectedStructure").has_node("Deck") and count({0: lower}, "Beam") == 0, "Lower deck and crossbars disappear under the upper Support")
		check(count(views, "Deck") == 1 and count(views, "Post") == 8, "Only top deck remains and both upright frames survive")
		check(world.navigation.walkable(Vector3i.ZERO) and not world.navigation.surfaces.has(Vector3i.UP), "Ground passage opens without an invisible intermediate floor")
		check(world.supports_build_cell(Vector3i.UP), "Open frame still structurally carries its upper module")
		var route: Array = world.navigation.route(-run, run)
		check(route.has(Vector3i.ZERO) and route.size() == 3, "Residents take the direct passage beneath the two Supports")
		check(world.order_move(0, run), "Order a resident through the opening")
		for tick in 80: world.tick_citizen_job(world.workers[0], 0.05)
		check(world.workers[0].cell == run, "Resident actually crosses under stacked Supports")
		world.workers[0].cell = Vector3i.ZERO; world.workers[0].position = Vector3.ZERO
		check(world.StructureLayout.restoring_deck_occupied(world, Vector3i.UP), "Removal cannot restore a deck through a resident below")
		world.workers[0].cell = run * 3; world.workers[0].position = Vector3(run * 3)
		check(not world.StructureLayout.restoring_deck_occupied(world, Vector3i.UP), "Restoration is available once the passage is clear")
		world.buildings.erase(Vector3i.UP); views[Vector3i.UP].free(); views.erase(Vector3i.UP)
		world.rebuild_navigation(); Structure.sync(world, views)
		check(lower.get_node("ConnectedStructure").has_node("Deck") and world.navigation.surfaces.has(Vector3i.UP) and not world.navigation.walkable(Vector3i.ZERO), "Removing the upper module restores the lower deck and closes its low passage")
		for node in views.values(): node.free()

		world = fixture.fixture(); views = {}
		var stair := add(world, views, "stair", Vector3i.ZERO, direction)
		var middle := add(world, views, "support", Vector3i.UP, direction)
		# Real landings on either side of the two flights; no floating cap in the shaft.
		world.ground.erase(run); world.ground[run + Vector3i.UP] = true
		for cell: Vector3i in [-run, -run + Vector3i.UP, run + Vector3i.UP, run + Vector3i.UP * 2]:
			world.buildings[cell] = {"kind": "support", "direction": direction}
		world.rebuild_navigation()
		check(world.request_build("stair", Vector3i.UP * 2, direction), "Upper same-direction Stair can be built on Support: " + world.last_message)
		plan = world.plans[world.next_plan_id - 1]
		plan.used = plan.materials.duplicate(); plan.installed = plan.required; world._complete_plan(plan)
		add(world, views, "stair", Vector3i.UP * 2, direction); Structure.sync(world, views)
		check(not middle.get_node("ConnectedStructure").has_node("Deck") and count({0: middle}, "Beam") == 0, "Support under upper Stair has no deck or crossbars")
		check(count({0: stair}, "Beam") == 2 and count(views, "Step") == 10, "Both flights retain five treads with open entrance and exit below")
		check(not world.navigation.surfaces.has(Vector3i.UP * 2), "No invisible walking floor remains between the stacked flights")
		var arrangement := preload("res://scripts/settlement/building_layout_sandbox.gd").new()
		for cell: Vector3i in views:
			arrangement.entries.append({"kind": world.buildings[cell].kind, "tier": 1, "turn": direction, "at": Vector3(cell)})
			arrangement.nodes.append(views[cell])
		arrangement._join_models()
		check(not middle.get_node("ConnectedStructure").has_node("Deck"), "Arrange applies the same open sandwich geometry")
		arrangement.free()
		for rise: int in [0, 2]:
			var start := -run + Vector3i.UP * rise; var end := run + Vector3i.UP * (rise + 1)
			check(world.navigation.edges.get(start, []).has(end) and world.navigation.edges.get(end, []).has(start), "Each same-direction flight has a bidirectional landing connection")
			var path: Array = world.navigation.room_paths.get(start, {}).get(end, [])
			check(path.size() == 4 and path[1].y == rise and path[2].y == rise + 1, "Movement climbs only the actual flight between its level approaches")
			world.workers[0].cell = start; world.workers[0].position = Vector3(start)
			check(world.order_move(0, end), "Resident can use stacked Stair")
			for tick in 100: world.tick_citizen_job(world.workers[0], 0.05)
			check(world.workers[0].cell == end, "Resident reaches the real landing of each flight")
		var restored = Model.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Open stair stack survives save/load")
		check(not restored.StructureLayout.has_deck(restored, Vector3i.UP) and not restored.navigation.surfaces.has(Vector3i.UP * 2), "Restored stair stack retains its opening in geometry and navigation")
		world.buildings.erase(Vector3i.UP * 2); views[Vector3i.UP * 2].free(); views.erase(Vector3i.UP * 2)
		world.rebuild_navigation(); Structure.sync(world, views)
		check(middle.get_node("ConnectedStructure").has_node("Deck"), "Removing upper Stair restores middle Support deck")
		for node in views.values(): node.free()
	fixture.free()
