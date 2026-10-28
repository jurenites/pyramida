extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
const Tooltip = preload("res://scripts/settlement/object_tooltip.gd")
const SOURCE := Vector3i.ZERO
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fresh():
	var world = Model.new()
	world.setup()
	world.trees.clear()
	world.deposits.clear()
	world.water_sources.clear()
	for worker in world.workers:
		world.set_role(worker.id, "idle")
		worker.hunger = 0
	world.exploration.reveal(Nav.point(Vector3i(4, 0, 0)))
	return world

func complete(world, kind: String, cell := SOURCE) -> void:
	check(world.request_build(kind, cell), "Fixture can build " + kind)
	if world.plans.is_empty(): return
	world._complete_plan(world.plans.values().back())

func reload_world(world):
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Deconstruction JSON restores")
	return restored

func advance_until(world, done: Callable, limit := 1200) -> void:
	for i in limit:
		if done.call(): return
		# Isolate salvage accounting from eating or production.
		for worker in world.workers: worker.hunger = 0
		world.tick(0.05)

func test_lifecycle() -> void:
	var world = fresh()
	complete(world, "pantry")
	world.stores[SOURCE].store("food", 7)
	var before_logs: int = world.resource_total("log")
	check(world.Deconstruction.request(world, SOURCE), "Remove queues completed storage")
	var id: int = world.next_plan_id - 1
	check(world.buildings.has(SOURCE) and world.resource_total("log") == before_logs, "Queue preserves source and gives no instant refund")
	check(not world.Deconstruction.request(world, SOURCE), "Duplicate removal rejected")
	check(not world.request_build("house", SOURCE + Vector3i.UP), "Cannot add upper floor over removal")
	check(world.order_build(0, id), "Builder accepts removal site")
	advance_until(world, func(): return world.plans[id].relocation.labour.applied_seconds >= 0.5)
	var applied: float = world.plans[id].relocation.labour.applied_seconds
	check(applied > 0 and world.buildings.has(SOURCE), "Builder applies work before source disappears")
	world.set_role(0, "idle")
	world = reload_world(world)
	check(is_equal_approx(world.plans[id].relocation.labour.applied_seconds, applied), "Partial dismantling survives interruption and save")
	check(world.order_build(1, id), "Another builder resumes dismantling")
	advance_until(world, func(): return world.plans[id].relocation.stage == "salvage")
	check(not world.buildings.has(SOURCE) and not world.stores.has(SOURCE), "Dismantling removes building and inventory location")
	var parts = world.plans[id].relocation.parts
	check(parts.count("log") == 4 and parts.count("plank") == 4 and parts.count("food") == 7, "Exact original recipe and stored food become physical salvage")
	world.set_role(1, "idle")
	world = reload_world(world)
	check(world.plans[id].relocation.parts.count("food") == 7, "Unhauled parts survive save")
	var info := Tooltip.describe(world, {"cell": SOURCE, "kind": "pantry", "entity_key": "plan:%s" % id})
	check(info.rows.size() == 3, "Salvage inspection lists actual remaining resources")
	# Full storage must leave material physically at the site.
	var store = world.stores.values()[0]
	store.capacity = store.total()
	world.set_role(1, "builder")
	check(not world.Jobs._assign_build(world, world.workers[1]), "Full storage leaves salvage unclaimed")
	check(world.plans[id].relocation.parts.total() == 15, "No parts lost when storage is full")
	store.capacity = 100
	complete(world, "log_shed", Vector3i(-4, 0, 0))
	complete(world, "house", Vector3i(4, 0, 0))
	world.revision += 1
	check(world.Jobs._assign_build(world, world.workers[1]), "Builder reserves salvage after storage opens")
	world = reload_world(world)
	check(world.workers[1].job.source == world.plans[id].relocation.parts, "Save preserves shared salvage reservation identity")
	advance_until(world, func(): return not world.plans.has(id) and world.workers[1].cargo.is_empty(), 2400)
	check(not world.plans.has(id), "Site clears after every physical pickup")
	check(world.resource_total("log") == before_logs + 4 and world.resource_total("plank") == 4 and world.resource_total("food") == 12, "All recovered materials and contents reach storage exactly once")
	world = reload_world(world)
	check(not world.construction_materials.has(SOURCE), "Removed construction history is retired")

func test_support_and_legacy() -> void:
	var world = fresh()
	complete(world, "house")
	complete(world, "house", SOURCE + world.Grid.STOREY)
	check(not world.Deconstruction.request(world, SOURCE), "Load-bearing source cannot be removed")
	world = fresh()
	complete(world, "stockpile")
	world.construction_materials[SOURCE] = {"log": 2}
	check(world.Deconstruction.request(world, SOURCE), "Legacy pile can be removed")
	var id: int = world.next_plan_id - 1
	world.order_build(0, id)
	advance_until(world, func(): return world.plans[id].relocation.stage == "salvage")
	check(world.plans[id].relocation.parts.count("log") == 2 and world.plans[id].relocation.parts.count("stone") == 0, "Legacy pile returns actual timber instead of current stone recipe")
	world = reload_world(world)
	check(world.plans[id].materials == {"log": 2}, "Legacy deconstruction recipe saves")
	world = fresh()
	complete(world, "platform", SOURCE + Vector3i.UP)
	check(world.Deconstruction.request(world, SOURCE + Vector3i.UP), "Unoccupied platform queues removal")
	id = world.next_plan_id - 1
	world.order_build(0, id)
	advance_until(world, func(): return world.plans[id].relocation.stage == "salvage")
	check(not world.platforms.has(SOURCE + Vector3i.UP), "Platform removal does not block on its own site")

func test_reuse_without_storage() -> void:
	var world = fresh()
	world.stores.clear()
	complete(world, "stockpile")
	check(world.Deconstruction.request(world, SOURCE), "Last storage plot can be dismantled")
	var old_id: int = world.next_plan_id - 1
	world.order_build(0, old_id)
	advance_until(world, func(): return world.plans[old_id].relocation.stage == "salvage")
	check(world.stores.is_empty(), "Last store is gone and its stone remains on site")
	check(world.request_build("stockpile", Vector3i(4, 0, 0)), "Replacement plot accepts normal construction")
	world.order_build(0, world.next_plan_id - 1)
	advance_until(world, func(): return not world.workers[0].cargo.is_empty())
	check(world.workers[0].cargo == "stone", "Builder physically picks up recovered stone without a store")
	world = reload_world(world)
	advance_until(world, func(): return world.plans.is_empty())
	check(world.stores.has(Vector3i(4, 0, 0)) and world.plans.is_empty(), "Recovered stone rebuilds storage and clears both sites")

func test_controls() -> void:
	var game = preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-deconstruction-test-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.model = fresh()
	complete(game.model, "house")
	game.model.buildings[SOURCE].direction = 2
	game.selected_object = {"cell": SOURCE, "kind": "house", "entity_key": "building:%s" % SOURCE}
	game.hud.update(game.model, -1, 1, game.selected_object)
	for frame in 3: await process_frame
	check(game.hud.copy_button.visible and game.hud.removal_button.visible, "Copy and Remove appear with Move")
	check(game.hud.copy_button.get_parent() == game.hud.selection_toolbar, "Actions belong to the top-center selection menu")
	check(is_equal_approx(game.hud.selection_toolbar.get_global_rect().get_center().x, game.hud.root.size.x / 2.0), "Three-button menu remains centered")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_C
	game._unhandled_input(key)
	check(game.tool == "house" and game.direction == 2 and is_instance_valid(game.preview), "C starts a copy with source orientation")
	check(game.model.plans.is_empty() and game.model.buildings.has(SOURCE), "Copy preview neither duplicates inventory nor moves source")
	key.physical_keycode = KEY_R
	game._unhandled_input(key)
	check(game.direction == 3 and game.model.plans.is_empty(), "R rotates during placement without removing source")
	game._set_tool("inspect")
	game.hud.copy_button.pressed.emit()
	check(game.tool == "house", "Copy button starts placement")
	game._set_tool("inspect")
	key.physical_keycode = KEY_R
	game._unhandled_input(key)
	check(game.model.plans.size() == 1 and game.model.plans.values()[0].get("deconstruction", false), "R queues deconstruction while inspecting")
	check(game.selected_object.entity_key.begins_with("plan:"), "Removal selects its construction site")
	check(not game.hud.copy_button.visible and not game.hud.removal_button.visible, "Queued removal cannot be duplicated through actions")
	game.world.sync(game.model, 0, -1)
	var id: int = game.model.next_plan_id - 1
	check(game.world.entity_views.has("plan:%s" % id) and not game.world.entity_views.has("building:%s" % SOURCE), "Removal site replaces the source view without duplicate geometry")
	game.hud.update_selection(game.world, game.rig.camera, game.selected_object, game.model)
	check(game.hud.work_bars.size() == 1, "Selected removal site shows dismantling progress")
	game.model.order_build(0, id)
	advance_until(game.model, func(): return game.model.plans[id].relocation.stage == "salvage")
	game.world.sync(game.model, 0, -1)
	var visible_parts := 0
	for name: String in game.world.entity_views:
		if name.begins_with("parts:%s:" % id): visible_parts += 1
	check(visible_parts == 5, "Each recovered timber has a physical world piece")
	game.hud.update_selection(game.world, game.rig.camera, game.selected_object, game.model)
	check(game.hud.work_bars.is_empty(), "Completed dismantling hides its work bar")
	game.free()

func run() -> void:
	test_lifecycle()
	test_support_and_legacy()
	test_reuse_without_storage()
	await test_controls()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d copy and deconstruction checks" % checks)
	quit(int(not failures.is_empty()))
