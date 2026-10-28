extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Jobs = preload("res://scripts/settlement/job_system.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	var game := Scene.instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.speed = 0
	await process_frame
	var model = game.model
	for worker in model.workers:
		worker.role = "idle"
	model.workers[0].role = "builder"
	check(model.request_build("stairs", Vector3i.ZERO), "Three-material site can be placed")
	var plan: Dictionary = model.plans.values()[0]
	var selection := {"kind": plan.kind, "cell": plan.cell, "entity_key": "plan:%s" % plan.id}
	for i in 1600:
		model.tick(0.05)
		if plan.installed == 1:
			break
	check(plan.installed == 1, "Builder installs the first material")
	model.workers[0].role = "idle"
	for i in 20:
		model.tick(0.05)
	game.world.sync(model, 0, -1)
	game.hud.update_selection(game.world, game.rig.camera, selection, model)
	check(game.hud.work_bars.size() == 1, "Selected waiting site retains one bar without a working builder")
	var bar: Dictionary = game.hud.work_bars[0]
	check(is_equal_approx(bar.fraction, 1.0 / 3.0), "One of three materials stays at 33 percent")
	check(is_equal_approx(bar.width, 144.0), "Three two-second materials occupy a six-second bar")
	game.hud.update_selection(game.world, game.rig.camera, {}, model)
	check(game.hud.work_bars.is_empty(), "Unselected construction hides its progress bar")
	game.hud.update_selection(game.world, game.rig.camera, {"entity_key": "stockpile:%s" % Vector3i.ZERO}, model)
	check(game.hud.work_bars.is_empty(), "Selecting another object does not reveal construction progress")
	model.workers[0].role = "builder"
	for i in 1600:
		model.tick(0.05)
		var job: Dictionary = model.workers[0].job
		if job.get("kind") == "build" and job.labour.applied_seconds >= 0.5:
			break
	var progress := Jobs.construction_progress(plan, model.workers)
	check(progress.applied_seconds > 2 and progress.applied_seconds < 4, "Current application adds smoothly to installed work")
	var restored := Model.new()
	check(restored.restore(model.snapshot()), "Partially built site and labour restore from a save")
	var saved_progress := Jobs.construction_progress(restored.plans[plan.id], restored.workers)
	check(is_equal_approx(progress.applied_seconds, saved_progress.applied_seconds), "Save/load retains cumulative progress")
	game.world.sync(model, 0, 0)
	game.hud.update_selection(game.world, game.rig.camera, {}, model)
	check(game.hud.work_bars.size() == 1, "Selected citizen applying construction has a personal bar")
	if game.hud.work_bars.size() == 1:
		var personal: Dictionary = game.hud.work_bars[0]
		check(is_equal_approx(personal.width, 48.0), "Citizen bar covers one two-second application, not the entire site")
		check(is_equal_approx(personal.fraction, model.workers[0].job.labour.progress_ratio()), "Citizen bar follows their own current applied labour")
	var work_phase: String = model.workers[0].job.phase
	model.workers[0].job.phase = "travel"
	game.hud.update_selection(game.world, game.rig.camera, {}, model)
	check(game.hud.work_bars.is_empty(), "Selected citizen travelling to construction has no application bar")
	model.workers[0].job.phase = work_phase
	var build_job: Dictionary = model.workers[0].job
	model.workers[0].job = {"kind": "restock", "phase": "work", "target": model.workers[0].cell, "labour": Jobs.Labour.new(0.6)}
	game.hud.update_selection(game.world, game.rig.camera, {}, model)
	check(game.hud.work_bars.is_empty(), "Selected citizen never shows an unloading bar, including legacy work jobs")
	model.workers[0].job = build_job
	game.hud.update_selection(game.world, game.rig.camera, selection, model)
	check(game.hud.work_bars.size() == 1 and is_equal_approx(game.hud.work_bars[0].width, 144.0), "Selected site total takes priority over a selected builder's bar")
	game.world.actors[0].ring.hide()
	game.hud.update_selection(game.world, game.rig.camera, {}, model)
	check(game.hud.work_bars.is_empty(), "Unselected active builder hides their personal bar")
	game.hud.update_selection(game.world, game.rig.camera, selection, model)
	check(game.hud.work_bars.size() == 1 and is_equal_approx(game.hud.work_bars[0].fraction, progress.applied_seconds / progress.required_seconds), "Selecting only the building shows total progress including the unselected builder")
	game.selected_object = selection
	game._clear_selection()
	check(game.hud.work_bars.is_empty(), "Esc deselection immediately hides the active site's progress")
	game.hud.update_selection(game.world, game.rig.camera, selection, model)
	check(game.hud.work_bars.size() == 1 and game.hud.work_bars[0].fraction > bar.fraction, "Reselecting reveals current progress without resetting construction")
	var second := Jobs.Labour.new(2.0)
	second.apply(1, 1.0)
	var old := Jobs.Labour.new(1.8)
	old.apply(0, 0.9)
	var combined := Jobs.construction_progress(plan, [
		{"job": {"kind": "build", "plan_id": plan.id, "labour": old}},
		{"job": {"kind": "build", "plan_id": plan.id, "labour": second}},
		{"job": {"kind": "build", "plan_id": -1, "labour": second}}])
	check(is_equal_approx(combined.applied_seconds / combined.required_seconds, 2.0 / 3.0), "Multiple builders aggregate only this site's work, including old job durations")
	game.world.entity_views["plan:%s" % plan.id].hide()
	game.hud.update_selection(game.world, game.rig.camera, selection, model)
	check(game.hud.work_bars.is_empty(), "Hidden construction does not leave a floating progress bar")
	for duration in [1.0, 2.0, 3.0]:
		game.hud._add_work_bar(game.rig.camera, Vector2.ONE, Vector3.ZERO, duration, duration / 2)
	check(game.hud.work_bars.map(func(value): return value.width) == [24.0, 48.0, 72.0], "One-, two- and three-second work has proportionate, distinct widths")
	for i in 2000:
		model.tick(0.05)
		if model.plans.is_empty():
			break
	check(model.plans.is_empty(), "Remaining deliveries complete the site")
	game.world.sync(model, 0, -1)
	game.hud.update_selection(game.world, game.rig.camera, selection, model)
	check(game.hud.work_bars.is_empty(), "Finished construction removes the site bar")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: cumulative work bars, durations, visibility, completion and save/load")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
