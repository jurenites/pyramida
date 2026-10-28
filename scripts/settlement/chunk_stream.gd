extends RefCounted
## Active chunks own simulation data. Dormant records contain values, never live
## inventories; any chunk referenced by citizens, jobs or construction stays live.
const Planting = preload("res://scripts/settlement/planting.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Vines = preload("res://scripts/settlement/vines.gd")
const FIELDS := ["trees", "deposits", "water_sources"]

static func chunk_for(cell: Vector3i) -> Vector2i:
	return Generator.chunk_at(Vector2i(cell.x, cell.z))

static func add_radius(wanted: Dictionary, cell: Vector3i, radius: int) -> void:
	var centre := chunk_for(cell)
	var limit := floori(float(Generator.WORLD_LIMIT) / Generator.CHUNK_SIZE)
	for x in range(centre.x - radius, centre.x + radius + 1):
		for z in range(centre.y - radius, centre.y + radius + 1):
			if x >= -limit and x < limit and z >= -limit and z < limit:
				wanted[Vector2i(x, z)] = true

static func required(world, focus: Vector3, radius: int) -> Dictionary:
	var wanted := {}
	add_radius(wanted, Vector3i(roundi(focus.x / Nav.CELL_SIZE), 0, roundi(focus.z / Nav.CELL_SIZE)), radius)
	# Keep the opening and its physical economy available; the rest is streamed.
	var first := Generator.chunk_at(Generator.INITIAL_BOUNDS.position)
	var last := Generator.chunk_at(Generator.INITIAL_BOUNDS.end - Vector2i.ONE)
	for x in range(first.x, last.x + 1):
		for z in range(first.y, last.y + 1): wanted[Vector2i(x, z)] = true
	for worker: Dictionary in world.workers:
		add_radius(wanted, worker.cell, 1)
		for cell: Vector3i in worker.route.slice(worker.route_index): add_radius(wanted, cell, 0)
		for cell: Vector3i in worker.get("clearance_route", []).slice(worker.get("clearance_index", 0)): add_radius(wanted, cell, 0)
		for key in ["target", "garden", "store", "source_cell"]:
			var cell: Variant = worker.job.get(key)
			if cell is Vector3i: add_radius(wanted, cell, 1)
	for collection in [world.buildings, world.platforms, world.stairs, world.stores, world.wells, world.gardens, world.soil_beds, world.water_orders]:
		for cell: Vector3i in collection: add_radius(wanted, cell, 1)
	for cell: Vector3i in world.vines:
		if not world.vines[cell].get("wild", false): add_radius(wanted, cell, 1)
	for plan: Dictionary in world.plans.values():
		add_radius(wanted, plan.cell, 1)
		if plan.has("relocation"):
			add_radius(wanted, plan.relocation.source, 1)
			add_radius(wanted, plan.relocation.pickup_cell, 1)
	for field in FIELDS:
		for cell: Vector3i in world.get(field):
			if not world.get(field)[cell].inventory.reservations.is_empty(): add_radius(wanted, cell, 0)
	return wanted

static func update(world, focus: Vector3, radius := 3, budget := 1, required_chunks: Variant = null) -> bool:
	if not world.streaming_enabled:
		return false
	var wanted: Dictionary = required(world, focus, radius) if required_chunks == null else required_chunks
	var pending: Array = []
	if budget > 0:
		pending = wanted.keys().filter(func(chunk): return not world.loaded_chunks.has(chunk))
		var centre := Generator.chunk_at(Vector2i(roundi(focus.x / Nav.CELL_SIZE), roundi(focus.z / Nav.CELL_SIZE)))
		pending.sort_custom(func(a, b):
			var da: int = (a - centre).length_squared()
			var db: int = (b - centre).length_squared()
			return da < db if da != db else (a.x < b.x if a.x != b.x else a.y < b.y))
	var changed := false
	var added := {}
	var removed := {}
	for index in mini(budget, pending.size()):
		load_chunk(world, pending[index])
		added.merge(chunk_surfaces(world, pending[index]))
		changed = true
	# Hysteresis keeps a one-chunk buffer instead of thrashing at a boundary.
	var keep := wanted.duplicate()
	for chunk: Vector2i in wanted:
		for x in range(-1, 2):
			for z in range(-1, 2): keep[chunk + Vector2i(x, z)] = true
	for chunk: Vector2i in world.loaded_chunks.keys():
		if not keep.has(chunk):
			removed.merge(chunk_surfaces(world, chunk))
			unload_chunk(world, chunk)
			changed = true
	if changed:
		world.terrain_revision += 1
		world.navigation.update_ground(added, removed, world.Soil.walking_shapes(world))
		world.revision += 1
	return changed

static func chunk_surfaces(world, chunk: Vector2i) -> Dictionary:
	var surfaces := {}
	var origin := chunk * Generator.CHUNK_SIZE
	for x in range(origin.x, origin.x + Generator.CHUNK_SIZE):
		for z in range(origin.y, origin.y + Generator.CHUNK_SIZE):
			var cell: Vector3i = world.surface_at(x, z)
			if world.ground.has(cell): surfaces[cell] = true
	for base: Vector3i in world.deposits:
		if chunk_for(base) == chunk:
			for top in world.rock_surfaces(base): surfaces[top] = true
	world.remove_rock_interiors(surfaces)
	return surfaces

static func integrate(world, chunk: Vector2i, generated: Dictionary) -> void:
	if world.loaded_chunks.has(chunk): return
	load_chunk(world, chunk, generated)
	world.navigation.update_ground(chunk_surfaces(world, chunk), {}, world.Soil.walking_shapes(world))
	world.terrain_revision += 1
	world.revision += 1

static func populate(world, generated: Dictionary) -> void:
	for cell: Vector3i in generated.water:
		var kind: String = generated.water[cell]
		world.water_sources[cell] = entry(kind, "water", 3 if kind == "puddle" else 2)
	for cell: Vector3i in generated.nature:
		world.navigation.blocked[cell] = true
		var kind: String = generated.nature[cell]
		if kind in ["tree", "dead_tree"]:
			world.trees[cell] = entry("living" if kind == "tree" else "dead", "log", 3)
			preload("res://scripts/settlement/nature_identity.gd").ensure(world.trees[cell], cell, world.world_seed)
		else:
			world.deposits[cell] = entry(kind, "food" if kind == "berry" else "stone", Economy.BUSH_CAPACITY if kind == "berry" else Economy.StoneVolume.capacity(cell, world.world_seed))
			if kind == "berry": preload("res://scripts/settlement/nature_identity.gd").ensure(world.deposits[cell], cell, world.world_seed)

	# Wild cuttings use sparse, seed-stable empty patches in either landscape.
	# The opening has one reachable root; no seedlings are granted to inventory.
	for cell: Vector3i in generated.ground:
		if cell.y != 0 or generated.shapes.has(cell) or generated.water.has(cell): continue
		if cell != Vector3i(-4, 0, -1):
			if maxi(absi(cell.x), absi(cell.z)) <= Generator.SAFE_RADIUS: continue
			if posmod(cell.x, 8) != 3 or posmod(cell.z, 8) != 3: continue
			if Vines.Random.world_fraction(cell.x, cell.z, world.world_seed, 941) > 0.25: continue
		var clear := true
		for x in range(-1, 2):
			for z in range(-1, 2):
				if generated.nature.has(cell + Vector3i(x, 0, z)): clear = false
		if not clear: continue
		var plant := Vines.create()
		plant.wild = true
		plant.placement_offset = Vector3(Vines.Random.world_fraction(cell.x, cell.z, world.world_seed, 942) - 0.5, 0, Vines.Random.world_fraction(cell.x, cell.z, world.world_seed, 943) - 0.5) * 0.6
		world.vines[cell] = plant

static func entry(kind: String, resource: String, capacity: int) -> Dictionary:
	var inventory = Inventory.new()
	inventory.capacity = capacity
	inventory.store(resource, capacity)
	return {"kind": kind, "inventory": inventory, "regrowth": 0.0}

static func load_chunk(world, chunk: Vector2i, generated: Dictionary = {}) -> void:
	if world.loaded_chunks.has(chunk): return
	if generated.is_empty(): generated = Generator.generate_chunk(world.world_seed, chunk, world.difficulty)
	world.ground.merge(generated.ground)
	world.terrain_heights.merge(generated.heights)
	world.terrain_shapes.merge(generated.shapes)
	world.chunk_details[chunk] = {"border": generated.border, "border_shapes": generated.border_shapes, "grass": generated.grass}
	world.loaded_chunks[chunk] = true
	if not world.dormant_chunks.has(chunk):
		populate(world, generated)
		world.Soil.rebuild(world, generated.ground)
		world.Soil.add_hollows(world, generated.ground)
		world.TerrainEditor.apply_chunk(world, chunk)
		return
	var record: Dictionary = world.dormant_chunks[chunk]
	for field in FIELDS:
		for cell: Vector3i in record[field]:
			var data: Dictionary = record[field][cell]
			# Older dormant chunks may still contain exhausted trunks.
			if field == "trees" and data.amount == 0 and float(data.get("seed_growth", 1.0)) >= 1.0: continue
			var restored := entry(data.kind, data.resource, data.capacity)
			restored.inventory.amounts = {data.resource: data.amount}
			restored.regrowth = float(data.regrowth)
			if data.has("appearance_seed"): restored.appearance_seed = int(data.appearance_seed)
			var elapsed := maxf(0.0, world.time - float(record.get("berry_time", world.time)))
			if data.has("seed_growth"):
				restored.seed_growth = data.seed_growth
				var seconds: float = Planting.growth_seconds(data.kind, field == "trees")
				var remaining := (1.0 - float(data.seed_growth)) * seconds
				Planting.grow(restored, elapsed, field == "trees")
				elapsed = maxf(0.0, elapsed - remaining)
			if field == "deposits" and data.kind == "berry" and float(restored.get("seed_growth", 1.0)) >= 1.0:
				Economy.grow_bush(restored, elapsed)
			if field == "deposits": Economy.upgrade_stone(restored, cell, world.world_seed)
			if field == "trees" or (field == "deposits" and restored.kind == "berry"):
				preload("res://scripts/settlement/nature_identity.gd").ensure(restored, cell, world.world_seed)
			world.get(field)[cell] = restored
			if field in ["trees", "deposits"] and not (field == "deposits" and data.kind == "limestone" and restored.inventory.count("stone") == 0): world.navigation.blocked[cell] = true
	world.vines.merge(record.get("vines", {}))
	world.dormant_chunks.erase(chunk)
	world.Soil.rebuild(world, generated.ground)
	world.TerrainEditor.apply_chunk(world, chunk)

static func unload_chunk(world, chunk: Vector2i) -> void:
	var record := {"berry_time": world.time, "vines": {}}
	for cell: Vector3i in world.vines.keys():
		if chunk_for(cell) != chunk: continue
		record.vines[cell] = world.vines[cell]
		world.vines.erase(cell)
	for field in FIELDS:
		record[field] = {}
		for cell: Vector3i in world.get(field).keys():
			if chunk_for(cell) != chunk: continue
			var value: Dictionary = world.get(field)[cell]
			var resource := "water" if field == "water_sources" else ("log" if field == "trees" else ("food" if value.kind == "berry" else "stone"))
			record[field][cell] = {"kind": value.kind, "resource": resource, "capacity": value.inventory.capacity,
				"amount": value.inventory.count(resource), "regrowth": value.get("regrowth", 0.0)}
			if value.has("seed_growth"): record[field][cell].seed_growth = value.seed_growth
			if value.has("appearance_seed"): record[field][cell].appearance_seed = value.appearance_seed
			world.get(field).erase(cell)
			if field in ["trees", "deposits"]: world.navigation.blocked.erase(cell)
	var origin := chunk * Generator.CHUNK_SIZE
	for x in range(origin.x, origin.x + Generator.CHUNK_SIZE):
		for z in range(origin.y, origin.y + Generator.CHUNK_SIZE):
			world.soil_shapes.erase(world.surface_at(x, z))
			world.terrain_shapes.erase(world.surface_at(x, z))
			world.ground.erase(world.surface_at(x, z))
			world.terrain_heights.erase(Vector2i(x, z))
	world.loaded_chunks.erase(chunk)
	world.chunk_details.erase(chunk)
	world.dormant_chunks[chunk] = record

static func valid_state(state: Variant, world: Dictionary) -> bool:
	if not state is Dictionary or not state.get("enabled") is bool or not state.get("loaded") is Dictionary or not state.get("dormant") is Dictionary:
		return false
	if state.enabled and world.generator_version != Generator.VERSION: return false
	if not state.enabled: return state.loaded.is_empty() and state.dormant.is_empty()
	for chunk: Variant in state.loaded.keys() + state.dormant.keys():
		if not chunk is Vector2i or not Catalog.in_bounds(Vector3i(chunk.x * Generator.CHUNK_SIZE, 0, chunk.y * Generator.CHUNK_SIZE)):
			return false
	for chunk: Vector2i in state.loaded:
		if state.loaded[chunk] != true or state.dormant.has(chunk): return false
	for cell: Vector3i in world.ground:
		if not state.loaded.has(chunk_for(cell)): return false
	if world.get("difficulty", "normal") == "easy":
		# Coastal chunks include nonwalkable sea. Validate their actual land mask.
		var expected := 0
		for chunk: Vector2i in state.loaded:
			var origin := chunk * Generator.CHUNK_SIZE
			for x in range(origin.x, origin.x + Generator.CHUNK_SIZE):
				for z in range(origin.y, origin.y + Generator.CHUNK_SIZE):
					if x <= preload("res://scripts/settlement/greece_landscape.gd").coast(z, world.world_seed):
						expected += 1
						if not world.ground.has(Vector3i(x, int(world.get("surface_edits", {}).get(Vector2i(x, z), 0)), z)): return false
		if world.ground.size() != expected: return false
	elif world.ground.size() != state.loaded.size() * Generator.CHUNK_SIZE * Generator.CHUNK_SIZE: return false
	for chunk: Vector2i in state.dormant:
		var record: Variant = state.dormant[chunk]
		if not record is Dictionary: return false
		if not Vines.valid(record.get("vines", {})): return false
		for cell: Vector3i in record.get("vines", {}):
			if chunk_for(cell) != chunk: return false
		var berry_time: Variant = record.get("berry_time", world.get("time", 0.0))
		if not (berry_time is int or berry_time is float) or not is_finite(float(berry_time)) or berry_time < 0 or berry_time > world.get("time", 0.0): return false
		for field in FIELDS:
			if not record.get(field) is Dictionary: return false
			for cell: Variant in record[field]:
				var value: Variant = record[field][cell]
				if not cell is Vector3i or chunk_for(cell) != chunk or not Catalog.in_bounds(cell) or cell.y > Generator.MAX_HEIGHT or not value is Dictionary: return false
				var kinds := ["living", "dead", "palm"] if field == "trees" else (["berry", "limestone"] if field == "deposits" else ["stream", "puddle"])
				if value.get("kind") not in kinds or not Planting.valid_growth(value): return false
				if field == "trees" and float(value.get("seed_growth", 1.0)) < 1.0 and value.get("amount") != 0: return false
				var resource := "water" if field == "water_sources" else ("log" if field == "trees" else ("food" if value.kind == "berry" else "stone"))
				var capacity := 3 if field == "trees" else (int(value.get("capacity", 0)) if field == "deposits" else (3 if value.kind == "puddle" else 2))
				# Preserve older eight-berry inventories as well as new growth stages.
				if field == "deposits" and value.kind == "berry" and capacity not in [1, 2, 3, 8]: return false
				# Keep both current small stone deposits and legacy saved stock.
				if field == "deposits" and value.kind == "limestone" and not Economy.StoneVolume.valid_saved_capacity(cell, world.world_seed, capacity): return false
				if value.get("resource") != resource or value.get("capacity") != capacity or not value.get("amount") is int or value.amount < 0 or value.amount > capacity: return false
				if not (value.get("regrowth") is float or value.get("regrowth") is int) or not is_finite(float(value.regrowth)) or value.regrowth < 0: return false
	return true
