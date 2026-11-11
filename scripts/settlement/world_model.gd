extends RefCounted
const SolidIslands = preload("res://scripts/settlement/solid_islands.gd")
var terrain_excavations: Array = []
signal timber_cut(worker_id: int, cell: Vector3i, segment: int)
signal timber_stored(worker_id: int, cell: Vector3i, slot: int)
signal timber_picked_up(worker_id: int, cell: Vector3i, slot: int)
signal timber_installed(worker_id: int, plan: Dictionary)
signal timber_dismantled(plan: Dictionary)
signal timber_salvage_picked_up(worker_id: int, plan_id: int, slot: int)
signal timber_visuals_reset
const Perf = preload("res://scripts/settlement/performance_log.gd")
## Simulation owns truth; rendering never creates resources or navigation links.
const Rooms = preload("res://scripts/settlement/room_construction.gd")
const RoomNavigation = preload("res://scripts/settlement/room_navigation.gd")
var room_site: Dictionary = {}
var home_utilities := {"next_id":1,"services":{}}
var roof_rain: Dictionary = preload("res://scripts/settlement/roof_rain.gd").fresh()
const RopeBridges = preload("res://scripts/settlement/rope_bridges.gd")
var bridges: Dictionary = {}
const Planning = preload("res://scripts/settlement/construction_planning.gd")
const Platforms = preload("res://scripts/settlement/platform_tiers.gd")
const Houses = preload("res://scripts/settlement/house_groups.gd")
const Planting = preload("res://scripts/settlement/planting.gd")
const BushTransplants = preload("res://scripts/settlement/bush_transplants.gd")
const Farming = preload("res://scripts/settlement/farming.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
const Soil = preload("res://scripts/settlement/soil_surface.gd")
const TerrainEditor = preload("res://scripts/settlement/terrain_editor.gd")
const Volume = preload("res://scripts/settlement/terrain_volume.gd")
const Hydrology = preload("res://scripts/settlement/hydrology.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Clearance = preload("res://scripts/settlement/citizen_clearance.gd")
const StructureLayout = preload("res://scripts/settlement/structure_layout.gd")
const ChildPlay = preload("res://scripts/settlement/child_play.gd")
const Citizens = preload("res://scripts/settlement/citizen_lifecycle.gd")
const Relocation = preload("res://scripts/settlement/relocation.gd")
const Deconstruction = preload("res://scripts/settlement/deconstruction.gd")
const Jobs = preload("res://scripts/settlement/job_system.gd")
const SaveCodec = preload("res://scripts/settlement/save_codec.gd")
const DIRECTIONS = Navigation.DIRECTIONS
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const BUILD_COSTS = Catalog.COSTS
const Exploration = preload("res://scripts/settlement/exploration.gd")
const IDLE_DETECTION_SECONDS := 3.0
const STARTING_HOUSE := Vector3i(-6, 0, 2)
var idle_seconds: Dictionary = {}
var ledge_escape_checks: Dictionary = {}
var rock_surface_cache: Dictionary = {}
var child_play := {"games": [], "next_scan": 8.0}
var child_players: Dictionary = {}
# Only goal selection/retries are budgeted; movement and labour run every fixed tick.
var decision_candidates: Dictionary = {}
var job_decisions := 0
var exploration = Exploration.new()
var navigation = Navigation.new()
var ground: Dictionary = {}
var difficulty := "normal"
var world_seed := Generator.DEFAULT_SEED
var generator_version := Generator.VERSION
var terrain_heights: Dictionary = {}
var streaming_enabled := false
var loaded_chunks: Dictionary = {}
var dormant_chunks: Dictionary = {}
var chunk_details: Dictionary = {}
var terrain_revision := 0
var terrain_ramps: Dictionary = {}
var terrain_shapes: Dictionary = {}
var soil_enabled := false
var soil_cuts: Dictionary = {}
var soil_shapes: Dictionary = {}
var soil_noise: FastNoiseLite
var soil_revision := 0
var volume_edits: Dictionary = {}
var surface_edits: Dictionary = {}
var water_sources: Dictionary = {}
var water_orders: Dictionary = {}
var weather := {"seconds": 0, "remainder": 0.0, "raining": false, "rain_count": 0}
var platforms: Dictionary = {}
var stairs: Dictionary = {}
var stores: Dictionary = {}
var discovered_resources: Dictionary = {}
var unlocked_materials: Dictionary = {}
var plans: Dictionary = {}
var debug_mode := false
var buildings: Dictionary = {}
var construction_materials: Dictionary = {}
var wells: Dictionary = {}
var gardens: Dictionary = {}
var soil_beds: Dictionary = {}
var crop_light_cache: Dictionary = {}
var crop_light_revision := -1
var trees: Dictionary = {}
var vines: Dictionary = {}
# A collected root is reserved immediately by its sowing order.
var vine_roots := 0
var vine_discovered := false
var uprooted_bushes: Array[Dictionary] = []
var bush_discovered := false
var workers: Array[Dictionary] = []
var deposits: Dictionary = {}
var birth_clock := 0.0
var well := Vector3i(-6, 0, -4)
var time := 0.0
var meals_eaten := 0
var deliveries := 0
var revision := 0
var last_message := ""
var next_plan_id := 1
var consumption_clock := 0.0
var well_inventory = Inventory.new()

func setup(seed_: int = Generator.DEFAULT_SEED, difficulty_: String = "normal", terrain_version: int = Generator.VERSION) -> void:
	timber_visuals_reset.emit()
	room_site = {}
	home_utilities = {"next_id":1,"services":{}}
	roof_rain = preload("res://scripts/settlement/roof_rain.gd").fresh(true)
	bridges.clear()
	child_play = {"games": [], "next_scan": 8.0}
	child_players.clear()
	idle_seconds.clear()
	soil_enabled = true
	terrain_excavations.clear()
	soil_cuts.clear()
	surface_edits.clear()
	soil_noise = Soil.noise(seed_)
	difficulty = difficulty_
	var generated := Generator.generate_region(seed_, Generator.INITIAL_BOUNDS, Generator.EROSION_STEPS, difficulty,terrain_version)
	world_seed = seed_
	ground = generated.ground
	terrain_heights = generated.heights
	terrain_shapes = generated.shapes
	generator_version = generated.version
	terrain_ramps = generated.ramps
	streaming_enabled = true
	var first_chunk := Generator.chunk_at(Generator.INITIAL_BOUNDS.position)
	var last_chunk := Generator.chunk_at(Generator.INITIAL_BOUNDS.end - Vector2i.ONE)
	for x in range(first_chunk.x, last_chunk.x + 1):
		for z in range(first_chunk.y, last_chunk.y + 1): loaded_chunks[Vector2i(x, z)] = true
	# Slice generated details once; renderers use them without rerolling nature.
	for chunk: Vector2i in loaded_chunks:
		var grass := {}
		var border := {}
		var border_shapes := {}
		var bounds := Rect2i(chunk * Generator.CHUNK_SIZE, Vector2i.ONE * Generator.CHUNK_SIZE).grow(1)
		for column: Vector2i in generated.border:
			if bounds.has_point(column): border[column] = generated.border[column]
		for cell: Vector3i in generated.border_shapes:
			if bounds.has_point(Vector2i(cell.x, cell.z)): border_shapes[cell] = generated.border_shapes[cell]
		for cell: Vector3i in generated.grass:
			if Chunks.chunk_for(cell) == chunk: grass[cell] = true
		chunk_details[chunk] = {"grass": grass, "border": border, "border_shapes": border_shapes}
	Chunks.populate(self, generated)
	Soil.rebuild(self)
	Soil.add_hollows(self, ground)
	terrain_revision += 1
	buildings[STARTING_HOUSE] = {"kind": "house", "direction": 0, "reviewed": true, "house_tier": 1}
	construction_materials[STARTING_HOUSE] = Catalog.recipe("house")
	add_store(STARTING_HOUSE, {"food": Houses.ROOM_FOOD})
	stores[STARTING_HOUSE].capacity = Houses.ROOM_STORAGE
	for cell in [Vector3i(-8, 0, -4), Vector3i(6, 0, -4), Vector3i(8, 0, 4)]:
		var inventory = Inventory.new()
		inventory.capacity = 3
		inventory.store("log", 3)
		trees[cell] = {"inventory": inventory, "regrowth": 0.0, "kind": "dead" if cell == Vector3i(6, 0, -4) else "living"}
	for index in 3:
		var cell := Vector3i((-2 + index) * 2, 0, 4)
		workers.append({"id": index, "cell": cell, "position": Navigation.point(cell),
			"route": [], "route_index": 0, "job": {}, "cargo": "", "status": "idle", "distance": 0.0, "hunger": 0.0,
			"life_stage": "child" if index == 2 else "adult", "growth_seconds": 0.0,
			"appearance": index, "cloth_color": index})
	Economy.setup(self)
	Soil.prepare(self, {"kind": "house", "cell": STARTING_HOUSE})
	exploration.configure_islands(self)
	exploration.update(workers)
	rebuild_navigation()
	for worker: Dictionary in workers:
		worker.position = navigation.surface_point(worker.cell)
	preload("res://scripts/settlement/roof_rain.gd").starter(self)
	rebuild_navigation()

func add_store(cell: Vector3i, initial: Dictionary = {}) -> void:
	var inventory = Inventory.new()
	track_store_resources(inventory)
	for resource: String in initial:
		inventory.store(resource, int(initial[resource]))
	stores[cell] = inventory
	revision += 1

func discover_resource(resource: String) -> void:
	if resource in Economy.RESOURCES:
		discovered_resources[resource] = true

func building_unlocked(kind: String) -> bool:
	if not BUILD_COSTS.has(kind): return false
	if debug_mode: return true
	# Producer completion is permanent; stock only matters when supplying a plan.
	var materials := Catalog.recipe(kind)
	for resource: String in materials:
		if int(materials[resource]) > 0 and resource not in Catalog.NATURAL_CONSTRUCTION_MATERIALS and not unlocked_materials.has(resource):
			return false
	return true

func unlock_production(kind: String) -> void:
	var production: Dictionary = Economy.RECIPES.get(kind, Economy.EXTRACTORS.get(kind, {}))
	if not production.is_empty(): unlocked_materials[production.output] = true

func track_store_resources(inventory) -> void:
	if not inventory.resource_stored.is_connected(discover_resource):
		inventory.resource_stored.connect(discover_resource)
	for resource: String in inventory.amounts:
		if inventory.count(resource) > 0:
			discover_resource(resource)

func rebuild_navigation() -> void:
	var navigation_started := Perf.begin()
	preload("res://scripts/settlement/nature_identity.gd").prepare(self)
	var surfaces := ground.duplicate()
	for base: Vector3i in deposits:
		for top in rock_surfaces(base): surfaces[top] = true
	for cell: Vector3i in platforms:
		for support: Vector3i in Grid.support_cells(cell):
			surfaces[support] = true
	for cell: Vector3i in buildings:
		if buildings[cell].kind == "small_warehouse":
			surfaces[cell + Vector3i.UP] = true
			continue
		if buildings[cell].kind == "house" and preload("res://scripts/settlement/house_tiers.gd").tier(buildings[cell]) < 2: continue
		if buildings[cell].kind in ["support", "stair"]: continue # Metre structures use exact cells below.
		if (buildings[cell].kind == "sawmill" and int(buildings[cell].get("sawmill_tier", 2)) == 3) or buildings[cell].kind in Catalog.NATURAL_ROOFS or (buildings[cell].kind in Catalog.ROOFS and needs_stack_support(cell)):
			for support: Vector3i in structural_roof_cells(cell, buildings[cell]):
				surfaces[support] = true
	navigation.support_poses.clear()
	navigation.blocked.clear()
	navigation.access_overrides.clear()
	for cell: Vector3i in buildings:
		if buildings[cell].kind in ["goods_rack", "small_warehouse"]:
			navigation.blocked[cell] = true
			var front := Vector3.BACK.rotated(Vector3.UP, -int(buildings[cell].direction) * PI / 2)
			navigation.access_overrides[cell] = [cell + Vector3i(roundi(front.x), 0, roundi(front.z))]
	for base: Vector3i in buildings:
		if buildings[base].kind != "stone_storage": continue
		for x in range(-1, 2):
			for z in range(-1, 2):
				surfaces[base + Vector3i(x, 2, z)] = true
				navigation.blocked[base + Vector3i(x, 0, z)] = true
		var entrances: Array[Vector3i] = []
		for step in DIRECTIONS:
			entrances.append(base + step * 2)
		if int(buildings[base].get("storage_tier", 1)) == 3:
			var front := Vector3.BACK.rotated(Vector3.UP, -int(buildings[base].direction) * PI / 2)
			entrances = [base + Vector3i(roundi(front.x), 0, roundi(front.z)) * 2]
		navigation.access_overrides[base] = entrances

	# Room footprints include body clearance and the saved placement nudge.
	for cell: Vector3i in buildings:
		if buildings[cell].kind not in Catalog.ROOFS or buildings[cell].kind in ["well", "small_warehouse"]: continue
		if StructureLayout.passage_open(self, cell): continue
		for candidate in Farming.cells(buildings[cell].kind, cell, int(buildings[cell].direction), buildings[cell].get("placement_offset", Vector3.ZERO)):
			navigation.blocked[candidate] = true
	# Trunks and rocks are solid; low crops, piles and roads remain usable.
	for collection in [trees, deposits, wells]:
		for cell: Vector3i in collection:
			if collection == deposits and collection[cell].kind == "limestone" and collection[cell].inventory.count("stone") == 0: continue
			navigation.blocked[cell] = true
	navigation.roads.clear()
	for cell: Vector3i in buildings:
		if buildings[cell].kind == "road":
			navigation.roads[cell] = true
	remove_rock_interiors(surfaces)
	RoomNavigation.configure(self,surfaces)
	preload("res://scripts/settlement/home_assembly.gd").configure_navigation(self,surfaces)
	preload("res://scripts/settlement/building_assembly_navigation.gd").configure(self,surfaces)
	StructureLayout.configure_navigation(self, surfaces)
	preload("res://scripts/settlement/structure_elevation.gd").configure_navigation(self,surfaces)
	preload("res://scripts/settlement/home_stack.gd").configure_navigation(self,surfaces)
	SolidIslands.configure_navigation(self,surfaces)
	StructureLayout.connect_stairs(self,surfaces)
	preload("res://scripts/settlement/support_foundation.gd").connect_shore(self, surfaces)
	preload("res://scripts/settlement/roof_rain.gd").configure_navigation(self,surfaces)
	Perf.end("navigation.prepare", navigation_started)
	navigation_started = Perf.begin()
	navigation.puddle_basins.clear()
	if SolidIslands.enabled(self):
		for cell in preload("res://scripts/settlement/puddle_basin.gd").cells(self): navigation.puddle_basins[cell]=world_seed
	navigation.rebuild(surfaces, stairs, terrain_ramps, Soil.walking_shapes(self))
	Perf.end("navigation.rebuild", navigation_started)
	navigation_started = Perf.begin()
	RopeBridges.configure(self)
	for cell: Vector3i in buildings:
		if (Catalog.Reviewed.has(buildings[cell].kind) or buildings[cell].kind == "rope_maker") and buildings[cell].kind not in ["house", "hay_field", "road", "stair"]:
			navigation.access_overrides[cell] = Farming.entrances(self, buildings[cell].kind, cell, int(buildings[cell].direction))
	preload("res://scripts/settlement/building_assembly_navigation.gd").restore_access(self)
	Houses.reconcile(self)
	Perf.end("navigation.housing", navigation_started)
	revision += 1

func build_error(kind: String, cell: Vector3i, direction := 0, offset := Vector3.ZERO, ignored_plan_id := -1, platform_height := 1) -> String:
	if kind == "support" and buildings.get(cell, {}).get("kind") == "support": return StructureLayout.restore_error(self, cell) if ignored_plan_id == -1 else "This space is occupied"
	if kind == "house" and buildings.get(cell, {}).get("kind") == "house": return preload("res://scripts/settlement/house_tiers.gd").error(self, cell, ignored_plan_id)
	if kind == "stockpile": return "Use household or dedicated storage"
	if kind == "claypit" and not Hydrology.on_puddle(self, cell): return "Puddle required"
	if kind == "well" and wells.has(cell) and Hydrology.units(buildings[cell]) >= 3: return "Already fully upgraded"
	if Rooms.legacy_overlap(self,cell): return "Room frame occupies this space"
	if kind == "hay_barn": direction = preload("res://scripts/settlement/hay_barn_view.gd").direction_for(self, cell, direction)
	if kind in ["windmill", "stone_storage"] and buildings.get(cell, {}).get("kind") == kind and not buildings[cell].get("reviewed", false):
		if int(buildings[cell].get("storage_tier", 1) if kind == "stone_storage" else buildings[cell].get("mill_tier", 3)) >= 3: return "Already fully upgraded"
		for plan: Dictionary in plans.values():
			if plan.id != ignored_plan_id and plan.cell == cell and not Deconstruction.is_salvage(plan): return "Already planned"
		if Relocation.locked(self, cell): return "Finish moving first"
		return ""
	if buildings.get(cell, {}).get("kind") == "sawmill" and not buildings[cell].get("reviewed", false):
		var tier: int = int(buildings[cell].get("sawmill_tier", 2))
		if kind == "house" and tier == 1: return "Upgrade the saw bench first"
		if kind == "sawmill" and tier == 2 and ignored_plan_id == -1: return "Add a building around the sawmill"
	kind = construction_kind(kind, cell)
	if goods_upgrade(kind, cell) and Relocation.locked(self, cell): return "Finish moving first"
	if kind == "sawmill" and buildings.get(cell, {}).get("kind") == "sawmill" and (buildings[cell].get("reviewed", false) or int(buildings[cell].get("sawmill_tier", 2)) >= 3):
		return "Already fully upgraded"
	if not Catalog.valid_placement_offset(kind, offset):
		return "Outside the building area"
	if (not BUILD_COSTS.has(kind) and kind != "berry") or not Catalog.in_bounds(cell) or direction < 0 or direction > 3:
		return "Outside the building area"
	var bridge_error: String = RopeBridges.construction_error(self, kind, cell, direction, offset)
	if not bridge_error.is_empty(): return bridge_error
	if kind == "seed_bush" and uprooted_bushes.is_empty() and ignored_plan_id == -1:
		return "No collected bushes left"
	if kind == "seed_vine":
		if vine_roots <= 0 and ignored_plan_id == -1: return "No vine roots left"
		return preload("res://scripts/settlement/vines.gd").placement_error(self, cell, offset, ignored_plan_id)
	if kind == "hay_field": offset = Farming.FIELD_OFFSET
	var foundation_error := Farming.foundation_error(self, kind, cell)
	if not foundation_error.is_empty(): return foundation_error
	if kind == "platform":
		platform_height = int(plans.get(ignored_plan_id, {}).get("platform_tier", platform_height))
		var merge_error := Platforms.merge_error(self, cell, platform_height, ignored_plan_id)
		if not merge_error.is_empty(): return merge_error
	var water_support: bool = kind == "support" and preload("res://scripts/settlement/support_foundation.gd").water(self, cell, offset)
	var shore_platform: bool = kind == "platform" and Volume.shore_platform(self, cell)
	if shore_platform and not Volume.platform_grounded(self, cell, platform_height):
		return "Posts must reach the seabed"
	if SolidIslands.enabled(self) and kind!="support":
		for occupied_cell in Grid.support_cells(cell):
			for height in [0.1,0.8,1.4]:
				if SolidIslands.solid(self,Vector3(occupied_cell)+offset+Vector3.UP*(height+preload("res://scripts/settlement/structure_elevation.gd").base_shift(self,cell,kind,direction,offset))): return "Rock occupies this space"
	if SolidIslands.enabled(self) and kind=="support" and SolidIslands.solid(self,Vector3(cell)+offset+Vector3.UP*0.5) and work_cells(kind,cell,direction).is_empty(): return "Build from an exposed rock face"
	if kind=="house":
		var stack_plan: Dictionary=preload("res://scripts/settlement/home_stack.gd").plan(self,cell,offset)
		if not stack_plan.error.is_empty(): return stack_plan.error
	var planned_decks := Planning.platforms(self, ignored_plan_id)
	var support_level := cell + Vector3i.DOWN * platform_height if kind == "platform" else cell
	var pending_support := false
	var home_bearing: bool=kind=="house" and preload("res://scripts/settlement/home_stack.gd").supported(self,cell,offset)
	for support: Vector3i in ([] if home_bearing or shore_platform or water_support or kind in ["hay_field", "soil_bed", "berry"] or kind in Catalog.SEEDS else ([support_level] if kind in ["support", "well", "goods_rack", "small_warehouse"] else (Farming.cells(kind, support_level, direction, offset) if Catalog.Reviewed.has(kind) or kind == "rope_maker" else Grid.support_cells(support_level)))):
		if not Catalog.in_bounds(support):
			return "Outside the building area"
		if (not SolidIslands.enabled(self) and support.y < surface_at(support.x, support.z).y) or terrain_shapes.has(support):
			return "Choose level ground"
		if not Planning.supports(self, support, planned_decks, ignored_plan_id):
			return "Support the whole footprint"
		pending_support = pending_support or not supports_build_cell(support)
	var level_error: String = preload("res://scripts/settlement/structure_elevation.gd").level_error(self,kind,cell,direction,offset,platform_height)
	if not level_error.is_empty(): return level_error
	for plan: Dictionary in plans.values():
		if plan.id == ignored_plan_id or Deconstruction.is_salvage(plan): continue
		if plan.has("relocation") and (Farming.overlaps(plan.kind, plan.relocation.source, kind, cell, buildings.get(plan.relocation.source, {}).get("placement_offset", Vector3.ZERO), offset) or Grid.overlaps(plan.relocation.source + Grid.STOREY, support_level)):
			return "This space is occupied"
		if plan.kind == "hay_field" and kind in Catalog.ROOFS: continue
		if plan.kind == "platform" and Planning.includes(plan) and kind != "platform": continue
		if Farming.overlaps(plan.kind, plan.cell, kind, cell, plan.get("placement_offset", Vector3.ZERO), offset, int(plan.direction), direction):
			return "Already planned"
		if kind == "platform" and Grid.overlaps(plan.cell, support_level) and plan.kind not in Catalog.PLATFORM_COVERABLE and plan.kind != "platform":
			return "Already planned"
	if kind == "platform":
		if (cell.y == 0 and not shore_platform) or occupied(cell if shore_platform else support_level, "platform") or _overlaps_collection(platforms, cell):
			return "This space is occupied"
		return "" if pending_support or not work_cells(kind, cell, direction, platform_height).is_empty() else "Build beside an accessible floor"
	if rock_blocks_build(kind, cell, offset, direction) or occupied(cell, kind, offset, direction):
		return "This space is occupied"
	if kind == "stairs":
		var upper: Vector3i = navigation.stair_landing(cell, direction)
		if _overlaps_collection(platforms, cell + Grid.STOREY) or occupied(upper):
			return "Keep the upper landing clear"
		return ""
	for lower: Vector3i in stairs:
		if Grid.overlaps(navigation.stair_landing(lower, int(stairs[lower])), cell):
			return "Keep the upper landing clear"
	if kind not in Catalog.PLATFORM_COVERABLE and Planning.posts_overlap(self, kind, cell, planned_decks):
		return "This space is occupied"
	if (cell.y > 0 or water_support) and kind not in Farming.GROUND_SEEDS and not pending_support and work_cells(kind, cell, direction).is_empty():
		return "Build beside an accessible floor"
	return ""

func _overlaps_collection(collection: Dictionary, cell: Vector3i) -> bool:
	for x in range(-1, 2):
		for z in range(-1, 2):
			if collection.has(cell + Vector3i(x, 0, z)):
				var entry = collection[cell + Vector3i(x, 0, z)]
				if collection == deposits and entry.kind == "limestone" and (entry.inventory.count("stone") == 0 or entry.inventory.capacity > 30): continue
				return true
	return false

func occupied(cell: Vector3i, kind := "", offset := Vector3.ZERO, direction := 0) -> bool:
	return Farming.occupied(self, kind, cell, offset, direction)

func stone_storage_cells(cell: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for x in range(-1, 2):
		for z in range(-1, 2): result.append(cell + Vector3i(x, 0, z))
	return result

func supports_build_cell(cell: Vector3i) -> bool:
	if SolidIslands.enabled(self) and SolidIslands.solid(self,Vector3(cell)-Vector3.UP*0.02): return true
	if rock_supports(cell): return true
	# Open frames carry the next module even when their intermediate deck is gone.
	if buildings.get(cell + Vector3i.DOWN, {}).get("kind", "") in ["stair", "support"]: return true
	if navigation.surfaces.has(cell):
		return true
	# Structural support follows the real footprint and roof socket, even when
	# a sloping canopy has not yet been replaced by an upper floor.
	for base: Vector3i in buildings:
		var building: Dictionary = buildings[base]
		if base.y + int(Catalog.building_height(building.kind)) != cell.y: continue
		if cell in structural_roof_cells(base, building): return true
	return false

func structural_roof_cells(base: Vector3i, building: Dictionary) -> Array[Vector3i]:
	var kind: String = building.kind
	if kind not in Catalog.ROOFS and kind != "stair": return []
	if kind == "house" and preload("res://scripts/settlement/house_tiers.gd").tier(building) < 2: return []
	var top := base + Vector3i.UP * int(Catalog.building_height(kind))
	if kind in ["support", "stair", "small_warehouse", "well"]: return [top]
	if Catalog.Reviewed.has(kind) or kind == "rope_maker":
		return Farming.cells(kind, top, int(building.get("direction", 0)), building.get("placement_offset", Vector3.ZERO))
	return Grid.support_cells(top)

func snap_cell(kind: String, hit_kind: String, cell: Vector3i, platform_height := 1) -> Vector3i:
	if kind == "support" and hit_kind == "stair": return cell + Vector3i.UP
	if kind == "stockpile" and hit_kind in ["stockpile", "goods_rack"]: return cell
	if kind in ["windmill", "stone_storage"] and hit_kind == kind: return cell
	# Roof sockets are exact multiples of LEVEL_HEIGHT, shared by meshes and paths.
	if hit_kind == "sawmill" and not buildings.get(cell, {}).get("reviewed", false) and kind in ["sawmill", "house"] and int(buildings.get(cell, {}).get("sawmill_tier", 2)) < 3: return cell
	if kind == "remove" or ((hit_kind == "well" and kind in Catalog.ROOFS) or (hit_kind == "waterworks" and kind == "well")):
		return cell
	if hit_kind in Catalog.ROOFS:
		cell += Vector3i(0, int(Catalog.building_height(hit_kind)), 0)
	if kind == "platform" and not Volume.shore_platform(self, cell):
		cell += Vector3i.UP * platform_height
	return cell

func roof_panel_covered(cell: Vector3i, offset: Vector3) -> bool:
	if RopeBridges.supports_bridge(self, cell, buildings.get(cell, {}).get("kind", "")): return true
	var upper := cell + Vector3i(0, int(Catalog.building_height(buildings.get(cell, {}).get("kind", ""))), 0)
	for x in range(-1, 2):
		for z in range(-1, 2):
			var centre := upper + Vector3i(x, 0, z)
			if absf(offset.x - x * Grid.CELL_SIZE) >= Grid.ROOM_SIZE * 0.5 or absf(offset.z - z * Grid.CELL_SIZE) >= Grid.ROOM_SIZE * 0.5:
				continue
			if platforms.has(centre) or (buildings.has(centre) and buildings[centre].kind in Catalog.ROOFS):
				return true
	return false

func placement_offset(kind: String, cell: Vector3i, cursor: Vector3) -> Vector3:
	if kind=="house": return preload("res://scripts/settlement/home_stack.gd").offset(self,cell)
	if kind in ["goods_rack", "small_warehouse"]: return Vector3.ZERO
	if kind == "hay_barn": return Vector3.ZERO
	if kind in ["windmill", "stone_storage"] and buildings.get(cell, {}).get("kind") == kind and not buildings[cell].get("reviewed", false): return buildings[cell].get("placement_offset", Vector3.ZERO)
	if kind == "hay_field": return Farming.FIELD_OFFSET
	if kind in ["seed_vine", "vine_tree"]:
		var delta := cursor - Navigation.point(cell)
		return Vector3(delta.x, 0, delta.z)
	if buildings.get(cell, {}).get("kind") == "sawmill" and kind in ["sawmill", "house"] and not buildings[cell].get("reviewed", false): return buildings[cell].get("placement_offset", Vector3.ZERO)
	if kind == "well": return Vector3.ZERO
	if wells.has(cell) and kind in Catalog.ROOFS: return buildings.get(cell, {}).get("placement_offset", Vector3.ZERO)
	# New construction uses exact grid sockets. Keep the authored field/vine
	# anchors and existing upgrade positions above, including older saves.
	return Vector3.ZERO

func needs_stack_support(cell: Vector3i) -> bool:
	if preload("res://scripts/settlement/home_stack.gd").carries(self,cell): return true
	if RopeBridges.supports_bridge(self, cell, buildings.get(cell, {}).get("kind", "")): return true
	var upper := cell + Vector3i(0, int(Catalog.building_height(buildings.get(cell, {}).get("kind", ""))), 0)
	for collection in [buildings, stores, gardens, platforms, stairs, soil_beds]:
		if _overlaps_collection(collection, upper):
			return true
	# A platform's posts stand one level below its deck.
	for deck: Vector3i in platforms:
		if Grid.overlaps(deck - Vector3i.UP * Platforms.tier(platforms[deck]), upper): return true
	for plan: Dictionary in plans.values():
		if Deconstruction.is_salvage(plan): continue
		var base: Vector3i = plan.cell - Vector3i.UP * int(plan.get("platform_tier", 1)) if plan.kind == "platform" else plan.cell
		if Grid.overlaps(base, upper):
			return true
	for lower: Vector3i in stairs:
		var landing: Vector3i = navigation.stair_landing(lower, int(stairs[lower]))
		if Grid.overlaps(landing, upper):
			return true
	return false

func goods_upgrade(kind: String, cell: Vector3i) -> bool:
	return (kind == "goods_rack" and stores.has(cell) and not buildings.has(cell)) or (kind == "small_warehouse" and buildings.get(cell, {}).get("kind") == "goods_rack")

func construction_kind(kind: String, cell: Vector3i) -> String:
	if kind == "stockpile":
		if stores.has(cell) and not buildings.has(cell): return "goods_rack"
		if buildings.get(cell, {}).get("kind") == "goods_rack": return "small_warehouse"
	if kind == "house" and buildings.get(cell, {}).get("kind") == "sawmill" and not buildings[cell].get("reviewed", false) and int(buildings[cell].get("sawmill_tier", 2)) == 2: return "sawmill"
	if wells.has(cell) and buildings.get(cell, {}).get("kind", "well") == "well" and kind in Catalog.NATURAL_ROOFS and kind != "well":
		return "waterworks"
	return kind

func request_build(kind: String, cell: Vector3i, direction := 0, offset := Vector3.ZERO, snap_join := true, support_yaw := 0.0) -> bool:
	if kind == "support" and buildings.get(cell, {}).get("kind") == "support": return StructureLayout.restore_deck(self, cell)
	if kind == "rope_bridge":
		last_message = "Choose two bridge landings"; return false
	if kind == "house" and buildings.get(cell, {}).get("kind") == "house": return preload("res://scripts/settlement/house_tiers.gd").request(self, cell)
	if kind == "stockpile":
		last_message = "Use household or dedicated storage"
		return false
	if kind == "hay_barn":
		direction = preload("res://scripts/settlement/hay_barn_view.gd").direction_for(self, cell, direction)
	if buildings.get(cell, {}).get("kind") == "sawmill" and kind in ["sawmill", "house"] and not buildings[cell].get("reviewed", false):
		direction = int(buildings[cell].direction)
		offset = buildings[cell].get("placement_offset", Vector3.ZERO)
	if kind in ["windmill", "stone_storage"] and buildings.get(cell, {}).get("kind") == kind and not buildings[cell].get("reviewed", false):
		direction = int(buildings[cell].direction)
		offset = buildings[cell].get("placement_offset", Vector3.ZERO)
	var sawmill_shell: bool = kind == "house" and buildings.get(cell, {}).get("kind") == "sawmill" and not buildings[cell].get("reviewed", false)
	if sawmill_shell and int(buildings[cell].get("sawmill_tier", 2)) != 2:
		last_message = "Upgrade the saw bench first"
		return false
	kind = construction_kind(kind, cell)
	if goods_upgrade(kind, cell):
		direction = int(buildings.get(cell, {}).get("direction", direction))
		offset = Vector3.ZERO
	if kind == "house" and snap_join:
		if offset==Vector3.ZERO: offset=preload("res://scripts/settlement/home_stack.gd").offset(self,cell)
		offset = Houses.snap_offset(self, cell, direction, offset)
	# Bush placement is validated for replanting, never constructed from a recipe.
	if not BUILD_COSTS.has(kind) or kind == "seed_grass":
		last_message = "Outside the building area"
		return false
	if not building_unlocked(kind):
		last_message = "Build the material producer first"
		return false
	if kind == "hay_field": offset = Farming.FIELD_OFFSET
	last_message = build_error("house" if sawmill_shell else kind, cell, direction, offset)
	if not last_message.is_empty():
		return false
	if kind == "support":
		last_message = preload("res://scripts/settlement/support_runtime.gd").foundation_error(self,cell,offset,support_yaw)
		if not last_message.is_empty(): return false
	var id := next_plan_id
	next_plan_id += 1
	plans[id] = {"id": id, "kind": kind, "cell": cell, "direction": direction,
		"installed": 0, "required": BUILD_COSTS[kind], "reserved": 0,
		"materials": Catalog.recipe(kind), "used": {}, "claims": {}}
	if kind == "support": plans[id].support_yaw = support_yaw
	if kind == "windmill":
		plans[id].mill_tier = int(buildings[cell].get("mill_tier", 3)) + 1 if buildings.get(cell, {}).get("kind") == "windmill" else 1
		plans[id].materials = [{"stone": 2}, {"log": 2}, {"log": 6, "plank": 4}][plans[id].mill_tier - 1]
		plans[id].required = [2, 2, 10][plans[id].mill_tier - 1]
	if goods_upgrade(kind, cell): plans[id].goods_upgrade = true
	if kind == "stone_storage":
		plans[id].storage_tier = int(buildings.get(cell, {}).get("storage_tier", 0)) + 1
		plans[id].materials = [{"log": 4}, {"log": 4}, {"plank": 12}][plans[id].storage_tier - 1]
		plans[id].required = [4, 4, 12][plans[id].storage_tier - 1]
	if kind == "platform": plans[id].platform_tier = 1
	if kind == "sawmill":
		plans[id].sawmill_tier = 3 if sawmill_shell else (2 if buildings.get(cell, {}).get("kind") == "sawmill" else 1)
		if not sawmill_shell and buildings.get(cell, {}).get("kind") == "sawmill" and int(buildings[cell].get("sawmill_tier", 2)) >= 2:
			plans.erase(id)
			last_message = "Add a building around the sawmill"
			return false
		plans[id].materials = {"log": 5} if sawmill_shell else ({"log": 2, "plank": 2} if plans[id].sawmill_tier == 2 else {"log": 3})
		plans[id].required = 5 if sawmill_shell else (4 if plans[id].sawmill_tier == 2 else 3)
	if kind in Catalog.ROOFS or kind in ["hay_field", "seed_vine"]:
		plans[id]["placement_offset"] = offset
	if kind == "seed_vine":
		vine_roots -= 1
		plans[id].reserved_root = true
	if kind == "seed_bush":
		plans[id].bush_payload = uprooted_bushes.pop_front()
	if kind in Catalog.SEEDS:
		plans[id].sowing = Jobs.Labour.new(Jobs.Balance.number("sowing_seconds"))
	if Catalog.Reviewed.has(kind):
		plans[id].reviewed = true
		plans[id].materials = Catalog.recipe(kind)
		if kind == "house":
			plans[id].house_tier = 1
			Houses.price_plan(self, plans[id])
		plans[id].required = 0
		for amount: int in plans[id].materials.values(): plans[id].required += amount
		if plans[id].required == 0:
			_complete_plan(plans[id])
			return true
	if kind == "support": preload("res://scripts/settlement/support_foundation.gd").price_plan(self, plans[id])
	last_message = "Construction queued"
	# Blueprints reserve placement, not pedestrian space.
	revision += 1
	return true

func editable_plan(id: int) -> Dictionary:
	var plan: Dictionary = plans.get(id, {})
	return plan if not plan.has("relocation") else {}

func _release_debug_builder(worker: Dictionary) -> void:
	Jobs._cancel_job(self, worker)
	worker.route = []
	worker.route_index = 0
	Jobs.clear_retry(worker)
	if not worker.cargo.is_empty():
		worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Jobs.Labour.new(0.6)}

func set_debug_mode(enabled: bool) -> void:
	if debug_mode == enabled and (enabled or not workers.any(func(worker): return worker.job.get("debug_free", false))): return
	debug_mode = enabled
	for worker: Dictionary in workers:
		var job: Dictionary = worker.job
		var free_work: bool = job.get("debug_free", false)
		if job.get("kind") == "build" and (free_work and not enabled or not free_work and enabled and plans.has(job.plan_id) and Planning.includes(plans[job.plan_id]) and not plans[job.plan_id].has("relocation")):
			_release_debug_builder(worker)
		Jobs.clear_retry(worker)
	revision += 1

func can_debug_finish(id: int) -> bool:
	var plan := editable_plan(id)
	# The manual wand is independent of the automatic free-builder setting.
	return not plan.is_empty() and Planning.includes(plan) and Planning.ready(self, plan)

func debug_finish_plan(id: int) -> bool:
	if not can_debug_finish(id): return false
	var plan: Dictionary = plans[id]
	for worker: Dictionary in workers:
		if worker.job.get("kind") == "build" and worker.job.get("plan_id") == id:
			_release_debug_builder(worker)
	for worker: Dictionary in workers:
		if worker.job.get("kind") == "delivery" and worker.job.get("plan_id") == id:
			Jobs._cancel_job(self, worker)
			worker.route = []; worker.route_index = 0
	plan.installed = plan.required
	plan.used = plan.materials.duplicate()
	plan.reserved = 0
	plan.claims = {}
	_complete_plan(plan)
	return true

func move_plan_error(id: int, cell: Vector3i, direction: int, offset: Vector3) -> String:
	if plans.get(id, {}).has("relocation"):
		return Relocation.destination_error(self, plans[id].relocation.source, cell, direction, offset, id)
	var plan := editable_plan(id)
	if plan.is_empty() or not exploration.contains(navigation.point(cell)):
		return "relocation_unavailable_text"
	if plan.get("house_upgrade", false): return "Finish the upgrade before moving"
	if plan.kind == "stone_storage" and int(plan.get("storage_tier", 1)) > 1: return "Finish the upgrade before moving"
	if plan.kind == "windmill" and int(plan.get("mill_tier", 1)) > 1: return "Finish the upgrade before moving"
	if plan.kind == "sawmill" and (int(plan.get("sawmill_tier", 1)) > 1 or buildings.get(cell, {}).get("kind") == "sawmill"):
		return "Finish the upgrade before moving"
	if plan.get("goods_upgrade", false) or goods_upgrade(plan.kind, cell): return "Finish the upgrade before moving"
	if plan.kind=="support":
		var fitting_error: String = preload("res://scripts/settlement/support_runtime.gd").foundation_error(self,cell,offset,float(plan.get("support_yaw",0.0)),id)
		if not fitting_error.is_empty(): return fitting_error
	return build_error(plan.kind, cell, direction, offset, id)

func move_plan(id: int, cell: Vector3i, direction: int, offset: Vector3) -> bool:
	last_message = move_plan_error(id, cell, direction, offset)
	if not last_message.is_empty(): return false
	var plan: Dictionary = plans[id]
	if plan.has("relocation"):
		# Dismantling still targets the source. Keep its worker, labour and parts.
		plan.cell = cell
		plan.direction = direction
		plan.placement_offset = Farming.FIELD_OFFSET if plan.kind == "hay_field" else offset
		if plan.kind == "support": preload("res://scripts/settlement/support_foundation.gd").price_plan(self, plan)
		revision += 1
		return true
	var resolved := construction_kind(plan.kind, cell)
	if resolved != plan.kind:
		plan.shell_kind = plan.kind
		plan.kind = resolved
	plan.cell = cell
	plan.direction = direction
	plan.placement_offset = Farming.FIELD_OFFSET if plan.kind == "hay_field" else offset
	if plan.kind == "support": preload("res://scripts/settlement/support_foundation.gd").price_plan(self, plan)
	revision += 1
	# Keep the same site identity, installed pieces, claims and applied labour.
	# Builders fetching supplies keep their pickup route; carriers follow the new site.
	var targets := work_cells(plan.kind, cell, direction)
	for worker: Dictionary in workers:
		var job: Dictionary = worker.job
		if job.get("kind") not in ["build", "delivery"] or job.get("plan_id") != id: continue
		var route := nearest_route(worker.cell, targets)
		job.target = route.back() if not route.is_empty() else cell
		Jobs.clear_retry(worker)
		if job.phase != "pickup":
			job.phase = "travel"
			worker.route = []
			worker.route_index = 0
			Jobs._route_to_job(self, worker)
	return true

func delete_plan(id: int) -> bool:
	var plan := editable_plan(id)
	if plan.is_empty(): return false
	var delivered: Dictionary = plan.used.duplicate()
	if plan.has("delivered"):
		for resource: String in plan.delivered.amounts: delivered[resource] = int(delivered.get(resource, 0)) + plan.delivered.count(resource)
		plan.delivered.amounts.clear()
	for worker: Dictionary in workers:
		if worker.get("assigned_plan_id", -1) == id: worker.assigned_plan_id = -1
		if worker.job.get("kind") not in ["build", "delivery"] or worker.job.get("plan_id") != id: continue
		# Work-phase cargo has already arrived; leave it with the recovered pieces.
		# Materials still travelling stay with their carrier and return to storage.
		if worker.job.get("phase") == "work" and not worker.cargo.is_empty():
			delivered[worker.cargo] = int(delivered.get(worker.cargo, 0)) + 1
			worker.cargo = ""
		Jobs._cancel_job(self, worker)
		worker.route = []
		worker.route_index = 0
		Jobs.clear_retry(worker)
		if not worker.cargo.is_empty():
			worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Jobs.Labour.new(0.6)}
	if plan.get("reserved_root", false): vine_roots += 1
	if plan.has("bush_payload"): uprooted_bushes.push_front(plan.bush_payload)
	plan.erase("house_upgrade")
	plan.erase("shared_frame")
	if delivered.is_empty():
		plans.erase(id)
	else:
		# Keep the saved inventory identity for hauling, without reserving a footprint.
		var parts := Inventory.new()
		parts.capacity = maxi(32, plan.required)
		for resource: String in delivered: parts.store(resource, delivered[resource])
		var pickup_cell: Vector3i = plan.cell
		if plan.kind == "platform": pickup_cell -= Vector3i.UP * int(plan.get("platform_tier", 1))
		plan.deconstruction = true
		plan.relocation = {"source": plan.cell, "pickup_cell": pickup_cell, "stage": "salvage",
			"parts": parts, "payload": {}, "owner": -1, "labour": Jobs.Labour.new(0.6)}
		plan.installed = 0
		plan.used = {}
		plan.reserved = 0
		plan.claims = {}
		if plan.kind in ["rope_bridge","rain_fitting"]:
			# A cancelled span becomes ordinary loose material, not an occupied
			# bridge plan that would keep reserving both landings.
			plan.kind = "stockpile"; plan.required = 0; plan.materials = {}
			plan.dropped_cargo = true; plan.erase("bridge"); plan.erase("rain_spec")
	last_message = ""
	revision += 1
	return true

func work_cells(kind: String, cell: Vector3i, _direction := 0, platform_height := 0) -> Array[Vector3i]:
	if kind == "rope_bridge":
		var landings: Array[Vector3i] = []
		if navigation.walkable(cell): landings.append(cell)
		return landings
	if kind in Rooms.COSTS:
		for plan in plans.values():
			if plan.kind==kind and plan.cell==cell: return Rooms.work_cells(self,plan)
		return []
	var result: Array[Vector3i] = []
	for plan: Dictionary in plans.values():
		if plan.kind == kind and plan.cell == cell and not Planning.ready(self, plan): return result
	if kind == "platform":
		var height := platform_height if platform_height > 0 else Platforms.planned(self, cell)
		var bottom := cell - Vector3i.UP * height
		if Platforms.merge_base(self, cell, height) != cell: bottom -= Vector3i.UP
		if navigation.walkable(bottom): result.append(bottom)
		for neighbour in navigation.access_cells(bottom):
			if neighbour not in result: result.append(neighbour)
		if not result.is_empty(): return result
	if Catalog.Reviewed.has(kind) or kind == "rope_maker":
		result.append_array(Farming.entrances(self, kind, cell, _direction))
	if kind != "platform":
		result.append_array(navigation.access_cells(cell))
	for direction: Vector3i in DIRECTIONS:
		if navigation.walkable(cell + direction):
			result.append(cell + direction)
	if kind == "support" and cell.y == 0:
		# Extend the pier from its completed deck, one metre above the water.
		for direction: Vector3i in DIRECTIONS:
			var edge := cell + direction + Vector3i.UP
			if navigation.walkable(edge): result.append(edge)
	if kind == "platform" and Volume.shore_platform(self, cell):
		for direction: Vector3i in DIRECTIONS:
			var edge := cell + direction * Grid.CELLS_PER_ROOM
			if navigation.walkable(edge): result.append(edge)
	# A worker below may raise a floor supported by the ground/deck they stand on.
	if result.is_empty() and supports_build_cell(cell):
		var below := cell + Vector3i.DOWN
		if navigation.walkable(below): result.append(below)
		result.append_array(navigation.access_cells(below))
	if result.is_empty() and navigation.surfaces.has(cell + (-Grid.STOREY)):
		result.append(cell + (-Grid.STOREY))
	return result

func nearest_route(start: Vector3i, destinations: Array[Vector3i]) -> Array[Vector3i]:
	var best: Array[Vector3i] = []
	var best_distance := INF
	for cell in destinations:
		var candidate: Array[Vector3i] = navigation.route(start, cell)
		if not candidate.is_empty() and navigation.distance(candidate) < best_distance:
			best = candidate
			best_distance = navigation.distance(candidate)
	return best

func can_replant_bush(cell: Vector3i) -> bool:
	return deposits.get(cell, {}).get("kind") == "berry" and Relocation.source_error(self, cell).is_empty()

func replant_bush(cell: Vector3i) -> bool:
	return BushTransplants.request_collect(self, cell)

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	var started := Perf.begin()
	time += delta
	Hydrology.tick(self, delta)
	preload("res://scripts/settlement/room_utilities.gd").tick(self,delta)
	preload("res://scripts/settlement/home_assembly.gd").tick(self,delta)
	Perf.end("simulation.water", started)
	started = Perf.begin()
	Economy.tick(self, delta)
	if preload("res://scripts/settlement/building_assembly_navigation.gd").stock_signature(self)!=navigation.building_stock_state: rebuild_navigation()
	Perf.end("simulation.economy", started)
	started = Perf.begin()
	# Partially chopped trees retain their remaining harvestable trunk.
	# Keep legacy regrowth values in saves, but never advance or apply them.
	Planting.tick(self, delta)
	Farming.tick_crops(self, delta)
	Perf.end("simulation.plants", started)
	started = Perf.begin()
	for worker in workers:
		worker.hunger = float(worker.get("hunger", 0.0)) + delta
	ChildPlay.tick(self)
	Jobs.prepare_decisions(self)
	for worker in workers:
		var was_idle := _is_idle(worker)
		Citizens.tick(self, worker, delta)
		if was_idle and _is_idle(worker):
			idle_seconds[worker.id] = minf(float(idle_seconds.get(worker.id, 0.0)) + delta, IDLE_DETECTION_SECONDS)
		else:
			idle_seconds.erase(worker.id)
	Perf.end("simulation.citizens", started)
	started = Perf.begin()
	exploration.update(workers)
	Perf.end("simulation.exploration", started)
	started = Perf.begin()
	Deconstruction.cleanup(self)
	Perf.end("simulation.cleanup", started)

func _complete_plan(plan: Dictionary) -> void:
	if plan.kind == "rope_bridge":
		RopeBridges.complete(self, plan); return
	if plan.get("house_upgrade", false):
		preload("res://scripts/settlement/house_tiers.gd").complete(self, plan); return
	if plan.kind in Rooms.COSTS:
		Rooms.complete(self,plan); return
	SolidIslands.excavate(self,plan)
	Farming.remember_field(self, plan.cell)
	Soil.prepare(self, plan)
	if plan.kind in ["well", "waterworks"]:
		Hydrology.complete(self, plan)
		plans.erase(plan.id)
		for worker: Dictionary in workers:
			if worker.get("assigned_plan_id", -1) == plan.id: worker.assigned_plan_id = -1
		rebuild_navigation()
		last_message = "Construction complete"
		return
	if plan.kind in Catalog.SEEDS:
		Planting.complete(self, plan)
		plans.erase(plan.id)
		for worker: Dictionary in workers:
			if worker.get("assigned_plan_id", -1) == plan.id: worker.assigned_plan_id = -1
		rebuild_navigation()
		return
	var previous_materials: Dictionary = construction_materials.get(plan.cell, {}).duplicate() if plan.kind in ["goods_rack", "small_warehouse", "sawmill", "windmill", "stone_storage"] else {}
	if plan.kind != "soil_bed":
		construction_materials[plan.cell] = plan.get("materials", {"log": plan.required}).duplicate()
	match str(plan.kind):
		"soil_bed": soil_beds[plan.cell] = {"materials": plan.materials.duplicate()}
		"platform": platforms[plan.cell] = int(plan.get("platform_tier", 1))
		"stairs": stairs[plan.cell] = plan.direction
		"stockpile": add_store(plan.cell)
		"garden", "hay_field": gardens[plan.cell] = {"water": 0, "growth": 0.0, "food": 0, "reserved": -1}
	if plan.kind not in ["platform", "stairs", "stockpile", "garden", "soil_bed"]:
		buildings[plan.cell] = {"kind": plan.kind, "direction": plan.direction, "reviewed": plan.get("reviewed", false)}
		if plan.kind == "house": buildings[plan.cell].house_tier = int(plan.get("house_tier", 3))
		if plan.has("placement_offset"):
			buildings[plan.cell]["placement_offset"] = plan.placement_offset
		if plan.kind == "support": preload("res://scripts/settlement/support_runtime.gd").complete(self,plan.cell,float(plan.get("support_yaw",0.0)))
		if plan.kind in Catalog.STORAGE or plan.kind == "mine_camp" or plan.kind in Economy.RECIPES:
			if not stores.has(plan.cell): add_store(plan.cell)
			stores[plan.cell].capacity = 50 if plan.kind == "pantry" else 48
	if plan.kind in ["goods_rack", "small_warehouse"]:
		stores[plan.cell].capacity = maxi(stores[plan.cell].total(), 48 if plan.kind == "goods_rack" else 64)
		for resource: String in previous_materials:
			construction_materials[plan.cell][resource] = int(construction_materials[plan.cell].get(resource, 0)) + int(previous_materials[resource])
	if plan.kind == "stone_storage":
		buildings[plan.cell].storage_tier = int(plan.get("storage_tier", 1))
		stores[plan.cell].capacity = 32 if buildings[plan.cell].storage_tier == 1 else 64
		for resource: String in previous_materials:
			construction_materials[plan.cell][resource] = int(construction_materials[plan.cell].get(resource, 0)) + int(previous_materials[resource])
	if plan.kind == "windmill":
		buildings[plan.cell].mill_tier = int(plan.get("mill_tier", 3))
		for resource: String in previous_materials:
			construction_materials[plan.cell][resource] = int(construction_materials[plan.cell].get(resource, 0)) + int(previous_materials[resource])
	if plan.kind == "sawmill":
		buildings[plan.cell].sawmill_tier = int(plan.get("sawmill_tier", 2))
		for resource: String in previous_materials:
			construction_materials[plan.cell][resource] = int(construction_materials[plan.cell].get(resource, 0)) + int(previous_materials[resource])
	if plan.get("reviewed", false) and stores.has(plan.cell):
		stores[plan.cell].capacity = maxi(stores[plan.cell].total(), Catalog.Reviewed.capacity(plan.kind, int(Catalog.Reviewed.data.production_buffer_default) if plan.kind in Economy.RECIPES else stores[plan.cell].capacity))
	if plan.kind in Economy.EXTRACTORS:
		buildings[plan.cell].deposit_remaining = int(plan.get("relocation", {}).get("payload", {}).get("buildings", {}).get("deposit_remaining", Catalog.Reviewed.data.extraction[plan.kind].reserve))
	if plan.has("relocation"):
		Relocation.restore_payload(self, plan)
	if plan.kind == "stone_storage": stores[plan.cell].enable_slots()
	if plan.kind == "platform": Platforms.complete(self, plan.cell, Platforms.tier(platforms[plan.cell]))
	unlock_production(plan.kind)
	plans.erase(plan.id)
	if plan.kind == "house":
		for queued: Dictionary in plans.values(): Houses.price_plan(self, queued)
	for worker: Dictionary in workers:
		if worker.get("assigned_plan_id", -1) == plan.id:
			worker.assigned_plan_id = -1
	rebuild_navigation()
	last_message = "Construction complete"

func resource_total(resource: String) -> int:
	var amount := 0
	for inventory in stores.values():
		amount += inventory.count(resource)
	for plan: Dictionary in plans.values():
		if Deconstruction.is_salvage(plan): amount += plan.relocation.parts.count(resource)
	return amount

func is_stump(cell: Vector3i) -> bool:
	return trees.has(cell) and float(trees[cell].get("seed_growth", 1.0)) >= 1.0 and trees[cell].inventory.count("log") == 0

func remove_stump(cell: Vector3i, update_navigation := true) -> bool:
	if not is_stump(cell):
		return false
	# A final-log carrier may still reference this inventory; keep their haul intact.
	var inventory = trees[cell].inventory
	for worker: Dictionary in workers:
		if worker.job.get("source") != inventory: continue
		Jobs._cancel_job(self, worker)
		worker.route = []
		worker.route_index = 0
		if not worker.cargo.is_empty():
			worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": preload("res://scripts/applied_labour.gd").new(0.6)}
	trees.erase(cell)
	if update_navigation:
		# Legacy/edited worlds may overlap a tree with another solid object.
		# In that case let the full model rebuild decide which blockers remain.
		var overlaps: bool = deposits.has(cell) or wells.has(cell) or navigation.room_nodes.has(cell) or navigation.room_edges.has(cell)
		# Blocked connector endpoints may have been omitted from the graph.
		for base: Vector3i in stairs:
			var direction: int = stairs[base]
			if cell in [base, base - DIRECTIONS[direction] * Grid.CELLS_PER_ROOM, navigation.stair_landing(base, direction)]:
				overlaps = true
		for bridge: Dictionary in bridges.values():
			if cell in [bridge.a, bridge.b]: overlaps = true
		for base: Vector3i in buildings:
			var building: Dictionary = buildings[base]
			if cell in Farming.cells(building.kind, base, int(building.direction), building.get("placement_offset", Vector3.ZERO)):
				overlaps = true
				break
		if overlaps:
			rebuild_navigation()
		else:
			navigation.remove_obstacle(cell)
			revision += 1
	return true

func remove_at(cell: Vector3i) -> bool:
	if RopeBridges.supports_bridge(self, cell, Relocation.kind_at(self, cell)):
		last_message = "Move or remove the attached bridge first"; return false
	if Relocation.locked(self, cell):
		return false
	# Deleting a connector underneath an actor would strand them in mid-air.
	for worker in workers:
		if worker.route_index < worker.route.size() and navigation.ladder_cell(worker.cell, worker.route[worker.route_index]) == cell:
			last_message = "Wait until the worker clears this space"
			return false
		if worker.cell == cell or (worker.route_index < worker.route.size() and worker.route[worker.route_index] == cell):
			last_message = "Wait until the worker clears this space"
			return false
	if stairs.has(cell):
		stairs.erase(cell)
		rebuild_navigation()
		last_message = "Stairs removed · routes will be recalculated"
		return true
	last_message = "Only stairs can be removed in this prototype"
	return false


func snapshot() -> Dictionary:
	return SaveCodec.snapshot(self)

func restore(data: Dictionary) -> bool:
	var restored := SaveCodec.restore(self, data)
	if restored:
		idle_seconds.clear()
		Economy.ensure_output_stores(self)
		timber_visuals_reset.emit()
	return restored

func surface_at(x: int, z: int) -> Vector3i:
	return Vector3i(x, int(terrain_heights.get(Vector2i(x, z), 0)), z)

func request_collect_water(cell: Vector3i) -> bool:
	var inventory = Hydrology.inventory_at(self, cell)
	if inventory == null or inventory.available("water") <= 0:
		last_message = "No water yet"
		return false
	water_orders[cell] = inventory.available("water")
	last_message = "Water collection queued"
	revision += 1
	return true

func order_collect_water(id: int, cell: Vector3i) -> bool:
	if id < 0 or id >= workers.size() or not can_control(workers[id]) or Hydrology.inventory_at(self, cell) == null or Relocation.locked(self, cell): return false
	if not exploration.contains(Navigation.point(cell)) or navigation.route(workers[id].cell, cell).is_empty(): return false
	if not set_role(id, "hauler"): return false
	var worker: Dictionary = workers[id]
	worker.assigned_water_source = cell
	if worker.job.is_empty(): Jobs._tick_worker(self, worker, 0.0)
	return true

func can_control(worker: Dictionary) -> bool:
	return Citizens.is_adult(worker)

func _is_idle(worker: Dictionary) -> bool:
	return not worker.has("clearance_route") and can_control(worker) and worker.job.is_empty() and worker.cargo.is_empty() and worker.route_index >= worker.route.size()

func idle_citizen_ids() -> Array[int]:
	var ids: Array[int] = []
	for worker: Dictionary in workers:
		if _is_idle(worker) and float(idle_seconds.get(worker.id, 0.0)) >= IDLE_DETECTION_SECONDS:
			ids.append(worker.id)
	return ids

func tick_citizen_job(worker: Dictionary, delta: float) -> void:
	Jobs._tick_worker(self, worker, delta)
	discover_resource(worker.cargo)

func set_role(id: int, role: String, plan_id := -1) -> bool:
	if id < 0 or id >= workers.size() or not can_control(workers[id]) or role not in Economy.ROLES:
		return false
	if RopeBridges.crossing(self, workers[id]):
		last_message = "Finish crossing first"; return false
	var worker: Dictionary = workers[id]
	if not worker.job.is_empty():
		Jobs._cancel_job(self, worker)
	idle_seconds.erase(id)
	Jobs.clear_retry(worker)
	worker.role = role
	worker.assigned_plan_id = plan_id
	worker.erase("assigned_workplace")
	worker.erase("assigned_water_source")
	worker.route = []
	worker.route_index = 0
	if not Jobs.cargo_matches_role(self, worker, role, plan_id):
		Deconstruction.drop_cargo(self, worker)
	if not worker.cargo.is_empty() and role != "builder":
		worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Jobs.Labour.new(0.6)}
	revision += 1
	return true

func order_workplace(id: int, cell: Vector3i) -> bool:
	var kind: String = buildings.get(cell, {}).get("kind", "")
	if id < 0 or id >= workers.size() or not can_control(workers[id]) or not Economy.is_workplace(kind) or Relocation.locked(self, cell): return false
	if navigation.route(workers[id].cell, cell).is_empty(): return false
	if kind != "windmill" and workers.any(func(other): return other.id != id and other.get("assigned_workplace") == cell): return false
	if not set_role(id, Economy.workplace_role(kind)): return false
	var worker: Dictionary = workers[id]
	worker.assigned_workplace = cell
	# Choose a pickup or use the input already in hand immediately.
	if not Jobs.assign_workplace(self, worker, kind) and worker.job.is_empty():
		Jobs._tick_worker(self, worker, 0.0)
	return true

func order_build(id: int, plan_id: int) -> bool:
	if id < 0 or id >= workers.size() or not can_control(workers[id]) or not plans.has(plan_id):
		return false
	var plan: Dictionary = plans[plan_id]
	var targets := work_cells(plan.kind, plan.cell, plan.direction)
	if plan.has("relocation") and plan.relocation.stage == "dismantle":
		targets = Relocation.source_work_cells(self, plan.kind, plan.relocation.source, plan.direction)
	elif plan.get("deconstruction", false) and plan.relocation.stage == "salvage":
		targets.assign([plan.relocation.pickup_cell])
	if nearest_route(workers[id].cell, targets).is_empty():
		return false
	if not set_role(id, "builder", plan_id): return false
	var worker: Dictionary = workers[id]
	# Choose the material source now; do not walk to the site empty-handed.
	if worker.job.is_empty():
		Jobs._tick_worker(self, worker, 0.0)
	return true

func order_move(id: int, cell: Vector3i) -> bool:
	if id < 0 or id >= workers.size() or not can_control(workers[id]):
		return false
	if RopeBridges.crossing(self, workers[id]):
		last_message = "Finish crossing first"; return false
	var route := navigation.route(workers[id].cell, cell)
	if route.is_empty():
		last_message = "waiting · destination unreachable"
		return false
	var worker: Dictionary = workers[id]
	if not worker.job.is_empty():
		Jobs._cancel_job(self, worker)
	idle_seconds.erase(id)
	worker.assigned_plan_id = -1
	worker.erase("assigned_workplace")
	worker.erase("assigned_water_source")
	worker.job = {"kind": "move", "phase": "travel", "target": cell, "labour": Jobs.Labour.new(0.1)}
	Jobs._set_route(self, worker, route, "economy_walking_text")
	revision += 1
	return true

func rock_solid(point: Vector3) -> bool:
	var x := roundi(point.x / Grid.CELL_SIZE)
	var z := roundi(point.z / Grid.CELL_SIZE)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var base := surface_at(x + dx, z + dz)
			var deposit: Dictionary = deposits.get(base, {})
			if deposit.get("kind") != "limestone" or deposit.inventory.capacity <= 30: continue
			var local := point - Navigation.point(base)
			if local.y < 0 or local.y > Economy.StoneVolume.MAX_HEIGHT: continue
			if stone_geometry().solid_at(base, world_seed, deposit.inventory.count("stone"), local, deposit.inventory.capacity): return true
	return false

func rock_supports(cell: Vector3i) -> bool:
	var point := Navigation.point(cell)
	return rock_solid(point - Vector3.UP * 0.002) and not rock_solid(point + Vector3.UP * 0.002)

func rock_blocks_build(kind: String, cell: Vector3i, offset := Vector3.ZERO, direction := 0) -> bool:
	if deposits.is_empty(): return false
	var height := float(Catalog.building_height(kind)) if kind in Catalog.ROOFS or kind == "stairs" else 1.0
	var footprint := Farming.footprint(kind, cell, offset, direction)
	var bounds := AABB(Vector3(footprint.position.x, Navigation.point(cell).y + offset.y, footprint.position.y), Vector3(footprint.size.x, height, footprint.size.y)).grow(-0.0001)
	var radius := ceili(maxf(footprint.size.x, footprint.size.y) * 0.5) + Economy.StoneVolume.RADIUS + 1
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var base := surface_at(cell.x + dx, cell.z + dz)
			var deposit: Dictionary = deposits.get(base, {})
			if deposit.get("kind") != "limestone" or deposit.inventory.capacity <= 30: continue
			var local := AABB(bounds.position - Navigation.point(base), bounds.size)
			if local.end.y <= 0 or local.position.y >= Economy.StoneVolume.MAX_HEIGHT: continue
			for box in stone_geometry().occupied_boxes(base, world_seed, deposit.inventory.count("stone"), deposit.inventory.capacity):
				if local.intersects(box): return true
	return false

func remove_rock_interiors(surfaces: Dictionary) -> void:
	# Both full rebuilds and streamed chunks remove every filled cell, not only
	# the resource's centre. Boundary routes must clear a citizen's body as well.
	for base: Vector3i in deposits:
		var deposit: Dictionary = deposits[base]
		if deposit.kind != "limestone" or deposit.inventory.capacity <= 30 or deposit.inventory.count("stone") == 0: continue
		var boxes: Array = stone_geometry().occupied_boxes(base, world_seed, deposit.inventory.count("stone"), deposit.inventory.capacity)
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				for height in range(0, int(Economy.StoneVolume.MAX_HEIGHT)):
					var cell := base + Vector3i(dx, height, dz)
					if not surfaces.has(cell): continue
					var body := AABB(Vector3(dx - 0.18, height + 0.002, dz - 0.18), Vector3(0.36, 1.4, 0.36))
					for box in boxes:
						if body.intersects(box):
							surfaces.erase(cell)
							break

func rock_in_use(cell: Vector3i) -> bool:
	for collection in [buildings, plans]:
		for key in collection:
			if collection == plans and Deconstruction.is_salvage(plans[key]): continue
			var base: Vector3i = key if collection == buildings else collection[key].cell
			if base.y > cell.y and base.y <= cell.y + int(Economy.StoneVolume.MAX_HEIGHT) + 1 and absi(base.x - cell.x) <= 2 and absi(base.z - cell.z) <= 2: return true
	for worker: Dictionary in workers:
		if worker.cell.y > cell.y and worker.cell.y <= cell.y + int(Economy.StoneVolume.MAX_HEIGHT) + 1 and absi(worker.cell.x - cell.x) <= 2 and absi(worker.cell.z - cell.z) <= 2: return true
	return false

func stone_geometry():
	return preload("res://scripts/settlement/eroded_stone.gd") if SolidIslands.enabled(self) and generator_version>=10 else Economy.StoneVolume

func rock_surfaces(base: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var deposit: Dictionary = deposits.get(base, {})
	if deposit.get("kind") != "limestone" or deposit.inventory.capacity <= 30 or deposit.inventory.count("stone") == 0: return result
	# Top surfaces depend on this quarry and any overlapping neighbours, not
	# on an unrelated building completing elsewhere in the loaded world.
	var state: Array = [world_seed]
	for dx in range(-4, 5):
		for dz in range(-4, 5):
			var nearby := surface_at(base.x + dx, base.z + dz)
			var rock: Dictionary = deposits.get(nearby, {})
			if rock.get("kind") == "limestone" and rock.inventory.capacity > 30:
				state.append([nearby, rock.inventory.capacity, rock.inventory.count("stone")])
	if rock_surface_cache.has(base) and rock_surface_cache[base].state == state:
		return rock_surface_cache[base].surfaces.duplicate()
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for height in range(1, int(Economy.StoneVolume.MAX_HEIGHT) + 1):
				var top := base + Vector3i(dx, height, dz)
				if rock_supports(top): result.append(top)
	if rock_surface_cache.size() >= 512: rock_surface_cache.clear()
	rock_surface_cache[base] = {"state": state, "surfaces": result.duplicate()}
	return result

func platform_posts_overlap(kind: String, cell: Vector3i) -> bool:
	var height := int(Catalog.building_height(kind)) if kind in Catalog.ROOFS or kind == "stairs" else 1
	for deck: Vector3i in platforms:
		var bottom := deck.y - Platforms.tier(platforms[deck])
		if cell.y < deck.y and cell.y + height > bottom and Grid.overlaps(Vector3i(cell.x, deck.y, cell.z), deck): return true
	return false
