extends RefCounted
## A removal site shares dismantling with relocation, then exposes physical salvage.
const Labour = preload("res://scripts/applied_labour.gd")

static func is_salvage(plan: Dictionary) -> bool:
	return plan.get("deconstruction", false) and plan.get("relocation", {}).get("stage") == "salvage"

static func drop_cargo(world, worker: Dictionary) -> void:
	if worker.cargo.is_empty(): return
	# Loose goods use the existing visible, saveable salvage inventory. They do
	# not occupy a building footprint or require storage before another order.
	var owner: int = worker.get("relocation_cargo", -1)
	var pile := {}
	for plan: Dictionary in world.plans.values():
		if plan.get("dropped_cargo", false) and plan.cell == worker.cell and int(plan.get("parts_owner", -1)) == owner:
			pile = plan
			break
	if pile.is_empty():
		var id: int = world.next_plan_id
		world.next_plan_id += 1
		pile = {"id": id, "kind": "stockpile", "cell": worker.cell, "direction": 0,
			"installed": 0, "required": 0, "reserved": 0, "materials": {}, "used": {}, "claims": {},
			"deconstruction": true, "dropped_cargo": true,
			"relocation": {"source": worker.cell, "pickup_cell": worker.cell, "stage": "salvage",
				"parts": world.Inventory.new(), "payload": {}, "owner": -1, "labour": Labour.new(0.6)}}
		if owner != -1: pile.parts_owner = owner
		world.plans[id] = pile
	var amount: int = worker.get("cargo_amount", 1)
	pile.relocation.parts.capacity = maxi(pile.relocation.parts.capacity, pile.relocation.parts.total() + amount)
	pile.relocation.parts.store(worker.cargo, amount)
	world.discover_resource(worker.cargo)
	worker.cargo = ""
	worker.cargo_amount = 1
	worker.erase("relocation_cargo")
	world.revision += 1

static func request(world, cell: Vector3i) -> bool:
	var kind: String = world.Relocation.kind_at(world, cell)
	if world.RopeBridges.supports_bridge(world, cell, kind):
		world.last_message = "Move or remove the attached bridge first"; return false
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
	if plan.has("parts_owner"): return false
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
		# The structure was removed when dismantling completed. Empty salvage
		# is only an inventory/visual change, not a change to walkable surfaces.
		world.revision += 1
