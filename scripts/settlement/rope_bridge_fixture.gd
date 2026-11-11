extends RefCounted
const Model = preload("res://scripts/settlement/world_model.gd")
const Bridges = preload("res://scripts/settlement/rope_bridges.gd")
const START := Vector3(-1.78, 2, -0.22)
const END := Vector3(4.78, 5, 2.24)
const SOURCE := Vector3i(-6, 2, -2)
const TARGET := Vector3i(8, 5, 4)
const MAKER := Vector3i(-6, 2, 1)
const HAY := Vector3i(-3, 2, -3)

static func create(queue_bridge := true):
	var world = Model.new()
	for x in range(-9, -1):
		for z in range(-5, 5): world.ground[Vector3i(x, 2, z)] = true
	for x in range(5, 12):
		for z in range(-1, 8): world.ground[Vector3i(x, 5, z)] = true
	for spec in [[SOURCE, "log_shed"], [TARGET, "log_shed"], [MAKER, "rope_maker"], [HAY, "hay_barn"]]:
		world.buildings[spec[0]] = {"kind": spec[1], "direction": 0}
		world.add_store(spec[0]); world.stores[spec[0]].capacity = 64
	world.stores[MAKER].capacity = 16
	world.stores[SOURCE].store("log", 24); world.stores[SOURCE].store("plank", 24)
	world.stores[HAY].store("grain", 24)
	# Presupplied independent scenario; no player settlement is loaded or saved.
	for id in 2:
		var cell := Vector3i(-4, 2, id + 1)
		world.workers.append({"id": id, "cell": cell, "position": Vector3(cell), "route": [], "route_index": 0,
			"job": {}, "cargo": "", "cargo_amount": 1, "status": "idle", "distance": 0.0, "hunger": 0.0,
			"role": "auto" if id == 0 else "ropemaker", "life_stage": "adult", "appearance": id, "cloth_color": id,
			"assigned_plan_id": -1})
	world.unlock_production("rope_maker"); world.unlock_production("sawmill")
	world.exploration.update(world.workers); world.rebuild_navigation()
	if queue_bridge: assert(Bridges.request(world, START, END), world.last_message)
	return world
