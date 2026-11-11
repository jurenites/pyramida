extends RefCounted
## Sea-level decks keep integer addresses; fitted timber and paths use real heights.
const Volume = preload("res://scripts/settlement/terrain_volume.gd")
const Solids = preload("res://scripts/settlement/solid_islands.gd")
const Assembly = preload("res://scripts/settlement/support_assembly.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const MAX_DEPTH := 128.0
const DECK_CLEARANCE := 0.15
static func water_level(world) -> float:
	return preload("res://scripts/settlement/ocean_surface.gd").LEVEL if Solids.enabled(world) else -0.08

static func earth(world, point: Vector3) -> bool:
	var voxel := Vector3i(roundi(point.x), floori(point.y), roundi(point.z))
	if world.volume_edits.has(voxel): return world.volume_edits[voxel] == "solid"
	if Solids.enabled(world) and world.generator_version >= 17: return Solids.solid(world, point)
	return Volume.material_at(world, voxel) == "solid"

static func depth(world, point: Vector3) -> float:
	if not is_zero_approx(point.y) or earth(world, point - Vector3.UP * 0.02): return 0.0
	var column := Vector3i(roundi(point.x), 0, roundi(point.z))
	var water: bool = Volume.material_at(world, column + Vector3i.DOWN) == "water"
	if Solids.enabled(world): water = water or Solids.shore_distance(Vector2(point.x, point.z), world.world_seed, world.generator_version) > 0
	if not water: return 0.0
	# Sample the real edited solid, then refine the first submerged bearing.
	var distance := 0.25
	while distance <= MAX_DEPTH:
		if earth(world, point - Vector3.UP * distance):
			var low := distance - 0.25
			var high := distance
			for iteration in 10:
				var middle := (low + high) * 0.5
				if earth(world, point - Vector3.UP * middle): high = middle
				else: low = middle
			return high
		distance += 0.25
	return -1.0

static func depths(world, cell: Vector3i, offset := Vector3.ZERO, yaw := 0.0) -> Array[float]:
	var result: Array[float] = []
	for corner: Vector3 in Assembly.CORNERS:
		result.append(depth(world, Vector3(cell) + offset + Basis(Vector3.UP, yaw) * corner * 0.76))
	return result

static func water(world, cell: Vector3i, offset := Vector3.ZERO, yaw := 0.0) -> bool:
	for length in depths(world, cell, offset, yaw):
		if not is_zero_approx(length): return true
	return false

static func recipe(world, cell: Vector3i, offset := Vector3.ZERO, yaw := 0.0) -> Dictionary:
	var result := Catalog.recipe("support")
	# Deep piles need rapidly increasing timber for bracing as well as length.
	for length in depths(world, cell, offset, yaw):
		result.log += post_cost(maxf(0.0, length + water_level(world))) if length > 0 else 0
	return result

static func post_cost(submerged_length: float) -> int:
	var lengths := ceili(maxf(0.0, submerged_length - 0.001) / Timber.LOG_LENGTH)
	return lengths + 2 * maxi(0, lengths - 1) * maxi(0, lengths - 1)

static func price_plan(world, plan: Dictionary) -> void:
	var materials := recipe(world, plan.cell, plan.get("placement_offset", Vector3.ZERO), float(plan.get("support_yaw", 0.0)))
	# Moving a funded site keeps its delivered/claimed timber; no material vanishes.
	var committed := int(plan.used.get("log", 0)) + int(plan.claims.get("log", 0))
	if plan.has("delivered"): committed += plan.delivered.count("log")
	if plan.has("relocation"): committed = maxi(committed, int(plan.materials.get("log", 0)))
	materials.log = maxi(materials.log, committed)
	plan.reviewed = true
	plan.materials = materials
	plan.required = int(materials.log)

static func deck_height(world, cell: Vector3i, offset := Vector3.ZERO, yaw := 0.0) -> float:
	return water_level(world) + DECK_CLEARANCE if water(world, cell, offset, yaw) else float(cell.y + 1) + float(load("res://scripts/settlement/structure_elevation.gd").base_shift(world,cell,"support",0,offset))

static func deck_drop(world, cell: Vector3i, offset := Vector3.ZERO, yaw := 0.0) -> float:
	return deck_height(world, cell, offset, yaw) - float(cell.y + 1) - float(load("res://scripts/settlement/structure_elevation.gd").base_shift(world,cell,"support",0,offset))

static func landing_paths(world, cell: Vector3i) -> Dictionary:
	var data: Dictionary = world.buildings.get(cell, {})
	var offset: Vector3 = data.get("placement_offset", Vector3.ZERO)
	var yaw: float = data.get("support_yaw", 0.0)
	if not water(world, cell, offset, yaw) or not world.StructureLayout.has_deck(world, cell): return {}
	if world.navigation.room_nodes.has(cell + Vector3i.UP): return {}
	var deck := Vector3(cell) + offset
	deck.y = deck_height(world, cell, offset, yaw)
	var result := {}
	for direction: Vector3i in world.DIRECTIONS:
		var shore := cell + direction
		if not world.ground.has(shore) or world.navigation.blocked.has(shore): continue
		var start := Vector3(shore)
		start.y = world.navigation.surface_height(shore, start) + 0.025
		if absf(start.y - deck.y) > 0.8: continue
		var lip := Vector3(shore) - Vector3(direction) * 0.48
		lip.y = world.navigation.surface_height(shore, lip) + 0.025
		if Solids.enabled(world) and not Solids.passage_clear(world, lip, deck): continue
		result[shore] = [start, lip, deck]
	return result

static func connect_shore(world, surfaces: Dictionary) -> void:
	for cell: Vector3i in world.buildings:
		if world.buildings[cell].kind != "support" or not surfaces.has(cell + Vector3i.UP): continue
		var paths := landing_paths(world, cell)
		for shore: Vector3i in paths:
			if not surfaces.has(shore): continue
			world.RoomNavigation.add_path(world.navigation, shore, cell + Vector3i.UP, paths[shore])
