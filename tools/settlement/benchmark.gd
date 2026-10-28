extends SceneTree
## Optional --baseline=/absolute/path/navigation.gd compares a preserved implementation.
const Navigation = preload("res://scripts/settlement/navigation.gd")

func measure(script: Script, surfaces: Dictionary) -> Dictionary:
	var nav = script.new()
	nav.rebuild(surfaces, {})
	var checksum := 0.0
	var started := Time.get_ticks_usec()
	for round_ in 4:
		for index in 40:
			var finish := Vector3i((index * 7) % 41 - 20, 0, (index * 13) % 41 - 20)
			checksum += nav.distance(nav.route(Vector3i.ZERO, finish))
	return {"microseconds": Time.get_ticks_usec() - started, "distance_checksum": checksum}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var surfaces := {}
	for x in range(-20, 21):
		for z in range(-20, 21):
			surfaces[Vector3i(x, 0, z)] = true
	var report := {"cells": surfaces.size(), "queries": 160, "optimized": measure(Navigation, surfaces)}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline="):
			report.baseline = measure(load(argument.trim_prefix("--baseline=")), surfaces)
			report.speedup = float(report.baseline.microseconds) / report.optimized.microseconds
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--view-baseline="):
			report.view_optimized = measure_view(preload("res://scripts/settlement/world_view.gd"))
			report.view_baseline = measure_view(load(argument.trim_prefix("--view-baseline=")))
	print(JSON.stringify(report))
	quit()

func measure_view(script: Script) -> Dictionary:
	var model = preload("res://scripts/settlement/world_model.gd").new()
	model.setup()
	var view = script.new()
	root.add_child(view)
	view.setup(model)
	var started := Time.get_ticks_usec()
	for index in 40:
		model.stores[Vector3i(-3, 0, 1)].amounts.log = 2 + index % 10
		model.revision += 1
		view.sync(model, 0, -1)
	var elapsed := Time.get_ticks_usec() - started
	view.free()
	return {"microseconds": elapsed, "inventory_updates": 40}
