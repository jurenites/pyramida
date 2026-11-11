extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fixture():
	var world = Model.new()
	world.streaming_enabled = false
	# This fixture tests costs, placement and production after catalogue unlocks.
	for kind: String in Model.Economy.RECIPES: world.unlock_production(kind)
	for kind: String in Model.Economy.EXTRACTORS: world.unlock_production(kind)
	for x in range(-14, 15):
		for z in range(-10, 11): world.ground[Vector3i(x, 0, z)] = true
	world.workers.append({"id": 0, "cell": Vector3i.ZERO, "position": Vector3.ZERO, "route": [], "route_index": 0, "job": {}, "cargo": "", "status": "idle", "distance": 0.0, "hunger": 0.0, "role": "idle", "life_stage": "adult"})
	world.exploration.update(world.workers)
	world.rebuild_navigation()
	return world

func step(world, count := 1) -> void:
	for i in count:
		world.time += 0.1
		world.Jobs.prepare_decisions(world)
		world.workers[0].hunger = 0
		world.tick_citizen_job(world.workers[0], 0.1)

func finish(world, kind: String, cell: Vector3i) -> void:
	check(world.request_build(kind, cell), "Place " + kind + ": " + world.last_message)
	for plan: Dictionary in world.plans.values():
		if plan.cell != cell: continue
		plan.used = plan.materials.duplicate(); plan.installed = plan.required
		world._complete_plan(plan)
		return

func save_roundtrip(world) -> void:
	var other = Model.new()
	check(other.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Save/restore reviewed state")

func test_water() -> void:
	var world = fixture()
	Model.Hydrology.populate(world, {Vector3i.ZERO: "puddle"})
	for units in [1, 2, 3]:
		for distance in [0, 1, 2, 3, 4, 7]:
			var expected: int = [3, 6, 9][units - 1] if distance == 0 else ((2 if distance <= 2 else 1) if units == 1 else [1, 3, 6][units - 1])
			check(Model.Hydrology.capacity(world, Vector3i(distance, 0, 0), units) == expected, "Well capacity %d/%d" % [units, distance])
	finish(world, "well", Vector3i.ZERO)
	check(world.wells[Vector3i.ZERO].count("water") == 3 and world.wells[Vector3i.ZERO].capacity == 3, "Well captures puddle's three drops")
	finish(world, "well", Vector3i.ZERO)
	check(world.wells[Vector3i.ZERO].count("water") == 3 and world.wells[Vector3i.ZERO].capacity == 6, "Deepening adds capacity without water")
	finish(world, "well", Vector3i.ZERO)
	check(world.wells[Vector3i.ZERO].capacity == 9, "Third depth capacity")
	check(not world.request_build("well", Vector3i.ZERO), "Fourth depth rejected")
	save_roundtrip(world)
	world = fixture()
	check(not world.request_build("claypit", Vector3i(5, 0, 0)), "Claypit rejects dry ground")
	Model.Hydrology.populate(world, {Vector3i(5, 0, 0): "puddle"})
	finish(world, "claypit", Vector3i(5, 0, 0))
	check(world.buildings.has(Vector3i(5, 0, 0)), "Claypit allowed on puddle")

func test_costs_and_models() -> void:
	for row: Dictionary in Model.Catalog.Reviewed.data.buildings:
		var world = fixture()
		var kind: String = row.id
		check(Model.Catalog.Reviewed.cost(kind).size() <= 2, "At most two construction materials: " + kind)
		if kind == "claypit": Model.Hydrology.populate(world, {Vector3i(5, 0, 0): "puddle"})
		check(world.request_build(kind, Vector3i(5, 0, 0)), "Reviewed placement " + kind + ": " + world.last_message)
		for plan: Dictionary in world.plans.values(): check(plan.materials == Model.Catalog.Reviewed.cost(kind), "Reviewed costs " + kind)
		var asset := Assets.create(kind)
		check(asset != null and asset.get_child_count() > 0, "Model " + kind)
		asset.free()
		save_roundtrip(world)
	var world = fixture()
	finish(world, "quarry", Vector3i(5, 0, 0))
	check(world.construction_materials[Vector3i(5, 0, 0)].is_empty(), "Quarry free")
	check(world.stores[Vector3i(5, 0, 0)].capacity == 4, "Quarry buffer four")
	finish(world, "log_shed", Vector3i(-5, 0, 0))
	check(Model.Economy.accepts(world, Vector3i(-5, 0, 0), "plank"), "Shed stores planks")
	check(world.stores[Vector3i(-5, 0, 0)].capacity == 8, "Shed capacity eight")
	finish(world, "hay_barn", Vector3i(0, 0, 5))
	check(Model.Economy.accepts(world, Vector3i(0, 0, 5), "flour"), "Barn stores flour")
	save_roundtrip(world)

func tree(world) -> void:
	var inventory := Model.Inventory.new(); inventory.store("log", 3)
	world.trees[Vector3i(3, 0, 0)] = {"kind": "living", "inventory": inventory, "regrowth": 0.0}
	world.rebuild_navigation()

func test_ground_and_courier() -> void:
	var world = fixture(); tree(world)
	world.set_role(0, "woodcutter")
	step(world, 350)
	var loose := 0
	for plan: Dictionary in world.plans.values():
		if Model.Deconstruction.is_salvage(plan): loose += plan.relocation.parts.count("log")
	check(loose == 3, "No storage: all three logs remain on floor")
	check(world.workers[0].role == "woodcutter", "Floor delivery preserves occupation")
	save_roundtrip(world)
	world = fixture(); tree(world)
	check(world.request_build("sawmill", Vector3i(-5, 0, 0)), "Queue sawmill without storage")
	var site: Dictionary = world.plans.values()[0]
	world.set_role(0, "woodcutter")
	var saved_in_flight := false
	for i in 500:
		step(world)
		if world.workers[0].job.get("kind") == "delivery" and not saved_in_flight:
			save_roundtrip(world); saved_in_flight = true
	check(saved_in_flight, "Producer uses courier job")
	check(site.get("delivered") != null and site.delivered.count("log") == 3, "Three logs delivered to site")
	check(site.installed == 0 and world.workers[0].role == "woodcutter", "Courier does not build or change role")
	save_roundtrip(world)
	# A builder uses staged inventory; fourth item comes from another tree.
	tree(world)
	world.set_role(0, "builder")
	step(world, 600)
	check(world.buildings.get(Vector3i(-5, 0, 0), {}).get("kind") == "sawmill", "Builder consumes delivered stock and finishes")
	save_roundtrip(world)

func test_production() -> void:
	for kind: String in ["sawmill", "mill", "bakery", "masonry", "pottery_workshop", "kiln", "tilery"]:
		var world = fixture()
		var cell := Vector3i(5, 0, 0)
		finish(world, kind, cell)
		var recipe: Dictionary = Model.Economy.RECIPES[kind]
		world.stores[cell].store(recipe.input)
		check(world.order_workplace(0, cell), "Assign " + kind)
		step(world, 200)
		check(world.resource_total(recipe.output) == 1, "One input to one output " + kind)
		check(world.resource_total(recipe.input) == 0, "Input consumed " + kind)
		save_roundtrip(world)
	for kind in ["claypit", "mine"]:
		var world = fixture(); var cell := Vector3i(5, 0, 0)
		if kind == "claypit": Model.Hydrology.populate(world, {cell: "puddle"})
		finish(world, kind, cell)
		check(world.order_workplace(0, cell), "Assign extractor " + kind)
		step(world, 120)
		check(world.resource_total(Model.Economy.EXTRACTORS[kind].output) > 0, "Extract without storage " + kind)
		save_roundtrip(world)

func test_startup_and_support() -> void:
	var world = fixture()
	var candidates: Array[Vector3i] = []; candidates.assign(world.ground.keys())
	Model.Economy.seed_hay_patches(world, candidates)
	check(world.gardens.size() == 3, "Natural grass supplies first Field")
	tree(world)
	world.set_role(0, "farmer"); step(world, 700)
	check(world.resource_total("grain") >= 4, "Farmer gathers starting Hay without any store")
	check(world.request_build("hay_field", Vector3i(-9, 0, -6)), "Queue first Field using wild Hay")
	world.set_role(0, "builder"); step(world, 1600)
	check(world.buildings.get(Vector3i(-9, 0, -6), {}).get("kind") == "hay_field", "First Field finishes from natural materials without circular dependency")
	world = fixture()
	finish(world, "support", Vector3i(-1, 0, 0))
	finish(world, "stair", Vector3i(-2, 0, 0))
	check(not world.navigation.route(Vector3i(-3, 0, 0), Vector3i(-1, 1, 0)).is_empty(), "One-metre stair reaches one-metre support")
	finish(world, "masonry", Vector3i(6, 0, 0))
	check(not world.request_build("house", Vector3i(8, 0, 0)), "Larger reviewed footprint rejects overlap")
	check(not world.navigation.walkable(Vector3i(7, 0, 1)), "Navigation blocks outer workplace footprint")
	world = fixture()
	check(world.request_build("sawmill", Vector3i(5, 0, 0)), "Stage cancellable site")
	var plan: Dictionary = world.plans.values()[0]
	plan.delivered = Model.Inventory.new(); plan.delivered.store("log", 2)
	check(world.delete_plan(plan.id), "Cancel delivered site")
	check(world.resource_total("log") == 2, "Cancellation leaves staged goods recoverable")
	save_roundtrip(world)


func test_free_quarry_move() -> void:
	var world = fixture()
	var source := Vector3i(5, 0, 0); var target := Vector3i(-5, 0, 0)
	finish(world, "quarry", source)
	world.stores[source].store("stone", 2)
	world.exploration.reveal(Model.Navigation.point(target))
	check(world.Relocation.request(world, source, target, 0, Vector3.ZERO), "Free Quarry can move")
	save_roundtrip(world)
	var id: int = world.plans.keys()[0]
	world.order_build(0, id); step(world, 500)
	check(world.buildings.get(target, {}).get("kind") == "quarry" and not world.buildings.has(source), "Zero-cost relocation finishes")
	check(world.stores.has(target) and world.stores[target].count("stone") == 2, "Quarry move preserves its buffer")
	save_roundtrip(world)


func _initialize() -> void:
	test_water(); test_costs_and_models(); test_ground_and_courier(); test_production(); test_startup_and_support(); test_free_quarry_move()
	for message in failures: push_error(message)
	print("%s: %d reviewed balance checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
