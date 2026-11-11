extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, text_: String) -> void:
	checks += 1
	if not ok: failures.append(text_)
func _initialize() -> void: call_deferred("run")
func build(world, kind: String, cell: Vector3i) -> void:
	check(world.request_build(kind, cell), "Can plan " + kind + ": " + world.last_message)
	if not world.plans.is_empty(): world._complete_plan(world.plans.values().back())
func run() -> void:
	var world = Model.new()
	world.setup()
	world.trees.clear()
	world.deposits.clear()
	world.water_sources.clear()
	world.plans.clear()
	world.streaming_enabled = false
	world.loaded_chunks.clear()
	world.chunk_details.clear()
	world.terrain_shapes.clear()
	world.ground.clear()
	world.terrain_heights.clear()
	for x in range(-12, 13):
		for z in range(-12, 13):
			world.ground[Vector3i(x, 0, z)] = true
			world.terrain_heights[Vector2i(x, z)] = 0
	world.rebuild_navigation()
	for worker in world.workers: worker.role = "idle"; worker.job = {}; worker.life_stage = "adult"
	var home: Vector3i = world.STARTING_HOUSE
	check(world.stores.size() == 1 and world.buildings[home].kind == "house", "A new settlement starts with a home, without a general pile")
	check(not world.Catalog.CATEGORIES.structure.has("stockpile") and not world.request_build("stockpile", Vector3i.ZERO), "The retired pile cannot be selected or constructed")
	for resource in ["food", "grain", "log", "water"]: check(Economy.accepts(world, home, resource), "Household provisions have a starting destination: " + resource)
	for resource in ["plank", "stone", "block", "pottery"]: check(not Economy.accepts(world, home, resource), "The home does not become universal industrial storage: " + resource)
	world.stores[home].amounts = {"log": 12, "grain": 4, "water": 4}
	check(Economy.storage_space(world, home, "log") == 0 and Economy.storage_space(world, home, "food") == 12, "Fuel and hay cannot use the food reserve")
	world.stores[home].amounts = {"food": 5}
	var carrier: Dictionary = world.workers[0]
	carrier.cell = world.navigation.access_cells(home)[0]
	carrier.position = world.Navigation.point(carrier.cell)
	for resource in ["log", "grain"]:
		carrier.cargo = resource
		carrier.job = {"kind": "restock", "phase": "store", "target": home}
		world.tick_citizen_job(carrier, 0.1)
		check(carrier.cargo.is_empty() and world.stores[home].count(resource) == 1, "Citizens actually deliver starting " + resource + " to the house")
	var saw := Vector3i(0, 0, 0)
	var mason := Vector3i(4, 0, 0)
	build(world, "sawmill", saw)
	build(world, "masonry", mason)
	check(world.stores.has(saw) and world.stores.has(mason), "Completed workshops provide their own output storage")
	for spec in [[saw, "log", "plank"], [mason, "stone", "block"]]:
		var cell: Vector3i = spec[0]
		check(Economy.accepts(world, cell, spec[1]) and Economy.accepts(world, cell, spec[2]), "Workshop accepts only its relevant input and output")
		world.stores[cell].store(spec[1], Economy.resource_capacity(world, cell, spec[1]))
		check(Economy.storage_space(world, cell, spec[1]) == 0 and Economy.storage_space(world, cell, spec[2]) > 0, "Workshop inputs leave room for the produced material")
		carrier.cell = world.navigation.access_cells(cell)[0]
		carrier.position = world.Navigation.point(carrier.cell)
		carrier.cargo = spec[1]
		carrier.job = {"kind": "process", "phase": "work", "target": cell, "output": spec[2], "labour": world.Jobs.Labour.new(0.01)}
		world.tick_citizen_job(carrier, 0.1)
		world.tick_citizen_job(carrier, 0.1)
		check(carrier.cargo.is_empty() and world.stores[cell].count(spec[2]) == 1, "Processed output reaches its workshop without needing a pile")
	# Existing supplies and workshops migrate without resource loss.
	world.add_store(Vector3i(8, 0, 0), {"pottery": 2})
	var before: int = world.resource_total("pottery")
	world.stores.erase(saw)
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Dedicated storage and legacy loose supplies restore")
	check(restored.stores.has(saw) and restored.resource_total("pottery") == before, "Legacy workshops gain empty output buffers without deleting supplies")
	check(not Economy.accepts(restored, Vector3i(8, 0, 0), "pottery"), "Legacy piles can be emptied but accept no new deliveries")
	if failures.is_empty(): print("PASS: %d starting provisions, dedicated storage, processing and migration checks" % checks)
	else:
		for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
