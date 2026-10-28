extends SceneTree
const Controller = preload("res://scripts/settlement/settlement.gd")
const Fixture = preload("res://tests/settlement/terrace_fixture.gd")
const Citizens = preload("res://scripts/settlement/citizen_lifecycle.gd")
var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func fresh(kind: String):
	# Exercise the real frame scheduler without paying for rendering each frame.
	var game = Controller.new()
	game.model.setup()
	# Keep scheduler equivalence focused on the starting simulation. Distant
	# streamed scenery has independent generation, unloading and save tests.
	game.model.streaming_enabled = false
	game.model.loaded_chunks.clear()
	game.model.dormant_chunks.clear()
	game.model.terrain_shapes.clear()
	for cell: Vector3i in game.model.ground.keys():
		if maxi(absi(cell.x), absi(cell.z)) > 14:
			game.model.ground.erase(cell)
			game.model.terrain_heights.erase(Vector2i(cell.x, cell.z))
	for field in ["trees", "deposits", "water_sources"]:
		for cell: Vector3i in game.model.get(field).keys():
			if not game.model.ground.has(cell): game.model.get(field).erase(cell)
	game.model.rebuild_navigation()
	if kind == "terraces":
		Fixture.add_to(game.model)
	elif kind == "family":
		game.model.time = 340.0
		game.model.workers[2].growth_seconds = Citizens.adulthood_seconds() - 30.0
		game.model.trees[Vector3i(-8, 0, -4)].inventory.amounts.clear()
	else:
		for entry in [["hay_field", Vector3i(-4, 0, -4)], ["well", Vector3i(-4, 0, -6)],
				["hay_barn", Vector3i(-4, 0, 0)], ["windmill", Vector3i(0, 0, 0)]]:
			check(game.model.request_build(entry[0], entry[1]), "Production fixture can plan " + entry[0])
			game.model._complete_plan(game.model.plans[game.model.next_plan_id - 1])
		game.model.set_role(0, "farmer")
		game.model.set_role(1, "baker")
	return game

func advance(game, seconds: float, frames: Array) -> void:
	var remaining: float = seconds / game.speed
	var index := 0
	while remaining > 0.000000001:
		var delta := minf(remaining, frames[index % frames.size()])
		game._advance_simulation(delta)
		remaining -= delta
		index += 1
	# A stall may leave debt, but must never skip a simulation step.
	while game.accumulator + 0.000000001 >= Controller.SIMULATION_STEP:
		game._advance_simulation(0.0)

func _initialize() -> void:
	for kind in ["family", "terraces", "production"]:
		var baseline = fresh(kind)
		var checkpoints: Array[Dictionary] = []
		for duration in [4.0, 36.0, 120.0, 100.0]:
			advance(baseline, duration, [1.0 / 60.0])
			checkpoints.append(baseline.model.snapshot())
		if kind == "family":
			check(baseline.model.can_control(baseline.model.workers[2]), "Scenario crosses childhood maturation")
			check(baseline.model.weather.rain_count >= 2, "Scenario crosses multiple weather cycles")
		elif kind == "terraces":
			check(baseline.model.platforms.has(Vector3i(4, 1, 0)) and baseline.model.deliveries >= 5, "Scenario completes physical vertical hauling and construction")
		else:
			check(baseline.model.meals_eaten > 5, "Scenario feeds citizens through the field and mill production chain")
		for play_speed in [1.0, 2.0, 4.0]:
			for frames in [[1.0 / 60.0], [1.0 / 15.0], [1.0 / 144.0], [0.007, 0.13, 0.025, 0.475, 0.9]]:
				var game = fresh(kind)
				game.speed = play_speed
				var checkpoint := 0
				for duration in [4.0, 36.0, 120.0, 100.0]:
					advance(game, duration, frames)
					check(game.model.snapshot() == checkpoints[checkpoint], "%s: full state matches 1x at checkpoint %d, speed %s, frames %s" % [kind, checkpoint, play_speed, frames])
					checkpoint += 1
				game.free()
		baseline.free()
	test_stall_and_speed_changes()
	for message in failures:
		printerr("FAIL: " + message)
	if failures.is_empty():
		print("PASS: %d fixed-step speed, slow-frame, production and state-equivalence checks" % checks)
	quit(int(not failures.is_empty()))

func test_stall_and_speed_changes() -> void:
	var game = fresh("terraces")
	var reference = fresh("terraces")
	game.speed = 4.0
	game._advance_simulation(2.0)
	check(is_equal_approx(game.model.time, Controller.SIMULATION_STEP * Controller.MAX_STEPS_PER_FRAME), "Stall catch-up has a bounded per-frame tick budget")
	check(is_equal_approx(game.model.time + game.accumulator, 8.0), "Stall retains every elapsed simulation second")
	game.speed = 1.0
	game._advance_simulation(0.125)
	game.speed = 2.0
	game._advance_simulation(0.0625)
	while game.accumulator + 0.000000001 >= Controller.SIMULATION_STEP:
		game._advance_simulation(0.0)
	advance(reference, 8.25, [1.0 / 60.0])
	check(game.model.snapshot() == reference.model.snapshot(), "Changing speed preserves already-earned time and fractional ticks")
	game.free()
	reference.free()
