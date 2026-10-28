extends RefCounted
## Small saved identities, independent of render order and of a plant's new home.
const Random = preload("res://scripts/deterministic_random.gd")

static func ensure(plant: Dictionary, cell: Vector3i, world_seed: int) -> void:
	if not plant.has("appearance_seed"):
		# Stay in JSON's exact integer range.
		plant.appearance_seed = Random.world_coordinate_seed(cell.x, cell.z, world_seed, 1210 + cell.y) % 2147483647

static func prepare(world) -> void:
	for cell: Vector3i in world.trees: ensure(world.trees[cell], cell, world.world_seed)
	for cell: Vector3i in world.deposits:
		if world.deposits[cell].kind == "berry": ensure(world.deposits[cell], cell, world.world_seed)
	for plan: Dictionary in world.plans.values():
		if not plan.has("relocation"): continue
		for field in ["trees", "deposits"]:
			if plan.relocation.payload.has(field):
				ensure(plan.relocation.payload[field], plan.relocation.source, world.world_seed)

static func valid(plant: Dictionary) -> bool:
	return not plant.has("appearance_seed") or (plant.appearance_seed is int and plant.appearance_seed >= 0 and plant.appearance_seed < 2147483647)
