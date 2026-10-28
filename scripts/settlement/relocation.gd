extends RefCounted
## A destination plan owns its source, recovered parts and saved dismantling work.
const Catalog = preload("res://data/settlement/catalog.gd")
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Labour = preload("res://scripts/applied_labour.gd")
const FIELDS := ["buildings", "platforms", "stairs", "stores", "wells", "gardens", "trees", "deposits", "soil_beds"]

static func kind_at(world, cell: Vector3i) -> String:
	if world.deposits.get(cell, {}).get("kind") == "berry": return "berry"
	if world.buildings.has(cell): return world.buildings[cell].kind
	if world.gardens.has(cell): return "garden"
	if world.soil_beds.has(cell): return "soil_bed"
	if world.platforms.has(cell): return "platform"
	if world.stairs.has(cell): return "stairs"
	if world.stores.has(cell): return "stockpile"
	if world.wells.has(cell): return "well"
	if world.trees.has(cell): return "tree"
	if world.vines.has(cell): return "vine_tree"
	return ""

static func portable_plant(plan: Dictionary) -> bool:
	return not plan.get("collect_bush", false) and (plan.kind in ["tree", "berry"] or (plan.kind == "garden" and plan.required == 0))

static func locked(world, cell: Vector3i) -> bool:
	for plan: Dictionary in world.plans.values():
		if world.Deconstruction.is_salvage(plan): continue
		if plan.has("relocation") and plan.relocation.source == cell: return true
		if plan.cell == cell and (world.wells.has(cell) or world.buildings.get(cell, {}).get("kind") == "sawmill" or plan.get("goods_upgrade", false)): return true
	return false

static func source_error(world, cell: Vector3i, existing := false) -> String:
	var kind := kind_at(world, cell)
	if kind.is_empty() or (not existing and locked(world, cell)): return "relocation_unavailable_text"
	if kind == "tree" and world.is_stump(cell) and not existing: return "relocation_unavailable_text"
	if not world.exploration.contains(world.navigation.point(cell)): return "relocation_unavailable_text"
	if kind == "berry": return ""
	if kind == "vine_tree": return "" if world.vines[cell].health > 0 else "relocation_unavailable_text"
	if kind == "soil_bed" and world.Farming.bed_in_use(world, cell): return "relocation_support_text"
	if world.needs_stack_support(cell): return "relocation_support_text"
	if kind == "platform":
		if world.occupied(cell): return "relocation_support_text"
		for plan: Dictionary in world.plans.values():
			if world.Deconstruction.is_salvage(plan): continue
			if existing and plan.has("relocation") and plan.relocation.source == cell: continue
			if Grid.overlaps(plan.cell, cell) or (plan.kind == "platform" and Grid.overlaps(plan.cell - Vector3i.UP * int(plan.get("platform_tier", 1)), cell)): return "relocation_support_text"
	for worker: Dictionary in world.workers:
		if worker.route_index < worker.route.size() and world.navigation.ladder_cell(worker.cell, worker.route[worker.route_index]) == cell:
			return "relocation_support_text"
		if worker.cell.y > cell.y and worker.route_index < worker.route.size() and Grid.overlaps(Vector3i(worker.route[worker.route_index].x, cell.y, worker.route[worker.route_index].z), cell):
			return "relocation_support_text"
		if worker.cell.y >= cell.y + (0 if kind == "platform" else 1):
			if kind == "stairs" or Grid.overlaps(Vector3i(worker.cell.x, cell.y, worker.cell.z), cell):
				return "relocation_support_text"
	return ""

static func destination_error(world, source: Vector3i, target: Vector3i, direction: int, offset: Vector3) -> String:
	var error := source_error(world, source)
	if not error.is_empty(): return error
	var kind := kind_at(world, source)
	if source == target or world.goods_upgrade(kind, target): return "This space is occupied"
	if world.buildings.get(target, {}).get("kind") == "sawmill": return "This space is occupied"
	if kind != "well" and world.wells.has(target): return "This space is occupied"
	if kind == "hay_field": offset = world.Farming.FIELD_OFFSET
	if world.Farming.overlaps(kind, source, kind, target, world.buildings.get(source, {}).get("placement_offset", Vector3.ZERO), offset): return "This space is occupied"
	if target.y > source.y and Grid.overlaps(source, Vector3i(target.x, source.y, target.z)):
		return "relocation_support_text"
	if not world.exploration.contains(world.navigation.point(target)): return "relocation_unavailable_text"
	# Plants share the footprint checks, but only root in natural level ground.
	if kind == "tree":
		for cell: Vector3i in Grid.support_cells(target):
			if not world.ground.has(cell) or world.terrain_shapes.has(cell): return "Choose level ground"
	# Bushes use their own single-tile checks; trees retain room-sized checks.
	var placement_kind := "garden" if kind == "tree" else kind
	if kind == "garden" and world.gardens[source].has("species"):
		placement_kind = "seed_grass" if world.gardens[source].species == "grass" else "seed_vegetables"
	error = world.build_error(placement_kind, target, direction, offset, -1, world.Platforms.tier(world.platforms[source]) if kind == "platform" else 1)
	if not error.is_empty(): return error
	var reachable := false
	for start: Vector3i in source_work_cells(world, kind, source, direction):
		if not world.nearest_route(start, world.work_cells(kind, target, direction, world.Platforms.tier(world.platforms[source]) if kind == "platform" else 0)).is_empty():
			reachable = true
			break
	if not reachable: return "waiting · destination unreachable"
	return ""

static func request(world, source: Vector3i, target: Vector3i, direction: int, offset: Vector3, dismantle_only := false, collect_only := false) -> bool:
	world.last_message = source_error(world, source) if dismantle_only or collect_only else destination_error(world, source, target, direction, offset)
	if not world.last_message.is_empty(): return false
	var kind := kind_at(world, source)
	if kind in ["tree", "berry"]:
		preload("res://scripts/settlement/nature_identity.gd").ensure(world.trees[source] if kind == "tree" else world.deposits[source], source, world.world_seed)
	if dismantle_only and (kind not in Catalog.COSTS or target != source): return false
	if collect_only and (kind != "berry" or target != source or dismantle_only): return false
	if kind == "hay_field" and not dismantle_only: offset = world.Farming.FIELD_OFFSET
	var materials: Dictionary = {} if kind in ["tree", "berry"] else world.construction_materials.get(source, Catalog.recipe(kind)).duplicate()
	if kind == "soil_bed": materials = world.soil_beds[source].materials.duplicate()
	var required := 0
	for amount: int in materials.values(): required += amount
	var id: int = world.next_plan_id
	world.next_plan_id += 1
	var parts = Inventory.new()
	parts.capacity = maxi(32, required)
	world.plans[id] = {"id": id, "kind": kind, "cell": target, "direction": direction,
		"installed": 0, "required": required, "reserved": 0, "materials": materials, "used": {}, "claims": {},
		"placement_offset": offset, "relocation": {"source": source, "pickup_cell": source,
		"stage": "dismantle", "parts": parts, "payload": {}, "owner": -1,
		"labour": Labour.new(maxf(2.0, required * 1.0))}}
	if kind == "stone_storage": world.plans[id].storage_tier = int(world.buildings[source].get("storage_tier", 1))
	if kind == "windmill": world.plans[id].mill_tier = int(world.buildings[source].get("mill_tier", 3))
	if kind == "platform": world.plans[id].platform_tier = world.Platforms.tier(world.platforms[source])
	if dismantle_only: world.plans[id]["deconstruction"] = true
	if collect_only: world.plans[id].collect_bush = true
	# Release old harvesting/production reservations before the source is sealed.
	for worker: Dictionary in world.workers:
		var job: Dictionary = worker.job
		var uses_source: bool = job.get("target") == source or job.get("garden") == source
		for field in ["stores", "wells", "trees", "deposits"]:
			if world.get(field).has(source):
				var value: Variant = world.get(field)[source]
				var inventory = value.inventory if value is Dictionary else value
				uses_source = uses_source or (job.has("source") and job.source == inventory)
		if not job.is_empty() and uses_source:
			world.Jobs._cancel_job(world, worker)
			worker.route = []
			worker.route_index = 0
			if not worker.cargo.is_empty():
				worker.job = {"kind": "restock", "phase": "store", "target": worker.cell, "labour": Labour.new(0.6)}
	world.rebuild_navigation()
	return true

static func assign(world, worker: Dictionary, plan: Dictionary) -> bool:
	var move: Dictionary = plan.relocation
	if move.stage == "rebuild" and not portable_plant(plan): return false
	if move.owner != -1: return false
	if move.stage == "dismantle" and not source_error(world, move.source, true).is_empty(): return false
	var cell: Vector3i = move.source if move.stage == "dismantle" else move.pickup_cell
	var candidates := source_work_cells(world, plan.kind, cell, plan.direction)
	var route: Array[Vector3i] = world.nearest_route(worker.cell, candidates)
	if route.is_empty(): return false
	move.owner = worker.id
	worker.job = {"kind": "relocate", "plan_id": plan.id, "target": route.back(), "phase": "travel", "labour": move.labour}
	world.Jobs._set_route(world, worker, route, "relocation_to_source_text")
	return true

static func material_source(world, worker: Dictionary, plan: Dictionary, resource: String) -> Dictionary:
	var move: Dictionary = plan.relocation
	if move.stage != "rebuild" or move.parts.available(resource) <= 0: return {}
	var route: Array[Vector3i] = world.navigation.route(worker.cell, move.pickup_cell)
	var destination: Array[Vector3i] = world.nearest_route(move.pickup_cell, world.work_cells(plan.kind, plan.cell, plan.direction))
	if route.is_empty() or destination.is_empty(): return {}
	return {"inventory": move.parts, "route": route, "target": destination.back()}

static func tick_work(world, worker: Dictionary, delta: float) -> void:
	var plan: Dictionary = world.plans[worker.job.plan_id]
	var move: Dictionary = plan.relocation
	worker.status = "building"
	if move.stage == "rebuild" and portable_plant(plan) and not worker.has("plant_plan_id"):
		_start_plant_carry(world, worker, plan)
		return
	if not worker.job.labour.apply(worker.id, delta * world.Economy.work_speed(world) * (0.5 if worker.hunger >= 120 else 1.0)): return
	if move.stage == "dismantle":
		# Recheck structural use: another order may have changed the source while walking.
		if not source_error(world, move.source, true).is_empty(): return
		if plan.get("collect_bush", false):
			world.BushTransplants.finish_collect(world, worker, plan)
			return
		if plan.get("collect_vine", false):
			preload("res://scripts/settlement/vines.gd").finish_collect(world, worker, plan)
			return
		world.water_orders.erase(move.source)
		for field in FIELDS:
			if field == "soil_beds" and plan.kind != "soil_bed": continue
			if world.get(field).has(move.source):
				move.payload[field] = world.get(field)[move.source]
				world.get(field).erase(move.source)
		if plan.kind != "soil_bed": world.construction_materials.erase(move.source)
		move.pickup_cell = worker.cell
		for resource: String in plan.materials: move.parts.store(resource, plan.materials[resource])
		if plan.get("deconstruction", false):
			world.Deconstruction.unpack(world, plan)
			worker.job = {}
			world.rebuild_navigation()
			return
		move.stage = "rebuild"
		move.labour = Labour.new(2.0)
		world.rebuild_navigation()
	if portable_plant(plan):
		if worker.get("plant_plan_id", -1) == plan.id:
			finish_plant(world, plan)
			worker.erase("plant_plan_id")
			worker.job = {}
		else:
			_start_plant_carry(world, worker, plan)
	else:
		move.owner = -1
		worker.job = {}

static func finish_plant(world, plan: Dictionary) -> void:
	if plan.kind == "garden": world.construction_materials[plan.cell] = {}
	for field: String in plan.relocation.payload: world.get(field)[plan.cell] = plan.relocation.payload[field]
	world.plans.erase(plan.id)
	for worker: Dictionary in world.workers:
		if worker.get("assigned_plan_id", -1) == plan.id: worker.assigned_plan_id = -1
	world.rebuild_navigation()

static func restore_payload(world, plan: Dictionary) -> void:
	if plan.kind == "house":
		for worker: Dictionary in world.workers:
			if worker.get("home_cell") == plan.relocation.source: worker.home_cell = plan.cell
	if plan.relocation.payload.has("buildings"):
		var destination: Dictionary = world.buildings[plan.cell]
		world.buildings[plan.cell] = plan.relocation.payload.buildings.merged(destination, true)
	for field: String in plan.relocation.payload:
		if field in ["buildings", "stairs"]: continue # New orientation and cursor offset belong to the destination.
		world.get(field)[plan.cell] = plan.relocation.payload[field]
	if world.stores.has(plan.cell): world.track_store_resources(world.stores[plan.cell])

static func return_parts(world, worker: Dictionary) -> bool:
	var id: int = worker.get("relocation_cargo", -1)
	if id == -1: return false
	var move: Dictionary = world.plans[id].relocation
	if world.navigation.at_access(worker.cell, move.pickup_cell):
		move.parts.store(worker.cargo)
		worker.cargo = ""
		worker.erase("relocation_cargo")
		worker.job = {}
		world.revision += 1
	else:
		var route: Array[Vector3i] = world.navigation.route(worker.cell, move.pickup_cell)
		if route.is_empty(): world.Jobs._defer_decision(world, worker)
		else: world.Jobs._set_route(world, worker, route, "relocation_return_parts_text")
	return true

static func _start_plant_carry(world, worker: Dictionary, plan: Dictionary) -> void:
	worker.plant_plan_id = plan.id
	worker.job.target = plan.cell
	worker.job.phase = "travel"
	worker.job.labour = plan.relocation.labour
	world.Jobs._route_to_job(world, worker)

static func source_work_cells(world, kind: String, cell: Vector3i, direction: int) -> Array[Vector3i]:
	var candidates: Array[Vector3i] = world.work_cells(kind, cell, direction)
	if kind == "platform":
		if world.navigation.surfaces.has(cell - Vector3i.UP * world.Platforms.tier(world.platforms.get(cell, true))): candidates.append(cell - Vector3i.UP * world.Platforms.tier(world.platforms.get(cell, true)))
		candidates = candidates.filter(func(candidate): return candidate.y < cell.y or not Grid.overlaps(candidate, cell))
	return candidates
