extends RefCounted
## Bucket inventories and seasonal recharge; terrain volumes own foundations.
const Inventory = preload("res://scripts/settlement/inventory.gd")
const CYCLE_SECONDS := 120
const RAIN_START := 90
const RAIN_END := 106
const WELL_STORAGE := 3
const WELL_CAPACITY := 6 # Legacy on-puddle capacity.

static func populate(world, definitions: Dictionary) -> void:
	world.water_sources.clear()
	for cell: Vector3i in definitions:
		var inventory = Inventory.new()
		inventory.capacity = 3 if definitions[cell] == "puddle" else 2
		inventory.store("water", inventory.capacity)
		world.water_sources[cell] = {"kind": definitions[cell], "inventory": inventory}

static func tick(world, delta: float) -> void:
	world.weather.remainder += delta
	# Fixed environmental seconds make weather independent of frame/tick rate.
	while world.weather.remainder + 0.000000001 >= 1.0:
		world.weather.remainder = maxf(0.0, world.weather.remainder - 1.0)
		world.weather.seconds += 1
		var second: int = world.weather.seconds
		var was_raining: bool = world.weather.raining
		world.weather.raining = second % CYCLE_SECONDS >= RAIN_START and second % CYCLE_SECONDS < RAIN_END
		if second % CYCLE_SECONDS == RAIN_START:
			world.weather.rain_count += 1
		var changed: bool = was_raining != world.weather.raining
		for cell: Vector3i in world.water_sources:
			if world.wells.has(cell): continue
			var source: Dictionary = world.water_sources[cell]
			var inventory = source.inventory
			if world.weather.raining and second % 4 == 0 and inventory.total() < inventory.capacity:
				inventory.store("water")
				changed = true
			elif not world.weather.raining and second % (35 if source.kind == "puddle" else 120) == 0 and inventory.available("water") > 0:
				# Never evaporate a bucket reserved by a citizen already travelling.
				inventory.amounts.water -= 1
				changed = true
		if world.weather.raining and second % 4 == 0:
			for cell: Vector3i in world.wells:
				if not world.Volume.well_connected(world, cell): continue
				var inventory = world.wells[cell]
				var amount := mini(inventory.capacity - inventory.total(), rain_yield(world, cell) * units(world.buildings.get(cell, {})))
				if amount > 0:
					inventory.store("water", amount)
					changed = true
		preload("res://scripts/settlement/vines.gd").tick_second(world)
		if changed:
			world.revision += 1

static func seconds_to_rain(world) -> int:
	return posmod(RAIN_START - int(world.weather.seconds), CYCLE_SECONDS)

# A tile means the minimum terrain cell; diagonals use the same distance ring.
static func rain_yield(world, cell: Vector3i) -> int:
	var result := 1
	for x in range(-1, 2):
		for z in range(-1, 2):
			var nearby := cell + Vector3i(x, 0, z)
			if world.water_sources.get(nearby, {}).get("kind") == "puddle":
				result = maxi(result, 3 - maxi(absi(x), absi(z)))
	return result

static func units(building: Dictionary) -> int:
	# Legacy authored wells had the roofed silhouette, but only one storage unit.
	return int(building.get("well_units", 1))

static func inventory_at(world, cell: Vector3i):
	return world.wells.get(cell, world.water_sources.get(cell, {}).get("inventory"))

static func _take_puddle(world, cell: Vector3i, inventory) -> void:
	if world.water_sources.get(cell, {}).get("kind") != "puddle": return
	var source = world.water_sources[cell].inventory
	var amount: int = mini(source.count("water"), inventory.capacity - inventory.total())
	inventory.store("water", amount)
	source.amounts["water"] = source.count("water") - amount
	# In-flight collectors keep their reservation and collect from the finished utility.
	for owner: int in source.reservations:
		inventory.reservations[owner] = source.reservations[owner]
	for worker: Dictionary in world.workers:
		if worker.job.get("source") == source: worker.job.source = inventory
	source.reservations.clear()

static func complete(world, plan: Dictionary) -> void:
	var cell: Vector3i = plan.cell
	var existing: Dictionary = world.buildings.get(cell, {})
	var payload: Dictionary = plan.get("relocation", {}).get("payload", {})
	var incoming: Dictionary = payload.get("buildings", {})
	var count := units(existing) if world.wells.has(cell) else 0
	if plan.kind == "well" or not payload.is_empty(): count += units(incoming)
	count = maxi(1, count)
	var inventory = world.wells.get(cell, Inventory.new())
	inventory.capacity = inventory.capacity + (count - units(existing)) * WELL_STORAGE if world.wells.has(cell) else rain_yield(world, cell) + count * WELL_STORAGE
	var materials: Dictionary = world.construction_materials.get(cell, {}).duplicate()
	for resource: String in plan.materials:
		materials[resource] = int(materials.get(resource, 0)) + int(plan.materials[resource])
	var overflow := 0
	if not world.wells.has(cell): _take_puddle(world, cell, inventory)
	if payload.has("wells"):
		var amount: int = payload.wells.count("water")
		var accepted := mini(amount, inventory.capacity - inventory.total())
		inventory.store("water", accepted)
		overflow = amount - accepted
		payload.wells.amounts.clear()
	world.wells[cell] = inventory
	if cell == world.well: world.well_inventory = inventory
	var wrapped: bool = plan.kind == "waterworks" or existing.get("kind") == "waterworks"
	world.buildings[cell] = {"kind": "waterworks" if wrapped else "well", "direction": existing.get("direction", plan.direction),
		"placement_offset": existing.get("placement_offset", plan.get("placement_offset", Vector3.ZERO)), "well_units": count}
	world.construction_materials[cell] = materials
	if overflow > 0:
		# Excess carried water remains a haulable bucket cache, never vanishes on merge.
		var salvage: Dictionary = plan.duplicate(true)
		var id: int = world.next_plan_id
		world.next_plan_id += 1
		salvage.id = id
		salvage.cell = salvage.relocation.source
		salvage.deconstruction = true
		salvage.relocation.payload = {}
		salvage.relocation.stage = "salvage"
		salvage.relocation.owner = -1
		salvage.relocation.parts = Inventory.new()
		salvage.relocation.parts.capacity = maxi(32, overflow)
		salvage.relocation.parts.store("water", overflow)
		world.plans[id] = salvage
