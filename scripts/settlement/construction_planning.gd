extends RefCounted
## Prospective structure for placement and rendering, never pedestrian navigation.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Catalog = preload("res://data/settlement/catalog.gd")

static func includes(plan: Dictionary) -> bool:
	return not plan.get("deconstruction", false) and plan.kind in Catalog.COSTS and plan.kind not in Catalog.SEEDS

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
		if plan.id == ignored_id or not includes(plan) or plan.kind not in Catalog.ROOFS: continue
		var top: Vector3i = plan.cell + Vector3i.UP * int(Catalog.building_height(plan.kind))
		if plan.kind == "small_warehouse":
			if cell == top: return true
		elif Grid.overlaps(top, cell): return true
	return false

static func support_cells(world, kind: String, cell: Vector3i, height := 1) -> Array[Vector3i]:
	var base := cell - Vector3i.UP * height if kind == "platform" else cell
	if kind in ["well", "goods_rack", "small_warehouse"]: return [base]
	return world.stone_storage_cells(base) if kind == "stone_storage" else Grid.support_cells(base)

static func ready(world, plan: Dictionary) -> bool:
	if not includes(plan) or plan.kind in ["hay_field", "soil_bed"]: return true
	if plan.kind == "platform" and world.Volume.shore_platform(world, plan.cell): return true
	for cell: Vector3i in support_cells(world, plan.kind, plan.cell, int(plan.get("platform_tier", 1))):
		if not world.supports_build_cell(cell): return false
	return true

static func posts_overlap(world, kind: String, cell: Vector3i, decks: Dictionary) -> bool:
	var height := int(Catalog.building_height(kind)) if kind in Catalog.ROOFS or kind == "stairs" else 1
	for deck: Vector3i in decks:
		if cell.y < deck.y and cell.y + height > deck.y - world.Platforms.tier(decks[deck]) and Grid.overlaps(Vector3i(cell.x, deck.y, cell.z), deck): return true
	return false

static func upper_used(world, cell: Vector3i, kind: String, panel_offset = null) -> bool:
	var upper := cell + Vector3i.UP * int(Catalog.building_height(kind))
	var entries: Array = []
	for base: Vector3i in world.buildings:
		entries.append({"cell": base, "kind": world.buildings[base].kind})
	for deck: Vector3i in platforms(world):
		entries.append({"cell": deck, "kind": "platform"})
	for plan: Dictionary in world.plans.values():
		if includes(plan) and plan.kind != "platform": entries.append(plan)
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
