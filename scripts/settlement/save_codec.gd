extends RefCounted
## Versioned JSON codec. Preserves shared inventories and in-flight reservations.
const Desires = preload("res://scripts/desire_state.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Planting = preload("res://scripts/settlement/planting.gd")
const Labour = preload("res://scripts/applied_labour.gd")
const Citizens = preload("res://scripts/settlement/citizen_lifecycle.gd")
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Jobs = preload("res://scripts/settlement/job_system.gd")
# Read-only compatibility for saves created before these buildings were removed.
const RETIRED_BUILDINGS := {"archer_hut": 10, "wall": 1, "gate": 3, "watch_tower": 5, "brick_road": 1}

static func snapshot(world) -> Dictionary:
	var inventories := {"well": world.well_inventory}
	for cell: Vector3i in world.wells:
		if world.wells[cell] != world.well_inventory:
			inventories["well:%s" % cell] = world.wells[cell]
	for cell: Vector3i in world.stores:
		inventories["store:%s" % cell] = world.stores[cell]
	for cell: Vector3i in world.trees:
		inventories["tree:%s" % cell] = world.trees[cell].inventory
	for cell: Vector3i in world.water_sources:
		inventories["surface_water:%s" % cell] = world.water_sources[cell].inventory
	for cell: Vector3i in world.deposits:
		inventories["deposit:%s" % cell] = world.deposits[cell].inventory
	for plan: Dictionary in world.plans.values():
		if not plan.has("relocation"): continue
		inventories["relocation:%s" % plan.id] = plan.relocation.parts
		for field: String in plan.relocation.payload:
			var value: Variant = plan.relocation.payload[field]
			if field in ["stores", "wells"]: inventories["relocation:%s:%s" % [plan.id, field]] = value
			elif field in ["trees", "deposits"]: inventories["relocation:%s:%s" % [plan.id, field]] = value.inventory
	var references := {}
	var inventory_data := {}
	for key: String in inventories:
		var inventory = inventories[key]
		references[inventory] = key
		inventory_data[key] = {"amounts": inventory.amounts, "reservations": inventory.reservations, "capacity": inventory.capacity}
	return {"version": 5, "inventories": _encode(inventory_data, references), "world": _encode({
		"explored": world.exploration.snapshot(),
		"discovered_resources": world.discovered_resources,
		"deposits": world.deposits, "birth_clock": world.birth_clock,
		"grid_version": 3, "platform_tiers": true,
		"level_height": Grid.LEVEL_HEIGHT,
		"streaming": {"enabled": world.streaming_enabled, "loaded": world.loaded_chunks, "dormant": world.dormant_chunks},
		"difficulty": world.difficulty, "world_seed": world.world_seed, "generator_version": world.generator_version,
		"soil_enabled": world.soil_enabled, "soil_cuts": world.soil_cuts,
		"surface_edits": world.surface_edits, "volume_edits": world.volume_edits, "terrain_shapes": world.terrain_shapes, "terrain_ramps": world.terrain_ramps, "water_sources": world.water_sources,
		"water_orders": world.water_orders, "weather": world.weather, "vines": world.vines,
		"vine_roots": world.vine_roots, "vine_discovered": world.vine_discovered,
		"uprooted_bushes": world.uprooted_bushes, "bush_discovered": world.bush_discovered,
		"ground": world.ground, "platforms": world.platforms, "stairs": world.stairs, "stores": world.stores,
		"construction_materials": world.construction_materials, "buildings": world.buildings, "wells": world.wells, "plans": world.plans, "soil_beds": world.soil_beds, "gardens": world.gardens, "trees": world.trees, "workers": world.workers,
		"child_play": world.child_play, "time": world.time, "meals_eaten": world.meals_eaten, "deliveries": world.deliveries,
		"next_plan_id": world.next_plan_id, "consumption_clock": world.consumption_clock}, references)}

static func restore(model, data: Dictionary) -> bool:
	if (data.get("version") != 1 and data.get("version") != 2 and data.get("version") != 3 and data.get("version") != 4 and data.get("version") != 5) or not data.has("inventories") or not data.has("world"):
		return false
	var inventory_data: Variant = _decode(data.inventories, {})
	if not inventory_data is Dictionary or not inventory_data.has("well"):
		return false
	var references := {}
	for key: Variant in inventory_data:
		if not key is String:
			return false
		var entry: Variant = inventory_data[key]
		if not entry is Dictionary or not entry.get("amounts") is Dictionary or not entry.get("reservations") is Dictionary:
			return false
		var inventory = Inventory.new()
		inventory.amounts = entry.amounts
		inventory.reservations = entry.reservations
		inventory.capacity = int(entry.get("capacity", 32))
		if not _valid_inventory(inventory):
			return false
		references[key] = inventory
	var world: Variant = _decode(data.world, references)
	if not world is Dictionary:
		return false
	if not model.Soil.valid(world): return false
	for key in ["ground", "platforms", "stairs", "stores", "plans", "gardens", "trees"]:
		if not world.get(key) is Dictionary:
			return false
	if not world.get("workers") is Array or (world.workers.size() < 1 or world.workers.size() > 30):
		return false
	if data.version == 1:
		world["buildings"] = {}
		world["wells"] = {model.well: references.well}
	if not world.get("buildings") is Dictionary or not world.get("wells") is Dictionary:
		return false
	if data.version < 4:
		world.deposits = {}
		world.monument = {}
		world.birth_clock = 0.0
	world["uprooted_bushes"] = world.get("uprooted_bushes", [])
	world["bush_discovered"] = world.get("bush_discovered", false)
	if not world.uprooted_bushes is Array or not world.bush_discovered is bool: return false
	if not world.uprooted_bushes.is_empty() and not world.bush_discovered: return false
	for payload: Variant in world.uprooted_bushes:
		if not model.BushTransplants.valid(payload): return false
	world["vines"] = world.get("vines", {})
	world["vine_roots"] = world.get("vine_roots", 0)
	world["vine_discovered"] = world.get("vine_discovered", false)
	if not world.vine_roots is int or world.vine_roots < 0 or not world.vine_discovered is bool: return false
	if world.vine_roots > 0 and not world.vine_discovered: return false
	if not preload("res://scripts/settlement/vines.gd").valid(world.vines, 2 if int(world.get("grid_version", 1)) < 3 else 1): return false
	world["soil_beds"] = world.get("soil_beds", {})
	if not world.soil_beds is Dictionary: return false
	for cell: Variant in world.soil_beds:
		if not cell is Vector3i or not Catalog.in_bounds(cell): return false
		var bed: Variant = world.soil_beds[cell]
		if not bed is Dictionary or not bed.get("materials") is Dictionary or bed.materials != Catalog.recipe("soil_bed"): return false
	if not _valid_economy(world):
		return false
	if not world.get("platform_tiers", false):
		for plan: Dictionary in world.plans.values():
			if plan.kind == "platform": plan.platform_tier = 2
	if not _valid_world(world):
		return false
	if data.version < 3:
		world["terrain_ramps"] = {}
		world["water_sources"] = {}
		world["water_orders"] = {}
		world["world_seed"] = 0
		world["generator_version"] = 0
		world["weather"] = {"seconds": 0, "remainder": 0.0, "raining": false, "rain_count": 0}
		var existing := {}
		for cell: Vector3i in world.ground:
			existing[Vector2i(cell.x, cell.z)] = true
		for x in range(-20, 21):
			for z in range(-20, 21):
				if not existing.has(Vector2i(x, z)):
					world.ground[Vector3i(x, 0, z)] = true
	if not _valid_terrain(world):
		return false
	if world.get("grid_version", 1) == 1:
		world = _upgrade_half_grid(world)
	elif world.get("grid_version") not in [2, 3] or not _valid_shapes(world):
		return false
	if world.get("grid_version", 2) in [1, 2]:
		world = _upgrade_height_grid(world)
	if not _valid_world(world) or not _valid_terrain(world):
		return false
	var saved_height: Variant = world.get("level_height", 2.4)
	if not (saved_height is float or saved_height is int) or not is_finite(float(saved_height)) or saved_height <= 0:
		return false
	for worker: Dictionary in world.workers:
		worker.position.y *= Grid.LEVEL_HEIGHT / float(saved_height)
	var discovered: Variant = world.get("discovered_resources", {})
	if not discovered is Dictionary:
		return false
	for resource: Variant in discovered:
		if resource not in Economy.RESOURCES or discovered[resource] != true:
			return false
	var exploration = preload("res://scripts/settlement/exploration.gd").new()
	if world.has("explored") and not exploration.restore(world.explored):
		return false
	var streaming: Variant = world.get("streaming", {"enabled": false, "loaded": {}, "dormant": {}}) if data.version >= 5 else {"enabled": false, "loaded": {}, "dormant": {}}
	if not preload("res://scripts/settlement/chunk_stream.gd").valid_state(streaming, world):
		return false
	var child_play: Variant = world.get("child_play", {"games": [], "next_scan": 8.0})
	if not model.ChildPlay.valid(child_play, world.workers): return false
	model.child_play = child_play.duplicate(true)
	model.child_players.clear()
	model.streaming_enabled = streaming.enabled
	model.loaded_chunks = streaming.loaded
	model.dormant_chunks = streaming.dormant
	model.chunk_details.clear()
	model.terrain_revision += 1
	model.exploration = exploration
	model.discovered_resources = discovered.duplicate()
	for cell: Vector3i in world.deposits:
		Economy.upgrade_stone(world.deposits[cell], cell, world.world_seed)
	model.deposits = world.deposits
	model.birth_clock = float(world.birth_clock)
	model.difficulty = world.get("difficulty", "normal")
	model.world_seed = world.world_seed
	model.generator_version = world.generator_version
	model.terrain_ramps = world.terrain_ramps
	model.soil_enabled = world.get("soil_enabled", false)
	model.soil_cuts = world.get("soil_cuts", {})
	model.soil_noise = model.Soil.noise(world.world_seed)
	model.soil_revision += 1
	model.surface_edits = world.get("surface_edits", {})
	model.volume_edits = world.get("volume_edits", {})
	model.terrain_shapes = world.terrain_shapes
	model.water_sources = world.water_sources
	model.water_orders = world.water_orders
	model.weather = world.weather
	model.weather.remainder = float(model.weather.remainder)
	model.terrain_heights.clear()
	for cell: Vector3i in world.ground:
		model.terrain_heights[Vector2i(cell.x, cell.z)] = cell.y
	model.ground = world.ground
	model.Soil.rebuild(model)
	model.construction_materials = world.get("construction_materials", {})
	model.buildings = world.buildings
	model.wells = world.wells
	model.platforms = world.platforms
	model.stairs = world.stairs
	model.stores = world.stores
	for inventory in model.stores.values():
		model.track_store_resources(inventory)
		# Older saves kept spent resources as zero-valued inventory entries.
		if not world.has("discovered_resources"):
			for resource: String in inventory.amounts:
				model.discover_resource(resource)
	model.plans = world.plans
	model.crop_light_cache.clear()
	model.crop_light_revision = -1
	model.soil_beds = world.soil_beds
	model.gardens = world.gardens
	model.uprooted_bushes.assign(world.uprooted_bushes)
	model.bush_discovered = world.bush_discovered
	model.vines = world.vines
	model.vine_roots = world.vine_roots
	model.vine_discovered = world.vine_discovered
	model.trees = world.trees
	model.workers.assign(world.workers)
	for worker: Dictionary in model.workers:
		Citizens.restore_defaults(worker)
		# Old configurable gathering batches become one-item actions. Already
		# collected cargo stays intact; uncollected water remains ordered.
		if worker.job.has("collection_amount"):
			if worker.job.get("kind") == "collect_water" and worker.job.get("phase") == "collect":
				var source = model.Hydrology.inventory_at(model, worker.job.target)
				if source != null:
					model.water_orders[worker.job.target] = mini(source.capacity,
						int(model.water_orders.get(worker.job.target, 0)) + int(worker.job.collection_amount) - 1)
			worker.job.erase("collection_amount")
		if worker.job.get("kind") == "relocate":
			worker.job.labour = model.plans[worker.job.plan_id].relocation.labour
		if worker.job.get("kind") == "build" and model.plans[worker.job.plan_id].has("sowing"):
			worker.job.labour = model.plans[worker.job.plan_id].sowing
		model.discover_resource(worker.cargo)
	model.well_inventory = references.well
	model.time = float(world.get("time", 0.0))
	model.meals_eaten = int(world.get("meals_eaten", 0))
	model.deliveries = int(world.get("deliveries", 0))
	model.next_plan_id = int(world.get("next_plan_id", 1))
	model.consumption_clock = float(world.get("consumption_clock", 0.0))
	if data.version < 4:
		Economy.setup(model)
	# Retire exhausted trees from older saves, including any inventory references.
	for cell: Vector3i in model.trees.keys():
		model.remove_stump(cell, false)
	_remove_retired_monument_jobs(model)
	_remove_retired_buildings(model)
	if world.has("explored"):
		for worker: Dictionary in model.workers:
			model.exploration.last_positions[worker.id] = model.exploration.Mask.cell_at(worker.position)
	else:
		model.exploration.update(model.workers)
		# Old saves have no travel history; retain sight of their existing settlement.
		for collection in [model.buildings, model.stores, model.platforms, model.stairs, model.gardens, model.wells]:
			for cell: Vector3i in collection:
				model.exploration.reveal(Jobs.Navigation.point(cell))
		for plan: Dictionary in model.plans.values():
			model.exploration.reveal(Jobs.Navigation.point(plan.cell))
	return true

# Compatibility only: release old block claims and return carried blocks to storage.
static func _remove_retired_monument_jobs(model) -> void:
	for worker: Dictionary in model.workers:
		if worker.role == "monument": worker.role = "auto"
		if worker.job.get("kind") != "monument": continue
		Jobs._cancel_job(model, worker)
		worker.route = []
		worker.route_index = 0
		worker.position = Jobs.Navigation.point(worker.cell)
		worker.status = "idle"
		if not worker.cargo.is_empty():
			worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Labour.new(0.6)}

static func _remove_retired_buildings(model) -> void:
	var removed_roofs := {}
	for cell: Vector3i in model.buildings.keys():
		var kind: String = model.buildings[cell].kind
		if kind in RETIRED_BUILDINGS:
			if kind in ["archer_hut", "watch_tower"]:
				removed_roofs[cell + Grid.STOREY] = true
			model.buildings.erase(cell)
	var removed_plans := {}
	for id: int in model.plans.keys():
		if model.plans[id].kind in RETIRED_BUILDINGS:
			removed_plans[id] = true
			model.plans.erase(id)
	model.rebuild_navigation()
	for worker: Dictionary in model.workers:
		var affected: bool = worker.job.get("kind") == "build" and removed_plans.has(worker.job.get("plan_id"))
		for cell: Vector3i in worker.route:
			if removed_roofs.has(cell) and not model.navigation.surfaces.has(cell):
				affected = true
		if removed_roofs.has(worker.cell) and not model.navigation.surfaces.has(worker.cell):
			worker.cell = model.surface_at(worker.cell.x, worker.cell.z)
			affected = true
		if not affected:
			continue
		if not worker.job.is_empty():
			Jobs._cancel_job(model, worker)
		worker.position = model.navigation.point(worker.cell)
		worker.route = []
		worker.route_index = 0
		worker.status = "idle"
		# Keep already collected cargo and use the existing delivery-to-storage phase.
		if not worker.cargo.is_empty():
			worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Labour.new(0.6)}

static func _encode(value: Variant, references: Dictionary) -> Variant:
	if value is Vector2i:
		return {"type": "column", "v": [value.x, value.y]}
	if value is Vector3i:
		return {"type": "cell", "v": [value.x, value.y, value.z]}
	if value is Vector3:
		return {"type": "position", "v": [value.x, value.y, value.z]}
	if value is Dictionary:
		var pairs := []
		for key: Variant in value:
			pairs.append([_encode(key, references), _encode(value[key], references)])
		return {"type": "map", "v": pairs}
	if value is Array:
		var items := []
		for item: Variant in value:
			items.append(_encode(item, references))
		return items
	if value is Object:
		if references.has(value):
			return {"type": "inventory", "v": references[value]}
		if value.get_script() == Labour:
			return {"type": "labour", "v": [value.required_seconds, value.applied_seconds]}
		return null
	return value

static func _decode(value: Variant, references: Dictionary) -> Variant:
	if value is Array:
		var items := []
		for item: Variant in value:
			items.append(_decode(item, references))
		return items
	if not value is Dictionary:
		# JSON numbers are doubles; dictionary reservation/plan IDs need integers.
		return int(value) if value is float and value == floor(value) else value
	var payload: Variant = value.get("v")
	match str(value.get("type", "")):
		"column":
			if not payload is Array or payload.size() != 2 or not (payload[0] is int or payload[0] is float) or not (payload[1] is int or payload[1] is float): return null
			if payload[0] != floor(payload[0]) or payload[1] != floor(payload[1]): return null
			return Vector2i(int(payload[0]), int(payload[1]))
		"cell", "position":
			if not payload is Array or payload.size() != 3:
				return null
			if value.type == "cell":
				return Vector3i(int(payload[0]), int(payload[1]), int(payload[2]))
			return Vector3(payload[0], payload[1], payload[2])
		"map":
			if not payload is Array:
				return null
			var result := {}
			for pair: Variant in payload:
				if not pair is Array or pair.size() != 2:
					return null
				result[_decode(pair[0], references)] = _decode(pair[1], references)
			return result
		"inventory": return references.get(payload)
		"labour":
			if not payload is Array or payload.size() != 2:
				return null
			var labour = Labour.new(float(payload[0]))
			labour.applied_seconds = float(payload[1])
			return labour
	return null

static func _valid_inventory(inventory) -> bool:
	if inventory.capacity < 1 or inventory.capacity > 10000:
		return false
	var total := 0
	for resource: Variant in inventory.amounts:
		if resource not in Economy.RESOURCES or not inventory.amounts[resource] is int or inventory.amounts[resource] < 0:
			return false
		total += inventory.amounts[resource]
	if total > inventory.capacity:
		return false
	for owner: Variant in inventory.reservations:
		if not owner is int or owner < 0 or owner >= 30 or inventory.reservations[owner] not in Economy.RESOURCES:
			return false
	for resource in Economy.RESOURCES:
		if inventory.available(resource) < 0:
			return false
	return true

static func _valid_world(world: Dictionary) -> bool:
	var compatible_costs := Catalog.COSTS.merged(RETIRED_BUILDINGS)
	var material_history: Variant = world.get("construction_materials", {})
	if not material_history is Dictionary: return false
	for cell: Variant in material_history:
		if not cell is Vector3i or not Catalog.in_bounds(cell) or not material_history[cell] is Dictionary: return false
		for resource: Variant in material_history[cell]:
			if resource not in Economy.RESOURCES or not material_history[cell][resource] is int or material_history[cell][resource] < 0 or material_history[cell][resource] > 10000: return false
	for field in ["ground", "platforms", "stairs", "stores", "gardens", "trees", "buildings", "wells"]:
		for cell: Variant in world[field]:
			if not cell is Vector3i: return false
			if not (preload("res://scripts/settlement/terrain_editor.gd").valid_cell(cell) if field == "ground" else Catalog.in_bounds(cell)):
				return false
	for value: Variant in world.platforms.values():
		if value is bool:
			if not value: return false
		elif not value is int or value < 1 or value > 2: return false
	for building: Variant in world.buildings.values():
		if building is Dictionary and building.has("storage_tier") and (not building.storage_tier is int or building.storage_tier not in [1, 2, 3]): return false
		if building is Dictionary and building.has("mill_tier") and (not building.mill_tier is int or building.mill_tier not in [1, 2, 3]): return false
		if building is Dictionary and building.has("sawmill_tier") and (not building.sawmill_tier is int or building.sawmill_tier < 1 or building.sawmill_tier > 3): return false
		if not building is Dictionary or building.get("kind") not in compatible_costs or building.get("direction") not in [0, 1, 2, 3]:
			return false
		if not Desires.valid(building.get("desires", {})): return false
		if not Catalog.valid_placement_offset(building.kind, building.get("placement_offset", Vector3.ZERO)):
			return false
	for cell: Vector3i in world.wells:
		var building: Dictionary = world.buildings.get(cell, {})
		if building.has("well_units") and (not building.well_units is int or building.well_units < 1 or building.well_units > 3332): return false
	for inventory: Variant in world.wells.values():
		if not inventory is Object or inventory.get_script() != Inventory:
			return false
	for direction: Variant in world.stairs.values():
		if not direction is int or direction < 0 or direction > 3:
			return false
	for inventory: Variant in world.stores.values():
		if not inventory is Object or inventory.get_script() != Inventory:
			return false
	for tree: Variant in world.trees.values():
		if not tree is Dictionary or not tree.get("inventory") is Object or not tree.get("regrowth") is float and not tree.get("regrowth") is int:
			return false
		if tree.get("kind", "living") not in ["living", "dead", "palm"] or tree.inventory.get_script() != Inventory:
			return false
		if not Planting.valid_growth(tree): return false
		if float(tree.get("seed_growth", 1.0)) < 1.0 and tree.inventory.total() != 0: return false
		if tree.inventory.count("log") > 3 or tree.inventory.total() != tree.inventory.count("log"):
			return false
	for garden: Variant in world.gardens.values():
		if not garden is Dictionary:
			return false
		if garden.get("species", "vegetables") not in ["grass", "vegetables"]: return false
		for key in ["water", "growth", "food", "reserved"]:
			if not garden.get(key) is int and not garden.get(key) is float:
				return false
		if garden.has("standing_quarters"):
			var mask: Variant = garden.standing_quarters
			if not (mask is int or mask is float) or mask != int(mask) or mask < 0 or mask > 15: return false
			var remaining := 0
			for quarter in 4: remaining += int((int(mask) & (1 << quarter)) != 0)
			if remaining != garden.food: return false
	for id: Variant in world.plans:
		var plan: Variant = world.plans[id]
		if not plan is Dictionary or plan.get("id") != id or plan.get("kind") not in compatible_costs.merged({"tree": 0, "berry": 0, "vine_tree": 0}) or not plan.get("cell") is Vector3i:
			return false
		if not Catalog.valid_placement_offset(plan.kind, plan.get("placement_offset", Vector3.ZERO)):
			return false
		for key in ["installed", "required", "reserved", "direction"]:
			if not plan.get(key) is int or plan[key] < 0:
				return false
		var valid_cost: bool = (plan.kind == "hay_barn" and plan.required == 8) or (plan.kind == "windmill" and not plan.has("mill_tier") and plan.required == 10) or plan.required == compatible_costs.get(plan.kind, 0) or (plan.kind == "stockpile" and plan.required == 2)
		if plan.has("relocation") and not _valid_relocation(plan, world): return false
		if plan.kind == "platform" and (not plan.get("platform_tier", 1) is int or plan.get("platform_tier", 1) not in [1, 2]): return false
		if plan.kind == "stone_storage":
			if not plan.get("storage_tier") is int or plan.storage_tier not in [1, 2, 3]: return false
			valid_cost = plan.required == [4, 4, 12][plan.storage_tier - 1]
		if plan.kind == "windmill" and plan.has("mill_tier"):
			if not plan.mill_tier is int or plan.mill_tier not in [1, 2, 3]: return false
			valid_cost = plan.required == [2, 2, 10][plan.mill_tier - 1]
		if plan.kind == "sawmill":
			if plan.has("sawmill_tier") and (not plan.sawmill_tier is int or plan.sawmill_tier < 1 or plan.sawmill_tier > 3): return false
			valid_cost = plan.required == ([3, 4, 5][int(plan.sawmill_tier) - 1] if plan.has("sawmill_tier") else 10)
		if plan.has("relocation") and plan.kind in ["goods_rack", "small_warehouse", "stone_storage", "sawmill", "windmill", "well", "waterworks", "platform"]:
			valid_cost = plan.required > 0 and plan.required <= 10000
		if plan.kind == "garden" and plan.has("relocation") and plan.required == 0:
			var crop: Dictionary = plan.relocation.get("payload", {}).get("gardens", world.gardens.get(plan.relocation.get("source"), {}))
			valid_cost = crop.get("species") in ["grass", "vegetables"] or (plan.get("deconstruction", false) and plan.relocation.get("stage") == "salvage" and plan.get("materials") == {})
		if plan.has("bush_payload") and (plan.kind != "seed_bush" or not preload("res://scripts/settlement/bush_transplants.gd").valid(plan.bush_payload)): return false
		if plan.has("collect_bush"):
			if plan.collect_bush != true or plan.kind != "berry" or not plan.has("relocation") or plan.relocation.stage != "dismantle" or plan.cell != plan.relocation.source or world.deposits.get(plan.cell, {}).get("kind") != "berry": return false
		if plan.has("goods_upgrade") and (plan.goods_upgrade != true or plan.kind not in ["goods_rack", "small_warehouse"]): return false
		if plan.has("shell_kind"):
			if plan.kind != "waterworks" or plan.shell_kind not in Catalog.ROOFS or plan.shell_kind in ["well", "waterworks"]: return false
			valid_cost = plan.required == Catalog.COSTS[plan.shell_kind]
		if plan.has("reserved_root") and (plan.kind != "seed_vine" or plan.reserved_root != true): return false
		if plan.kind == "vine_tree":
			if plan.get("collect_vine") != true or not plan.has("relocation") or plan.relocation.stage != "dismantle" or plan.cell != plan.relocation.source or not world.vines.has(plan.cell): return false
		elif plan.has("collect_vine"): return false
		if plan.kind in Catalog.SEEDS:
			if not plan.get("sowing") is Object or plan.sowing.get_script() != Labour: return false
			if not is_finite(plan.sowing.required_seconds) or plan.sowing.required_seconds < 0.001 or plan.sowing.required_seconds > 1000000.0 or not is_finite(plan.sowing.applied_seconds) or plan.sowing.applied_seconds < 0 or plan.sowing.applied_seconds > plan.sowing.required_seconds: return false
		elif plan.has("sowing"): return false
		if plan.kind in ["tree", "berry"] and not plan.has("relocation"): return false
		if plan.has("deconstruction") and (plan.deconstruction != true or not plan.has("relocation") or plan.kind not in Catalog.COSTS or plan.cell != plan.relocation.source): return false
		if not Catalog.in_bounds(plan.cell) or not valid_cost or plan.installed + plan.reserved > plan.required or plan.direction > 3:
			return false
		if plan.has("materials"):
			if not plan.materials is Dictionary or not plan.get("used") is Dictionary or not plan.get("claims") is Dictionary:
				return false
			var required := 0
			var used := 0
			var claimed := 0
			for resource: Variant in plan.materials:
				if resource not in Economy.RESOURCES or not plan.materials[resource] is int or plan.materials[resource] < 0:
					return false
				var installed: Variant = plan.used.get(resource, 0)
				var reserved: Variant = plan.claims.get(resource, 0)
				if not installed is int or not reserved is int or installed < 0 or reserved < 0 or installed + reserved > plan.materials[resource]:
					return false
				required += plan.materials[resource]
				used += installed
				claimed += reserved
			if required != plan.required or used != plan.installed or claimed != plan.reserved:
				return false
	for index in world.workers.size():
		var worker: Variant = world.workers[index]
		if not worker is Dictionary or worker.get("id") != index or not worker.get("cell") is Vector3i or not worker.get("position") is Vector3:
			return false
		if not Desires.valid(worker.get("desires", {})): return false
		if not worker.position.is_finite() or not worker.get("job") is Dictionary or not worker.get("route") is Array:
			return false
		if worker.get("cargo") not in ([""] + Economy.RESOURCES) or not worker.get("route_index") is int:
			return false
		if not worker.get("cargo_amount", 1) is int or worker.get("cargo_amount", 1) < 1 or worker.get("cargo_amount", 1) > preload("res://scripts/settlement/balance.gd").MAX_ITEMS:
			return false
		if worker.route_index < 0 or worker.route_index > maxi(1, worker.route.size()):
			return false
		for cell: Variant in worker.route:
			if not cell is Vector3i:
				return false
		if worker.has("clearance_route"):
			if not worker.clearance_route is Array or not worker.get("clearance_index") is int:
				return false
			if worker.clearance_index < 1 or worker.clearance_index >= worker.clearance_route.size():
				return false
			for cell: Variant in worker.clearance_route:
				if not cell is Vector3i: return false
		var citizen: Dictionary = worker.duplicate()
		if citizen.get("role") == "monument": citizen.role = "auto"
		if not Citizens.valid(citizen):
			return false
		for tag in ["relocation_cargo", "plant_plan_id"]:
			if worker.has(tag) and (not worker[tag] is int or not world.plans.has(worker[tag]) or not world.plans[worker[tag]].has("relocation")): return false
		var job: Dictionary = worker.job
		# Read-only compatibility for saves from configurable gathering batches.
		if job.has("collection_amount") and (not job.collection_amount is int or job.collection_amount < 1 or job.collection_amount > preload("res://scripts/settlement/balance.gd").MAX_ITEMS): return false
		if job.has("salvage_plan_id"):
			var salvage: Variant = world.plans.get(job.salvage_plan_id)
			if not salvage is Dictionary or not salvage.get("deconstruction", false) or salvage.relocation.stage != "salvage": return false
			if job.get("kind") != "restock" or job.get("phase") != "pickup" or job.get("source") != salvage.relocation.parts: return false
		if job.get("kind") == "relocate" and (not world.plans.has(job.get("plan_id")) or not world.plans[job.plan_id].has("relocation")): return false
		if not Citizens.is_adult(worker) and (not worker.cargo.is_empty() and worker.cargo != "food" or not job.is_empty() and job.get("kind") != "eat"):
			return false
		if job.is_empty():
			continue
		if job.get("kind") not in ["build", "water", "harvest", "fell", "restock", "eat", "collect_water", "gather", "process", "monument", "move", "relocate"] or job.get("phase") not in ["pickup", "travel", "work", "collect", "store"]:
			return false
		if not job.get("target") is Vector3i or not job.get("labour") is Object or job.labour.get_script() != Labour:
			return false
		if job.has("quarter"):
			var quarter: Variant = job.quarter
			if job.kind != "harvest" or not (quarter is int or quarter is float) or quarter != int(quarter) or quarter < 0 or quarter >= 4: return false
		if (job.phase == "pickup" or (job.phase == "collect" and job.kind in ["fell", "collect_water", "gather"])) and (not job.get("source") is Object or job.source.get_script() != Inventory):
			return false
		if job.kind in ["build", "relocate"] and not world.plans.has(job.get("plan_id")):
			return false
		if job.kind == "process":
			if job.get("output") not in Economy.RESOURCES or not job.get("yield") is int or job.yield < 1 or job.yield > preload("res://scripts/settlement/balance.gd").MAX_ITEMS:
				return false
		if job.kind == "monument" and world.get("monument", {}).is_empty():
			return false
		if job.kind == "water" and not world.gardens.has(job.get("garden")):
			return false
	return true

static func _valid_terrain(world: Dictionary) -> bool:
	if not preload("res://scripts/settlement/terrain_editor.gd").valid_edits(world): return false
	if not world.get("volume_edits", {}) is Dictionary: return false
	for cell: Variant in world.get("volume_edits", {}):
		if not cell is Vector3i or world.volume_edits[cell] not in ["solid", "water", "air"]: return false
	if world.get("difficulty", "normal") not in ["normal", "easy"]: return false
	for key in ["terrain_ramps", "water_sources", "water_orders", "weather"]:
		if not world.get(key) is Dictionary:
			return false
	if not world.get("world_seed") is int or not world.get("generator_version") is int:
		return false
	var columns := {}
	for cell: Vector3i in world.ground:
		var column := Vector2i(cell.x, cell.z)
		if not preload("res://scripts/settlement/terrain_editor.gd").valid_cell(cell) or columns.has(column):
			return false
		if world.get("surface_edits", {}).has(column) and world.surface_edits[column] != cell.y: return false
		columns[column] = true
	for lower: Variant in world.terrain_ramps:
		var upper: Variant = world.terrain_ramps[lower]
		if not lower is Vector3i or not upper is Vector3i or not world.ground.has(lower) or not world.ground.has(upper):
			return false
		if upper.y - lower.y not in [1, 2] or absi(upper.x - lower.x) + absi(upper.z - lower.z) not in [1, 2]:
			return false
	for cell: Variant in world.water_sources:
		var source: Variant = world.water_sources[cell]
		if not world.ground.has(cell) or not source is Dictionary or source.get("kind") not in ["puddle", "stream"]:
			return false
		var inventory: Variant = source.get("inventory")
		if not inventory is Object or inventory.get_script() != Inventory:
			return false
		if inventory.capacity > 3 or inventory.total() != inventory.count("water"):
			return false
	for cell: Variant in world.water_orders:
		if (not world.water_sources.has(cell) and not world.wells.has(cell)) or not world.water_orders[cell] is int or world.water_orders[cell] < 0 or world.water_orders[cell] > (world.wells[cell].capacity if world.wells.has(cell) else 3):
			return false
	var weather: Dictionary = world.weather
	for key in ["seconds", "rain_count"]:
		if not weather.get(key) is int or weather[key] < 0:
			return false
	if not weather.get("raining") is bool or not (weather.get("remainder") is float or weather.get("remainder") is int):
		return false
	return is_finite(float(weather.remainder)) and weather.remainder >= 0 and weather.remainder < 1

static func _valid_economy(world: Dictionary) -> bool:
	if not world.get("deposits") is Dictionary or not world.get("monument", {}) is Dictionary:
		return false
	var clock: Variant = world.get("birth_clock")
	if not (clock is float or clock is int) or not is_finite(float(clock)) or clock < 0:
		return false
	for cell: Variant in world.deposits:
		var deposit: Variant = world.deposits[cell]
		if not cell is Vector3i or not Catalog.in_bounds(cell) or not deposit is Dictionary:
			return false
		if deposit.get("kind") not in ["berry", "limestone"] or not deposit.get("inventory") is Object or deposit.inventory.get_script() != Inventory:
			return false
		if not Planting.valid_growth(deposit): return false
		var resource := "food" if deposit.kind == "berry" else "stone"
		if deposit.inventory.total() != deposit.inventory.count(resource):
			return false
		var growth: Variant = deposit.get("regrowth")
		if not (growth is int or growth is float) or not is_finite(float(growth)) or growth < 0:
			return false
	var monument: Dictionary = world.get("monument", {})
	if not monument.is_empty():
		if not monument.get("cell") is Vector3i or not Catalog.in_bounds(monument.cell):
			return false
		if not monument.get("discovered") is bool or not monument.get("active") is bool:
			return false
		for field in ["installed", "reserved", "required"]:
			if not monument.get(field) is int or monument[field] < 0:
				return false
		if monument.required != 40 or monument.installed + monument.reserved > monument.required:
			return false
	return true

static func _valid_shapes(world: Dictionary) -> bool:
	if not world.get("terrain_shapes") is Dictionary:
		return false
	for cell: Variant in world.terrain_shapes:
		var corners: Variant = world.terrain_shapes[cell]
		if not cell is Vector3i or not world.ground.has(cell) or cell.y != 0 or not corners is Array or corners.size() != 4:
			return false
		for height: Variant in corners:
			if not (height is float or height is int) or not is_finite(float(height)) or height < 0 or height > 2.6:
				return false
	return true

static func _upgrade_half_grid(world: Dictionary) -> Dictionary:
	# Convert logical addresses only. Asset dimensions, worker world positions,
	# elapsed work, inventory references and exploration coordinates stay intact.
	var upgraded: Dictionary = _scale_addresses(world)
	var old_columns := {}
	for cell: Vector3i in world.ground:
		old_columns[Vector2i(cell.x, cell.z)] = cell.y
	upgraded.ground = {}
	var fine_columns := {}
	for column: Vector2i in old_columns:
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var x := column.x * 2 + dx
				var z := column.y * 2 + dz
				var source := Vector2i(roundi(float(x) / 2), roundi(float(z) / 2))
				var height: int = old_columns.get(source, old_columns[column])
				fine_columns[Vector2i(x, z)] = height
	for column: Vector2i in fine_columns:
		upgraded.ground[Vector3i(column.x, fine_columns[column], column.y)] = true
	upgraded.terrain_shapes = {}
	for worker: Dictionary in upgraded.workers:
		_upgrade_route(worker)
	return upgraded

static func _scale_addresses(value: Variant) -> Variant:
	if value is Vector3i:
		return Grid.from_room(value)
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[_scale_addresses(key)] = _scale_addresses(value[key])
		return result
	if value is Array:
		var result := []
		for item: Variant in value:
			result.append(_scale_addresses(item))
		return result
	return value

static func _upgrade_route(worker: Dictionary) -> void:
	var old_route: Array = worker.route
	var route: Array[Vector3i] = []
	var next_index: int = worker.route_index
	var mapped_index := 0
	for index in old_route.size():
		var target: Vector3i = old_route[index]
		if index > 0:
			var previous: Vector3i = old_route[index - 1]
			var offset := target - previous
			if offset.y == 0 and maxi(absi(offset.x), absi(offset.z)) == 2:
				# Migrated room-grid steps are even, so the midpoint is integral.
				@warning_ignore("integer_division")
				var midpoint := previous + Vector3i(offset.x / 2, 0, offset.z / 2)
				route.append(midpoint)
				if index == next_index:
					var start := Jobs.Navigation.point(previous)
					var direction := Jobs.Navigation.point(target) - start
					if (worker.position - start).dot(direction) >= direction.length_squared() * 0.5:
						worker.cell = midpoint
						mapped_index = route.size()
					else:
						mapped_index = route.size() - 1
			elif index == next_index:
				mapped_index = route.size()
		route.append(target)
	worker.route = route
	worker.route_index = route.size() if next_index >= old_route.size() else mapped_index

static func _valid_relocation(plan: Dictionary, world: Dictionary) -> bool:
	var move: Variant = plan.relocation
	if not move is Dictionary or move.get("stage") not in ["dismantle", "rebuild", "salvage"]: return false
	if move.stage == "salvage" and not plan.get("deconstruction", false): return false
	if plan.get("deconstruction", false) and move.stage == "rebuild": return false
	for key in ["source", "pickup_cell"]:
		if not move.get(key) is Vector3i or not Catalog.in_bounds(move[key]): return false
	if not move.get("owner") is int or move.owner < -1 or move.owner >= world.workers.size(): return false
	if not move.get("parts") is Object or move.parts.get_script() != Inventory: return false
	if not move.get("labour") is Object or move.labour.get_script() != Labour: return false
	if not is_finite(move.labour.required_seconds) or move.labour.required_seconds <= 0 or not is_finite(move.labour.applied_seconds) or move.labour.applied_seconds < 0 or move.labour.applied_seconds > move.labour.required_seconds: return false
	if not move.get("payload") is Dictionary: return false
	for field: Variant in move.payload:
		if field not in ["buildings", "platforms", "stairs", "stores", "wells", "gardens", "trees", "deposits", "soil_beds"]: return false
		var value: Variant = move.payload[field]
		if field == "soil_beds" and (plan.kind != "soil_bed" or not value is Dictionary or value.get("materials") != Catalog.recipe("soil_bed")): return false
		if field in ["stores", "wells"] and (not value is Object or value.get_script() != Inventory): return false
		if field in ["trees", "deposits"] and (not value is Dictionary or not value.get("inventory") is Object or value.inventory.get_script() != Inventory): return false
	return true

static func _height_cells(value: Variant) -> Variant:
	if value is Vector3i:
		return Vector3i(value.x, value.y * 2, value.z)
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[_height_cells(key)] = _height_cells(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(_height_cells(entry))
		return result
	return value

static func _upgrade_height_grid(world: Dictionary) -> Dictionary:
	var upgraded: Dictionary = _height_cells(world)
	_preserve_vine_nodes(world, upgraded)
	for chunk in world.get("streaming", {}).get("dormant", {}):
		_preserve_vine_nodes(world.streaming.dormant[chunk], upgraded.streaming.dormant[chunk])
	for cell: Vector3i in world.get("volume_edits", {}):
		upgraded.volume_edits[Vector3i(cell.x, cell.y * 2 + 1, cell.z)] = world.volume_edits[cell]
	# Existing physical positions stay at their old heights; only cell IDs subdivide.
	var old_height := float(world.get("level_height", 2.4))
	for worker: Dictionary in upgraded.workers:
		worker.position.y *= Grid.STOREY_HEIGHT / old_height
	upgraded.level_height = Grid.LEVEL_HEIGHT
	upgraded.grid_version = 3
	return upgraded

static func _preserve_vine_nodes(original: Dictionary, upgraded: Dictionary) -> void:
	# Vine nodes already use metre coordinates; only their root's floor ID changes.
	for cell: Vector3i in original.get("vines", {}):
		var root := Vector3i(cell.x, cell.y * 2, cell.z)
		upgraded.vines[root].nodes = original.vines[cell].nodes.duplicate()
