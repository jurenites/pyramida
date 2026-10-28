extends RefCounted
## Room-sized soil foundations and crop light exposure belong to simulation data.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Balance = preload("res://scripts/settlement/balance.gd")
static var GROW_SECONDS := Balance.number("crop_growth_seconds")
const HARVEST := 3
const HAY_HARVEST := 4
const FIELD_OFFSET := Vector3(Grid.ROOM_SIZE * 0.5, 0, Grid.ROOM_SIZE * 0.5)

static func standing_quarters(crop: Dictionary) -> int:
	# Older saves retain their remaining yield, represented as contiguous quarters.
	return int(crop.get("standing_quarters", (1 << clampi(int(crop.food), 0, HAY_HARVEST)) - 1))

static func quarter_at(local_position: Vector3) -> int:
	return int(local_position.x >= 0.0) + 2 * int(local_position.z >= 0.0)

static func quarter_cell(world, cell: Vector3i, quarter: int) -> Vector3i:
	var building: Dictionary = world.buildings[cell]
	var local := Vector3(1 if quarter % 2 else -1, 0, 1 if quarter >= 2 else -1) * Grid.ROOM_SIZE * 0.5
	var offset: Vector3 = building.get("placement_offset", Vector3.ZERO)
	offset += local.rotated(Vector3.UP, -int(building.get("direction", 0)) * PI * 0.5)
	return cell + Vector3i(roundi(offset.x / Grid.CELL_SIZE), 0, roundi(offset.z / Grid.CELL_SIZE))

static func cut_quarter(crop: Dictionary, quarter := -1) -> void:
	var standing := standing_quarters(crop)
	# Jobs saved before quarters existed still finish one valid cut.
	if quarter < 0 or (standing & (1 << quarter)) == 0:
		for candidate in HAY_HARVEST:
			if standing & (1 << candidate):
				quarter = candidate
				break
	if quarter < 0: return
	crop.standing_quarters = standing & ~(1 << quarter)
	crop.food -= 1

static func bed_cells(cell: Vector3i) -> Array[Vector3i]:
	return [cell, cell + Vector3i(2, 0, 0), cell + Vector3i(0, 0, 2), cell + Vector3i(2, 0, 2)]

static func footprint(kind: String, cell: Vector3i, offset := Vector3.ZERO, direction := 0) -> Rect2:
	var width: float = Grid.CELL_SIZE if kind in ["well", "berry", "seed_bush", "seed_vine", "vine_tree", "seed_grass", "grass_patch"] else Grid.ROOM_SIZE
	if kind in ["seed_vine", "vine_tree"]: width = 0.16
	if kind == "hay_field": width *= 2.0
	if kind == "stone_storage": width = 3.0
	if kind in ["goods_rack", "small_warehouse"]: width = 1.0
	var centre := Vector2(cell.x * Grid.CELL_SIZE + offset.x, cell.z * Grid.CELL_SIZE + offset.z)
	var size := Vector2(1, 2) if kind in ["hay_barn", "log_shed"] else Vector2.ONE * width
	if kind in ["hay_barn", "log_shed"] and direction % 2 == 1: size = Vector2(size.y, size.x)
	return Rect2(centre - size * 0.5, size)

static func overlaps(kind: String, cell: Vector3i, other_kind: String, other: Vector3i, offset := Vector3.ZERO, other_offset := Vector3.ZERO, direction := 0, other_direction := 0) -> bool:
	# Ordinary buildings retain their logical room footprint despite visual nudges.
	if kind not in ["hay_field", "seed_vine", "vine_tree"] and other_kind not in ["seed_vine", "vine_tree"]: offset = Vector3.ZERO
	if other_kind not in ["hay_field", "seed_vine", "vine_tree"] and kind not in ["seed_vine", "vine_tree"]: other_offset = Vector3.ZERO
	var height := int(Catalog.building_height(kind)) if kind in Catalog.ROOFS or kind == "stairs" else 1
	var other_height := int(Catalog.building_height(other_kind)) if other_kind in Catalog.ROOFS or other_kind == "stairs" else 1
	return cell.y < other.y + other_height and other.y < cell.y + height and footprint(kind, cell, offset, direction).intersects(footprint(other_kind, other, other_offset, other_direction))

static func occupied(world, kind: String, cell: Vector3i, offset := Vector3.ZERO, direction := 0) -> bool:
	if world.rock_blocks_build(kind, cell, offset, direction): return true
	# A room spans two height steps; half-storey placements cannot intersect it.
	for dy in range(-5, int(Catalog.building_height(kind))):
		if dy == 0: continue
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var other := cell + Vector3i(dx, dy, dz)
				if world.buildings.has(other) and overlaps(kind, cell, world.buildings[other].kind, other, offset, world.buildings[other].get("placement_offset", Vector3.ZERO)): return true
	# Preserve the cheap room-grid query while generating an unbuilt world.
	if not world.buildings.values().any(func(b): return b.kind in ["stone_storage", "goods_rack", "small_warehouse"]) and kind not in ["goods_rack", "small_warehouse", "stone_storage", "hay_barn", "log_shed", "sawmill", "well", "waterworks", "soil_bed", "berry", "hay_field", "platform"] and world.vines.is_empty() and world.soil_beds.is_empty() and kind not in Catalog.SEEDS and world.gardens.is_empty():
		for collection in [world.buildings, world.stores, world.stairs, world.trees, world.wells, world.water_sources, world.deposits]:
			if world._overlaps_collection(collection, cell): return true
		return false
	# Bounded neighbourhood keeps streaming-world placement independent of map size.
	for field in ["buildings", "stores", "gardens", "stairs", "trees", "wells", "water_sources", "deposits", "soil_beds", "vines"]:
		if field == "soil_beds" and kind in ["hay_field", "platform", "seed_vegetables", "seed_grass", "seed_bush", "berry"]: continue
		var collection: Dictionary = world.get(field)
		for x in range(-4, 5):
			for z in range(-4, 5):
				var other := cell + Vector3i(x, 0, z)
				if not collection.has(other): continue
				if other == cell and field in ["stores", "buildings"] and world.goods_upgrade(kind, cell): continue
				if field == "buildings" and other == cell and kind == "sawmill" and collection[other].kind == "sawmill": continue
				if field == "deposits" and collection[other].kind == "limestone" and (collection[other].inventory.count("stone") == 0 or collection[other].inventory.capacity > 30): continue
				if field == "water_sources" and kind == "well" and collection[other].kind == "puddle": continue
				if other == cell and world.wells.has(cell) and kind in ["well", "waterworks"] and field in ["buildings", "wells", "water_sources"]: continue
				var plot_kind: String = {"stores": "stockpile", "gardens": "garden", "soil_beds": "soil_bed", "vines": "vine_tree"}.get(field, "")
				var other_kind: String = world.buildings.get(other, {}).get("kind", plot_kind)
				if field == "deposits": other_kind = collection[other].kind
				if field == "gardens" and collection[other].get("species") == "grass": other_kind = "grass_patch"
				if kind == "platform" and (other_kind in Catalog.PLATFORM_COVERABLE or other_kind == "grass_patch"): continue
				var other_offset: Vector3 = world.buildings.get(other, {}).get("placement_offset", Vector3.ZERO)
				if field == "vines": other_offset = collection[other].get("placement_offset", Vector3.ZERO)
				if overlaps(kind, cell, other_kind, other, offset, other_offset, direction, int(world.buildings.get(other, {}).get("direction", 0))): return true
	return false

static func bush_soil_ready(world, cell: Vector3i) -> bool:
	# The entire small root plot must be inside completed, unlocked soil beds.
	var plot := footprint("berry", cell).grow(-0.001)
	for point: Vector2 in [plot.position, plot.end, Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.position.y)]:
		var supported := false
		for x in range(-1, 2):
			for z in range(-1, 2):
				var bed := cell + Vector3i(x, 0, z)
				if world.soil_beds.has(bed) and not world.Relocation.locked(world, bed) and footprint("soil_bed", bed).has_point(point): supported = true
		if not supported: return false
	return true

static func foundation_error(world, kind: String, cell: Vector3i) -> String:
	if kind in ["berry", "seed_bush"]:
		return "" if bush_soil_ready(world, cell) else "Prepared soil required"
	if kind in Catalog.SEEDS:
		if kind in ["seed_vegetables", "seed_grass"] and world.soil_beds.has(cell) and not world.Relocation.locked(world, cell): return ""
		for support: Vector3i in ([cell] if kind in ["seed_bush", "seed_vine", "vine_tree", "seed_grass"] else Grid.support_cells(cell)):
			if not world.ground.has(support) or world.terrain_shapes.has(support): return "Choose level ground"
		return ""
	if kind == "soil_bed":
		for support in Grid.support_cells(cell):
			if not Catalog.in_bounds(support): return "Outside the building area"
			if world.terrain_shapes.has(support) or support.y < world.surface_at(support.x, support.z).y: return "Choose level ground"
			if not world.supports_build_cell(support): return "Support the whole footprint"
		return ""
	if kind != "hay_field": return ""
	for bed: Vector3i in bed_cells(cell):
		if world.soil_beds.has(bed) and not world.Relocation.locked(world, bed): continue
		# Each room-sized quadrant needs soil or flat natural sand throughout.
		for support in Grid.support_cells(bed):
			if not Catalog.in_bounds(support): return "Outside the building area"
			if support.y != 0 or not world.ground.has(support) or world.terrain_shapes.has(support):
				return "Sand or four soil beds required"
	return ""

static func bed_in_use(world, bed: Vector3i) -> bool:
	for cell: Vector3i in world.deposits:
		if world.deposits[cell].kind == "berry" and overlaps("soil_bed", bed, "berry", cell): return true
	for cell: Vector3i in world.gardens:
		if world.gardens[cell].has("species") and overlaps("soil_bed", bed, "garden", cell): return true
	for plan: Dictionary in world.plans.values():
		if world.Deconstruction.is_salvage(plan): continue
		if plan.kind in ["seed_vegetables", "seed_grass", "seed_bush", "berry"] and overlaps("soil_bed", bed, plan.kind, plan.cell): return true
	for cell: Vector3i in world.buildings:
		var building: Dictionary = world.buildings[cell]
		if building.kind == "hay_field" and overlaps("soil_bed", bed, "hay_field", cell, Vector3.ZERO, building.get("placement_offset", Vector3.ZERO)): return true
	for plan: Dictionary in world.plans.values():
		if world.Deconstruction.is_salvage(plan): continue
		if plan.kind == "hay_field" and overlaps("soil_bed", bed, "hay_field", plan.cell, Vector3.ZERO, plan.get("placement_offset", FIELD_OFFSET)): return true
	return false

static func sky_open(world, point: Vector3) -> bool:
	# Vertical clearance is independent of camera, sun angle and rendering/shadows.
	var column: Vector3i = world.surface_at(roundi(point.x / Grid.CELL_SIZE), roundi(point.z / Grid.CELL_SIZE))
	if column.y * Grid.LEVEL_HEIGHT > point.y: return false
	var p := Vector2(point.x, point.z)
	for cell: Vector3i in world.platforms:
		if cell.y * Grid.LEVEL_HEIGHT > point.y and footprint("platform", cell).has_point(p): return false
	for cell: Vector3i in world.buildings:
		var building: Dictionary = world.buildings[cell]
		if building.kind in Catalog.ROOFS and building.kind not in Catalog.NATURAL_ROOFS and not world.needs_stack_support(cell): continue
		var top: float = (cell.y + (Grid.STOREY.y if building.kind in Catalog.ROOFS else 0)) * Grid.LEVEL_HEIGHT
		if top > point.y and footprint(building.kind, cell, building.get("placement_offset", Vector3.ZERO)).has_point(p): return false
	for cell: Vector3i in world.soil_beds:
		if cell.y * Grid.LEVEL_HEIGHT > point.y and footprint("soil_bed", cell).has_point(p): return false
	return true

static func light_rate(world, cell: Vector3i, field := false) -> float:
	if world.crop_light_revision != world.navigation.revision:
		world.crop_light_revision = world.navigation.revision
		world.crop_light_cache.clear()
	var key := [cell, field]
	if not world.crop_light_cache.has(key):
		world.crop_light_cache[key] = _light_rate(world, cell, field)
	return world.crop_light_cache[key]

static func _light_rate(world, cell: Vector3i, field: bool) -> float:
	var base := Vector3(cell.x * Grid.CELL_SIZE, cell.y * Grid.LEVEL_HEIGHT + 0.35, cell.z * Grid.CELL_SIZE)
	if not field: return 1.0 if sky_open(world, base) else Balance.number("shade_growth_multiplier")
	base += Vector3(world.buildings.get(cell, {}).get("placement_offset", Vector3.ZERO))
	var open := 0
	var samples := [-1.5, -0.5, 0.5, 1.5] if world.buildings.get(cell, {}).get("kind") == "hay_field" else [-0.5, 0.5]
	for x in samples:
		for z in samples:
			open += int(sky_open(world, base + Vector3(x, 0, z) * Grid.CELL_SIZE))
	return lerpf(Balance.number("shade_growth_multiplier"), 1.0, float(open) / (samples.size() * samples.size()))

static func tick_crops(world, delta: float) -> void:
	for cell: Vector3i in world.gardens:
		var crop: Dictionary = world.gardens[cell]
		if (crop.water <= 0 and crop.get("species") != "grass") or crop.food > 0: continue
		crop.growth += delta * light_rate(world, cell, true)
		if crop.growth >= Balance.number("crop_growth_seconds"):
			var hay: bool = world.buildings.get(cell, {}).get("kind") == "hay_field"
			crop.food = HAY_HARVEST if hay else HARVEST
			if hay: crop.standing_quarters = (1 << HAY_HARVEST) - 1
			crop.water = 0
			crop.growth = 0.0
			world.revision += 1
