extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
const Tooltip = preload("res://scripts/settlement/object_tooltip.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	var model = Model.new()
	model.setup()
	for worker in model.workers: model.set_role(worker.id, "idle")
	model.tick(3.0)
	check(model.idle_citizen_ids() == [0, 1], "Resting adults enter the idle queue")
	for appearance in 4:
		check(Tooltip.person_title({"appearance": appearance, "role": "idle"}) == "Willager", "Unassigned adult title is Willager for appearance %d" % appearance)
	check(Tooltip.person_title({"id": 1, "role": "auto"}) == "Willager", "Legacy unassigned adult uses Willager")
	check(Tooltip.person_title({"appearance": 1, "role": "builder"}) == "Builder", "Assigned occupation remains visible")
	check(Tooltip.person_title({"appearance": 1, "life_stage": "child"}) == "Kid", "Children remain Kid")
	var destination := Vector3i.ZERO
	var closest := INF
	for cell: Vector3i in model.terrain_shapes:
		if model.navigation.surface_point(cell).y < 1.5: continue
		var distance: float = Nav.point(cell).distance_to(model.workers[0].position)
		if distance < closest:
			closest = distance
			destination = cell
	check(destination != Vector3i.ZERO, "Generated butte has a substantial slope")
	var start: Vector3i = model.workers[0].cell
	check(model.order_move(0, destination), "Player can order a citizen onto generated gravel")
	check(0 not in model.idle_citizen_ids(), "Move order immediately leaves idle queue")
	var restored = null
	var saw_slope := false
	for step in 1200:
		model.tick(0.05)
		var worker: Dictionary = model.workers[0]
		if not worker.job.is_empty():
			check(0 not in model.idle_citizen_ids(), "Travelling citizen stays out of idle queue")
		var column := Vector3i(roundi(worker.position.x), 0, roundi(worker.position.z))
		if model.terrain_shapes.has(column):
			saw_slope = true
			check(absf(worker.position.y - model.navigation.surface_height(column, worker.position)) < 0.002, "Feet follow the actual terrain triangles")
			if restored == null and worker.route_index < worker.route.size():
				restored = Model.new()
				check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "In-flight slope order saves and restores")
		if worker.job.is_empty(): break
	check(saw_slope and model.workers[0].cell == destination, "Citizen arrives on the clicked slope")
	check(model.workers[0].position.is_equal_approx(model.navigation.surface_point(destination)), "Arrival uses slope height rather than floor zero")
	check(0 not in model.idle_citizen_ids(), "Arrival does not instantly count as idle")
	model.tick(2.0)
	check(0 not in model.idle_citizen_ids(), "Arrival starts a fresh three-second delay")
	model.tick(1.0)
	check(0 in model.idle_citizen_ids(), "Standing citizen returns to idle queue after delay")
	if restored != null:
		for step in 600:
			restored.tick(0.05)
			if restored.workers[0].job.is_empty(): break
		check(restored.workers[0].cell == destination, "Restored slope order reaches its destination")
	check(model.order_move(0, start), "Downhill order accepted")
	for step in 1200:
		# Avoid a meal interrupting the arrival assertion after the move completes.
		model.workers[0].hunger = 0.0
		model.tick(0.05)
		if model.workers[0].job.is_empty(): break
	check(model.workers[0].cell == start and model.workers[0].position.is_equal_approx(model.navigation.surface_point(start)), "Citizen descends back onto the original soil surface")
	for cell: Vector3i in model.ground:
		if cell.y > 0:
			check(model.navigation.route(destination, cell).is_empty(), "Talus never grants access up a vertical cliff")
			break
	check(not model.request_build("house", destination), "Walking slopes remain nonbuildable")
	# Change direction mid-segment on a deliberately nonplanar gravel surface.
	var turning = Model.new()
	turning.ground = {Vector3i.ZERO: true, Vector3i.RIGHT: true, Vector3i.BACK: true}
	turning.terrain_shapes = {Vector3i.ZERO: [0.0, 0.3, 1.0, 0.2], Vector3i.RIGHT: [0.3, 0.4, 0.6, 1.0], Vector3i.BACK: [0.2, 1.0, 0.3, 0.0]}
	turning.rebuild_navigation()
	var walker: Dictionary = model.workers[0].duplicate(true)
	walker.cell = Vector3i.ZERO
	walker.position = turning.navigation.surface_point(walker.cell)
	walker.hunger = 0.0
	turning.workers.append(walker)
	turning.order_move(0, Vector3i.RIGHT)
	turning.tick(0.1)
	turning.order_move(0, Vector3i.BACK)
	for step in 100:
		turning.tick(0.05)
		var cell := Vector3i(roundi(walker.position.x), 0, roundi(walker.position.z))
		check(absf(walker.position.y - turning.navigation.surface_height(cell, walker.position)) < 0.002, "Mid-slope replacement order remains on the physical surface")
		if walker.job.is_empty(): break
	check(walker.cell == Vector3i.BACK, "Replacement order reaches the new destination")
	# Verify streaming inserts/removes slope geometry and invalidates cached routes.
	var nav = Nav.new()
	var a := Vector3i.ZERO
	var b := Vector3i.RIGHT
	var c := Vector3i(2, 0, 0)
	var shapes := {b: [0.0, 1.0, 1.0, 0.0], c: [1.0, 2.0, 2.0, 1.0]}
	nav.rebuild({a: true}, {})
	nav.update_ground({b: true, c: true}, {}, shapes)
	check(nav.route(a, c).size() == 3 and nav.surface_point(c).y == 1.5, "Streamed slopes connect and retain heights")
	nav.update_ground({}, {b: true}, {c: shapes[c]})
	check(nav.route(a, c).is_empty() and not nav.terrain_shapes.has(b), "Unloaded slope splits the route and removes its height")
	nav.update_ground({b: true}, {}, shapes)
	check(nav.route(c, a).size() == 3, "Reloaded slope reconnects downhill")
	nav.rebuild({a: true, b: true}, {}, {}, {b: [1.0, 2.0, 2.0, 1.0]})
	check(nav.route(a, b).is_empty(), "Discontinuous gravel edges cannot be stepped through")
	if failures.is_empty():
		print("PASS: %d slope travel, idle status, labels, saves, streaming and cliff checks" % checks)
	else:
		for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
