extends SceneTree
const Fixture = preload("res://scripts/settlement/rope_bridge_fixture.gd")
const Bridges = Fixture.Bridges
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = Fixture.create(false)
	check(world.navigation.route(Vector3i(-2,2,0), Vector3i(5,5,2)).is_empty(), "Separate terraces are disconnected without bridge or roads")
	check(not Bridges.request(world, Fixture.START, Fixture.END + Vector3.UP), "Unsupported endpoint is rejected")
	check(not Bridges.request(world, Fixture.START, Fixture.START + Vector3(0,4,0)), "Vertical span is rejected")
	check(Bridges.request(world, Fixture.START, Fixture.END), "Queue a diagonal bridge with fractional endpoints and unequal height")
	var recipe := Bridges.cost(Fixture.START, Fixture.END)
	check(world.navigation.route(Vector3i(-2,2,0), Vector3i(5,5,2)).is_empty(), "Bridge plan grants no walking connection")
	var copy = Fixture.Model.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Pending bridge and Rope maker survive JSON save/load")
	var crossed := false; var mid_saved := false; var reverse := false
	var initial_hay: int = world.resource_total("grain")
	for step in 8000:
		world.tick(0.05)
		for worker: Dictionary in world.workers:
			if worker.position.x > -1.0 and worker.position.x < 4.3:
				if worker.cargo == "log":
					crossed = true
					check(worker.position.y > 1.8 and worker.position.y < 5.1, "Hauler stays on elevated deck")
					if not mid_saved:
						mid_saved = true
						check(copy.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Mid-crossing cargo, curve and route survive reload")
						check(not Bridges.remove(world, world.bridges.keys()[0]), "Occupied bridge cannot disappear under the citizen")
						check(not world.order_move(worker.id, Fixture.SOURCE), "A new order cannot shortcut into the air midway across")
				if worker.cell.y == 5 and worker.cargo == "": reverse = true
		if world.stores[Fixture.TARGET].count("log") >= 4: break
	check(crossed and reverse, "Citizen carries logs uphill and returns downhill")
	check(world.stores[Fixture.TARGET].count("log") == 4, "Real hauling delivers four logs to the remote shed without roads")
	check(world.resource_total("log") == 24, "Crossing conserves logs")
	check(world.resource_total("plank") == 24 - int(recipe.plank), "Construction consumes exact span-based plank cost")
	var rope: int = world.resource_total("rope")
	for worker: Dictionary in world.workers:
		if worker.cargo == "rope": rope += 1
	check(initial_hay - world.resource_total("grain") >= int(recipe.rope) + rope, "Hay is physically processed into consumed and stored Rope")
	check(world.navigation.roads.is_empty(), "The scenario contains no roads")
	for step in 4000:
		copy.tick(0.05)
		if copy.stores[Fixture.TARGET].count("log") >= 4: break
	check(copy.stores[Fixture.TARGET].count("log") == 4, "Reloaded crossing finishes hauling")
	if not world.bridges.is_empty():
		var id: int = world.bridges.keys()[0]; var bridge: Dictionary = world.bridges[id]
		check(bridge.start == Fixture.START and bridge.end == Fixture.END, "Fractional endpoints survive construction exactly")
		check(world.navigation.edge_distance(bridge.a, bridge.b) > Fixture.START.distance_to(Fixture.END), "Routing costs full curved deck and landing approaches")
		check(Bridges.remove(world, id), "Unoccupied bridge can be removed")
		check(world.navigation.route(bridge.a, bridge.b).is_empty(), "Removal invalidates cached connection")
	check(Fixture.Model.Catalog.recipe("rope_maker") == {"log": 4}, "Rope maker is a grid building with a starting-tier construction cost")
	var cancelled = Fixture.create()
	var cancelled_id: int = cancelled.plans.keys()[0]
	cancelled.plans[cancelled_id].installed = 1; cancelled.plans[cancelled_id].used = {"plank": 1}
	cancelled.stores[Fixture.SOURCE].amounts.plank -= 1
	check(cancelled.delete_plan(cancelled_id), "Partly built span can be cancelled")
	check(cancelled.plans[cancelled_id].kind == "stockpile" and cancelled.plans[cancelled_id].relocation.parts.count("plank") == 1, "Cancellation preserves delivered materials as loose salvage")
	check(Bridges.request(cancelled, Fixture.START, Fixture.END), "Cancelled span releases both endpoints for replacement")
	check(copy.restore(JSON.parse_string(JSON.stringify(cancelled.snapshot()))), "Replacement and cancelled bridge salvage survive reload")
	var build_world = Fixture.create(false)
	build_world.buildings.erase(Fixture.MAKER); build_world.stores.erase(Fixture.MAKER); build_world.unlocked_materials.erase("rope"); build_world.rebuild_navigation()
	check(not Bridges.request(build_world, Fixture.START, Fixture.END), "Bridge waits for its material producers")
	check(build_world.request_build("rope_maker", Fixture.MAKER), "Rope maker can be constructed through the normal grid API")
	for step in 4000:
		build_world.tick(0.05)
		if build_world.resource_total("rope") > 0: break
	check(build_world.resource_total("log") == 20 and build_world.resource_total("rope") > 0, "Newly constructed workplace consumes four logs and actually makes Rope")
	# Same-height rooftop-style connectors must follow the sag, not flatten to y.
	var flat = Fixture.Model.new()
	flat.platforms[Vector3i(0,4,0)] = 1; flat.platforms[Vector3i(7,4,2)] = 1
	flat.rebuild_navigation(); flat.unlock_production("rope_maker"); flat.unlock_production("sawmill")
	check(Bridges.request(flat, Vector3(0,4,0), Vector3(7,4,2)), "Exact cell-centre anchors and equal-height elevated decks are supported")
	if not flat.plans.is_empty():
		var plan: Dictionary = flat.plans.values()[0]; Bridges.complete(flat, plan)
		var a: Vector3i = plan.bridge.a; var b: Vector3i = plan.bridge.b
		flat.workers.append({"id": 0, "cell": a, "position": Vector3(a), "route": [], "route_index": 0, "job": {}, "cargo": "log", "cargo_amount": 1, "status": "idle", "distance": 0.0, "hunger": 0.0, "role": "idle", "life_stage": "adult"})
		check(flat.order_move(0,b), "Order rooftop crossing")
		var sagged := false
		for step in 600:
			flat.tick(0.025)
			if flat.workers[0].position.y < 3.9: sagged = true
			if flat.workers[0].cell == b: break
		check(sagged and flat.workers[0].cell == b, "Citizen follows suspended deck sag between equal-height roofs")
		flat.workers[0].cell = a; flat.workers[0].position = Vector3(a); flat.workers[0].job = {}; flat.workers[0].route = []; flat.workers[0].route_index = 0
		var other: Dictionary = flat.workers[0].duplicate(true)
		other.id = 1; other.cell = b; other.position = Vector3(b); flat.workers.append(other)
		check(flat.order_move(0, b) and flat.order_move(1, a), "Queue opposing bridge journeys")
		var overlap := false
		for step in 1400:
			flat.tick(0.025)
			if Bridges.crossing(flat, flat.workers[0]) and Bridges.crossing(flat, flat.workers[1]): overlap = true
			if flat.workers[0].cell == b and flat.workers[1].cell == a: break
		check(not overlap and flat.workers[0].cell == b and flat.workers[1].cell == a, "Opposing traffic waits at landings and both journeys complete")
	print("PASS: rope bridge construction, production, hauling and saves" if failures == 0 else "FAIL: %d rope bridge checks" % failures)
	quit(1 if failures else 0)
