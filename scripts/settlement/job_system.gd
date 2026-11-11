extends RefCounted
## Stateless scheduler. All persistent job state lives in the world snapshot.
const Relocation = preload("res://scripts/settlement/relocation.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Citizens = preload("res://scripts/settlement/citizen_lifecycle.gd")
const Labour = preload("res://scripts/applied_labour.gd")
const Balance = preload("res://scripts/settlement/balance.gd")
const SiteDelivery = preload("res://scripts/settlement/site_delivery.gd")
const RETRY_SECONDS := 1.0
const MIN_RETRY_SECONDS := 0.25
const DECISIONS_PER_TICK := 2

static func construction_progress(plan: Dictionary, workers: Array) -> Dictionary:
	# Installed materials remain complete while builders fetch the next delivery.
	# Normalise in-flight labour so older saves with 1.8-second jobs still agree.
	if plan.has("relocation") and (plan.relocation.stage == "dismantle" or Relocation.portable_plant(plan) or plan.required == 0):
		var labour = plan.relocation.labour
		return {"required_seconds": labour.required_seconds, "applied_seconds": labour.applied_seconds}
	if plan.has("sowing"):
		return {"required_seconds": plan.sowing.required_seconds, "applied_seconds": plan.sowing.applied_seconds}
	var completed: float = plan.installed
	for worker: Dictionary in workers:
		var job: Dictionary = worker.job
		if job.get("kind") == "build" and job.get("plan_id") == plan.id:
			completed += job.labour.progress_ratio()
	var seconds := Balance.construction_seconds(plan.kind)
	return {"required_seconds": plan.required * seconds,
		"applied_seconds": minf(completed, plan.required) * seconds}

static func _source_for(world, worker: Dictionary, resource: String, targets: Array[Vector3i], excluded: Variant = null, minimum_stock := 0, nearest_pickup := false) -> Dictionary:
	if targets.is_empty(): return {}
	var best := {}
	var best_distance := INF
	var candidates = world.stores.duplicate()
	if resource == "water":
		candidates.merge(world.wells)
		for cell: Vector3i in world.water_sources:
			if not world.wells.has(cell) and world.exploration.contains(Navigation.point(cell)):
				candidates[cell] = world.water_sources[cell].inventory
	var sources: Array[Dictionary] = []
	for cell: Vector3i in candidates:
		sources.append({"cell": cell, "inventory": candidates[cell], "salvage": false})
	# Recovered pieces can feed construction directly, even after the last store is removed.
	for plan: Dictionary in world.plans.values():
		if plan.get("deconstruction", false) and plan.relocation.stage == "salvage" and not plan.has("parts_owner"):
			sources.append({"cell": plan.relocation.pickup_cell, "inventory": plan.relocation.parts, "salvage": true})
	# Try nearby supplies first and prune by a horizontal lower bound
	# before asking navigation for expensive pickup and delivery routes.
	var origins: Array[Vector3i] = world.navigation.access_cells(worker.cell)
	var destinations: Array[Vector3i] = []
	for target: Vector3i in targets: destinations.append_array(world.navigation.access_cells(target))
	for source: Dictionary in sources:
		source.travel_bound = INF
		source.delivery_bound = INF
		if source.inventory.available(resource) <= minimum_stock: continue
		var pickup := INF
		var delivery := 0.0 if nearest_pickup else INF
		for access: Vector3i in world.navigation.access_cells(source.cell):
			for origin in origins: pickup = minf(pickup, Vector2(origin.x - access.x, origin.z - access.z).length() * Navigation.CELL_SIZE)
			if not nearest_pickup:
				for destination in destinations: delivery = minf(delivery, Vector2(destination.x - access.x, destination.z - access.z).length() * Navigation.CELL_SIZE)
		source.travel_bound = pickup + delivery
		source.delivery_bound = delivery
	sources.sort_custom(func(a, b): return a.travel_bound < b.travel_bound)
	for source: Dictionary in sources:
		if float(source.travel_bound) >= best_distance: break
		var cell: Vector3i = source.cell
		var inventory = source.inventory
		if (not source.salvage and Relocation.locked(world, cell)) or cell == excluded or inventory.available(resource) <= minimum_stock:
			continue
		var to_source: Array[Vector3i] = world.navigation.route(worker.cell, cell)
		if to_source.is_empty():
			continue
		var pickup_distance: float = world.navigation.distance(to_source)
		# Obstacles can make the pickup much longer than its geometric bound.
		# Use that known cost before starting a separate delivery search.
		if pickup_distance + float(source.delivery_bound) >= best_distance: continue
		var to_target = world.nearest_route(to_source.back(), targets)
		if to_target.is_empty():
			continue
		var distance = pickup_distance + (0.0 if nearest_pickup else world.navigation.distance(to_target))
		if distance < best_distance:
			best_distance = distance
			best = {"inventory": inventory, "cell": cell, "target": to_target.back(), "route": to_source}
	return best

static func _assign(world, worker: Dictionary) -> void:
	if not worker.cargo.is_empty():
		if _build_with_cargo(world, worker): return
		if _process_with_cargo(world, worker): return
		worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Labour.new(0.6)}
		return
	if worker.has("relocation_cargo"):
		worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Labour.new(0.6)}
		return
	if float(worker.get("hunger", 0.0)) >= 30.0:
		var nearest := {}
		var distance := INF
		var order := -1
		var sources: Array[Dictionary] = []
		for cell: Vector3i in world.stores:
			if world.stores[cell].available("food") <= 0 or Relocation.locked(world, cell): continue
			sources.append({"cell": cell, "bound": world.navigation.distance_lower_bound(worker.cell, cell), "order": sources.size()})
		sources.sort_custom(func(a, b): return a.bound < b.bound)
		for source: Dictionary in sources:
			if source.bound > distance: break
			var cell: Vector3i = source.cell
			var route: Array[Vector3i] = world.navigation.route(worker.cell, cell)
			if route.is_empty(): continue
			var length: float = world.navigation.distance(route)
			if length < distance or (length == distance and source.order < order):
				distance = length
				order = source.order
				nearest = {"cell": cell, "route": route, "inventory": world.stores[cell]}
		if not nearest.is_empty() and nearest.inventory.reserve(worker.id, "food"):
			worker.job = {"kind": "eat", "phase": "pickup", "source": nearest.inventory,
				"target": nearest.cell, "labour": Labour.new(Balance.number("eating_seconds"))}
			_set_route(world, worker, nearest.route, "going for a meal")
			return
	if not Citizens.is_adult(worker):
		worker.status = "growing up"
		return
	var role: String = worker.get("role", "auto")
	if role == "idle":
		worker.status = "idle"
		return
	if worker.has("assigned_water_source"):
		var source: Vector3i = worker.assigned_water_source
		var inventory = world.Hydrology.inventory_at(world, source)
		if inventory != null and not Relocation.locked(world, source) and _assign_collection(world, worker, source, "water", "collect_water", false, true):
			if inventory.reserve(worker.id, "water"):
				worker.job.source = inventory
				return
			worker.job = {}
		worker.status = "waiting · water or storage unavailable"
		return
	# Protect food production from a long construction queue.
	if role in ["auto", "baker"] and (role == "baker" or world.resource_total("food") < Economy.food_target(world)):
		if _assign_recipe(world, worker, "bakery") or _assign_recipe(world, worker, "windmill"):
			return
	if role in ["auto", "forager"] and (role == "forager" or world.resource_total("food") < Economy.food_target(world)):
		if _assign_deposit(world, worker, "berry"):
			return
	if role in ["auto", "builder"] and _assign_build(world, worker):
		return
	if role in ["auto", "farmer"] and _assign_farm(world, worker):
		return
	if role in ["auto", "hauler"] and _assign_storage_transfer(world, worker): return
	if role in ["auto", "hauler"]:
		for cell: Vector3i in world.water_orders.keys():
			var inventory = world.Hydrology.inventory_at(world, cell)
			if inventory == null or world.Relocation.locked(world, cell) or world.water_orders[cell] <= 0 or inventory.available("water") <= 0:
				world.water_orders.erase(cell)
				continue
			if _assign_collection(world, worker, cell, "water", "collect_water"):
				if inventory.reserve(worker.id, "water"):
					worker.job.source = inventory
					world.water_orders[cell] -= 1
					return
				worker.job = {}
	# Small local buffers supply homes and timber-processing buildings.
	if role in ["auto", "hauler"]:
		for cell: Vector3i in world.stores:
			if Relocation.locked(world, cell) or not Economy.accepts(world, cell, "log"):
				continue
			var destination = world.stores[cell]
			var inbound := 0
			for other: Dictionary in world.workers:
				if other.job.get("kind") == "restock" and other.job.target == cell:
					inbound += 1
			if destination.count("log") + inbound >= 4 or Economy.storage_space(world, cell, "log") <= inbound:
				continue
			var source := _source_for(world, worker, "log", [cell], cell, 4)
			if not source.is_empty() and source.inventory.reserve(worker.id, "log"):
				worker.job = {"kind": "restock", "source": source.inventory, "target": cell,
					"phase": "pickup", "labour": Labour.new(0.6)}
				_set_route(world, worker, source.route, "restocking timber")
				return
	# Automatic cutters stop at a small reserve, including loose ground stock.
	if role in ["auto", "woodcutter"] and (role == "woodcutter" or (world.resource_total("log") < 18)):
		for cell: Vector3i in nearby_cells(world.trees, worker.cell):
			if Relocation.locked(world, cell): continue
			var tree: Dictionary = world.trees[cell]
			if tree.inventory.available("log") > 0 and _assign_collection(world, worker, cell, "log", "fell"):
				if tree.inventory.reserve(worker.id, "log"):
					worker.job.source = tree.inventory
					return
				worker.job = {}
	for kind: String in Economy.RECIPES:
		if role in ["auto", Economy.RECIPES[kind].role] and _assign_recipe(world, worker, kind):
			return
	for kind: String in Economy.EXTRACTORS:
		if role in ["auto", Economy.EXTRACTORS[kind].role] and _assign_extraction(world, worker, kind): return
	# A direct mining assignment can use a completed pile; the camp only
	# enables automatic mining, not the player's order to gather a deposit.
	if role == "miner" or (role == "auto" and (Economy.count_buildings(world, "mine_camp") + Economy.count_buildings(world, "quarry")) > 0 and world.resource_total("stone") < 16):
		if _assign_quarry(world, worker): return
		if not worker.has("assigned_workplace") and Economy.count_buildings(world, "quarry") == 0 and _assign_deposit(world, worker, "limestone"):
			return
	if world.Rooms.visit_bed(world,worker): return
	worker.status = "idle · no reachable work"


static func _assign_storage_transfer(world, worker: Dictionary) -> bool:
	for plan: Dictionary in world.plans.values():
		if world.Deconstruction.is_salvage(plan) and world.Deconstruction.assign_salvage(world, worker, plan): return true
	for cell: Vector3i in world.stores:
		if Relocation.locked(world, cell): continue
		var inventory = world.stores[cell]
		for resource: String in inventory.amounts:
			if inventory.available(resource) <= 0 or Economy.accepts(world, cell, resource): continue
			var route: Array[Vector3i] = world.navigation.route(worker.cell, cell)
			if route.is_empty(): continue
			var destination := _destination_store(world, route.back(), resource)
			if destination.is_empty() or not inventory.reserve(worker.id, resource): continue
			worker.job = {"kind": "restock", "source": inventory, "target": destination.cell, "phase": "pickup", "labour": Labour.new(0.6)}
			_set_route(world, worker, route, "restocking")
			return true
	return false

static func _assign_build(world, worker: Dictionary) -> bool:
	var assigned_id: int = worker.get("assigned_plan_id", -1)
	if assigned_id != -1 and not world.plans.has(assigned_id):
		worker.assigned_plan_id = -1
		assigned_id = -1
	# A player order owns every delivery until the whole site is complete.
	var plans: Array = [world.plans[assigned_id]] if assigned_id != -1 else world.plans.values()
	for plan: Dictionary in plans:
		if plan.kind in ["room_utility","home_utility"] and not world.Rooms.ready(world,plan): continue
		if plan.get("deconstruction", false) and plan.relocation.stage == "salvage":
			if world.Deconstruction.assign_salvage(world, worker, plan): return true
			continue
		if plan.has("relocation") and (plan.relocation.stage == "dismantle" or Relocation.portable_plant(plan) or plan.required == 0):
			if Relocation.assign(world, worker, plan): return true
			continue
		if plan.has("sowing"):
			if world.workers.any(func(other): return other.job.get("kind") == "build" and other.job.get("plan_id") == plan.id): continue
			var route: Array[Vector3i] = world.nearest_route(worker.cell, world.work_cells(plan.kind, plan.cell))
			if route.is_empty(): continue
			worker.job = {"kind": "build", "plan_id": plan.id, "target": route.back(), "phase": "travel", "labour": plan.sowing}
			_set_route(world, worker, route, "walking to harvest")
			return true
		var resource := needed_material(plan)
		if resource.is_empty():
			continue
		if world.debug_mode and not plan.has("relocation"):
			var route: Array[Vector3i] = world.nearest_route(worker.cell, world.work_cells(plan.kind, plan.cell, plan.direction))
			if route.is_empty(): continue
			claim_material(plan, resource, 1)
			worker.job = {"kind": "build", "plan_id": plan.id, "resource": resource, "debug_free": true,
				"target": route.back(), "phase": "travel", "labour": Labour.new(Balance.construction_seconds(plan.kind))}
			_set_route(world, worker, route, "building")
			return true
		var source := Relocation.material_source(world, worker, plan, resource) if plan.has("relocation") else _source_for(world, worker, resource, world.work_cells(plan.kind, plan.cell, plan.direction), null, 0, true)
		if plan.has("delivered") and plan.delivered.available(resource) > 0:
			var site_route: Array[Vector3i] = world.nearest_route(worker.cell, world.work_cells(plan.kind, plan.cell, plan.direction))
			if not site_route.is_empty(): source = {"inventory": plan.delivered, "route": site_route, "target": site_route.back()}
		if source.is_empty():
			if not plan.has("relocation") and _gather_build_material(world, worker, plan, resource): return true
			continue
		if source.inventory.reserve(worker.id, resource):
			claim_material(plan, resource, 1)
			worker.job = {"kind": "build", "plan_id": plan.id, "source": source.inventory, "resource": resource,
				"target": source.target, "phase": "pickup", "labour": Labour.new(Balance.construction_seconds(plan.kind))}
			_set_route(world, worker, source.route, "fetching timber" if resource == "log" else "economy_fetch_material_text")
			return true
	return false

static func _gather_build_material(world, worker: Dictionary, plan: Dictionary, resource: String) -> bool:
	# The first shed/pile must be buildable without already owning material storage.
	if resource not in ["log", "stone"]: return false
	var targets: Array[Vector3i] = world.work_cells(plan.kind, plan.cell, plan.direction)
	if targets.is_empty(): return false
	var sources: Dictionary = world.trees if resource == "log" else world.deposits
	var candidates: Array[Dictionary] = []
	for cell: Vector3i in sources:
		if sources[cell].inventory.available(resource) <= 0 or not world.exploration.contains(Navigation.point(cell)): continue
		if Relocation.locked(world, cell): continue
		if resource == "stone" and (sources[cell].kind != "limestone" or world.rock_in_use(cell)): continue
		var route: Array[Vector3i] = world.navigation.route(worker.cell, cell)
		if route.is_empty(): continue
		# Rank pickups from the one shared citizen search first. Searching from
		# every tree to the site builds dozens of unused navigation trees.
		candidates.append({"cell": cell, "distance": world.navigation.distance(route), "arrival": route.back()})
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	for candidate: Dictionary in candidates:
		var cell: Vector3i = candidate.cell
		if not targets.any(func(target): return world.navigation.can_reach(candidate.arrival, target)): continue
		if not _assign_collection(world, worker, cell, resource, "fell" if resource == "log" else "gather", true): continue
		if sources[cell].inventory.reserve(worker.id, resource):
			worker.job.source = sources[cell].inventory
			worker.job.plan_id = plan.id
			return true
		worker.job = {}
	return false

static func needed_material(plan: Dictionary) -> String:
	if plan.has("delivered"):
		for resource: String in plan.delivered.amounts:
			if plan.delivered.available(resource) > 0: return resource
	if not plan.has("materials"):
		return "log" if plan.installed + plan.reserved < plan.required else ""
	for resource: String in plan.materials:
		if int(plan.used.get(resource, 0)) + int(plan.claims.get(resource, 0)) < int(plan.materials[resource]):
			return resource
	return ""

static func claim_material(plan: Dictionary, resource: String, amount: int) -> void:
	plan.reserved += amount
	if plan.has("materials"):
		plan.claims[resource] = int(plan.claims.get(resource, 0)) + amount

static func _assign_farm(world, worker: Dictionary) -> bool:
	for cell: Vector3i in nearby_cells(world.gardens, worker.cell):
		if Relocation.locked(world, cell): continue
		var garden: Dictionary = world.gardens[cell]
		# Stop grain from filling every general store before a mill is built.
		if Economy.field_resource(world, cell) == "grain" and world.resource_total("grain") >= 8 and worker.get("role", "auto") != "farmer":
			continue
		if garden.reserved != -1:
			continue
		if world.Farming.needs_water(world, cell):
			var source := _source_for(world, worker, "water", world.Farming.watering_targets(world, cell))
			if not source.is_empty() and source.inventory.reserve(worker.id, "water"):
				garden.reserved = worker.id
				worker.job = {"kind": "water", "garden": cell, "source": source.inventory,
					"target": source.target, "phase": "pickup", "labour": Labour.new(Balance.number("watering_seconds"))}
				_set_route(world, worker, source.route, "fetching water")
				return true
		if garden.food > 0 and _assign_collection(world, worker, cell, Economy.field_resource(world, cell), "harvest"):
			garden.reserved = worker.id
			return true
	return false

static func _assign_recipe(world, worker: Dictionary, kind: String) -> bool:
	var recipe: Dictionary = Economy.RECIPES[kind].duplicate()
	var carried: bool = worker.cargo == recipe.input and int(worker.get("cargo_amount", 1)) == 1 and not worker.has("relocation_cargo")
	if not worker.cargo.is_empty() and not carried: return false
	var tuning := Balance.production(kind)
	recipe.seconds = tuning.seconds_per_batch
	recipe.buffer = tuning.automatic_stock_target
	if worker.get("role", "auto") == "auto" and world.resource_total(recipe.output) >= recipe.buffer:
		return false
	for cell: Vector3i in nearby_cells(world.buildings, worker.cell):
		if worker.has("assigned_workplace") and worker.assigned_workplace != cell: continue
		if Relocation.locked(world, cell) or world.buildings[cell].kind != kind:
			continue
		var capacity := 2 if kind == "windmill" and int(world.buildings[cell].get("mill_tier", 3)) == 2 else 1
		var assigned := 0
		for other: Dictionary in world.workers:
			if other.id != worker.id and other.job.get("kind") == "process" and other.job.get("target") == cell: assigned += 1
		if assigned >= capacity: continue
		# Each operator reserves their own physical grain input.
		var route: Array[Vector3i] = []
		if carried: route = world.navigation.route(worker.cell, cell)
		var source := {} if carried else _source_for(world, worker, recipe.input, [cell])
		if (carried and not route.is_empty()) or (not source.is_empty() and source.inventory.reserve(worker.id, recipe.input)):
			worker.job = {"kind": "process", "target": cell, "phase": "travel" if carried else "pickup",
				"recipe_kind": kind, "output": recipe.output, "yield": int(tuning.output_items), "labour": Labour.new(recipe.seconds)}
			if not carried: worker.job.source = source.inventory
			if kind == "windmill" and int(world.buildings[cell].get("mill_tier", 3)) == 2:
				var spots: Array[Vector3i] = world.navigation.access_cells(cell)
				spots.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.z < b.z))
				var taken: Array = []
				for other: Dictionary in world.workers:
					if other.id != worker.id and other.job.get("target") == cell and other.job.has("work_cell"): taken.append(other.job.work_cell)
				if not spots.is_empty(): worker.job.work_cell = spots.front() if spots.front() not in taken else spots.back()
			if carried: _route_to_job(world, worker)
			else: _set_route(world, worker, source.route, "economy_fetch_material_text")
			return true
	return false

static func _process_with_cargo(world, worker: Dictionary) -> bool:
	if worker.cargo.is_empty() or not Citizens.is_adult(worker): return false
	for kind: String in Economy.RECIPES:
		if worker.get("role", "auto") in ["auto", Economy.RECIPES[kind].role] and worker.cargo == Economy.RECIPES[kind].input:
			if _assign_recipe(world, worker, kind): return true
	return false

static func _assign_deposit(world, worker: Dictionary, kind: String, quarry: Variant = null) -> bool:
	var cells: Array = world.deposits.keys()
	cells.sort_custom(func(a, b): return worker.cell.distance_squared_to(a) < worker.cell.distance_squared_to(b))
	for cell: Vector3i in cells:
		if Relocation.locked(world, cell): continue
		var deposit: Dictionary = world.deposits[cell]
		if kind == "limestone" and world.rock_in_use(cell): continue
		if kind == "limestone" and worker.has("assigned_workplace"):
			if world.buildings.get(worker.assigned_workplace, {}).get("kind") != "quarry" or Vector2(cell.x - worker.assigned_workplace.x, cell.z - worker.assigned_workplace.z).length() > 8.0: continue
		if quarry != null and Vector2(cell.x - quarry.x, cell.z - quarry.z).length() > 8.0: continue
		var resource := "food" if kind == "berry" else "stone"
		if deposit.kind == kind and deposit.inventory.available(resource) > 0 and _assign_collection(world, worker, cell, resource, "gather"):
			if deposit.inventory.reserve(worker.id, resource):
				worker.job.source = deposit.inventory
				if quarry != null: worker.job.quarry = quarry
				return true
			worker.job = {}
	return false

static func _assign_collection(world, worker: Dictionary, source: Vector3i, resource: String, kind: String, for_construction := false, direct_water := false) -> bool:
	if not world.exploration.contains(Navigation.point(source)):
		return false
	var route: Array[Vector3i] = world.navigation.route(worker.cell, source)
	var quarter := -1
	if kind == "harvest" and world.Farming.is_hay(world, source):
		route = []
		var shortest := INF
		for candidate in world.Farming.HAY_HARVEST:
			if (world.Farming.standing_quarters(world.gardens[source]) & (1 << candidate)) == 0 or not world.Farming.quarter_open(world, source, candidate): continue
			var target: Vector3i = world.Farming.quarter_cell(world, source, candidate)
			if not world.navigation.walkable(target): continue
			var option: Array[Vector3i] = world.navigation.route(worker.cell, target)
			if not option.is_empty() and world.navigation.distance(option) < shortest:
				route = option
				quarter = candidate
				shortest = world.navigation.distance(option)
	var collection := "tree"
	var available := 0
	if kind == "harvest":
		collection = "hay" if world.Farming.is_hay(world, source) else ("grass" if world.gardens[source].get("species") == "grass" else "vegetables")
		available = int(world.gardens[source].food)
	elif kind == "gather":
		collection = "berry" if resource == "food" else "stone"
		available = world.deposits[source].inventory.available(resource)
	elif kind == "collect_water":
		collection = "water"
		var inventory = world.wells.get(source, world.water_sources.get(source, {}).get("inventory"))
		if inventory != null: available = inventory.available(resource)
	else:
		available = world.trees[source].inventory.available(resource)
	var tuning := Balance.gathering(collection)
	if kind == "collect_water" and not direct_water: available = mini(available, int(world.water_orders.get(source, 0)))
	if available <= 0 or route.is_empty():
		return false
	# Solid materials can go to a site or the ground when storage is unavailable.
	# Water collection still needs a compatible receiving vessel.
	var assigned_gatherer: bool = worker.get("role", "auto") in ["woodcutter", "forager", "farmer", "miner"]
	if not assigned_gatherer and not for_construction and resource == "water" and not _has_destination_store(world, route.back(), resource):
		return false
	worker.job = {"kind": kind, "target": source, "resource": resource, "phase": "collect",
		"labour": Labour.new(float(tuning.seconds_per_action))}
	if direct_water: worker.job.direct_water = true
	if quarter >= 0: worker.job.quarter = quarter
	_set_route(world, worker, route, "walking to water" if kind == "collect_water" else ("walking to harvest" if kind == "harvest" else ("economy_to_deposit_text" if kind == "gather" else "walking to tree")))
	return true

static func _has_destination_store(world, start: Vector3i, resource: String) -> bool:
	# Before collecting water, only the existence of a receiving vessel matters.
	# Select its actual delivery route after pickup, when capacity is rechecked.
	for cell: Vector3i in world.stores:
		if not Economy.accepts(world, cell, resource) or Economy.storage_space(world, cell, resource) < 1: continue
		if not Relocation.locked(world, cell) and world.navigation.can_reach(start, cell): return true
	return false

static func _destination_store(world, start: Vector3i, resource := "log", amount := 1) -> Dictionary:
	var result := {}
	var shortest := INF
	var household := false
	for cell: Vector3i in world.stores:
		if Relocation.locked(world, cell) or not Economy.accepts(world, cell, resource) or Economy.storage_space(world, cell, resource) < amount:
			continue
		var route: Array[Vector3i] = world.navigation.route(start, cell)
		var feeds_house: bool = resource == "food" and world.buildings.get(cell, {}).get("kind") == "house"
		if not route.is_empty() and ((feeds_house and not household) or (feeds_house == household and world.navigation.distance(route) < shortest)):
			household = feeds_house
			shortest = world.navigation.distance(route)
			result = {"cell": cell, "route": route, "inventory": world.stores[cell]}
	return result

static func _set_route(world, worker: Dictionary, route: Array, status: String) -> void:
	clear_retry(worker)
	worker.route = world.Clearance.arrival_route(world, worker, route)
	worker.route_index = 1
	worker.status = status

static func clear_retry(worker: Dictionary) -> void:
	for key in ["retry_at", "retry_revision", "retry_min_at", "retry_navigation", "retry_exploration", "retry_hungry"]:
		worker.erase(key)

static func _defer_decision(world, worker: Dictionary) -> void:
	worker.retry_revision = world.revision
	worker.retry_navigation = world.navigation.revision
	worker.retry_exploration = world.exploration.revision
	worker.retry_hungry = worker.hunger >= 30.0
	worker.retry_min_at = world.time + MIN_RETRY_SECONDS
	# Spread idle citizens across ticks, even when they all ran out of work together.
	worker.retry_at = world.time + RETRY_SECONDS + (int(worker.id) % 5) * 0.05

static func _retry_due(world, worker: Dictionary) -> bool:
	if world.time < float(worker.get("retry_min_at", 0.0)):
		return false
	return world.time >= float(worker.get("retry_at", 0.0)) \
		or int(worker.get("retry_revision", -1)) != world.revision \
		or int(worker.get("retry_navigation", -1)) != world.navigation.revision \
		or int(worker.get("retry_exploration", -1)) != world.exploration.revision \
		or bool(worker.get("retry_hungry", false)) != (worker.hunger >= 30.0)

static func prepare_decisions(world) -> void:
	world.decision_candidates.clear()
	var waiting: Array[Dictionary] = []
	for worker: Dictionary in world.workers:
		if worker.has("clearance_route") and not worker.job.is_empty(): continue
		if not Citizens.is_adult(worker) and worker.job.is_empty() and worker.hunger < 30.0:
			continue
		if (worker.job.is_empty() or worker.has("retry_at")) and _retry_due(world, worker):
			waiting.append(worker)
	# Oldest request wins, so frequent world changes cannot starve later citizens.
	waiting.sort_custom(func(a, b):
		var ta := float(a.get("decision_last_at", -1.0))
		var tb := float(b.get("decision_last_at", -1.0))
		return ta < tb if ta != tb else int(a.id) < int(b.id))
	for index in mini(DECISIONS_PER_TICK, waiting.size()):
		world.decision_candidates[waiting[index].id] = true

static func _can_decide(world, worker: Dictionary, immediate: bool) -> bool:
	if not immediate:
		if not world.decision_candidates.has(worker.id):
			return false
		world.decision_candidates.erase(worker.id)
		world.job_decisions += 1
	worker.decision_last_at = world.time
	clear_retry(worker)
	return true

static func _tick_worker(world, worker: Dictionary, delta: float) -> void:
	if worker.job.get("kind") == "process" and worker.job.get("phase") != "store" and worker.job.has("recipe_kind") and world.buildings.get(worker.job.target, {}).get("kind") != worker.job.recipe_kind:
		_cancel_job(world, worker)
		worker.route = []; worker.route_index = 0
	if worker.cargo != "food": worker.erase("cargo_food")
	if worker.job.get("debug_free", false) and not world.debug_mode:
		world._release_debug_builder(worker)
	if worker.job.is_empty() or worker.has("retry_at"):
		if not _can_decide(world, worker, delta == 0.0):
			return
	if worker.job.is_empty():
		_assign(world, worker)
		if worker.job.is_empty():
			_defer_decision(world, worker)
		return
	if worker.route_index < worker.route.size():
		var next: Vector3i = worker.route[worker.route_index]
		if not world.navigation.edges.get(worker.cell, []).has(next):
			worker.status = "waiting · route disconnected"
			var destination: Vector3i = worker.route.back()
			var reroute: Array[Vector3i] = world.navigation.route(worker.cell, destination)
			if not reroute.is_empty():
				_set_route(world, worker, reroute, "route restored")
				return
			if worker.cargo.is_empty():
				_cancel_job(world, worker)
				worker.route = []
				return
			if _retask_carrier(world, worker):
				return
			_defer_decision(world, worker)
			return
		var target: Vector3 = world.navigation.movement_target(worker.cell, next, worker.position)
		if not world.RopeBridges.can_step(world, worker, next): return
		var old: Vector3 = worker.position
		worker.position = old.move_toward(target, delta * preload("res://scripts/settlement/rain_exposure.gd").movement(world,worker,next,delta) * Balance.number("walk_speed") * (Balance.number("road_speed_multiplier") if world.buildings.get(next, {}).get("kind") == "road" else 1.0))
		if worker.cell.y == next.y and not world.navigation.room_paths.get(worker.cell,{}).has(next):
			# A replacement order can turn halfway across a terrain triangle.
			worker.position = world.navigation.ground_position(worker.position, worker.cell.y)
		worker.distance += old.distance_to(worker.position)
		if worker.position.distance_to(world.navigation.surface_point(next)) < 0.001:
			worker.cell = next
			worker.route_index += 1
		return
	var job: Dictionary = worker.job
	match str(job.phase):
		"pickup":
			worker.cargo = job.source.pickup(worker.id)
			if worker.cargo == "log":
				var source_cell = world.stores.find_key(job.source)
				if source_cell != null: world.timber_picked_up.emit(worker.id, source_cell, job.source.count("log"))
				else:
					for salvage: Dictionary in world.plans.values():
						if world.Deconstruction.is_salvage(salvage) and salvage.relocation.parts == job.source:
							world.timber_salvage_picked_up.emit(worker.id, salvage.id, job.source.count("log"))
							break
			world.revision += 1
			if worker.cargo.is_empty():
				_cancel_job(world, worker)
				return
			if job.has("salvage_plan_id"):
				# Once lifted, this piece belongs to the carrier and can use any store.
				job.erase("source")
				job.erase("salvage_plan_id")
				job.phase = "store"
				return
			if job.kind == "build" and world.plans[job.plan_id].has("relocation"):
				worker.relocation_cargo = job.plan_id
			job.phase = "travel"
			_route_to_job(world, worker)
		"travel":
			if job.kind == "move" and world.navigation.at_access(worker.cell, job.target):
				worker.job = {} if worker.cargo.is_empty() else {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Labour.new(0.6)}
			elif not world.navigation.at_access(worker.cell, job.target):
				_route_to_job(world, worker)
			elif job.kind == "delivery":
				SiteDelivery.finish(world, worker)
			elif job.kind == "restock":
				_deliver_to_store(world, worker)
			else:
				job.phase = "work"
		"work":
			if job.kind == "restock":
				# Older saves may still be in the former timed unloading phase.
				_deliver_to_store(world, worker)
				return
			if job.kind == "build" and world.plans.has(job.plan_id) and not world.Planning.ready(world, world.plans[job.plan_id]): return
			if job.kind == "relocate":
				Relocation.tick_work(world, worker, delta)
				return
			worker.status = "economy_processing_text" if job.kind == "process" else ("building" if job.kind == "build" else ("eating" if job.kind == "eat" else "watering"))
			if job.labour.apply(worker.id, delta * Economy.work_speed(world) * (Economy.production_speed(world, job.target) if job.kind == "process" else 1.0) * (0.5 if worker.hunger >= 120.0 and job.kind != "eat" else 1.0)):
				if job.kind == "build" and world.plans.has(job.plan_id):
					var plan: Dictionary = world.plans[job.plan_id]
					if plan.has("sowing"):
						world._complete_plan(plan)
						worker.job = {}
						return
					worker.erase("relocation_cargo")
					world.Soil.prepare(world, plan)
					plan.installed += 1
					var material: String = job.resource if job.get("debug_free", false) else worker.cargo
					claim_material(plan, material, -1)
					if plan.has("materials"):
						plan.used[material] = int(plan.used.get(material, 0)) + 1
					if material == "log" and not job.get("debug_free", false): world.timber_installed.emit(worker.id, plan)
					if plan.installed == plan.required:
						world._complete_plan(plan)
				elif job.kind == "extract":
					if not world.buildings.has(job.target) or int(world.buildings[job.target].get("deposit_remaining", 0)) <= 0:
						worker.job = {}
						return
					world.buildings[job.target].deposit_remaining -= 1
					worker.cargo = job.output
					worker.cargo_amount = 1
					job.phase = "store"
					world.discover_resource(job.output)
					world.revision += 1
					return
				elif job.kind == "process":
					# Keep turning a two-person mill until the other operator's
					# batch finishes too; sequential ticks must not strand them.
					if world.buildings.get(job.target, {}).get("kind") == "windmill" and int(world.buildings[job.target].get("mill_tier", 3)) == 2:
						for other: Dictionary in world.workers:
							if other.id != worker.id and other.job.get("kind") == "process" and other.job.get("target") == job.target and other.job.get("phase") == "work" and not other.job.labour.is_complete(): return
					worker.cargo = job.output
					if job.output == "food": worker.cargo_food = "bread"
					worker.cargo_amount = int(job.get("yield", 1))
					job.erase("source")
					job.phase = "store"
					world.revision += 1
					return
				elif job.kind == "eat":
					worker.hunger = 0.0
					world.meals_eaten += 1
				elif job.kind == "water" and world.gardens.has(job.garden):
					world.Farming.water_crop(world, job.garden)
					world.gardens[job.garden].reserved = -1
				worker.cargo = ""
				worker.cargo_amount = 1
				worker.job = {}
				world.deliveries += 1
				world.revision += 1
		"collect":
			if job.kind == "harvest" and world.Farming.is_hay(world, job.target) and job.has("quarter"):
				if not world.Farming.quarter_open(world, job.target, int(job.quarter)) or (world.Farming.standing_quarters(world.gardens[job.target]) & (1 << int(job.quarter))) == 0:
					_cancel_job(world, worker)
					return
			if job.kind == "harvest" and int(world.gardens[job.target].food) <= 0:
				_cancel_job(world, worker)
				return
			if job.kind == "gather" and world.deposits.get(job.target, {}).get("kind") == "limestone" and world.rock_in_use(job.target):
				_cancel_job(world, worker)
				return
			worker.status = "collecting water" if job.kind == "collect_water" else ("harvesting" if job.kind in ["harvest", "gather"] else "cutting timber")
			if job.labour.apply(worker.id, delta * Economy.work_speed(world) * (0.5 if worker.hunger >= 120.0 and job.kind != "eat" else 1.0)):
				if job.kind == "harvest":
					if world.Farming.is_hay(world, job.target):
						world.Farming.cut_quarter(world.gardens[job.target], int(job.get("quarter", -1)))
					else:
						world.gardens[job.target].food -= 1
					world.gardens[job.target].reserved = -1
					worker.cargo = job.get("resource", "food")
				else:
					worker.cargo = job.source.pickup(worker.id)
					if worker.cargo.is_empty():
						_cancel_job(world, worker)
						return
					if worker.cargo == "stone": world.rebuild_navigation()
				worker.cargo_amount = 1
				job.phase = "store"
				if job.kind == "fell": world.timber_cut.emit(worker.id, job.target, job.source.count("log") + 1)
				job.erase("source")
				if job.kind == "fell": world.remove_stump(job.target)
				world.revision += 1
		"store":
			if Relocation.return_parts(world, worker): return
			if worker.get("role", "auto") == "builder" and _build_with_cargo(world, worker): return
			if _process_with_cargo(world, worker): return
			var destination := _destination_store(world, worker.cell, worker.cargo, int(worker.get("cargo_amount", 1)))
			var workplace: Vector3i = worker.get("assigned_workplace", job.get("quarry", Vector3i(99999, 0, 0)))
			if world.stores.has(workplace) and Economy.storage_space(world, workplace, worker.cargo) >= int(worker.get("cargo_amount", 1)):
				var route: Array[Vector3i] = world.navigation.route(worker.cell, workplace)
				if not route.is_empty(): destination = {"cell": workplace, "route": route, "inventory": world.stores[workplace]}
			if destination.is_empty():
				if worker.cargo == "water":
					worker.status = "waiting · storage full or unreachable"
					_defer_decision(world, worker)
					return
				if _build_with_cargo(world, worker): return
				if SiteDelivery.assign(world, worker): return
				world.Deconstruction.drop_cargo(world, worker)
				worker.job = {}
				clear_retry(worker)
			elif world.navigation.at_access(worker.cell, destination.cell):
				if preload("res://scripts/settlement/building_assembly_navigation.gd").storage_busy(world,destination.cell): return
				if destination.inventory.store(worker.cargo, int(worker.get("cargo_amount", 1))):
					if worker.cargo == "log": world.timber_stored.emit(worker.id, destination.cell, destination.inventory.count("log") - int(worker.get("cargo_amount", 1)))
					worker.cargo_amount = 1
					worker.cargo = ""
					worker.job = {}
					world.deliveries += 1
					world.revision += 1
			else:
				_set_route(world, worker, destination.route, "carrying to storage")

static func _deliver_to_store(world, worker: Dictionary) -> void:
	if preload("res://scripts/settlement/building_assembly_navigation.gd").storage_busy(world,worker.job.target): return
	# Restock retains its labour field for save compatibility, but never applies it.
	var job: Dictionary = worker.job
	if not world.stores.has(job.target) or not Economy.accepts(world, job.target, worker.cargo) or Economy.storage_space(world, job.target, worker.cargo) < int(worker.get("cargo_amount", 1)) or not world.stores[job.target].store(worker.cargo, int(worker.get("cargo_amount", 1))):
		job.phase = "store"
		worker.status = "waiting · storage full or unreachable"
		_defer_decision(world, worker)
		return
	if worker.cargo == "log": world.timber_stored.emit(worker.id, job.target, world.stores[job.target].count("log") - int(worker.get("cargo_amount", 1)))
	worker.cargo = ""
	worker.cargo_amount = 1
	worker.job = {}
	world.deliveries += 1
	world.revision += 1

static func needs_material(plan: Dictionary, resource: String) -> bool:
	if plan.has("sowing") or plan.get("deconstruction", false): return false
	if not plan.has("materials"):
		return resource == "log" and plan.installed + plan.reserved < plan.required
	return int(plan.used.get(resource, 0)) + int(plan.claims.get(resource, 0)) + SiteDelivery.staged(plan, resource) < int(plan.materials.get(resource, 0))

static func cargo_matches_role(world, worker: Dictionary, role: String, plan_id := -1) -> bool:
	if worker.cargo.is_empty(): return true
	if worker.has("relocation_cargo"): return worker.relocation_cargo == plan_id
	if role in ["auto", "hauler"]: return true
	if role == "builder":
		var plans: Array = [world.plans[plan_id]] if world.plans.has(plan_id) else world.plans.values()
		return int(worker.get("cargo_amount", 1)) == 1 and plans.any(func(plan): return not plan.has("relocation") and needs_material(plan, worker.cargo))
	var resources: Array = {"woodcutter": ["log"], "forager": ["food"], "farmer": ["food", "grain", "water"]}.get(role, [])
	for recipe: Dictionary in Economy.RECIPES.values():
		if recipe.role == role: resources.append_array([recipe.input, recipe.output])
	if role == "miner": resources.append("stone")
	return worker.cargo in resources

static func _build_with_cargo(world, worker: Dictionary) -> bool:
	# Existing log carriers must be able to build their first dedicated shed.
	if worker.cargo.is_empty() or worker.get("role", "auto") not in ["auto", "builder"] or int(worker.get("cargo_amount", 1)) != 1: return false
	var assigned: int = worker.get("assigned_plan_id", -1)
	var plans: Array = [world.plans[assigned]] if world.plans.has(assigned) else world.plans.values()
	for plan: Dictionary in plans:
		if plan.kind in ["room_utility","home_utility"] and not world.Rooms.ready(world,plan): continue
		if not needs_material(plan, worker.cargo): continue
		if plan.has("relocation"):
			if worker.get("relocation_cargo", -1) != plan.id or plan.relocation.stage != "rebuild": continue
		elif worker.has("relocation_cargo"): continue
		var route: Array[Vector3i] = world.nearest_route(worker.cell, world.work_cells(plan.kind, plan.cell, plan.direction))
		if route.is_empty(): continue
		claim_material(plan, worker.cargo, 1)
		worker.job = {"kind": "build", "plan_id": plan.id, "target": route.back(), "phase": "travel", "resource": worker.cargo, "labour": Labour.new(Balance.construction_seconds(plan.kind))}
		_set_route(world, worker, route, "carrying " + worker.cargo)
		return true
	return false

static func _route_to_job(world, worker: Dictionary) -> void:
	var route: Array[Vector3i] = world.navigation.route(worker.cell, worker.job.get("work_cell", worker.job.target))
	if route.is_empty():
		worker.status = "waiting · destination unreachable"
		if not _retask_carrier(world, worker):
			_defer_decision(world, worker)
	else:
		_set_route(world, worker, route, "carrying " + worker.cargo)

static func _retask_carrier(world, worker: Dictionary) -> bool:
	# A disconnected delivery must not monopolise every worker. Reuse the cargo
	# on reachable construction (especially replacement stairs) without spawning it.
	if worker.job.get("kind") == "delivery":
		_cancel_job(world, worker)
		worker.route = []
		worker.route_index = 0
		worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Labour.new(0.1)}
		return true
	if worker.job.get("kind") != "build" or worker.has("relocation_cargo"):
		return false
	var assigned_id: int = worker.get("assigned_plan_id", -1)
	if world.plans.has(assigned_id):
		var assigned: Dictionary = world.plans[assigned_id]
		var route = world.nearest_route(worker.cell, world.work_cells(assigned.kind, assigned.cell, assigned.direction))
		if route.is_empty():
			return false
		worker.job.target = route.back()
		_set_route(world, worker, route, "carrying " + worker.cargo)
		return true
	for plan: Dictionary in world.plans.values():
		if plan.has("relocation") or plan.id == worker.job.plan_id or needed_material(plan) != worker.cargo:
			continue
		var route = world.nearest_route(worker.cell, world.work_cells(plan.kind, plan.cell, plan.direction))
		if route.is_empty():
			continue
		if world.plans.has(worker.job.plan_id):
			claim_material(world.plans[worker.job.plan_id], worker.cargo, -1)
		claim_material(plan, worker.cargo, 1)
		worker.job = {"kind": "build", "plan_id": plan.id, "target": route.back(),
			"phase": "travel", "resource": worker.cargo, "labour": Labour.new(Balance.construction_seconds(plan.kind))}
		_set_route(world, worker, route, "rerouting timber")
		return true
	return false

static func _cancel_job(world, worker: Dictionary) -> void:
	var job: Dictionary = worker.job
	if job.kind == "relocate" and world.plans.has(job.plan_id):
		var move: Dictionary = world.plans[job.plan_id].relocation
		move.owner = -1
		if worker.has("plant_plan_id"):
			move.pickup_cell = worker.cell
			worker.erase("plant_plan_id")
	if job.has("source"):
		job.source.release(worker.id)
	if job.kind in ["build", "delivery"] and world.plans.has(job.plan_id) and not world.plans[job.plan_id].has("sowing"):
		claim_material(world.plans[job.plan_id], job.get("resource", "log"), -int(job.get("amount", 1)))
	if job.kind == "water" and world.gardens.has(job.garden):
		world.gardens[job.garden].reserved = -1
	if job.kind == "collect_water" and job.get("phase", "collect") == "collect" and not job.get("direct_water", false):
		var inventory = world.Hydrology.inventory_at(world, job.target)
		if inventory != null:
			world.water_orders[job.target] = mini(inventory.capacity, int(world.water_orders.get(job.target, 0)) + 1)
	if job.kind == "harvest" and world.gardens.has(job.target):
		world.gardens[job.target].reserved = -1
	worker.job = {}


static func nearby_cells(values: Dictionary, origin: Vector3i) -> Array:
	var cells: Array = values.keys()
	cells.sort_custom(func(a, b): return origin.distance_squared_to(a) < origin.distance_squared_to(b))
	return cells

static func assign_workplace(world, worker: Dictionary, kind: String) -> bool:
	if kind in Economy.RECIPES: return _assign_recipe(world, worker, kind)
	if kind == "quarry": return _assign_quarry(world, worker)
	return _assign_extraction(world, worker, kind)

static func _assign_extraction(world, worker: Dictionary, kind: String) -> bool:
	if not worker.cargo.is_empty(): return false
	var recipe: Dictionary = Economy.EXTRACTORS[kind]
	if worker.get("role", "auto") == "auto" and world.resource_total(recipe.output) >= 12: return false
	for cell: Vector3i in nearby_cells(world.buildings, worker.cell):
		if worker.has("assigned_workplace") and worker.assigned_workplace != cell: continue
		var building: Dictionary = world.buildings[cell]
		if building.kind != kind or int(building.get("deposit_remaining", 0)) <= 0 or Relocation.locked(world, cell): continue
		if world.workers.any(func(other): return other.id != worker.id and other.job.get("kind") == "extract" and other.job.get("target") == cell): continue
		var route: Array[Vector3i] = world.navigation.route(worker.cell, cell)
		if route.is_empty(): continue
		var seconds := float(world.Catalog.Reviewed.data.extraction[kind].seconds)
		worker.job = {"kind": "extract", "phase": "travel", "target": cell, "output": recipe.output, "labour": Labour.new(seconds)}
		_set_route(world, worker, route, "gathering")
		return true
	return false

static func _assign_quarry(world, worker: Dictionary) -> bool:
	for cell: Vector3i in nearby_cells(world.buildings, worker.cell):
		if world.buildings[cell].kind != "quarry" or Relocation.locked(world, cell): continue
		if worker.has("assigned_workplace") and worker.assigned_workplace != cell: continue
		if world.workers.any(func(other): return other.id != worker.id and (other.job.get("quarry") == cell or other.get("assigned_workplace") == cell)): continue
		if _assign_deposit(world, worker, "limestone", cell): return true
	return false
