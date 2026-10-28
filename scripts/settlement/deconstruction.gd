extends RefCounted
## A removal site shares dismantling with relocation, then exposes physical salvage.
const Labour = preload("res://scripts/applied_labour.gd")

static func is_salvage(plan: Dictionary) -> bool:
	return plan.get("deconstruction", false) and plan.get("relocation", {}).get("stage") == "salvage"

static func request(world, cell: Vector3i) -> bool:
	var kind: String = world.Relocation.kind_at(world, cell)
	if kind not in world.Catalog.COSTS:
		return false
	if kind == "house": return world.Houses.remove(world, cell)
	var direction: int = world.buildings.get(cell, {}).get("direction", world.stairs.get(cell, 0))
	var offset: Vector3 = world.buildings.get(cell, {}).get("placement_offset", Vector3.ZERO)
	return world.Relocation.request(world, cell, cell, direction, offset, true)

static func unpack(world, plan: Dictionary) -> void:
	var move: Dictionary = plan.relocation
	# Stored goods are contents, not construction materials. Preserve both exactly.
	for field in ["stores", "wells"]:
		if not move.payload.has(field): continue
		var inventory = move.payload[field]
		move.parts.capacity += inventory.total()
		for resource: String in inventory.amounts:
			move.parts.store(resource, inventory.count(resource))
		inventory.amounts.clear()
		inventory.reservations.clear()
	if move.payload.has("gardens"):
		var food: int = move.payload.gardens.food
		move.parts.capacity += food
		move.parts.store("grain" if plan.kind == "hay_field" or move.payload.gardens.get("species") == "grass" else "food", food)
	move.payload.clear()
	move.stage = "salvage"
	move.owner = -1
	world.revision += 1

static func assign_salvage(world, worker: Dictionary, plan: Dictionary) -> bool:
	var move: Dictionary = plan.relocation
	var route: Array[Vector3i] = world.navigation.route(worker.cell, move.pickup_cell)
	if route.is_empty(): return false
	for resource: String in move.parts.amounts:
		if move.parts.available(resource) <= 0: continue
		if world.Jobs._destination_store(world, route.back(), resource).is_empty(): continue
		if not move.parts.reserve(worker.id, resource): continue
		worker.job = {"kind": "restock", "phase": "pickup", "source": move.parts,
			"target": move.pickup_cell, "salvage_plan_id": plan.id, "labour": Labour.new(0.6)}
		world.Jobs._set_route(world, worker, route, "salvage_to_parts_text")
		return true
	return false

static func cleanup(world) -> void:
	for id: int in world.plans.keys():
		var plan: Dictionary = world.plans[id]
		if not plan.get("deconstruction", false) or plan.relocation.stage != "salvage": continue
		if plan.relocation.parts.total() > 0 or not plan.relocation.parts.reservations.is_empty(): continue
		# Jobs may keep their source reference after pickup; retain it for save identity.
		if world.workers.any(func(worker): return worker.job.get("source") == plan.relocation.parts): continue
		world.plans.erase(id)
		for worker: Dictionary in world.workers:
			if worker.get("assigned_plan_id", -1) == id: worker.assigned_plan_id = -1
		world.rebuild_navigation()
