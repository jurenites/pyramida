extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const Plants = preload("res://scripts/settlement/plant_view.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	test_terrace_edges()
	var world = Model.new()
	world.setup(1409, "easy")
	var view := View.new()
	root.add_child(view)
	view.setup(world)
	check(world.gardens.size() == 3 and view.garden_views.size() == 3, "Grass appears only at the three existing resource patches")
	for terrain: Node3D in view.scenery.chunks.values():
		check(not terrain.has_node("Grass"), "No unselectable grass is rendered on terrain")
	for cell: Vector3i in world.gardens:
		var patch: Node3D = view.garden_views[cell]
		check(patch.get_meta("collider").get_meta("kind") == "grass_patch", "Every grass patch has a resource picking collider")
		check(patch.get_node("Plants").get_child_count() == 15, "Full patch has exactly fifteen individual leaves")
		check(world.gardens[cell].food == 3 and world.Economy.field_resource(world, cell) == "grain", "Grass still supplies three Hay")
	var cell: Vector3i = world.gardens.keys()[0]
	var patch: Node3D = view.garden_views[cell]
	var plants := patch.get_node("Plants")
	var roots := []
	for tuft: Node3D in plants.get_children(): roots.append(tuft.position)
	for stock in [3, 2, 1, 0]:
		world.gardens[cell].food = stock
		world.revision += 1
		view.sync(world, 0, -1)
		var visible := 0
		for blade: MeshInstance3D in plants.get_children():
			visible += int(blade.visible)
			check(is_equal_approx(blade.scale.y, float(blade.get_meta("grown_height"))), "Harvesting never shortens a leaf")
			check(blade.get_instance_shader_parameter("wind_origin") == Vector2(patch.position.x, patch.position.z), "All leaves sample wind at the same patch centre")
		check(visible == stock * 5, "Stock %d/3 displays exactly %d full leaves" % [stock, stock * 5])
		check((patch.get_meta("collider").collision_layer != 0) == (stock > 0), "Only visible grass intercepts selection")
	world.gardens[cell].food = 0
	world.gardens[cell].growth = world.Farming.GROW_SECONDS * 0.5
	view.sync(world, 0, -1)
	for index in plants.get_child_count():
		var tuft: Node3D = plants.get_child(index)
		check(tuft.position.is_equal_approx(roots[index]), "Harvesting never moves the remaining roots")
		check(not tuft.visible and is_equal_approx(tuft.scale.y, float(tuft.get_meta("grown_height"))), "Exhausted patch stays invisible even with an old regrowth timer")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Grass saves and restores")
	check(restored.gardens[cell].food == 0, "Reload preserves exhausted grass")
	for cycle in 3:
		restored.Farming.rain_crops(restored)
		restored.Farming.tick_crops(restored, restored.Farming.GROW_SECONDS * 100)
	check(restored.gardens[cell].food == 0, "Rain and elapsed time never refill harvested grass from older saves")
	restored.Economy.ensure_hay_source(restored)
	check(restored.gardens.size() == world.gardens.size() and restored.gardens[cell].food == 0, "Hay-source compatibility does not replace exhausted patches")
	var copy := Plants.grass()
	copy.position = patch.position
	root.add_child(copy)
	Plants.sync_grass(copy, restored, cell)
	for index in plants.get_child_count():
		check(copy.get_node("Plants").get_child(index).transform.is_equal_approx(plants.get_child(index).transform), "Reload retains seed-stable leaves and terrain roots")
		check(not copy.get_node("Plants").get_child(index).visible, "Reload does not reveal harvested leaves")
	copy.free()
	# Exercise a slope, then cut all blades: root heights must not scale with growth.
	world.soil_enabled = false
	world.terrain_shapes[cell] = [0.05, 0.25, 0.18, 0.4]
	world.terrain_revision += 1
	world.rebuild_navigation()
	world.gardens[cell].growth = 0.0
	view.sync(world, 0, -1)
	for tuft: Node3D in plants.get_children():
		var point := patch.position + tuft.position
		var ground: Vector3i = world.surface_at(roundi(point.x / Model.Grid.CELL_SIZE), roundi(point.z / Model.Grid.CELL_SIZE))
		check(is_equal_approx(point.y, world.navigation.surface_height(ground, point) + 0.012), "Larger patch roots follow the terrain beneath each leaf, including neighbouring cells")
		var collision: CollisionShape3D = patch.get_meta("collider").get_child(0)
		var bounds := AABB(collision.position - collision.shape.size * 0.5, collision.shape.size).grow(0.001)
		check(bounds.has_point(tuft.position) and bounds.has_point(tuft.position + Vector3.UP * float(tuft.get_meta("grown_height"))), "Resource picking bounds follow roots and grown tips on slopes")
	world.Farming.tick_crops(world, world.Farming.GROW_SECONDS * 2)
	check(world.gardens[cell].food == 0, "Fully harvested grass stays exhausted")
	view.sync(world, 0, -1)
	check(plants.get_children().all(func(blade): return not blade.visible) and patch.get_meta("collider").collision_layer == 0, "No leaves or picking target return after the former regrowth interval")
	patch = view.garden_views[world.gardens.keys()[1]]
	view.display_level = -1
	view.cutaway = true
	view.sync(world, 0, -1)
	check(not patch.visible and patch.get_meta("collider").collision_layer == 0, "Hidden grass cannot intercept selection")
	view.cutaway = false
	view.sync(world, 0, -1)
	check(patch.visible and patch.get_meta("collider").collision_layer != 0, "Visible grass restores interaction")
	view.free()
	# Exhausted history must not reserve the empty ground, but fresh legacy
	# sowing orders still grow once and preserve their first growth on reload.
	var planted = Model.new()
	planted.ground[Vector3i.ZERO] = true
	planted.gardens[Vector3i.ZERO] = {"species": "grass", "water": 0, "growth": 12.0, "food": 0, "reserved": -1}
	check(not planted.Farming.occupied(planted, "seed_tree", Vector3i.ZERO), "Exhausted grass leaves its root spot available")
	check(not planted.Farming.bed_in_use(planted, Vector3i.ZERO), "Exhausted grass does not reserve a soil bed")
	preload("res://scripts/settlement/planting.gd").complete(world, {"kind": "seed_grass", "cell": cell})
	world.Farming.tick_crops(world, world.Farming.GROW_SECONDS * 0.5)
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Legacy seed first growth saves and restores")
	restored.Farming.tick_crops(restored, restored.Farming.GROW_SECONDS * 2)
	check(restored.gardens[cell].food == 3 and not restored.gardens[cell].has("first_growth"), "Legacy sowing grows exactly one initial harvest")
	restored.gardens[cell].food = 0
	restored.Farming.tick_crops(restored, restored.Farming.GROW_SECONDS * 100)
	check(restored.gardens[cell].food == 0, "A fully cut legacy planting cannot regrow either")
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d sparse grass, interaction, finite harvest, terrain and save checks" % checks)
	quit(int(not failures.is_empty()))

func test_terrace_edges() -> void:
	# A patch on the middle shelf overlaps either an uphill wall or a drop.
	# Neither neighbour may pull individual blades onto another terrace.
	for neighbour_level in [4, 0]:
		var world = Model.new()
		var cell := Vector3i(0, 2, 0)
		world.ground[cell] = true
		world.gardens[cell] = {"species": "grass", "food": 3}
		for x in range(-1, 2):
			for z in range(-1, 2):
				var level: int = 2 if x == 0 and z == 0 else neighbour_level
				world.ground[Vector3i(x, level, z)] = true
				world.terrain_heights[Vector2i(x, z)] = level
		world.navigation.rebuild(world.ground, {})
		var patch := Plants.grass()
		patch.position = world.navigation.surface_point(cell)
		Plants.sync_grass(patch, world, cell)
		# Ensure the fixture crosses an edge regardless of seeded leaf scatter.
		patch.get_node("Plants").get_child(0).position.x = 0.75
		world.terrain_revision += 1
		Plants.sync_grass(patch, world, cell)
		for blade: Node3D in patch.get_node("Plants").get_children():
			check(is_equal_approx(patch.position.y + blade.position.y, 2.012),
				"Grass stays on its owning shelf beside terrain at level %d" % neighbour_level)
		patch.free()
