extends RefCounted
## Peaceful village economy. Physical gathering, crafting and town growth.
const Reviewed = preload("res://scripts/settlement/reviewed_balance.gd")
const Farming = preload("res://scripts/settlement/farming.gd")
const Balance = preload("res://scripts/settlement/balance.gd")
const BUSH_CAPACITY := 3
const StoneVolume = preload("res://scripts/settlement/stone_volume.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Vegetation = preload("res://scripts/settlement/vegetation_patches.gd")
const RESOURCES := ["log", "food", "water", "grain", "plank", "stone", "block", "pottery", "flour", "clay", "brick", "ore", "imbrex", "rope"]
const ROLES := ["auto", "builder", "forager", "farmer", "baker", "woodcutter", "sawyer", "miner", "mason", "hauler", "idle", "miller", "potter", "kilner", "claydigger", "prospector", "tiler", "ropemaker"]
const EXTRACTORS := {"claypit": {"output": "clay", "role": "claydigger"}, "mine": {"output": "ore", "role": "prospector"}}
static var RECIPES: Dictionary = preload("res://scripts/settlement/reviewed_balance.gd").data.recipes.merged({
	"rope_maker": {"input": "grain", "output": "rope", "role": "ropemaker"},
	"windmill": {"input": "grain", "output": "food", "role": "baker"},
}) # Legacy mill saves retain their original recipe.
const STORAGE := {"tilery": ["clay", "imbrex"], "rope_maker": ["grain", "rope"], "brickyard": ["clay", "brick"], "quarry": ["stone"], "mill": ["grain", "flour"], "bakery": ["flour", "food"], "pottery_workshop": ["clay", "pottery"], "kiln": ["clay", "brick"], "goods_rack": ["pottery"], "small_warehouse": ["pottery"], "stone_storage": ["stone", "block"], "log_shed": ["log", "plank"], "hay_barn": ["grain", "flour"], "house": ["food", "water", "pottery"],
	"sawmill": ["log", "plank"], "masonry": ["stone", "block"], "windmill": ["grain", "food"], "mine_camp": ["stone", "block"], "pantry": []}

static func ensure_output_stores(world) -> void:
	for cell: Vector3i in world.buildings:
		if world.buildings[cell].kind in RECIPES and not world.stores.has(cell):
			world.add_store(cell)
			world.stores[cell].capacity = preload("res://scripts/settlement/reviewed_balance.gd").capacity(world.buildings[cell].kind, int(Reviewed.data.production_buffer_default))

static func resource_capacity(world, cell: Vector3i, resource: String) -> int:
	var kind: String = world.buildings.get(cell, {}).get("kind", "")
	if kind == "house":
		if resource == "water": return mini(int(Reviewed.data.vase.house_vases), world.stores[cell].count("pottery")) * int(Reviewed.data.vase.water_capacity)
		if resource == "pottery": return int(Reviewed.data.vase.house_vases)
		return {"food": world.Houses.ROOM_FOOD, "pottery": 3}.get(resource, 0)
	# Inputs cannot fill the space needed for a workshop's own output.
	if kind in RECIPES: return int(world.stores[cell].capacity / 2)
	return world.stores[cell].capacity if accepts(world, cell, resource) else 0

static func storage_space(world, cell: Vector3i, resource: String) -> int:
	var stock = world.stores[cell]
	return maxi(0, mini(stock.capacity - stock.total(), resource_capacity(world, cell, resource) - stock.count(resource)))

static func food_target(world) -> int:
	# Keep three meal rounds available. Foraging and baking share this target;
	# population growth depends on housing, independently of stored food.
	return maxi(6, world.workers.size() * 3)

static func storage_capacity(world, resource: String) -> int:
	var total := 0
	for cell: Vector3i in world.stores:
		var inventory = world.stores[cell]
		# Real stores keep their configured limit even when an older save is overfull.
		# Unhoused legacy supplies remain recoverable without accepting deliveries.
		total += resource_capacity(world, cell, resource) if world.buildings.has(cell) else inventory.count(resource)
	return total

static func setup(world) -> void:
	# Keep the opening resources on the connected starting surface.
	# Outer mountains still require the player's ladders; critical resources do not.
	var reachable := {Vector3i.ZERO: true}
	var frontier: Array[Vector3i] = [Vector3i.ZERO]
	var index := 0
	while index < frontier.size():
		var cell := frontier[index]
		index += 1
		for direction: Vector3i in Navigation.DIRECTIONS:
			var next := cell + direction
			if world.ground.has(next) and not world.terrain_shapes.has(next) and not reachable.has(next):
				reachable[next] = true
				frontier.append(next)
	seed_hay_patches(world, frontier)
	# Resources outside the family's house remain physical, finite stock.
	var berry_centres := [Vector3i(-10, 0, 6), Vector3i(4, 0, 8), Vector3i(10, 0, -8), Vector3i(-16, 0, -8)]
	for patch in berry_centres.size():
		seed_berry_patch(world, frontier, berry_centres[patch], patch)
	if preload("res://scripts/settlement/solid_islands.gd").enabled(world) and world.generator_version>=10:
		preload("res://scripts/settlement/geological_deposits.gd").seed(world,frontier)
		return
	for spec in [[7, 3], [-7, 5], [11, -5], [-12, -8]]:
		var cell := nearest_free(world, frontier, Vector3i(spec[0] * 2, 0, spec[1] * 2))
		if cell == Vector3i.ZERO:
			continue
		var inventory = Inventory.new()
		inventory.capacity = StoneVolume.capacity(cell, world.world_seed)
		inventory.store("stone", inventory.capacity)
		world.deposits[cell] = {"kind": "limestone", "inventory": inventory, "regrowth": 0.0}

static func seed_berry_patch(world, reachable: Array[Vector3i], desired: Vector3i, patch: int) -> void:
	var offsets := Vegetation.bush_offsets(patch, patch)
	# Naturally established bushes begin mature and full.
	offsets.resize(mini(offsets.size(), 8))
	var candidates := reachable.duplicate()
	candidates.sort_custom(func(a, b): return a.distance_squared_to(desired) < b.distance_squared_to(desired))
	for centre: Vector3i in candidates:
		var cells: Array[Vector3i] = []
		for offset: Vector2i in offsets:
			var cell := centre + Vector3i(offset.x, 0, offset.y)
			# Leave room for the family's first construction around the origin.
			if maxi(absi(cell.x), absi(cell.z)) <= 5: break
			if not reachable.has(cell) or world.terrain_shapes.has(cell) or world.occupied(cell, "berry"): break
			cells.append(cell)
		if cells.size() != offsets.size(): continue
		for index in cells.size():
			var inventory = Inventory.new()
			inventory.capacity = BUSH_CAPACITY
			inventory.store("food", inventory.capacity)
			world.deposits[cells[index]] = {"kind": "berry", "inventory": inventory, "regrowth": 0.0}
		return

static func nearest_free(world, cells: Array[Vector3i], desired: Vector3i) -> Vector3i:
	var result := Vector3i.ZERO
	var distance := INF
	for cell: Vector3i in cells:
		if world.occupied(cell) or world.terrain_shapes.has(cell):
			continue
		var candidate := cell.distance_squared_to(desired)
		if candidate < distance:
			distance = candidate
			result = cell
	return result

static func count_buildings(world, kind: String) -> int:
	var count := 0
	for building: Dictionary in world.buildings.values():
		count += int(building.kind == kind)
	return count

static func work_speed(world) -> float:
	return Balance.number("work_speed_multiplier") * (Balance.number("workshop_speed_multiplier") if count_buildings(world, "workshop") > 0 else 1.0)

static func production_speed(world, cell: Vector3i) -> float:
	var building: Dictionary = world.buildings.get(cell, {})
	if building.get("kind") == "windmill":
		var tier := int(building.get("mill_tier", 3))
		if tier == 1: return 0.5
		if tier == 3: return 1.5
		var operators := 0
		for worker: Dictionary in world.workers:
			if worker.job.get("kind") == "process" and worker.job.get("target") == cell and worker.job.get("phase") == "work": operators += 1
		return 1.0 if operators >= 2 else 0.0
	if building.get("kind") != "sawmill": return 1.0
	return [0.75, 1.0, 1.5][clampi(int(building.get("sawmill_tier", 2)), 1, 3) - 1]

static func capacity(world) -> int:
	return count_buildings(world, "house") * world.Houses.ROOM_RESIDENTS

static func accepts(world, cell: Vector3i, resource: String) -> bool:
	var kind: String = world.buildings.get(cell, {}).get("kind", "")
	return resource in STORAGE.get(kind, [])

static func irrigated(world, cell: Vector3i) -> bool:
	for source: Vector3i in world.wells:
		if source.y == cell.y and absi(source.x - cell.x) <= 4 and absi(source.z - cell.z) <= 4:
			return true
	for source: Vector3i in world.water_sources:
		if source.y == cell.y and absi(source.x - cell.x) <= 2 and absi(source.z - cell.z) <= 2 and world.water_sources[source].inventory.count("water") > 0:
			return true
	return false

static func field_resource(world, cell: Vector3i) -> String:
	return "grain" if Farming.is_hay(world, cell) or world.gardens.get(cell, {}).get("species") == "grass" else "food"

# A growth interval adds one capacity slot and one berry, never two berries.
# Mature full bushes do not bank time toward an instant refill after picking.
static func grow_bush(deposit: Dictionary, delta: float) -> bool:
	if delta <= 0.0:
		return false
	var inventory = deposit.inventory
	if inventory.capacity >= BUSH_CAPACITY and inventory.total() >= inventory.capacity:
		deposit.regrowth = 0.0
		return false
	var interval: float = Balance.number("berry_regrowth_seconds")
	deposit.regrowth += delta
	var intervals := floori(deposit.regrowth / interval)
	if intervals == 0:
		return false
	var previous_capacity: int = inventory.capacity
	inventory.capacity += mini(intervals, maxi(0, BUSH_CAPACITY - inventory.capacity))
	var added := mini(intervals, inventory.capacity - inventory.total())
	inventory.store("food", added)
	deposit.regrowth = fmod(deposit.regrowth, interval)
	if inventory.capacity >= BUSH_CAPACITY and inventory.total() == inventory.capacity:
		deposit.regrowth = 0.0
	return added > 0 or inventory.capacity != previous_capacity

static func tick(world, delta: float) -> void:
	for cell: Vector3i in world.deposits:
		var deposit: Dictionary = world.deposits[cell]
		if deposit.kind != "berry" or float(deposit.get("seed_growth", 1.0)) < 1.0: continue
		# Full bushes cannot grow. Avoid scanning construction plans and testing
		# shade for every mature bush across all loaded chunks on every tick.
		var inventory = deposit.inventory
		if inventory.capacity >= BUSH_CAPACITY and inventory.total() >= inventory.capacity and deposit.regrowth == 0.0:
			continue
		if not world.Relocation.locked(world, cell) and grow_bush(deposit, delta * Farming.light_rate(world, cell)):
			world.revision += 1
	for cell: Vector3i in world.gardens:
		if not Farming.is_hay(world, cell) and field_resource(world, cell) == "grain" and irrigated(world, cell) and world.gardens[cell].water == 0:
			world.gardens[cell].water = 1
	# Completed, reachable housing enables growth even when food stores are empty.
	if world.workers.size() >= mini(capacity(world), 30):
		world.birth_clock = 0.0
		return
	var home: Variant = null
	var parent_cell := Vector3i.ZERO
	for cell: Vector3i in world.buildings:
		if world.buildings[cell].kind != "house" or world.Relocation.locked(world, cell) or world.Houses.room_occupancy(world, cell) >= world.Houses.ROOM_RESIDENTS: continue
		for worker: Dictionary in world.workers:
			if not world.can_control(worker): continue
			if world.navigation.can_reach(worker.cell, cell):
				home = cell
				parent_cell = worker.cell
				break
		if home != null: break
	if home == null: return
	world.birth_clock += delta
	if world.birth_clock < Balance.number("birth_interval_seconds"): return
	var arrival: Vector3i = world.navigation.route(parent_cell, home).back()
	var id: int = world.workers.size()
	world.workers.append({"id": id, "cell": arrival, "home_cell": home, "position": world.navigation.surface_point(arrival), "route": [], "route_index": 0,
		"job": {}, "cargo": "", "status": "growing up", "distance": 0.0, "hunger": 0.0,
		"life_stage": "child", "growth_seconds": 0.0, "appearance": id % 4, "cloth_color": id % 5, "role": "auto", "assigned_plan_id": -1})
	world.birth_clock = 0.0
	world.revision += 1


static func upgrade_stone(deposit: Dictionary, cell: Vector3i, world_seed: int) -> void:
	if deposit.kind != "limestone" or deposit.inventory.capacity != 6: return
	var inventory = deposit.inventory
	var capacity := StoneVolume.capacity(cell, world_seed)
	inventory.amounts["stone"] = roundi(float(inventory.count("stone")) / 6.0 * capacity)
	inventory.capacity = capacity

static func is_workplace(kind: String) -> bool:
	return kind in RECIPES or kind in EXTRACTORS or kind == "quarry"

static func workplace_role(kind: String) -> String:
	if kind == "quarry": return "miner"
	return str(RECIPES.get(kind, EXTRACTORS.get(kind, {})).get("role", "idle"))

static func seed_hay_patches(world, candidates: Array[Vector3i]) -> void:
	# Natural grass breaks Field -> Hay -> Field startup dependence.
	if world.gardens.values().any(func(crop): return crop.get("species") == "grass" or crop.has("field_layout")) or count_buildings(world, "hay_field") > 0: return
	for desired in [Vector3i(-3, 0, 8), Vector3i(3, 0, 6), Vector3i(9, 0, 2)]:
		var cell := nearest_free(world, candidates, desired)
		if cell == Vector3i.ZERO: continue
		world.gardens[cell] = {"species": "grass", "water": 0, "growth": 0.0, "food": Farming.HARVEST, "reserved": -1}

static func ensure_hay_source(world) -> void:
	if world.workers.is_empty() or world.resource_total("grain") > 0 or count_buildings(world, "hay_field") > 0 or world.gardens.values().any(func(crop): return crop.get("species") == "grass"): return
	var frontier: Array[Vector3i] = world.navigation.access_cells(world.workers[0].cell)
	var seen := {}; var candidates: Array[Vector3i] = []; var cursor := 0
	for cell in frontier: seen[cell] = true
	while cursor < frontier.size():
		var cell := frontier[cursor]; cursor += 1
		if world.ground.has(cell): candidates.append(cell)
		for neighbour: Vector3i in world.navigation.edges.get(cell, []):
			if seen.has(neighbour): continue
			seen[neighbour] = true; frontier.append(neighbour)
	seed_hay_patches(world, candidates)
