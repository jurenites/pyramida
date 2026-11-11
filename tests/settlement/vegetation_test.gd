extends SceneTree
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Scenery = preload("res://scripts/settlement/scenery_view.gd")
const Patches = preload("res://scripts/settlement/vegetation_patches.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var compact := Patches.bush_offsets(0)
	check(compact.has(Vector2i.ZERO) and compact.has(Vector2i.RIGHT), "New colonies include bushes on adjoining land tiles")
	for seed_ in [1409, 9182, 42]:
		var bounds := Rect2i(-48, -48, 96, 96)
		var whole := Generator.generate_region(seed_, bounds)
		var grass := {}
		var nature := {}
		# Reverse load order, including negative coordinates and crossing patches.
		for x in range(2, -4, -1):
			for z in range(2, -4, -1):
				var chunk := Generator.generate_chunk(seed_, Vector2i(x, z))
				grass.merge(chunk.grass)
				nature.merge(chunk.nature)
		check(grass == whole.grass and nature == whole.nature, "Chunk seams and load order preserve vegetation for seed %d" % seed_)
		check(whole.grass.has(Vector3i.ZERO), "Grass returns to starting clearing")
		var connected := 0
		for cell: Vector3i in grass:
			check(not whole.water.has(cell) and not whole.shapes.has(cell) and not nature.has(cell), "Grass excludes water, slopes and resource centres")
			for direction: Vector2i in Generator.DIRECTIONS:
				if grass.has(cell + Vector3i(direction.x, 0, direction.y)):
					connected += 1
					break
		check(connected > grass.size() * 0.9, "Grass forms connected patches rather than isolated random cells")
		var berries := 0
		var grouped := 0
		for cell: Vector3i in nature:
			if nature[cell] != "berry": continue
			berries += 1
			for other: Vector3i in nature:
				if other != cell and nature[other] == "berry" and cell.distance_squared_to(other) <= 8:
					grouped += 1
					break
		check(berries > 15 and grouped >= berries * 0.85, "Bushes grow in recognizable colonies: %d/%d grouped (seed %d)" % [grouped, berries, seed_])
	check(Patches.bushes_in(Rect2i(-64, -64, 128, 128), 1409) != Patches.bushes_in(Rect2i(-64, -64, 128, 128), 9182), "Seed changes colony layout")
	var world = Model.new()
	world.setup()
	# Opening colonies consist of mature bushes with three berries each.
	var opening_food := 0
	var opening_bushes := 0
	var initial_berries: Dictionary = Generator.generate_region(world.world_seed, Generator.INITIAL_BOUNDS).nature
	for cell: Vector3i in world.deposits:
		if world.deposits[cell].kind != "berry" or initial_berries.get(cell) == "berry": continue
		opening_bushes += 1
		opening_food += world.deposits[cell].inventory.count("food")
		check(not world.navigation.route(world.workers[0].cell, cell).is_empty(), "Opening bushes remain reachable")
	check(opening_food == opening_bushes * 3 and opening_bushes > 20, "Opening colonies start full at three berries per bush")
	var harvested: Vector3i = world.deposits.keys()[0]
	world.deposits[harvested].inventory.amounts.clear()
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Vegetation world saves and loads")
	check(restored.deposits.size() == world.deposits.size() and restored.deposits[harvested].inventory.total() == 0, "Reload preserves harvested bushes without repopulating")
	var scenery := Scenery.new()
	root.add_child(scenery)
	scenery.setup(world)
	for chunk in scenery.chunks.values():
		check(not chunk.has_node("Grass"), "Terrain contains no decorative grass")
	check(world.gardens.size() == 3, "Only three harvestable opening patches replace blanket grass")
	scenery.free()
	test_legacy_grass()
	if failures.is_empty():
		print("PASS: %d vegetation patch, streaming, save and visibility checks" % checks)
		quit()
	else:
		for failure in failures: printerr("FAIL: " + failure)
		quit(1)

func test_legacy_grass() -> void:
	var world = Model.new()
	world.setup()
	check(not world.request_build("seed_grass", Vector3i.ZERO) and world.plans.is_empty(), "Grass planting creates no order")
	check(not world.Catalog.CATEGORIES.has("nature"), "Nature excludes grass planting")
	preload("res://scripts/settlement/planting.gd").complete(world, {"kind": "seed_grass", "cell": Vector3i.ZERO})
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))) and restored.gardens[Vector3i.ZERO].species == "grass", "Existing grass patches remain save compatible")
