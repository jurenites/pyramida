extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Chunks = preload("res://scripts/settlement/chunk_stream.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	test_generation()
	test_persistence()
	test_stone_capacity_compatibility()
	test_incremental_navigation()
	for message in failures: printerr("FAIL: " + message)
	if failures.is_empty(): print("PASS: %d chunk seams, vegetation, persistence and residency checks" % checks)
	quit(int(not failures.is_empty()))

func test_stone_capacity_compatibility() -> void:
	var cell := Vector3i(80, 0, 80)
	var record := {"trees": {}, "water_sources": {}, "deposits": {
		cell: {"kind": "limestone", "resource": "stone", "capacity": 6, "amount": 6, "regrowth": 0.0}}}
	var state := {"enabled": true, "loaded": {}, "dormant": {Chunks.chunk_for(cell): record}}
	var world := {"generator_version": Generator.VERSION, "ground": {}, "time": 0.0, "world_seed": 1409}
	var old_capacity := Model.Economy.StoneVolume.sections(cell, 1409).size() * 64
	for capacity in [6, 30, Model.Economy.StoneVolume.capacity(cell, 1409), old_capacity, old_capacity * 2, old_capacity * 8, Model.Economy.StoneVolume.legacy_capacity(cell, 1409)]:
		record.deposits[cell].capacity = capacity
		record.deposits[cell].amount = capacity
		check(Chunks.valid_state(state, world), "Current and legacy stone capacities survive dormant saves")
	record.deposits[cell].capacity = 7
	record.deposits[cell].amount = 7
	check(not Chunks.valid_state(state, world), "Unknown dormant stone capacities remain invalid")

func test_generation() -> void:
	check(Generator.chunk_at(Vector2i(-1, -17)) == Vector2i(-1, -2), "Negative coordinates floor into the correct chunk")
	for difficulty in ["normal", "easy"]:
		var nature: Dictionary = Generator.generate_region(1409, Generator.INITIAL_BOUNDS, 0, difficulty).nature
		var close_pairs := 0
		for cell: Vector3i in nature:
			if nature[cell] not in ["tree", "dead_tree"]: continue
			for offset in [Vector3i(1, 0, 1), Vector3i(1, 0, -1)]:
				if nature.get(cell + offset) in ["tree", "dead_tree"]: close_pairs += 1
		check(close_pairs > 0, "%s generation allows closer diagonal tree clusters" % difficulty)
	for difficulty in ["normal", "easy"]:
		for seed_value in [1409, 9182, 773]:
			var forest_nature: Dictionary = Generator.generate_region(seed_value, Generator.INITIAL_BOUNDS, 0, difficulty).nature
			var tree_count := 0
			var dead_count := 0
			var packed_count := 0
			for tree_cell: Vector3i in forest_nature:
				if forest_nature[tree_cell] not in ["tree", "dead_tree"]: continue
				tree_count += 1
				if forest_nature[tree_cell] == "dead_tree": dead_count += 1
				for nearby_cell in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]:
					if forest_nature.get(tree_cell + nearby_cell) in ["tree", "dead_tree"]:
						packed_count += 1
						break
			check(tree_count > 100 and packed_count > tree_count * 0.5, "%s trees mostly grow in tightly packed stands" % difficulty)
			check(dead_count > tree_count * 0.15, "%s forests contain plentiful dead trees" % difficulty)
	for seed_value in [1409, 9182, 773]:
		for corner in [Vector2i(-1, -1), Vector2i(7, -9)]:
			var bounds := Rect2i(corner * Generator.CHUNK_SIZE, Vector2i.ONE * Generator.CHUNK_SIZE * 2)
			var whole := Generator.generate_region(seed_value, bounds)
			var merged := {"ground": {}, "shapes": {}, "nature": {}, "water": {}, "grass": {}}
			for offset in [Vector2i.ONE, Vector2i.ZERO, Vector2i.DOWN, Vector2i.RIGHT]:
				var chunk := Generator.generate_chunk(seed_value, corner + offset)
				for field in merged: merged[field].merge(chunk[field])
				for column: Vector2i in chunk.border:
					if whole.heights.has(column):
						check(chunk.border[column] == whole.heights[column], "Neighbour halo matches global terrain")
			for field in merged:
				check(merged[field] == whole[field], "Chunk traversal order preserves " + field)
			for cell: Vector3i in whole.nature:
				check(not whole.shapes.has(cell) and not whole.water.has(cell) and whole.ground.has(cell), "Resources rest on dry flat ground")
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						if dx == 0 and dz == 0: continue
						var neighbour := cell + Vector3i(dx, 0, dz)
						# Bushes can touch; trees can share neighbouring cells, while rocks keep clearance.
						var touching_bushes: bool = whole.nature[cell] == "berry" and whole.nature.get(neighbour) == "berry"
						var close_trees: bool = whole.nature[cell] in ["tree", "dead_tree"] and whole.nature.get(neighbour) in ["tree", "dead_tree"]
						check(touching_bushes or close_trees or not whole.nature.has(neighbour), "Resource spacing crosses chunk edges")
			for cell: Vector3i in whole.grass:
				check(not whole.shapes.has(cell) and not whole.water.has(cell) and not whole.nature.has(cell), "Grass shares terrain exclusions with resources")
	var a := Generator.generate_chunk(1409, Vector2i(20, 20))
	var b := Generator.generate_chunk(9182, Vector2i(20, 20))
	check(a.nature != b.nature or a.grass != b.grass, "Vegetation changes with the world seed")

func test_persistence() -> void:
	var world = Model.new()
	world.setup()
	var initial_count: int = world.loaded_chunks.size()
	var remote := Vector2i(12, -11)
	Chunks.load_chunk(world, remote)
	world.terrain_revision += 1
	world.rebuild_navigation()
	var generated := Generator.generate_chunk(world.world_seed, remote)
	var resource_cell := Vector3i.ZERO
	var resource_field := ""
	for field in ["trees", "deposits", "water_sources"]:
		for cell: Vector3i in world.get(field):
			if Chunks.chunk_for(cell) == remote:
				resource_cell = cell
				resource_field = field
				break
		if not resource_field.is_empty(): break
	check(not resource_field.is_empty(), "Remote fixture has a physical resource")
	if resource_field.is_empty(): return
	var resource: Dictionary = world.get(resource_field)[resource_cell]
	resource.inventory.amounts.clear()
	# Keep one harvestable log for the inventory-reservation checks below.
	var remaining := 1 if resource_field == "trees" else 0
	if remaining: resource.inventory.store("log", remaining)
	resource.regrowth = 12.5
	var preserved_kind: String = resource.kind
	Chunks.update(world, Vector3.ZERO, 2, 0)
	check(not world.loaded_chunks.has(remote) and world.dormant_chunks.has(remote), "Distant inactive chunks unload")
	check(not world.ground.has(resource_cell) and not world.get(resource_field).has(resource_cell), "Unloaded chunks release terrain and live inventories")
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Streamed world saves and restores")
	check(restored.dormant_chunks.keys() == world.dormant_chunks.keys() and restored.loaded_chunks == world.loaded_chunks, "Loaded and dormant chunk ownership persists")
	Chunks.load_chunk(restored, remote)
	var returned: Dictionary = restored.get(resource_field)[resource_cell]
	check(returned.inventory.total() == remaining and returned.regrowth == 12.5 and returned.kind == preserved_kind, "Reloading never rerolls or refills harvested resources")
	for cell: Vector3i in generated.ground:
		check(restored.ground.has(cell), "Regenerated dormant terrain matches its saved generator")
	for cell: Vector3i in generated.shapes:
		check(restored.terrain_shapes.get(cell) == generated.shapes[cell], "Talus corner shapes survive unloading")
	# A live reservation must retain inventory object identity while camera moves.
	var item: String = "water" if resource_field == "water_sources" else ("log" if resource_field == "trees" else ("food" if returned.kind == "berry" else "stone"))
	returned.inventory.store(item)
	returned.inventory.reserve(0, item)
	var inventory = returned.inventory
	Chunks.update(restored, Vector3.ZERO, 2, 0)
	check(restored.loaded_chunks.has(remote) and restored.get(resource_field)[resource_cell].inventory == inventory, "Reservations pin the exact live inventory")
	inventory.release(0)
	restored.workers[0].route = [resource_cell]
	Chunks.update(restored, Vector3.ZERO, 2, 0)
	check(restored.loaded_chunks.has(remote), "Citizen routes pin their destination chunks")
	restored.workers[0].route = []
	var build_cell: Vector3i = generated.ground.keys()[0]
	restored.platforms[build_cell + Vector3i.UP] = true
	Chunks.update(restored, Vector3.ZERO, 2, 0)
	check(restored.loaded_chunks.has(remote), "Construction keeps its supporting terrain loaded")
	restored.platforms.clear()
	for index in 12:
		var focus := Vector3(300 + index * 100, 0, -300)
		Chunks.update(restored, focus, 1, 1)
	check(restored.loaded_chunks.size() <= initial_count + 8, "Exploration does not accumulate live chunks indefinitely")
	var stable: Dictionary = restored.snapshot()
	var corrupt: Dictionary = stable.duplicate(true)
	for pair: Array in corrupt.world.v:
		if pair[0] == "streaming": pair[1] = null
	check(not restored.restore(corrupt) and restored.snapshot() == stable, "Invalid streaming metadata is rejected atomically")
	var legacy := stable.duplicate(true)
	legacy.world.v = legacy.world.v.filter(func(pair): return pair[0] != "streaming")
	var old = Model.new()
	check(old.restore(legacy) and not old.streaming_enabled, "Existing worlds without streaming metadata retain their saved terrain")

func test_incremental_navigation() -> void:
	var nav = Nav.new()
	var surfaces := {}
	for x in range(-5, 6):
		for z in range(-5, 6): surfaces[Vector3i(x, 0, z)] = true
	surfaces[Vector3i(2, 1, 0)] = true
	var stairs := {Vector3i.ZERO: 0}
	var ramps := {Vector3i(3, 0, 0): Vector3i(2, 1, 0)}
	nav.rebuild(surfaces, stairs, ramps)
	check(not nav.route(Vector3i(-2, 0, 0), Vector3i(2, 1, 0)).is_empty(), "Incremental fixture includes a full-room ladder")
	var added := {}
	for x in range(6, 12):
		for z in range(-5, 6): added[Vector3i(x, 0, z)] = true
	var removed := {Vector3i(4, 0, 2): true, Vector3i(5, 0, 2): true, Vector3i(5, 0, 3): true}
	nav.update_ground(added, removed)
	surfaces.merge(added)
	for cell in removed: surfaces.erase(cell)
	var reference = Nav.new()
	reference.rebuild(surfaces, stairs, ramps)
	check(nav.surfaces == reference.surfaces, "Incremental topology owns the same surfaces as a rebuild")
	for cell: Vector3i in reference.edges:
		check(nav.edges[cell] == reference.edges[cell], "Incremental cardinal, diagonal and connector edges match a full rebuild")
	check(nav.route(Vector3i(-2, 0, 0), Vector3i(10, 0, 0)) == reference.route(Vector3i(-2, 0, 0), Vector3i(10, 0, 0)), "New chunk invalidates stale route caches with deterministic path order")
