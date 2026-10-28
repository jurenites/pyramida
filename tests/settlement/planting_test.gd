extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Planting = preload("res://scripts/settlement/planting.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const TreeView = preload("res://scripts/settlement/tree_view.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fresh():
	var world = Model.new()
	world.setup()
	world.trees.clear()
	world.deposits.clear()
	world.water_sources.clear()
	for worker in world.workers: world.set_role(worker.id, "idle")
	world.rebuild_navigation()
	return world

func reload_world(world):
	var result = Model.new()
	check(result.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Planting state restores through JSON")
	return result

func advance(world, seconds: float) -> void:
	for i in ceili(seconds / 0.05): world.tick(0.05)

func _initialize() -> void:
	var world = fresh()
	check(world.request_build("seed_tree", Vector3i.ZERO), "Tree seed queues on flat natural ground")
	check(not world.request_build("seed_bush", Vector3i.ZERO), "Seed orders reserve their footprint")
	world = reload_world(world)
	var id: int = world.plans.keys()[0]
	check(world.order_build(0, id), "An adult can be assigned to sow a seed")
	check(not world.order_build(2, id), "A child cannot sow")
	for i in 400:
		world.tick(0.05)
		if world.plans[id].sowing.applied_seconds > 0.4: break
	check(world.plans[id].sowing.applied_seconds > 0, "Sowing waits for the worker to reach the site")
	world = reload_world(world)
	check(world.workers[0].job.labour == world.plans[id].sowing, "Reload reconnects shared sowing labour")
	var progress: float = world.plans[id].sowing.applied_seconds
	world.set_role(0, "idle")
	check(world.plans[id].sowing.applied_seconds == progress and world.plans[id].reserved == 0, "Interrupting sowing preserves work without phantom material claims")
	check(world.order_build(1, id), "Another adult can finish the same seed")
	advance(world, 15)
	check(world.plans.is_empty() and world.trees.has(Vector3i.ZERO), "Physical sowing creates a rooted sapling")
	check(world.trees[Vector3i.ZERO].inventory.count("log") == 0, "Saplings cannot be cut for timber before maturity")
	world.set_role(1, "idle")
	var sapling: Dictionary = world.trees[Vector3i.ZERO]
	var tree_node := Assets.create("tree")
	TreeView.sync(tree_node, sapling)
	check(tree_node.scale.y < 1 and tree_node.get_node("Segment3").visible, "Young tree shows a small living crown rather than a stump")
	Planting.tick(world, Planting.TREE_SECONDS)
	TreeView.sync(tree_node, sapling)
	check(tree_node.scale == Vector3.ONE and sapling.inventory.count("log") == 3, "Mature tree reaches full size and supplies three physical logs")
	sapling.inventory.amounts.clear()
	Planting.tick(world, Planting.TREE_SECONDS * 5)
	TreeView.sync(tree_node, sapling)
	check(sapling.inventory.total() == 0 and tree_node.get_node("StumpCut").visible, "Chopped planted trees never regenerate")
	tree_node.free()
	world = fresh()
	check(not world.request_build("seed_grass", Vector3i(2, 0, 0)), "New grass planting is unavailable")
	# Existing saved grass patches retain their growth and harvest behavior.
	Planting.complete(world, {"kind": "seed_grass", "cell": Vector3i(2, 0, 0)})
	world.uprooted_bushes.append({"berries": 0, "capacity": 1, "regrowth": 0.0, "seed_growth": 0.0})
	world.bush_discovered = true
	world.soil_beds[Vector3i.ZERO] = {"materials": {"log": 1}}
	for spec in [["seed_bush", Vector3i.ZERO], ["seed_palm", Vector3i(4, 0, 0)], ["seed_vegetables", Vector3i(0, 0, 4)]]:
		check(world.request_build(spec[0], spec[1]), "Can queue " + spec[0])
		world._complete_plan(world.plans[world.next_plan_id - 1])
	check(world.deposits[Vector3i.ZERO].inventory.total() == 0, "Collected young bush retains its shoot stage")
	world.Farming.tick_crops(world, 24)
	check(world.gardens[Vector3i(2, 0, 0)].food == 3, "Grass grows without a water delivery")
	check(world.gardens[Vector3i(0, 0, 4)].food == 0, "Vegetables wait for tending")
	world.gardens[Vector3i(0, 0, 4)].water = 1
	world.Farming.tick_crops(world, 24)
	check(world.gardens[Vector3i(0, 0, 4)].food == 3, "Watered vegetables produce food")
	check(world.Economy.field_resource(world, Vector3i(2, 0, 0)) == "grain", "Cut grass feeds the existing hay economy")
	Planting.tick(world, 12)
	check(is_equal_approx(world.deposits[Vector3i.ZERO].seed_growth, 0.5), "Bush has an intermediate growth stage")
	world = reload_world(world)
	Planting.tick(world, 12)
	check(world.deposits[Vector3i.ZERO].inventory.total() == 1 and world.deposits[Vector3i.ZERO].inventory.capacity == 1, "New bush matures into the existing 1/1 berry growth cycle")
	Planting.tick(world, Planting.PALM_SECONDS)
	var palm := Assets.create("palm")
	TreeView.sync(palm, world.trees[Vector3i(4, 0, 0)])
	check(world.trees[Vector3i(4, 0, 0)].kind == "palm" and palm.get_node("Segment3").visible and palm.has_node("Segment3/Crown/Frond"), "Palm keeps its distinct fronds and saved species")
	world.trees[Vector3i(4, 0, 0)].inventory.amounts.log = 0
	TreeView.sync(palm, world.trees[Vector3i(4, 0, 0)])
	check(not palm.get_node("Segment3").visible, "Harvested palm loses its crown")
	palm.free()
	# Harvested hay needs its dedicated storage destination.
	world.buildings[Vector3i(-6, 0, 2)] = {"kind": "hay_barn", "direction": 0}
	world.rebuild_navigation()
	world.set_role(0, "farmer")
	var hay_before: int = world.resource_total("grain")
	var carried := false
	for i in 1200:
		world.tick(0.05)
		carried = carried or world.workers[0].cargo == "grain"
		if world.resource_total("grain") > hay_before: break
	check(carried and world.resource_total("grain") > hay_before, "Grass is physically cut, carried and stored")
	world = fresh()
	check(world.request_build("seed_tree", Vector3i.ZERO), "Queue a cancellable seed order")
	world.order_build(0, world.next_plan_id - 1)
	check(world.delete_plan(world.next_plan_id - 1) and world.workers[0].job.is_empty() and world.gardens.is_empty(), "Deleting an assigned seed order leaves no crop or dangling job")
	world.terrain_shapes[Vector3i.ZERO] = [0.0, 0.1, 0.1, 0.0]
	check(not world.build_error("seed_bush", Vector3i.ZERO).is_empty(), "Seeds reject slopes")
	world.terrain_shapes.clear()
	world.platforms[Vector3i.UP] = true
	world.rebuild_navigation()
	check(not world.build_error("seed_vegetables", Vector3i.UP).is_empty(), "Bare decks cannot receive vegetable seeds")
	world.soil_beds[Vector3i.UP] = {"materials": {"log": 1}}
	check(world.build_error("seed_vegetables", Vector3i.UP).is_empty(), "Soil beds support rooftop vegetables")
	check(not world.build_error("seed_palm", Vector3i.UP).is_empty(), "Trees need natural ground")
	world.soil_beds.clear()
	Planting.complete(world, {"kind": "seed_bush", "cell": Vector3i.ZERO})
	Planting.tick(world, 12)
	check(is_equal_approx(world.deposits[Vector3i.ZERO].seed_growth, 0.05), "Overhead cover slows seed growth to ten percent")
	# Dormant trees preserve partial growth and catch up once; fully harvested trees stay absent.
	var chunk := Vector2i(8, 0)
	world.Chunks.load_chunk(world, chunk)
	var remote := Vector3i(chunk.x * world.Generator.CHUNK_SIZE + 4, 0, 4)
	Planting.complete(world, {"kind": "seed_palm", "cell": remote})
	world.trees[remote].seed_growth = 0.25
	world.Chunks.unload_chunk(world, chunk)
	world = reload_world(world)
	world.time += 30
	world.Chunks.load_chunk(world, chunk)
	check(is_equal_approx(world.trees[remote].seed_growth, 0.5), "Streamed palm resumes saved growth plus elapsed time")
	world.Chunks.unload_chunk(world, chunk)
	world.time += 120
	world.Chunks.load_chunk(world, chunk)
	check(world.trees[remote].inventory.count("log") == 3, "Dormant sapling matures once")
	world.trees[remote].inventory.amounts.clear()
	world.Chunks.unload_chunk(world, chunk)
	world.time += 120
	world.Chunks.load_chunk(world, chunk)
	check(not world.trees.has(remote), "Streaming removes exhausted palms without regrowing them")
	world = fresh()
	world.soil_beds[Vector3i.ZERO] = {"materials": {"log": 1}}
	Planting.complete(world, {"kind": "seed_grass", "cell": Vector3i.ZERO})
	world.gardens[Vector3i.ZERO].growth = 10.0
	world.exploration.reveal(world.navigation.point(Vector3i(4, 0, 0)))
	check(world.Relocation.source_error(world, Vector3i.ZERO).is_empty(), "Planted crop can move independently of its soil bed")
	check(world.Relocation.request(world, Vector3i.ZERO, Vector3i(4, 0, 0), 0, Vector3.ZERO), "Grass relocation queues without construction materials")
	id = world.next_plan_id - 1
	check(world.plans[id].materials.is_empty(), "Seeded crops cannot create timber from relocation")
	world = reload_world(world)
	world.order_build(0, id)
	advance(world, 20)
	check(world.gardens.has(Vector3i(4, 0, 0)) and world.soil_beds.has(Vector3i.ZERO), "Worker carries planted grass and leaves its soil bed in place")
	check(world.construction_materials.get(Vector3i(4, 0, 0), {"log": 2}).is_empty(), "Moved crop retains its zero-material history")
	world = reload_world(world)
	if world.gardens.has(Vector3i(4, 0, 0)):
		world.gardens[Vector3i(4, 0, 0)].food = 3
		check(world.Deconstruction.request(world, Vector3i(4, 0, 0)), "Planted grass can be cleared by a worker")
		id = world.next_plan_id - 1
		world.order_build(0, id)
		for i in 800:
			world.tick(0.05)
			if world.plans.has(id) and world.plans[id].relocation.stage == "salvage": break
		check(world.plans.has(id) and world.plans[id].relocation.parts.count("grain") == 3, "Clearing mature grass recovers hay without inventing food or timber")
		world = reload_world(world)
	# Reject corrupt growth values before they can reach the renderer.
	Planting.complete(world, {"kind": "seed_tree", "cell": Vector3i(8, 0, 0)})
	world.trees[Vector3i(8, 0, 0)].seed_growth = -0.5
	check(not Model.new().restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Invalid saved seed growth is rejected")
	for kind in world.Catalog.SEEDS + ["grass_patch"]:
		var node := Assets.create(kind)
		check(node.get_child_count() > 0, "Renderable planting asset: " + kind)
		node.free()
	if failures.is_empty(): print("PASS: %d seed planting, growth, harvest, streaming and persistence checks" % checks)
	for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
