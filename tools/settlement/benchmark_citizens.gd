extends SceneTree
## Headless CPU timings, not rendered FPS. Optional pre-change navigation/model scripts:
## -- --baseline-navigation=/absolute/navigation.gd --baseline-model=/absolute/world_model.gd
const Model = preload("res://scripts/settlement/world_model.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")

func _initialize() -> void:
	var baseline_nav: Script
	var baseline_model: Script
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-navigation="):
			baseline_nav = load(argument.trim_prefix("--baseline-navigation="))
		if argument.begins_with("--baseline-model="):
			baseline_model = load(argument.trim_prefix("--baseline-model="))
	var report := {"optimized": {"simulation": measure_citizens(Navigation, Model), "local_routes": measure_routes(Navigation)}}
	if baseline_nav != null:
		report.baseline = {"simulation": measure_citizens(baseline_nav, baseline_model if baseline_model != null else Model),
			"local_routes": measure_routes(baseline_nav)}
	print(JSON.stringify(report))
	quit()

func measure_citizens(nav_script: Script, model_script: Script) -> Dictionary:
	var world = model_script.new()
	world.navigation = nav_script.new()
	world.setup()
	for id in range(3, 6):
		var worker: Dictionary = world.workers[0].duplicate(true)
		worker.id = id
		worker.cell += Vector3i(id, 0, 0)
		worker.position = Navigation.point(worker.cell)
		world.workers.append(worker)
	var times: Array[int] = []
	var started := Time.get_ticks_usec()
	for step in 1200:
		var before := Time.get_ticks_usec()
		world.tick(0.05)
		times.append(Time.get_ticks_usec() - before)
	var elapsed := Time.get_ticks_usec() - started
	times.sort()
	return {"cells": world.navigation.surfaces.size(), "citizens": world.workers.size(), "simulation_seconds": 60,
		"total_ms": elapsed / 1000.0, "worst_tick_ms": times.back() / 1000.0,
		"p99_tick_ms": times[1188] / 1000.0, "searches": world.navigation.searches_built,
		"deliveries": world.deliveries, "meals": world.meals_eaten}

func measure_routes(nav_script: Script) -> Dictionary:
	var nav = nav_script.new()
	var surfaces := {}
	for x in range(-50, 51):
		for z in range(-50, 51): surfaces[Vector3i(x, 0, z)] = true
	surfaces[Vector3i.UP] = true
	var started := Time.get_ticks_usec()
	nav.rebuild(surfaces, {})
	var rebuild_us := Time.get_ticks_usec() - started
	var checksum := 0.0
	started = Time.get_ticks_usec()
	for id in 6:
		var source := Vector3i(id * 2, 0, 0)
		checksum += nav.distance(nav.route(source, source + Vector3i(3, 0, 2)))
	var local_us := Time.get_ticks_usec() - started
	# Compare cold unreachable queries; the old implementation otherwise already
	# flooded each entire component during the preceding local-route workload.
	nav.rebuild(surfaces, {})
	started = Time.get_ticks_usec()
	for id in 6: nav.route(Vector3i(id * 2, 0, 0), Vector3i.UP)
	return {"cells": surfaces.size(), "rebuild_ms": rebuild_us / 1000.0,
		"six_local_routes_ms": local_us / 1000.0, "six_disconnected_routes_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"distance_checksum": checksum}
