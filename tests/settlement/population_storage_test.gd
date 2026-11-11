extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Tooltip = preload("res://scripts/settlement/object_tooltip.gd")
const HUD = preload("res://scripts/settlement/hud.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func house(world, cell: Vector3i) -> void:
	world.buildings[cell] = {"kind": "house", "direction": 0}
func fresh():
	var world = Model.new()
	world.setup()
	preload("res://tests/settlement/supplied_pile_fixture.gd").add_to(world)
	world.trees.clear()
	world.deposits.clear()
	world.vines.clear()
	world.rebuild_navigation()
	return world
func run_for(world, seconds: float) -> void:
	for i in ceili(seconds / 0.1): world.tick(0.1)
func run() -> void:
	var world = fresh()
	var first := Vector3i.ZERO
	var joined := Vector3i(0, 0, 2)
	var separate := Vector3i(4, 0, 0)
	house(world, first)
	house(world, joined)
	house(world, separate)
	world.rebuild_navigation()
	check(Economy.capacity(world) == 3, "Only completed rooms supply one place each")
	check(world.Houses.totals(world, first).residents == 2 and world.Houses.totals(world, first).capacity == 2, "Joined rooms count their own residents and beds")
	check(Tooltip.describe(world, {"kind": "house", "cell": separate}).rows[0].value == "1/1", "Separate house has one resident")
	check(Tooltip.describe(world, {"kind": "house", "cell": joined}).rows[0].value == "2/2", "Either connected room shows the same household")
	check(world.stores[first].capacity == world.Houses.ROOM_STORAGE and Economy.storage_capacity(world, "food") == 17, "Homes add four food spaces each while preserving five legacy meals")
	world.workers[0].home_cell = separate
	world.workers[2].erase("home_cell")
	world.Houses.reconcile(world)
	check(Tooltip.describe(world, {"kind": "house", "cell": separate}).rows[0].value == "1/1", "Reassigned home remains within its one-person capacity")
	var copy = Model.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Resident assignments and home inventories save and load")
	check(copy.workers[0].home_cell == separate and copy.stores[first].capacity == world.Houses.ROOM_STORAGE, "Saved home identity is stable")
	# Simulate an older save with houses but neither resident assignments nor food stores.
	for worker in world.workers: worker.erase("home_cell")
	for cell in [first, joined, separate]: world.stores.erase(cell)
	check(copy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Legacy houses load without food stores")
	check(copy.stores.has(first) and copy.Houses.totals(copy, first).residents == 2, "Legacy homes gain real inventories and one resident per room")
	world = copy
	house(world,Vector3i(8,0,0))
	world.rebuild_navigation()
	world.stores[first].store("food", 4)
	Economy.tick(world, 60.0)
	check(world.birth_clock == 60.0, "Reachable vacant housing earns birth progress")
	for inventory in world.stores.values(): inventory.amounts.erase("food")
	Economy.tick(world, 30.0)
	check(world.birth_clock == 90.0 and world.workers.size() == 3, "Empty food stores do not pause housing-based birth progress")
	world.stores[first].store("food", 4)
	Economy.tick(world, 30.0)
	check(world.workers.size() == 4 and world.workers[3].life_stage == "child", "Reachable housing completes birth after the full interval")
	check(world.Houses.room_occupancy(world, world.workers[3].home_cell) == 1, "New child receives the room's one place")
	check(world.navigation.walkable(world.workers[3].cell), "Child spawns outside solid house walls")
	var view = View.new()
	root.add_child(view)
	view.setup(world)
	view.sync(world, 0, -1)
	check(view.actors.size() == 4, "Birth immediately creates a visible child actor")
	check(view.entity_views.has("building:%s" % first) and not view.entity_views.has("stockpile:%s" % first), "Home food storage does not duplicate house geometry")
	view.free()
	var hud = HUD.new()
	root.add_child(hud)
	hud.update(world, -1, 1)
	check(hud.resource_counts.citizens.text == "4/4", "Top population shows current residents over village beds")
	check(hud.resource_counts.food.text == "4/16  −4", "Four rooms show sixteen food capacity and population meal demand")
	check(hud.resource_counts.log.text == "18/18", "Legacy timber remains countable without inventing Home timber storage")
	for resource in Economy.RESOURCES: world.discover_resource(resource)
	hud.update(world, -1, 1)
	for frame in 3: await process_frame
	for count in hud.resource_counts.values():
		check(hud.root.get_global_rect().encloses(count.get_global_rect()), "Wrapped capacity readout stays within viewport")
	hud.free()
	# Dedicated destinations and physical migration of old supplies.
	var shed := Vector3i(-4, 0, 0)
	var barn := Vector3i(4, 0, 4)
	world.buildings[shed] = {"kind": "log_shed", "direction": 0}
	world.add_store(shed)
	world.buildings[barn] = {"kind": "hay_barn", "direction": 0}
	world.add_store(barn)
	world.rebuild_navigation()
	var pile := Vector3i(-6, 0, 2)
	for resource in ["log", "food", "grain"]:
		check(not Economy.accepts(world, pile, resource), "Pile rejects " + resource)
	for resource in ["stone", "block", "plank", "water"]:
		check(not Economy.accepts(world, pile, resource), "Retired pile accepts no new " + resource)
	check(Economy.accepts(world, shed, "log") and not Economy.accepts(world, shed, "plank"), "Log shed is exclusive to logs")
	check(Economy.accepts(world, barn, "grain") and not Economy.accepts(world, barn, "food"), "Hay barn is exclusive to hay")
	check(Economy.accepts(world, first, "food") and Economy.accepts(world, first, "log"), "House stores food and fuel")
	for worker in world.workers:
		worker.hunger = 0.0
		worker.role = "hauler"
	world.stores[pile].store("food", 2)
	var before: int = world.resource_total("log")
	run_for(world, 120)
	check(world.stores[shed].count("log") > 0 and world.resource_total("log") == before, "Haulers move legacy logs without duplication or loss")
	check(world.stores[pile].count("food") == 0, "Food leaves the old pile for homes or meals")
	check(copy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "In-flight transfers and expanded family reload")
	world = fresh()
	var carrier: Dictionary = world.workers[0]
	carrier.cargo = "log"
	carrier.role = "builder"
	carrier.job = {"kind": "restock", "phase": "store", "target": carrier.cell, "labour": world.Jobs.Labour.new(0.6)}
	check(world.request_build("log_shed", Vector3i.ZERO), "Carrier can plan the first dedicated shed")
	world.Jobs._tick_worker(world, carrier, 0.0)
	check(carrier.job.get("kind") == "build" and carrier.cargo == "log", "Legacy cargo can build its storage instead of waiting forever for a shed")
	check(world.plans[carrier.job.plan_id].reserved == 1, "Reused cargo claims exactly one building material")
	# Both new arrivals and saved unloading jobs deposit without applying labour.
	for phase in ["travel", "work"]:
		world = fresh()
		world.buildings[shed] = {"kind": "log_shed", "direction": 0}
		world.add_store(shed)
		world.rebuild_navigation()
		carrier = world.workers[0]
		carrier.cell = world.navigation.access_cells(shed)[0]
		carrier.position = world.navigation.surface_point(carrier.cell)
		carrier.route = []
		carrier.route_index = 0
		carrier.cargo = "log"
		carrier.cargo_amount = 2
		carrier.hunger = 140.0
		carrier.job = {"kind": "restock", "phase": phase, "target": shed, "labour": world.Jobs.Labour.new(0.6)}
		copy = Model.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Storage delivery restores in " + phase)
		world = copy
		carrier = world.workers[0]
		var labour = carrier.job.labour
		var deliveries: int = world.deliveries
		world.Jobs._tick_worker(world, carrier, 0.0)
		check(world.stores[shed].count("log") == 2 and carrier.cargo.is_empty() and carrier.job.is_empty(), "Arrival stores the entire cargo without elapsed work in " + phase)
		check(labour.applied_seconds == 0.0 and world.deliveries == deliveries + 1, "Storage applies no labour and counts one delivery in " + phase)
		world.stores[shed].store("log", world.stores[shed].capacity - 3)
		carrier.cargo = "log"
		carrier.cargo_amount = 2
		carrier.job = {"kind": "restock", "phase": phase, "target": shed, "labour": world.Jobs.Labour.new(0.6)}
		world.Jobs._tick_worker(world, carrier, 0.0)
		check(carrier.cargo == "log" and carrier.cargo_amount == 2 and carrier.job.phase == "store", "Full destination preserves cargo for another store in " + phase)
		check(world.stores[shed].total() == world.stores[shed].capacity - 1 and world.deliveries == deliveries + 1, "Failed deposit neither partially stores nor counts a delivery in " + phase)
	# This is the original regression: ordinary auto workers must reach a birth
	# without injected food or a manually assigned forager.
	world = Model.new()
	world.setup()
	house(world, Vector3i.ZERO)
	house(world, Vector3i(0, 0, 2))
	house(world, Vector3i(4, 0, 0))
	world.rebuild_navigation()
	for cell: Vector3i in world.deposits: world.exploration.reveal(world.Navigation.point(cell))
	run_for(world, 420)
	check(world.workers.size() > 3, "Automatic foraging sustains growth from the starting family")
	if failures.is_empty(): print("PASS: %d population, household, dedicated storage and HUD checks" % checks)
	for message in failures: printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))
