extends SceneTree
## End-to-end gameplay proof: all buildings use real deliveries from a new game.
const Model = preload("res://scripts/settlement/world_model.gd")
var world = Model.new()
func _initialize() -> void:
	world.setup()
	for spec in [["log_shed", -3, -1], ["hay_field", -4, -1], ["hay_barn", -2, -1],
		["sawmill", -2, 0], ["windmill", -1, -1], ["well", -5, -1], ["house", 1, -1],
		["hay_field", -6, -1], ["stockpile", 0, 0], ["mine_camp", -6, 3], ["masonry", -5, 2],
		["pantry", -1, 1], ["school", 2, -1], ["workshop", 2, 0]]:
		var desired := Vector3i(spec[1] * 2, 0, spec[2] * 2)
		var candidates: Array = world.ground.keys()
		candidates.sort_custom(func(a, b): return a.distance_squared_to(desired) < b.distance_squared_to(desired))
		var placed := false
		for cell: Vector3i in candidates:
			if cell.y == 0 and world.build_error(spec[0], cell).is_empty():
				placed = world.request_build(spec[0], cell)
				break
		if not placed:
			printerr("FAIL: no space for " + spec[0])
			quit(1)
			return
	# Scout a quarry with an actual walk so mining has a discovered deposit.
	for cell: Vector3i in world.deposits:
		if world.deposits[cell].kind == "limestone" and world.order_move(1, cell): break
	for step in 60000:
		world.tick(0.1)
		if step % 6000 == 0:
			print("PROGRESS: %.0fs · %d buildings · %d plans · %d residents · %d food" % [world.time, world.buildings.size(), world.plans.size(), world.workers.size(), world.resource_total("food")])
		if world.plans.is_empty() and world.resource_total("block") > 0:
			var restored = Model.new()
			if not restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))):
				printerr("FAIL: completed village does not reload")
				quit(1)
				return
			var file := FileAccess.open("res://artifacts/peaceful-village.json", FileAccess.WRITE)
			file.store_string(JSON.stringify(world.snapshot()))
			file.close()
			print("PASS: complete peaceful village from starting stock through real production in %.0f simulation seconds" % world.time)
			quit()
			return
	for worker in world.workers:
		print("WORKER: ", worker.id, " ", worker.status, " ", worker.cargo, " ", worker.job.get("kind"))
	for plan in world.plans.values(): print("PLAN: ", plan.kind, " ", plan.installed, "/", plan.required)
	for cell in world.stores: print("STORE: ", cell, " ", world.stores[cell].amounts)
	printerr("FAIL: progression stalled")
	quit(1)
