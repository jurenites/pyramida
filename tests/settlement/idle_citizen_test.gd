extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	var game = Scene.instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-idle-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.speed = 0
	await process_frame
	for worker in game.model.workers:
		game.model.set_role(worker.id, "idle")
	for id in range(3, 6):
		var worker: Dictionary = game.model.workers[0].duplicate(true)
		worker.id = id
		# Keep this counter fixture idle; overlapping spawns now step aside.
		worker.cell = Vector3i(-4, 0, 4 + id)
		worker.position = game.model.navigation.surface_point(worker.cell)
		game.model.workers.append(worker)
	check(game.model.idle_citizen_ids().is_empty(), "Brief gaps never count as idle")
	game.model.tick(2.0)
	check(game.model.idle_citizen_ids().is_empty(), "Idle detection waits three seconds")
	game.model.tick(1.0)
	game.model.revision += 1
	game.world.sync(game.model, 0, -1)
	game.hud.update(game.model, -1, 1)
	check(game.model.idle_citizen_ids() == [0, 1, 3, 4, 5], "Five idle adults are available; child is excluded")
	check(game.hud.idle_button.visible and game.hud.idle_count.text == "6/0" and game.hud.population_tooltip.ends_with("5 idle"), "Population capacity and idle tooltip stay distinct")
	check(game.hud.idle_button.get_theme_stylebox("normal") is StyleBoxEmpty, "Idle person icon stays borderless")
	check(game.hud.idle_count.get_theme_color("font_color") == Color.BLACK, "Idle count is black")
	game.selected_workers.assign([0, 1, 3])
	game.selected_object = {"cell": Vector3i.ZERO, "kind": "house"}
	game._set_tool("platform")
	await process_frame
	await process_frame
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = game.hud.idle_button.get_global_rect().get_center()
		root.push_input(click, true)
	check(game.selected == 0 and game.selected_workers == [0], "First click replaces group selection with exactly one citizen")
	check(game.selected_object.is_empty() and game.tool == "inspect", "Idle selection clears object selection and placement")
	check(not game.hud.detail_panel.visible and game.hud.detail_label.text.is_empty(), "Citizen text and job controls remain hidden")
	check(game.rig.focus == game.model.workers[0].position, "Selected idle citizen is brought into view")
	# Assign the selected citizen through the real workplace command path.
	var cell := Vector3i(4, 0, 0)
	game.model.buildings[cell] = {"kind": "sawmill", "direction": 0}
	game.model.rebuild_navigation()
	game.world.sync(game.model, 0, game.selected)
	await physics_frame
	await process_frame
	var workplace: Node3D = game.world.entity_views["building:%s" % cell]
	game.command_at(game.rig.camera.unproject_position(workplace.global_position + Vector3.UP))
	game.hud.update(game.model, game.selected, 1)
	check(game.model.workers[0].role == "sawyer" and not game.model.workers[0].job.is_empty(), "Right-click assigns the selected citizen")
	check(game.hud.population_tooltip.ends_with("4 idle"), "Assignment immediately removes one citizen from the idle tooltip")
	for id in [1, 3, 4, 5, 1]:
		game.hud.idle_button.pressed.emit()
		check(game.selected_workers == [id], "Queue cycles through remaining idle citizens: %d" % id)
		var selected_rings := 0
		for actor in game.world.actors:
			selected_rings += int(actor.ring.visible)
		check(selected_rings == 1, "Only one citizen selection marker is shown")
	# Recompute on click, even when the last rendered count is stale.
	game.model.order_move(3, game.model.workers[3].cell)
	game.hud.idle_button.pressed.emit()
	check(game.selected_workers == [4], "Newly busy citizen is skipped before the next HUD refresh")
	game.model.workers[5].cargo = "log"
	check(5 not in game.model.idle_citizen_ids(), "Carrying citizens are not idle")
	game.model.workers[1].job = {"kind": "eat"}
	check(1 not in game.model.idle_citizen_ids(), "Eating citizens are not idle")
	game.model.order_move(4, game.model.workers[4].cell)
	game.hud.update(game.model, game.selected, 1)
	check(game.hud.idle_button.visible and game.hud.idle_button.disabled and game.hud.idle_count.text == "6/0", "Total population remains when no idle adults remain")
	check(game.hud.idle_button.get_theme_stylebox("disabled") is StyleBoxEmpty, "Person icon stays borderless when the queue empties")
	game._select_next_idle_citizen()
	check(game.selected_workers == [4], "Empty queue does not select an unrelated citizen")
	game._choose_slot(0, true)
	game.speed = 0
	check(game.model.idle_citizen_ids().is_empty(), "New settlement resets idle delay")
	for worker in game.model.workers:
		game.model.set_role(worker.id, "idle")
	game.model.tick(3.0)
	game.hud.update(game.model, -1, 1)
	game.hud.idle_button.pressed.emit()
	check(game.last_idle_citizen == 0 and game.selected_workers == [0], "New settlement starts its queue from the first adult")
	game.model.order_move(0, game.model.workers[0].cell)
	game.model.tick(0.1)
	game.model.set_role(0, "idle")
	game.model.tick(2.0)
	check(0 not in game.model.idle_citizen_ids(), "Busy interruption restarts the full delay")
	game.model.tick(1.0)
	check(0 in game.model.idle_citizen_ids(), "Citizen returns after a fresh continuous idle interval")
	game.free()
	if failures.is_empty():
		print("PASS: idle count, single selection, cyclic queue, assignment, busy exclusions and game reset")
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
