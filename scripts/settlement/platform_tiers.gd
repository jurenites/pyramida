extends RefCounted
## Platform addresses are deck elevations; tier is the support height in metres.
const Grid = preload("res://scripts/settlement/world_grid.gd")

static func tier(value: Variant) -> int:
	return 2 if value is bool else int(value)

static func planned(world, cell: Vector3i) -> int:
	for plan: Dictionary in world.plans.values():
		if plan.kind == "platform" and plan.cell == cell and not world.Deconstruction.is_salvage(plan): return int(plan.get("platform_tier", 1))
	return 1

static func merge_base(world, cell: Vector3i, height := 1, include_plans := false, ignored_id := -1) -> Vector3i:
	var below := cell + Vector3i.DOWN
	var decks: Dictionary = world.Planning.platforms(world, ignored_id) if include_plans else world.platforms
	return below if height == 1 and decks.has(below) and tier(decks[below]) == 1 else cell

static func merge_error(world, cell: Vector3i, height := 1, ignored_id := -1) -> String:
	var below := merge_base(world, cell, height, true, ignored_id)
	if below == cell: return ""
	if world.occupied(below) or world.Relocation.locked(world, below): return "Clear the lower deck first"
	for plan: Dictionary in world.plans.values():
		if world.Deconstruction.is_salvage(plan): continue
		if plan.id == ignored_id or (plan.kind == "platform" and plan.cell == below and world.Planning.includes(plan)): continue
		if plan.cell != cell and Grid.overlaps(plan.cell, below): return "Clear the lower deck first"
	# Never erase an occupied walking floor while upgrading its supports.
	for worker: Dictionary in world.workers:
		if Grid.overlaps(worker.cell, below): return "Clear the lower deck first"
	return ""

static func complete(world, cell: Vector3i, height: int) -> void:
	var below := merge_base(world, cell, height)
	world.platforms[cell] = height
	if below == cell: return
	world.platforms.erase(below)
	world.platforms[cell] = 2
	var materials: Dictionary = world.construction_materials.get(cell, {}).duplicate()
	for resource: String in world.construction_materials.get(below, {}):
		materials[resource] = int(materials.get(resource, 0)) + int(world.construction_materials[below][resource])
	world.construction_materials[cell] = materials
	world.construction_materials.erase(below)

static func sync(node: Node3D, height: int) -> void:
	node.set_meta("platform_tier", height)
	preload("res://scripts/settlement/construction_variants.gd").apply(node, "platform_2m" if height == 2 else "platform")
