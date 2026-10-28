extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
const SOURCE := Vector3i.ZERO
const TARGET := Vector3i(4, 0, 0)
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func fresh():
	var model = Model.new()
	model.setup()
	model.trees.clear()
	model.deposits.clear()
	model.water_sources.clear()
	for worker in model.workers: model.set_role(worker.id, "idle")
	model.exploration.reveal(Nav.point(TARGET))
	check(model.request_build("house", SOURCE), "Queue empty construction site")
	return model

func reload_world(model):
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Construction action round-trips through JSON")
	return restored

func advance_until(model, done: Callable) -> void:
	for tick in 2400:
		if done.call(): return
		for worker in model.workers: worker.hunger = 0
		model.tick(0.05)
	check(false, "Simulation reached expected state")

func click_action(game, button: Button) -> void:
	for frame in 3: await process_frame
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	check(button.button_pressed, "Mouse press reaches the action button")
	# Real clicks span frames while the HUD refreshes its selection actions.
	for frame in 3:
		game.hud.update(game.model, game.selected, game.speed, game.selected_object)
		await process_frame
	check(button.button_pressed, "HUD refresh preserves the held action button")
	click.pressed = false
	root.push_input(click, true)

func test_unstarted() -> void:
	var model = fresh()
	var id: int = model.next_plan_id - 1
	var stock: int = model.resource_total("log")
	check(model.move_plan(id, SOURCE + Vector3i.RIGHT, 1, Vector3(0.1, 0, 0)), "Empty site can move within its former footprint")
	check(model.plans.size() == 1 and model.plans[id].installed == 0 and model.resource_total("log") == stock, "Move retains identity without consuming materials")
	check(not model.move_plan(id, model.stores.keys()[0], 0, Vector3.ZERO), "Occupied destination rejected")
	check(model.plans[id].cell == SOURCE + Vector3i.RIGHT, "Failed move leaves the site untouched")
	model = reload_world(model)
	check(model.delete_plan(id) and model.plans.is_empty(), "Delete removes untouched site immediately")
	check(model.resource_total("log") == stock and model.build_error("house", SOURCE).is_empty(), "Deleting an empty site creates no refund and frees placement")
	check(not model.move_plan(id, TARGET, 0, Vector3.ZERO) and not model.delete_plan(id), "Stale actions are rejected")

func test_reserved_delete() -> void:
	var model = fresh()
	var id: int = model.next_plan_id - 1
	var stock: int = model.resource_total("log")
	check(model.order_build(0, id), "Assign builder to empty site")
	check(model.workers[0].job.get("phase") == "pickup" and model.plans[id].reserved == 1, "Builder reserves a material before construction")
	check(model.delete_plan(id), "Delete site with incoming reservation")
	check(model.workers[0].job.is_empty() and model.workers[0].assigned_plan_id == -1, "Delete clears builder job and explicit assignment")
	check(model.stores.values().all(func(store): return store.reservations.is_empty()), "Delete releases material reservations")
	check(model.resource_total("log") == stock, "Uncollected materials remain in storage")
	model = reload_world(model)
	check(model.plans.is_empty(), "Deleted site stays deleted after reload")

func test_active_move_and_delete() -> void:
	var model = fresh()
	var id: int = model.next_plan_id - 1
	var stock: int = model.resource_total("log")
	model.order_build(0, id)
	advance_until(model, func(): return model.plans[id].installed == 1 and model.workers[0].job.get("phase") == "work" and model.workers[0].job.labour.applied_seconds > 0.2)
	var worker: Dictionary = model.workers[0]
	var applied: float = worker.job.labour.applied_seconds
	check(model.move_plan(id, TARGET, 2, Vector3(0.12, 0, -0.1)), "Move a partially built site")
	check(model.plans[id].installed == 1 and model.plans[id].used == {"log": 1}, "Move preserves installed materials")
	check(worker.assigned_plan_id == id and worker.cargo == "log" and is_equal_approx(worker.job.labour.applied_seconds, applied), "Move preserves builder assignment, cargo and partial labour")
	check(worker.job.phase == "travel" and worker.job.target in model.work_cells("house", TARGET, 2), "Active builder travels toward new site")
	model = reload_world(model)
	check(model.plans[id].direction == 2 and model.plans[id].placement_offset.is_equal_approx(Vector3(0.12, 0, -0.1)), "Moved placement saves orientation and offset")
	check(model.delete_plan(id), "Delete active site")
	check(model.plans[id].relocation.parts.count("log") == 1, "Only installed material becomes salvage")
	check(model.workers[0].cargo == "log" and model.workers[0].job.kind == "restock", "In-flight material stays with its carrier")
	check(model.editable_plan(id).is_empty(), "Salvage cannot be moved or deleted again")
	model = reload_world(model)
	# Timber now returns to a log shed; spare pile capacity cannot accept it.
	check(model.request_build("log_shed", Vector3i(-4, 0, 0)), "Provide timber storage for recovered materials")
	model._complete_plan(model.plans[model.next_plan_id - 1])
	model.set_role(0, "builder")
	advance_until(model, func(): return not model.plans.has(id) and model.workers[0].cargo.is_empty())
	check(model.resource_total("log") == stock, "Installed and carried materials return exactly once")

func test_move_to_completion() -> void:
	var model = fresh()
	var id: int = model.next_plan_id - 1
	model.order_build(0, id)
	check(model.move_plan(id, TARGET, 3, Vector3.ZERO), "Move while a builder fetches supplies")
	model = reload_world(model)
	advance_until(model, func(): return not model.plans.has(id))
	check(model.buildings.has(TARGET) and not model.buildings.has(SOURCE), "Builder completes only the moved site")

func test_controls() -> void:
	var game = preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-construction-actions-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.model = fresh()
	var id: int = game.model.next_plan_id - 1
	game.selected_object = {"cell": SOURCE, "kind": "house", "entity_key": "plan:%s" % id}
	game.hud.update(game.model, -1, 1, game.selected_object)
	for frame in 3: await process_frame
	check(game.hud.move_button.visible and game.hud.removal_button.visible and not game.hud.copy_button.visible, "Untouched site shows Move and Delete only")
	check(not game.hud.move_button.disabled and not game.hud.removal_button.disabled and game.hud.deleting_plan, "Construction actions are enabled before work starts")
	check(is_equal_approx(game.hud.selection_toolbar.get_global_rect().get_center().x, game.hud.root.size.x / 2), "Two-button action menu stays centered")
	await click_action(game, game.hud.move_button)
	check(game.moving_plan_id == id and is_instance_valid(game.preview), "Move button starts site placement")
	game._clear_selection()
	check(game.moving_plan_id == -1 and game.model.plans[id].cell == SOURCE, "Cancel leaves the original site intact")
	game.selected_object = {"cell": SOURCE, "kind": "house", "entity_key": "plan:%s" % id}
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_M
	game._unhandled_input(key)
	check(game.moving_plan_id == id, "M starts moving a selected site")
	key.physical_keycode = KEY_R
	game._unhandled_input(key)
	check(game.direction == 1 and game.model.plans.has(id), "R rotates site preview without deleting")
	check(game._commit_plan_move(TARGET, Vector3.ZERO), "Placement commits site move")
	game.world.sync(game.model, 0, -1)
	var view: Node3D = game.world.entity_views["plan:%s" % id]
	check(view.get_meta("cell") == TARGET and view.get_meta("collider").get_meta("cell") == TARGET, "Site geometry and hit target follow moved cell")
	game.hud.update(game.model, -1, 1, game.selected_object)
	await click_action(game, game.hud.removal_button)
	check(game.model.plans.is_empty() and game.selected_object.is_empty() and not game.hud.selection_toolbar.visible, "Delete button clears site, selection and toolbar")
	check(not game.world.entity_views.has("plan:%s" % id), "Delete clears site geometry")
	check(game.model.request_build("house", SOURCE), "Queue site for keyboard cancellation")
	id = game.model.next_plan_id - 1
	game.selected_object = {"cell": SOURCE, "kind": "house", "entity_key": "plan:%s" % id}
	key.physical_keycode = KEY_BACKSPACE
	key.echo = true
	root.push_input(key, true)
	check(game.model.plans.has(id), "Repeated Backspace does not cancel a site")
	key.echo = false
	game.menu.show()
	root.push_input(key, true)
	check(game.model.plans.has(id), "Backspace in a menu does not delete world selection")
	game.menu.hide()
	game._set_tool("house")
	root.push_input(key, true)
	check(game.model.plans.has(id), "Backspace during placement does not delete its source")
	game._set_tool("inspect")
	root.push_input(key, true)
	check(not game.model.plans.has(id) and game.selected_object.is_empty(), "Backspace cancels an inspected construction site through input routing")
	check(game.model.request_build("house", SOURCE), "Queue house for completed-building shortcut")
	game.model._complete_plan(game.model.plans.values().back())
	game.selected_object = {"cell": SOURCE, "kind": "house", "entity_key": "building:%s" % SOURCE}
	root.push_input(key, true)
	check(game.model.plans.size() == 1 and game.model.plans.values()[0].get("deconstruction", false), "Backspace queues dismantling of a completed building")
	game.free()

func run() -> void:
	test_unstarted()
	test_reserved_delete()
	test_active_move_and_delete()
	test_move_to_completion()
	await test_controls()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d construction action checks" % checks)
	quit(int(not failures.is_empty()))
