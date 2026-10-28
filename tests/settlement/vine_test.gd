extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Vines = preload("res://scripts/settlement/vines.gd")
const View = preload("res://scripts/settlement/vine_view.gd")
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func fixture():
	var model = Model.new()
	model.setup()
	model.trees.clear()
	model.deposits.clear()
	model.water_sources.clear()
	model.vines.clear()
	model.vine_roots = 1
	model.vine_discovered = true
	model.buildings[Vector3i.ZERO] = {"kind": "house", "direction": 0, "placement_offset": Vector3(0.12, 0, 0.08)}
	model.buildings[Vector3i.UP] = {"kind": "house", "direction": 0}
	model.buildings[Vector3i(2, 0, 0)] = {"kind": "house", "direction": 0}
	model.rebuild_navigation()
	return model

func run() -> void:
	test_radial_frontier()
	var model = fixture()
	var cell := Vector3i(-2, 0, 0)
	check(model.Catalog.title("seed_vine") == "Vine tree", "Plant menu has a localized concise name")
	var old_save: Dictionary = model.snapshot()
	old_save.world.v = old_save.world.v.filter(func(pair): return pair[0] != "vines")
	var old_model = Model.new()
	check(old_model.restore(old_save) and old_model.vines.is_empty(), "Existing saves load without a vine field")
	check(model.build_error("seed_vine", Vector3i(-8, 0, 0)).is_empty(), "A root can be planted before a wall exists")
	check(model.request_build("seed_vine", cell), "Vine planting fits beside the building on the quarter grid")
	var id: int = model.next_plan_id - 1
	var planned = Model.new()
	check(planned.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Sowing order round trips")
	check(model.order_build(0, id), "A builder can be assigned to sow the vine")
	for i in 1200:
		model.tick(0.1)
		if model.vines.has(cell): break
	check(model.vines.has(cell) and not model.plans.has(id), "Builder walks to the cutting and completes planting")
	if not model.vines.has(cell):
		finish()
		return
	check(not model.build_error("seed_vine", cell).is_empty(), "Root prevents duplicate planting")
	var plant: Dictionary = model.vines[cell]
	check(plant.nodes.size() <= 1, "New vine starts small")
	model.Hydrology.tick(model, 36.0)
	var young = Model.new()
	check(young.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Young radial frontier saves before maturity")
	check(is_equal_approx(young.vines[cell].radius, plant.radius), "Expanding radius persists")
	model.Hydrology.tick(model, 54.0)
	for i in 108: young.Hydrology.tick(young, 0.5)
	check(young.vines == model.vines, "Multiple growing tips resume deterministically after reload")
	var radius_before: float = young.vines[cell].radius
	young.vines[cell].water = 0.0
	young.weather.raining = false
	for i in 18: Vines.tick_second(young)
	check(young.vines[cell].radius == radius_before, "Dry roots stop the expanding growth front")
	for i in 720: model.Hydrology.tick(model, 1.0)
	check(plant.health == 1.0 and plant.water > 0, "Normal rain sustains an untended vine for many cycles")
	check(plant.nodes.size() > 12, "Vine earns coverage over time")
	var up := false
	var sideways := false
	var diagonal := false
	for i in plant.nodes.size():
		if plant.parents[i] < 0: continue
		var delta: Vector3i = plant.nodes[i] - plant.nodes[plant.parents[i]]
		check(delta.length_squared() in [1, 2], "Every growth segment joins cardinal or diagonal grid neighbours")
		up = up or delta.y > 0
		sideways = sideways or delta.x != 0 or delta.z != 0
		diagonal = diagonal or delta.length_squared() == 2
	check(up and sideways and diagonal, "Actual building vines climb and branch sideways and diagonally")
	var faces := Vines.surfaces(model, cell)
	check(not faces.has(Vector3i(0, 0, 1)) and not faces.has(Vector3i(0, 1, 1)), "Entrance stays clear")
	check(faces[Vector3i(-1, 1, 0)].point.is_equal_approx(Vector3(-0.945, 1, 0.08)), "Wall anchors follow saved building offsets")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Growth and water round trip through JSON saves")
	check(restored.vines[cell].nodes == plant.nodes and restored.vines[cell].parents == plant.parents and is_equal_approx(restored.vines[cell].growth, plant.growth) and is_equal_approx(restored.vines[cell].water, plant.water), "Save preserves topology, health and growth clock")
	for i in 30:
		model.Hydrology.tick(model, 0.5)
		model.Hydrology.tick(model, 0.5)
	restored.Hydrology.tick(restored, 30.0)
	check(restored.vines == model.vines, "Rain and growth are independent of tick size and reload")
	var required := Chunks.required(model, Vector3(900, 0, 900), 0)
	check(required.has(Chunks.chunk_for(cell)), "Planted vines retain their root chunk when the camera leaves")
	var node := Node3D.new()
	root.add_child(node)
	View.sync(node, model, cell)
	check(node.get_node("Growth").get_child_count() == 4, "Living vines render stems and varied green foliage")
	# The headless renderer does not retain MultiMesh buffers; check the source transforms.
	var stems: Array[Transform3D] = []
	View.branch(stems, [[], [], []], Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, RandomNumberGenerator.new(), 1.0, 1.0)
	check(stems.all(func(transform): return absf(transform.basis.y.normalized().y) < 0.4), "Sideways stems follow their branch direction")
	model.weather.raining = false
	Vines.water(plant, Vines.WATER_CAPACITY)
	var count: int = plant.nodes.size()
	for i in 230: Vines.tick_second(model)
	check(plant.health < 1.0 and plant.health > 0.0, "Prolonged drought visibly withers the vine")
	Vines.water(plant, Vines.WATER_CAPACITY)
	for i in 60: Vines.tick_second(model)
	check(plant.health == 1.0, "Water rescues a living wilted vine")
	for i in 300: Vines.tick_second(model)
	check(plant.health == 0.0, "An unwatered vine eventually dries out")
	View.sync(node, model, cell)
	check(node.get_node("Growth").get_child_count() == 1, "Dried vine loses its leaves and retains woody stems")
	model.weather.raining = true
	for i in 20: Vines.tick_second(model)
	check(plant.health == 0.0, "Rain does not resurrect dead wood")
	check(plant.nodes.size() >= count, "Drying preserves earned woody growth")
	model.buildings.clear()
	for i in 9: Vines.tick_second(model)
	check(plant.nodes.is_empty(), "Removing supports prunes suspended growth")
	var invalid := {cell: Vines.create()}
	invalid[cell].nodes = [Vector3i.ZERO]
	invalid[cell].parents = [0]
	check(not Vines.valid(invalid), "Corrupt cyclic growth is rejected")
	var legacy: Dictionary = model.snapshot()
	check(Model.new().restore(legacy), "Empty pruned vines remain valid saves")
	node.free()
	finish()

func test_radial_frontier() -> void:
	var model = Model.new()
	var faces := {}
	for x in range(-6, 7):
		for y in range(0, 7):
			var key := Vector3i(x, y, 0)
			faces[key] = {"point": Vector3(key), "normal": Vector3.BACK}
	var plant := Vines.create()
	plant.nodes = [Vector3i.ZERO]
	plant.parents = [-1]
	Vines.grow(model, Vector3i.ZERO, plant, faces)
	check(plant.nodes.all(func(point): return Vector3(point).length() <= Vines.START_RADIUS), "Young tips stay inside their small starting radius")
	var diagonal := false
	var left := false
	var right := false
	var multiple_tips := false
	for pulse in 40:
		plant.radius = minf(Vines.REACH, plant.radius + Vines.RADIUS_STEP)
		var previous: int = plant.nodes.size()
		Vines.grow(model, Vector3i.ZERO, plant, faces)
		multiple_tips = multiple_tips or plant.nodes.size() - previous > 1
		check(plant.nodes.size() - previous <= Vines.TIPS_PER_PULSE, "Spreading remains gradual per pulse")
		for i in plant.nodes.size():
			var point: Vector3i = plant.nodes[i]
			check(Vector3(point).length() <= plant.radius, "Growth follows a round radius rather than a square boundary")
			left = left or point.x < -2
			right = right or point.x > 2
			if i > 0: diagonal = diagonal or (point - plant.nodes[plant.parents[i]]).length_squared() == 2
	check(diagonal and left and right and multiple_tips, "A branching diagonal fan spreads on both sides with multiple active tips")
	check(Vines.valid({Vector3i.ZERO: plant}), "Diagonal topology remains saveable")
	var a := Vector3i.ZERO
	var b := Vector3i(1, 1, 0)
	check(Vines.connected(faces, a, b), "Continuous wall supports diagonal growth")
	faces.erase(Vector3i.RIGHT)
	check(not Vines.connected(faces, a, b), "Diagonal cannot cut through an entrance or missing wall corner")
	var severed := Vines.create()
	severed.nodes = [a, b]
	severed.parents = [-1, 0]
	Vines.prune(severed, faces)
	check(severed.nodes == [a], "Removing diagonal support prunes the suspended branch")
	var old := Vines.create()
	old.erase("radius")
	old.nodes = [Vector3i.ZERO, Vector3i.UP]
	old.parents = [-1, 0]
	check(Vines.valid({Vector3i.ZERO: old}), "Existing orthogonal vine saves remain compatible")

func finish() -> void:
	if failures.is_empty(): print("PASS: vine planting, growth, rain, drought, persistence and rendering")
	else:
		for message in failures: push_error("FAIL: " + message)
	quit(0 if failures.is_empty() else 1)
