extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Scene = preload("res://scenes/settlement/Terraces.tscn")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void:
	call_deferred("run")
func reload_world(world):
	var result = Model.new()
	check(result.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Bush collection state restores through JSON")
	return result
func advance_until_done(world, id: int) -> void:
	for i in 800:
		world.tick(0.05)
		if not world.plans.has(id): return
	check(false, "Worker completes bush order")
func population(world) -> int:
	var count: int = world.uprooted_bushes.size()
	for bush: Dictionary in world.deposits.values(): count += int(bush.kind == "berry")
	for plan: Dictionary in world.plans.values(): count += int(plan.has("bush_payload"))
	return count
func run() -> void:
	var world = Model.new()
	world.setup()
	for collection in [world.trees, world.deposits, world.vines, world.water_sources]: collection.clear()
	for worker: Dictionary in world.workers: world.set_role(worker.id, "idle")
	var source := Vector3i.ZERO
	var target := Vector3i(4, 0, 0)
	world.deposits[source] = world.Chunks.entry("berry", "food", 3)
	world.deposits[source].inventory.amounts.food = 2
	world.deposits[source].regrowth = 75.25
	world.rebuild_navigation()
	check(not world.request_build("seed_bush", target), "No unlimited bush seeds")
	check(world.replant_bush(source), "Move collects a bush with berries")
	check(not world.replant_bush(source), "Cannot queue duplicate collection")
	var id: int = world.next_plan_id - 1
	check(not world.order_build(2, id), "Children cannot uproot a bush")
	check(world.order_build(0, id), "Adult can uproot the bush")
	for i in 500:
		world.tick(0.05)
		if world.plans[id].relocation.labour.applied_seconds > 0.25: break
	check(world.uprooted_bushes.is_empty() and world.deposits.has(source), "Collection requires physical labour")
	world = reload_world(world)
	advance_until_done(world, id)
	world.set_role(0, "idle")
	check(world.uprooted_bushes.size() == 1 and not world.deposits.has(source) and population(world) == 1, "Uprooting transfers exactly one bush")
	var payload: Dictionary = world.uprooted_bushes[0].duplicate()
	check(payload.berries == 2 and payload.capacity == 3 and payload.regrowth == 75.25, "Collection preserves berries, capacity and partial growth")
	check(world.build_error("seed_bush", target) == "Prepared soil required", "Bare ground cannot receive a bush")
	check(world.request_build("soil_bed", target), "Prepare a soil bed")
	check(not world.request_build("seed_bush", target), "An unfinished soil bed is not farmland yet")
	world._complete_plan(world.plans[world.next_plan_id - 1])
	check(world.request_build("seed_bush", target), "A collected bush can be planted on completed soil")
	id = world.next_plan_id - 1
	check(world.uprooted_bushes.is_empty() and population(world) == 1, "Planting reserves the only bush")
	check(not world.request_build("seed_bush", Vector3i(8, 0, 0)), "A reserved bush cannot be duplicated")
	check(not world.Deconstruction.request(world, target), "Reserved planting protects its soil foundation")
	world = reload_world(world)
	check(world.move_plan(id, target, 0, Vector3.ZERO), "Reserved planting remains movable with zero available bushes")
	check(world.delete_plan(id) and population(world) == 1, "Deleting an order returns one bush")
	for key in payload:
		check(is_equal_approx(float(world.uprooted_bushes[0][key]), float(payload[key])), "Returned bush retains " + key)
	world = reload_world(world)
	check(world.request_build("seed_bush", target), "Returned bush can be replanted")
	id = world.next_plan_id - 1
	check(world.order_build(1, id), "An adult performs planting")
	advance_until_done(world, id)
	world.set_role(1, "idle")
	check(world.deposits.has(target) and world.soil_beds.has(target) and population(world) == 1, "Planting keeps the bush and soil separate")
	check(world.deposits[target].inventory.count("food") == 2 and world.deposits[target].inventory.capacity == 3, "Replanting does not reset the bush to a seedling")
	check(world.Relocation.kind_at(world, target) == "berry" and not world.Deconstruction.request(world, target), "Selecting a bush on soil cannot dismantle its foundation")
	check(world.replant_bush(target), "A planted bush can be collected again")
	id = world.next_plan_id - 1
	world.order_build(0, id)
	advance_until_done(world, id)
	world.set_role(0, "idle")
	check(world.soil_beds.has(target) and not world.deposits.has(target) and population(world) == 1, "Repeated collection never creates a bush or removes soil")
	# Other crops occupy their soil; adjoining beds can support a small plot between them.
	world.gardens[target] = {"species": "grass", "water": 0, "growth": 0.0, "food": 0, "reserved": -1}
	check(not world.build_error("seed_bush", target).is_empty(), "Occupied farmland rejects a bush")
	world.gardens.erase(target)
	check(not world.Farming.bush_soil_ready(world, target + Vector3i.RIGHT), "A half-supported bush plot is rejected")
	world.soil_beds[target + Vector3i(2, 0, 0)] = {"materials": {"log": 1}}
	check(world.Farming.bush_soil_ready(world, target + Vector3i.RIGHT), "Adjoining prepared beds support an intermediate bush plot")
	var upper := Vector3i(0, 1, 0)
	world.platforms[upper] = true
	world.rebuild_navigation()
	check(not world.build_error("seed_bush", upper).is_empty(), "Bare decks reject bushes")
	world.soil_beds[upper] = {"materials": {"log": 1}}
	check(world.build_error("seed_bush", upper).is_empty(), "Raised soil beds accept bushes")
	# Collection tombstones survive streaming; the uprooted plant remains in inventory.
	var chunk: Vector2i = world.Chunks.chunk_for(source)
	world.Chunks.unload_chunk(world, chunk)
	world = reload_world(world)
	world.Chunks.load_chunk(world, chunk)
	check(not world.deposits.has(source) and not world.deposits.has(target) and population(world) == 1, "Streaming does not respawn collected bushes")
	var game = Scene.instantiate()
	game.launch_to_menu = false
	game.capture = true
	root.add_child(game)
	game.set_process(false)
	game.model = world
	game.hud.show_category("nature")
	game.hud.update(world, -1, 1)
	var row: Button = game.hud.buttons.seed_bush
	check(row.visible and not row.disabled and row.get_meta("plant_title").text == "Berry bush (1)", "Collected bush appears with its available count")
	game._set_tool("seed_bush")
	check(game.preview.has_node("Leaves0") and game.preview.scale == Vector3.ONE, "Planting preview shows the collected mature bush")
	check(world.request_build("seed_bush", target), "UI fixture reserves collected bush")
	id = world.next_plan_id - 1
	game.hud.update(world, -1, 1)
	check(row.visible and row.disabled and row.get_meta("plant_title").text == "Berry bush (0)", "Exhausted bush entry stays disabled at zero")
	game.moving_plan_id = id
	game._refresh_preview()
	check(game.preview.has_node("Leaves0") and game.preview.scale == Vector3.ONE, "Moving a reserved order previews its bush even with zero stock")
	world.delete_plan(id)
	game._set_tool("inspect")
	world.uprooted_bushes.clear()
	world.bush_discovered = false
	world.deposits[source] = world.Chunks.entry("berry", "food", 3)
	world.rebuild_navigation()
	game.world.sync(world, 0, -1)
	game.selected_object = {"cell": source, "kind": "berry", "entity_key": "deposit:%s" % source}
	game.hud.update(world, -1, 1, game.selected_object)
	check(not row.visible and game.hud.move_label == "Move", "Undiscovered bush menu stays hidden and selected bush offers Move")
	game.hud.move_button.pressed.emit()
	check(world.plans.values().any(func(plan): return plan.get("collect_bush", false)) and game.relocation_source == null, "Move queues collection before choosing a planting spot")
	game.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d bush collection, soil, conservation, persistence and menu checks" % checks)
	quit(int(not failures.is_empty()))
