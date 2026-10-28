extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const SOURCE := Vector3i.ZERO
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
	check(model.request_build("house", SOURCE, 2, Vector3(0.1, 0, -0.1)), "Queue construction")
	return model

func reload_world(model):
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "Debug jobs and completed buildings round-trip")
	return restored

func advance_until(model, done: Callable) -> void:
	for tick in 2400:
		if done.call(): return
		for worker in model.workers: worker.hunger = 0
		model.tick(0.05)
	check(false, "Simulation reached expected state")

func test_free_construction() -> void:
	var model = fresh()
	var id: int = model.next_plan_id - 1
	for store in model.stores.values(): store.amounts.clear()
	check(not model.debug_mode and not model.debug_finish_plan(id), "Normal play rejects debug completion")
	model.order_build(0, id)
	check(model.workers[0].job.is_empty(), "Normal construction still requires materials")
	model.set_debug_mode(true)
	model.order_build(0, id)
	check(model.workers[0].job.get("debug_free", false) and model.workers[0].cargo.is_empty(), "Debug builder skips fetching and carries no invented cargo")
	model = reload_world(model)
	model.set_debug_mode(true)
	advance_until(model, func(): return model.buildings.has(SOURCE))
	check(model.resource_total("log") == 0 and model.plans.is_empty(), "Builder finishes with empty stores")
	check(model.buildings[SOURCE].direction == 2 and model.buildings[SOURCE].placement_offset == Vector3(0.1, 0, -0.1), "Completion preserves placement")
	model = reload_world(model)
	check(model.buildings.has(SOURCE), "Finished debug building persists")

func test_toggle_off() -> void:
	var model = fresh()
	var id: int = model.next_plan_id - 1
	for store in model.stores.values(): store.amounts.clear()
	model.set_debug_mode(true)
	model.order_build(0, id)
	model.set_debug_mode(false)
	check(model.workers[0].job.is_empty() and model.plans[id].reserved == 0, "Turning debug off releases free work claims")
	check(model.workers[0].assigned_plan_id == id, "Changing mode preserves the player's building order")
	for tick in 30: model.tick(0.05)
	check(model.plans[id].installed == 0 and not model.debug_finish_plan(id), "Normal material requirements resume")
	model.set_debug_mode(true)
	model.order_build(0, id)
	model = reload_world(model)
	model.tick(0.05)
	check(not model.workers[0].job.get("debug_free", false) and model.plans[id].reserved == 0, "Loading without debug enabled cancels free work safely")

func test_finish_during_delivery() -> void:
	for carrying in [false, true]:
		var model = fresh()
		var id: int = model.next_plan_id - 1
		var stock: int = model.resource_total("log")
		model.order_build(0, id)
		if carrying: advance_until(model, func(): return not model.workers[0].cargo.is_empty())
		# Enable directly to exercise Finish against existing pickup/travel jobs.
		model.debug_mode = true
		check(model.debug_finish_plan(id), "Finish completes an active site")
		check(not model.debug_finish_plan(id), "Repeated click cannot finish a stale plan")
		check(model.stores.values().all(func(store): return store.reservations.is_empty()), "Finish releases storage reservations")
		check(model.workers[0].assigned_plan_id == -1 and model.workers[0].job.get("kind") != "build", "Finish clears builder assignment and stale job")
		check(model.resource_total("log") + int(model.workers[0].cargo == "log") == stock, "Finish preserves real stored and carried resources")
		model = reload_world(model)
		if carrying:
			# Logs require their dedicated shed; the starting pile cannot receive them.
			var store_cell: Vector3i = model.stores.keys()[0]
			model.buildings[store_cell] = {"kind": "log_shed", "direction": 0}
			model.rebuild_navigation()
			advance_until(model, func(): return model.workers[0].cargo.is_empty())
			check(model.resource_total("log") == stock, "In-flight cargo returns to storage exactly once")

func test_support_and_other_sites() -> void:
	var model = fresh()
	model.set_debug_mode(true)
	var lower: int = model.next_plan_id - 1
	check(model.request_build("house", SOURCE + Model.Grid.STOREY), "Queue upper floor on planned support")
	var upper: int = model.next_plan_id - 1
	check(not model.debug_finish_plan(upper), "Finish preserves structural support order")
	check(model.debug_finish_plan(lower) and model.debug_finish_plan(upper), "Supported floors finish in order")
	check(model.Deconstruction.request(model, SOURCE + Model.Grid.STOREY), "Queue removal")
	check(not model.debug_finish_plan(model.next_plan_id - 1), "Finish does not act on removal sites")

func test_controls() -> void:
	var game = preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-debug-build-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.model = fresh()
	var id: int = game.model.next_plan_id - 1
	game.selected_object = {"cell": SOURCE, "kind": "house", "entity_key": "plan:%s" % id}
	game.hud.update(game.model, -1, 1, game.selected_object)
	check(not game.hud.finish_button.visible, "Debug action is hidden in normal play")
	game.menu.debug_mode.button_pressed = true
	check(game.model.debug_mode and game.saves.read_settings().debug_mode, "Settings toggle enables and persists debug mode")
	game.hud.update(game.model, -1, 1, game.selected_object)
	for frame in 3: await process_frame
	check(game.hud.finish_button.visible and not game.hud.finish_button.disabled, "Selected site offers Finish in debug mode")
	check(game.hud.finish_button.get_parent() == game.hud.removal_button.get_parent(), "Finish shares Move/Copy/Remove action group")
	check(is_equal_approx(game.hud.selection_toolbar.get_global_rect().get_center().x, game.hud.root.size.x / 2), "Debug action group remains centered")
	check(game.hud.finish_button.get_theme_stylebox("normal").border_width_left == 4, "Debug highlight uses shared four-point stroke")
	if DisplayServer.get_name() != "headless":
		game.world.sync(game.model, 0, -1)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pyramida-debug-finish.png")
	game.hud.finish_button.pressed.emit()
	check(game.model.buildings.has(SOURCE) and not game.world.entity_views.has("plan:%s" % id), "Finish button replaces site with completed building immediately")
	check(not game.hud.finish_button.visible, "Finish hides after completion")
	game.menu.debug_mode.button_pressed = false
	check(not game.model.debug_mode and not game.saves.read_settings().debug_mode, "Settings toggle disables debug and saves preference")
	game.free()

func run() -> void:
	test_free_construction()
	test_toggle_off()
	test_finish_during_delivery()
	test_support_and_other_sites()
	await test_controls()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d debug construction checks" % checks)
	quit(int(not failures.is_empty()))
