extends RefCounted
## Seed orders share construction's saved labour; rooted plants own their growth.
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Farming = preload("res://scripts/settlement/farming.gd")
const Balance = preload("res://scripts/settlement/balance.gd")
static var TREE_SECONDS := Balance.number("tree_growth_seconds")
static var PALM_SECONDS := Balance.number("palm_growth_seconds")
static var BUSH_SECONDS := Balance.number("bush_seedling_seconds")

static func growth_seconds(kind: String, tree: bool) -> float:
	return Balance.number(("palm_growth_seconds" if kind == "palm" else "tree_growth_seconds") if tree else "bush_seedling_seconds")

static func complete(world, plan: Dictionary) -> void:
	var cell: Vector3i = plan.cell
	match str(plan.kind):
		"seed_vine":
			world.vines[cell] = preload("res://scripts/settlement/vines.gd").create()
			world.vines[cell].placement_offset = plan.get("placement_offset", Vector3.ZERO)
		"seed_tree", "seed_palm":
			var inventory = Inventory.new()
			inventory.capacity = 3
			world.trees[cell] = {"kind": "palm" if plan.kind == "seed_palm" else "living", "inventory": inventory, "regrowth": 0.0, "seed_growth": 0.0}
			preload("res://scripts/settlement/nature_identity.gd").ensure(world.trees[cell], cell, world.world_seed)
		"seed_bush":
			if plan.has("bush_payload"):
				world.deposits[cell] = world.BushTransplants.unpack(plan.bush_payload)
				preload("res://scripts/settlement/nature_identity.gd").ensure(world.deposits[cell], cell, world.world_seed)
				return
			# Finish seed orders saved before collection-only bushes existed.
			var inventory = Inventory.new()
			inventory.capacity = 1
			world.deposits[cell] = {"kind": "berry", "inventory": inventory, "regrowth": 0.0, "seed_growth": 0.0}
			preload("res://scripts/settlement/nature_identity.gd").ensure(world.deposits[cell], cell, world.world_seed)
		"seed_vegetables", "seed_grass":
			world.construction_materials[cell] = {}
			world.gardens[cell] = {"species": "grass" if plan.kind == "seed_grass" else "vegetables", "water": 0, "growth": 0.0, "food": 0, "reserved": -1}

static func grow(plant: Dictionary, delta: float, tree: bool) -> bool:
	var growth := float(plant.get("seed_growth", 1.0))
	if growth >= 1.0: return false
	var seconds := growth_seconds(plant.kind, tree)
	plant.seed_growth = minf(1.0, growth + delta / seconds)
	if plant.seed_growth >= 1.0:
		plant.inventory.store("log" if tree else "food", 3 if tree else 1)
		return true
	return false

static func tick(world, delta: float) -> void:
	for cell: Vector3i in world.trees:
		if float(world.trees[cell].get("seed_growth", 1.0)) >= 1.0 or world.Relocation.locked(world, cell): continue
		if grow(world.trees[cell], delta * Farming.light_rate(world, cell), true): world.revision += 1
	for cell: Vector3i in world.deposits:
		if float(world.deposits[cell].get("seed_growth", 1.0)) >= 1.0 or world.Relocation.locked(world, cell): continue
		if world.deposits[cell].kind == "berry" and grow(world.deposits[cell], delta * Farming.light_rate(world, cell), false): world.revision += 1

static func valid_growth(plant: Dictionary) -> bool:
	if not preload("res://scripts/settlement/nature_identity.gd").valid(plant): return false
	var growth: Variant = plant.get("seed_growth", 1.0)
	return (growth is float or growth is int) and is_finite(float(growth)) and growth >= 0 and growth <= 1
