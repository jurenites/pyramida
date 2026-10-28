extends RefCounted
## Collected bushes are existing plants, never a source of renewable seedlings.
const Inventory = preload("res://scripts/settlement/inventory.gd")

static func request_collect(world, cell: Vector3i) -> bool:
	if world.deposits.get(cell, {}).get("kind") != "berry": return false
	return world.Relocation.request(world, cell, cell, 0, Vector3.ZERO, false, true)

static func pack(bush: Dictionary) -> Dictionary:
	var result := {"berries": bush.inventory.count("food"), "capacity": bush.inventory.capacity,
		"regrowth": float(bush.regrowth), "seed_growth": float(bush.get("seed_growth", 1.0))}
	if bush.has("appearance_seed"): result.appearance_seed = bush.appearance_seed
	return result

static func unpack(payload: Dictionary) -> Dictionary:
	var inventory = Inventory.new()
	inventory.capacity = payload.capacity
	inventory.store("food", payload.berries)
	var result := {"kind": "berry", "inventory": inventory, "regrowth": payload.regrowth, "seed_growth": payload.seed_growth}
	if payload.has("appearance_seed"): result.appearance_seed = payload.appearance_seed
	return result

static func finish_collect(world, worker: Dictionary, plan: Dictionary) -> void:
	world.uprooted_bushes.append(pack(world.deposits[plan.cell]))
	world.bush_discovered = true
	world.deposits.erase(plan.cell)
	world.plans.erase(plan.id)
	for citizen: Dictionary in world.workers:
		if citizen.get("assigned_plan_id", -1) == plan.id: citizen.assigned_plan_id = -1
	worker.job = {}
	world.rebuild_navigation()

static func valid(payload: Variant) -> bool:
	if not payload is Dictionary: return false
	if not preload("res://scripts/settlement/nature_identity.gd").valid(payload): return false
	if not payload.get("capacity") is int or payload.capacity not in [1, 2, 3, 8]: return false
	if not payload.get("berries") is int or payload.berries < 0 or payload.berries > payload.capacity: return false
	for key in ["regrowth", "seed_growth"]:
		if not (payload.get(key) is float or payload.get(key) is int) or not is_finite(float(payload[key])) or payload[key] < 0: return false
	return payload.seed_growth <= 1.0
