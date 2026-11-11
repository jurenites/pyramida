extends RefCounted
## Prospective structure for placement and rendering, never pedestrian navigation.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Catalog = preload("res://data/settlement/catalog.gd")

static func includes(plan: Dictionary) -> bool:
	return not plan.get("deconstruction", false) and (plan.kind in Catalog.COSTS or plan.kind in preload("res://scripts/settlement/room_construction.gd").COSTS) and plan.kind not in Catalog.SEEDS

static func platforms(world, ignored_id := -1) -> Dictionary:
	var result: Dictionary = world.platforms.duplicate()
	var queued: Array = world.plans.values().filter(func(plan): return includes(plan) and plan.kind == "platform" and plan.id != ignored_id)
	queued.sort_custom(func(a, b): return a.cell.y < b.cell.y)
	for plan: Dictionary in queued:
		var below: Vector3i = plan.cell + Vector3i.DOWN
		var height: int = int(plan.get("platform_tier", 1))
		if height == 1 and result.has(below) and world.Platforms.tier(result[below]) == 1:
			result.erase(below)
			height = 2
		result[plan.cell] = height
	return result

static func supports(world, cell: Vector3i, decks: Dictionary, ignored_id := -1) -> bool:
	# A merged platform no longer offers its intermediate floor.
	for deck: Vector3i in decks:
		if world.Platforms.tier(decks[deck]) == 2 and Grid.overlaps(deck + Vector3i.DOWN, cell): return false
	if world.supports_build_cell(cell): return true
	for deck: Vector3i in decks:
		if Grid.overlaps(deck, cell): return true
	for plan: Dictionary in world.plans.values():
		if plan.id == ignored_id or not includes(plan) or plan.get("house_upgrade", false): continue
		if plan.kind in ["support", "stair"]:
			if cell == plan.cell + Vector3i.UP: return true
			continue
		if plan.kind == "house" and int(plan.get("house_tier", 3)) < 2: continue
		if plan.kind not in Catalog.ROOFS: continue
		if cell in world.structural_roof_cells(plan.cell, plan): return true
	return false

static func support_cells(world, kind: String, cell: Vector3i, height := 1, direction := 0, offset := Vector3.ZERO) -> Array[Vector3i]:
	var base := cell - Vector3i.UP * height if kind == "platform" else cell
	if kind in ["support", "stair", "well", "goods_rack", "small_warehouse"]: return [base]
	if Catalog.Reviewed.has(kind) or kind == "rope_maker": return world.Farming.cells(kind, base, direction, offset)
	return world.stone_storage_cells(base) if kind == "stone_storage" else Grid.support_cells(base)

static func ready(world, plan: Dictionary) -> bool:
	if plan.kind == "rope_bridge": return world.RopeBridges.error(world, plan.bridge.start, plan.bridge.end, plan.id, int(plan.bridge.get("curve_version",1))).is_empty()
	if plan.get("house_upgrade", false): return world.buildings.get(plan.cell, {}).get("kind") == "house" and preload("res://scripts/settlement/house_tiers.gd").tier(world.buildings[plan.cell]) + 1 == int(plan.house_tier)
	if plan.kind in world.Rooms.COSTS: return world.Rooms.ready(world,plan)
	if not includes(plan) or plan.kind in ["hay_field", "soil_bed"]: return true
	if world.StructureLayout.removes_lower_deck(world, plan):
		# Completing the upper frame removes the floor used to build it.
		for worker: Dictionary in world.workers:
			if worker.cell == plan.cell: return false
			var route: Array = worker.get("rescue_route", worker.get("clearance_route", worker.route))
			var index: int = worker.get("rescue_index", worker.get("clearance_index", worker.route_index))
			if index < route.size() and route[index] == plan.cell: return false
	if plan.kind == "platform":
		var below: Vector3i = world.Platforms.merge_base(world, plan.cell, int(plan.get("platform_tier", 1)))
		if below != plan.cell:
			# Blueprints stay passable. Wait before removing a floor in use,
			# including residents already stepping onto it from a neighbouring cell.
			for worker: Dictionary in world.workers:
				if Grid.overlaps(worker.cell, below): return false
				var route: Array = worker.get("clearance_route", worker.route)
				var index: int = worker.get("clearance_index", worker.route_index)
				if index < route.size() and Grid.overlaps(route[index], below): return false
	if not preload("res://scripts/settlement/structure_elevation.gd").level_error(world,plan.kind,plan.cell,int(plan.direction),plan.get("placement_offset",Vector3.ZERO),int(plan.get("platform_tier",1))).is_empty(): return false
	if plan.kind=="support" and not preload("res://scripts/settlement/support_runtime.gd").foundation_error(world,plan.cell,plan.get("placement_offset",Vector3.ZERO),float(plan.get("support_yaw",0.0)),int(plan.id),null,false).is_empty(): return false
	if plan.kind == "support" and preload("res://scripts/settlement/support_foundation.gd").water(world, plan.cell, plan.get("placement_offset", Vector3.ZERO), float(plan.get("support_yaw", 0.0))): return true
	if plan.kind == "platform" and world.Volume.shore_platform(world, plan.cell): return true
	if plan.kind=="house" and preload("res://scripts/settlement/home_stack.gd").supported(world,plan.cell,plan.get("placement_offset",Vector3.ZERO)): return true
	for cell: Vector3i in support_cells(world, plan.kind, plan.cell, int(plan.get("platform_tier", 1)), int(plan.direction), plan.get("placement_offset", Vector3.ZERO)):
		if not world.supports_build_cell(cell): return false
	return true

static func posts_overlap(world, kind: String, cell: Vector3i, decks: Dictionary) -> bool:
	var height := int(Catalog.building_height(kind)) if kind in Catalog.ROOFS or kind == "stairs" else 1
	for deck: Vector3i in decks:
		if cell.y < deck.y and cell.y + height > deck.y - world.Platforms.tier(decks[deck]) and Grid.overlaps(Vector3i(cell.x, deck.y, cell.z), deck): return true
	return false

static func upper_used(world, cell: Vector3i, kind: String, panel_offset = null) -> bool:
	if world.RopeBridges.supports_bridge(world, cell, kind): return true
	var upper := cell + Vector3i.UP * int(Catalog.building_height(kind))
	var entries: Array = []
	for base: Vector3i in world.buildings:
		entries.append({"cell": base, "kind": world.buildings[base].kind})
	for deck: Vector3i in platforms(world):
		entries.append({"cell": deck, "kind": "platform"})
	for plan: Dictionary in world.plans.values():
		if includes(plan) and plan.kind != "platform" and not plan.get("house_upgrade", false): entries.append(plan)
	for entry: Dictionary in entries:
		if entry.kind not in Catalog.ROOFS and entry.kind != "platform": continue
		if not Grid.overlaps(upper, entry.cell): continue
		if panel_offset == null or entry.cell == upper: return true
		var delta: Vector3 = panel_offset - Vector3(entry.cell - upper) * Grid.CELL_SIZE
		if absf(delta.x) < Grid.ROOM_SIZE * 0.5 and absf(delta.z) < Grid.ROOM_SIZE * 0.5: return true
	# Posts resting on an open workplace require its supporting frame.
	if panel_offset == null:
		for deck: Vector3i in platforms(world):
			if Grid.overlaps(deck - Vector3i.UP * world.Platforms.tier(platforms(world)[deck]), upper): return true
	return false
