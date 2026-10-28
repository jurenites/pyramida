extends RefCounted
## Peaceful village economy. Tuning is ours; the production relationships follow Pyramida.
const Farming = preload("res://scripts/settlement/farming.gd")
const Balance = preload("res://scripts/settlement/balance.gd")
const BUSH_CAPACITY := 3
const StoneVolume = preload("res://scripts/settlement/stone_volume.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Vegetation = preload("res://scripts/settlement/vegetation_patches.gd")
const RESOURCES := ["log", "food", "water", "grain", "plank", "stone", "block", "pottery"]
const ROLES := ["auto", "builder", "forager", "farmer", "baker", "woodcutter", "sawyer", "miner", "mason", "hauler", "idle"]
const RECIPES := {
	"sawmill": {"input": "log", "output": "plank", "role": "sawyer"},
	"windmill": {"input": "grain", "output": "food", "role": "baker"},
	"masonry": {"input": "stone", "output": "block", "role": "mason"},
}
const STORAGE := {"goods_rack": ["pottery"], "small_warehouse": ["pottery"], "stone_storage": ["stone"], "log_shed": ["log"], "hay_barn": ["grain"], "house": ["food"],
	"stockpile": ["stone", "block", "plank", "water", "pottery"], "mine_camp": ["stone", "block"], "pantry": []}

static func food_target(world) -> int:
	# Two meals in reserve plus the next meal round, so ordinary eating does not
	# constantly undo growth. Foraging and baking must target the same reserve.
	return maxi(6, world.workers.size() * 3)

static func storage_capacity(world, resource: String) -> int:
	var total := 0
	for cell: Vector3i in world.stores:
		var inventory = world.stores[cell]
		# Legacy supplies remain usable, but unsupported stores gain no new space.
		total += inventory.capacity if accepts(world, cell, resource) else inventory.count(resource)
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
	# Resources outside the supplied starting stockpile remain physical, finite stock.
	var berry_centres := [Vector3i(-10, 0, 6), Vector3i(4, 0, 8), Vector3i(10, 0, -8), Vector3i(-16, 0, -8)]
	for patch in berry_centres.size():
		seed_berry_patch(world, frontier, berry_centres[patch], patch)
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
	var kind: String = world.buildings.get(cell, {}).get("kind", "stockpile")
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
	return "grain" if world.buildings.get(cell, {}).get("kind") == "hay_field" or world.gardens.get(cell, {}).get("species") == "grass" else "food"

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
		if deposit.kind == "berry" and not world.Relocation.locked(world, cell) and float(deposit.get("seed_growth", 1.0)) >= 1.0 and grow_bush(deposit, delta * Farming.light_rate(world, cell)):
			world.revision += 1
	for cell: Vector3i in world.gardens:
		if field_resource(world, cell) == "grain" and irrigated(world, cell) and world.gardens[cell].water == 0:
			world.gardens[cell].water = 1
	# A food shortage pauses earned progress instead of erasing it every meal.
	if world.workers.size() >= mini(capacity(world), 30):
		world.birth_clock = 0.0
		return
	if world.resource_total("food") < world.workers.size() * 2: return
	var home: Variant = null
	var arrival: Variant = null
	for cell: Vector3i in world.buildings:
		if world.buildings[cell].kind != "house" or world.Relocation.locked(world, cell) or world.Houses.room_occupancy(world, cell) >= world.Houses.ROOM_RESIDENTS: continue
		for worker: Dictionary in world.workers:
			if not world.can_control(worker): continue
			var route: Array[Vector3i] = world.navigation.route(worker.cell, cell)
			if not route.is_empty():
				home = cell
				arrival = route.back()
				break
		if home != null: break
	if home == null: return
	world.birth_clock += delta
	if world.birth_clock < Balance.number("birth_interval_seconds"): return
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
