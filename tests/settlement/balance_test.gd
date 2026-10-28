extends SceneTree
const Balance = preload("res://scripts/settlement/balance.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Jobs = preload("res://scripts/settlement/job_system.gd")
var failures: Array[String] = []
var settings_path := "/tmp/pyramida-balance-%d.cfg" % OS.get_process_id()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func write_settings(content: String) -> void:
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	file.store_string(content)

func fresh():
	var world = Model.new()
	world.setup()
	for worker in world.workers: world.set_role(worker.id, "idle")
	return world

func restored(world):
	var copy = Model.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Edited balance permits save/load")
	return copy

func complete(world, kind: String, cell: Vector3i) -> void:
	check(world.request_build(kind, cell), "Can place " + kind)
	if world.plans.has(world.next_plan_id - 1): world._complete_plan(world.plans[world.next_plan_id - 1])

func _initialize() -> void:
	check(Balance._data.warnings.is_empty(), "Shipped settings load without warnings")
	var parsed := Balance.SettingsFile.read(Balance.SETTINGS_PATH)
	var shipped: ConfigFile = parsed.config
	check(parsed.warnings.is_empty() and parsed.errors.is_empty(), "Unified file parses")
	check(shipped.get_section_keys("construction").size() == Balance.BUILDINGS.size(), "Every building is editable in the single file")
	check(shipped.get_section_keys("general").size() == Balance.GENERAL.size(), "Every general setting is present")
	for kind in Balance.COLLECTIONS:
		check(shipped.has_section("gathering." + kind), "Gathering section exists for " + kind)
	for kind in ["sawmill", "windmill", "masonry"]:
		check(shipped.has_section("production." + kind), "Production section exists for " + kind)
	check(Jobs.Labour.GameplaySettingsScript.SETTINGS_PATH == Balance.SETTINGS_PATH, "Both game versions read the same file")
	check(Jobs.Labour.GameplaySettingsScript.SUPPORT_RECIPE == {"log": 4}, "Legacy recipe still loads")
	# Real edited file, with reordered sections, comments and Windows line endings.
	write_settings(("; Custom tuning\n[construction]\nstairs = 0.75 ; work per material\n"
		+ "[gathering.tree]\nseconds_per_action = 0.5\n"
		+ "[gathering.hay]\nseconds_per_action = 0.25\n"
		+ "[gathering.water]\nseconds_per_action = 0.25\n"
		+ "[production.sawmill]\nseconds_per_batch = 0.5\noutput_items = 5\nautomatic_stock_target = 20\n"
		+ "[general]\nsowing_seconds = 1.25\ncrop_growth_seconds = 2\nwalk_speed = 4\n").replace("\n", "\r\n"))
	var original := Balance._data
	Balance._data = Balance.load_file(settings_path)
	check(Balance._data.warnings.is_empty(), "Sectioned key-value settings load")
	check(Balance.construction_seconds("house") == 2.0, "Missing keys retain defaults")
	check(Balance.gathering("tree").keys() == ["seconds_per_action"], "Gathering exposes work time only")
	test_building()
	test_gathering()
	test_production()
	test_hay()
	test_water()
	Balance._data = original
	# Bad user input must be diagnosed without invalidating other fields.
	write_settings("[gathering.tree]\nseconds_per_action = 0\nitems_per_action = 1.5\n"
		+ "[gathering.berry]\nseconds_per_action = 0.25\nunknown = 8\n"
		+ "[gathering.unknown]\nseconds_per_action = 2\n"
		+ "[general]\nwalk_speed = \"fast\"\nday_seconds = 0\nunknown = 5\n")
	var invalid := Balance.load_file(settings_path)
	check(invalid.warnings.size() == 7, "Invalid numbers and unknown sections/keys are diagnosed")
	check(invalid.gathering.tree.seconds_per_action == 3.0 and not invalid.gathering.tree.has("items_per_action"), "Invalid numbers fall back and removed setting is rejected")
	check(invalid.gathering.berry.seconds_per_action == 0.25, "Valid neighbouring settings survive")
	check(invalid.general.walk_speed == 2.25 and invalid.general.day_seconds == 360.0, "Bad scalars fall back")
	DirAccess.remove_absolute(settings_path)
	var missing := Balance.load_file(settings_path)
	check(missing.warnings.size() == 1 and missing.production.sawmill.output_items == 1, "Missing file safely uses defaults")
	for message in failures: printerr("FAIL: " + message)
	if failures.is_empty(): print("PASS: single settings file, validation, gathering conservation, production, construction and save/load")
	quit(int(not failures.is_empty()))

func test_building() -> void:
	var world = fresh()
	check(world.request_build("stairs", Vector3i.ZERO), "Queue tuned ladder")
	check(Jobs._assign_build(world, world.workers[0]), "Assign tuned construction")
	check(world.workers[0].job.labour.required_seconds == 0.75, "Construction reads edited duration")
	var plan: Dictionary = world.plans.values()[0]
	check(Jobs.construction_progress(plan, world.workers).required_seconds == 2.25, "Total progress uses tuned per-material duration")
	world = restored(world)
	check(world.workers[0].job.labour.required_seconds == 0.75, "Construction duration survives saving")
	world = fresh()
	world.trees.clear()
	world.rebuild_navigation()
	check(world.request_build("seed_tree", Vector3i.ZERO), "Queue tuned sowing")
	world = restored(world)
	check(world.plans.values()[0].sowing.required_seconds == 1.25, "Non-default sowing duration survives saving")

func test_gathering() -> void:
	var world = fresh()
	complete(world, "log_shed", Vector3i(-4, 0, 0))
	var worker: Dictionary = world.workers[0]
	var source: Variant = null
	for cell: Vector3i in world.trees:
		world.exploration.reveal(Jobs.Navigation.point(cell))
		if Jobs._assign_collection(world, worker, cell, "log", "fell"):
			source = cell
			break
	check(source != null, "Assign one-log collection with configured work time")
	if source == null: return
	var inventory = world.trees[source].inventory
	var before: int = inventory.count("log")
	check(inventory.reserve(worker.id, "log"), "Reserve first log")
	worker.job.source = inventory
	worker.job.collection_amount = 8 # Simulate a pending job from an older save.
	world = restored(world)
	worker = world.workers[0]
	inventory = world.trees[source].inventory
	check(not worker.job.has("collection_amount"), "Old gathering batch is removed on load")
	check(inventory.reserve(1, "log"), "Another worker reserves a log")
	check(worker.job.labour.required_seconds == 0.5, "Gather duration comes from settings")
	for tick in 1500:
		Jobs._tick_worker(world, worker, 0.05)
		if worker.job.get("phase") == "store": break
	check(worker.cargo == "log" and worker.cargo_amount == 1 and inventory.count("log") == before - 1, "One completed action transfers exactly one log")
	check(inventory.reservations.has(1), "Other reservation is protected")
	inventory.release(1)
	world = restored(world)
	worker = world.workers[0]
	var cargo: int = worker.cargo_amount
	var stock_before: int = world.resource_total("log")
	# Cancelling a job keeps the collected item for delivery.
	world.set_role(0, "idle")
	for tick in 1500:
		Jobs._tick_worker(world, worker, 0.05)
		if worker.cargo.is_empty(): break
	check(worker.cargo.is_empty() and world.resource_total("log") == stock_before + cargo, "Interrupted gathering delivers every carried item")
	world.trees[source].inventory.amounts["log"] = 0
	check(not Jobs._assign_collection(world, worker, source, "log", "fell"), "Empty trees cannot produce more logs")

func test_production() -> void:
	var world = fresh()
	complete(world, "sawmill", Vector3i(-4, 0, 0))
	var worker: Dictionary = world.workers[0]
	check(Jobs._assign_recipe(world, worker, "sawmill"), "Assign production from settings")
	if worker.job.is_empty(): return
	check(worker.job.labour.required_seconds == 0.5 and worker.job.yield == 5, "Batch time and output come from settings")
	world = restored(world)
	worker = world.workers[0]
	for tick in 1500:
		Jobs._tick_worker(world, worker, 0.05)
		if worker.job.get("phase") == "store": break
	check(worker.cargo == "plank" and worker.cargo_amount == 5, "Production creates configured batch")
	world = restored(world)
	check(world.workers[0].cargo_amount == 5, "Larger production loads survive save/load")

func test_hay() -> void:
	var world = fresh()
	world.vines.clear()
	var cell := Vector3i(-4, 0, -4)
	complete(world, "hay_field", cell)
	complete(world, "hay_barn", Vector3i(-4, 0, 0))
	world.gardens[cell].water = 1
	world.Farming.tick_crops(world, 2.0)
	check(world.gardens[cell].food == 4, "Crop growth reads key-value setting")
	var worker: Dictionary = world.workers[0]
	check(Jobs._assign_collection(world, worker, cell, "grain", "harvest"), "Assign one-quarter harvest")
	if worker.job.is_empty(): return
	world.gardens[cell].reserved = worker.id
	for tick in 1500:
		Jobs._tick_worker(world, worker, 0.05)
		if worker.job.get("phase") == "store": break
	check(worker.cargo_amount == 1 and world.gardens[cell].food == 3, "One completed action cuts exactly one quarter")
	world = restored(world)
	check(world.gardens[cell].food == 3, "Quarter mask remains save-compatible")

func test_water() -> void:
	var world = fresh()
	var cell: Vector3i = world.water_sources.keys()[0]
	world.exploration.reveal(Jobs.Navigation.point(cell))
	var inventory = world.water_sources[cell].inventory
	inventory.amounts["water"] = 3
	inventory.capacity = maxi(3, inventory.capacity)
	world.water_orders[cell] = 3
	var worker: Dictionary = world.workers[0]
	world.set_role(0, "hauler")
	Jobs._assign(world, worker)
	check(worker.job.get("kind") == "collect_water" and not worker.job.has("collection_amount"), "Water collection has no batch-size setting")
	if worker.job.get("kind") != "collect_water": return
	check(world.water_orders[cell] == 2, "Water order subtracts one assigned item")
	world.set_role(0, "idle")
	check(world.water_orders[cell] == 3, "Cancelling unfinished work restores one ordered item")
	world.set_role(0, "hauler")
	Jobs._assign(world, worker)
	worker.job.collection_amount = 2
	world.water_orders[cell] = 1
	world = restored(world)
	worker = world.workers[0]
	inventory = world.water_sources[cell].inventory
	check(world.water_orders[cell] == 2 and not worker.job.has("collection_amount"), "Old pending water batches restore uncollected orders")
	for tick in 1500:
		Jobs._tick_worker(world, worker, 0.05)
		if worker.job.get("phase") == "store": break
	check(worker.cargo == "water" and worker.cargo_amount == 1 and inventory.count("water") == 2, "Water collection transfers exactly one existing item")
	world.set_role(0, "idle")
	check(world.water_orders[cell] == 2, "A completed collection is not refunded on role change")
