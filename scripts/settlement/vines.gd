extends RefCounted
## Saved growth follows exposed room faces on the quarter-room terrain grid.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
const Sides = preload("res://scripts/settlement/house_groups.gd")
const Random = preload("res://scripts/deterministic_random.gd")
const WATER_CAPACITY := 180.0
const GROW_SECONDS := 9.0
const MAX_NODES := 96
const REACH := 6
const START_RADIUS := 1.5
const RADIUS_STEP := 0.18
const TIPS_PER_PULSE := 3

static func create() -> Dictionary:
	return {"water": WATER_CAPACITY, "health": 1.0, "growth": 0.0, "radius": START_RADIUS, "nodes": [], "parents": []}

static func surfaces(world, root: Vector3i) -> Dictionary:
	var result := {}
	for cell: Vector3i in world.buildings:
		var building: Dictionary = world.buildings[cell]
		# Solid timber/earth walls support vines; open machinery does not.
		if building.kind not in Catalog.NATURAL_ROOFS or absi(cell.x - root.x) > REACH or absi(cell.z - root.z) > REACH: continue
		var base := Vector3i(cell.x, cell.y, cell.z)
		var offset: Vector3 = building.get("placement_offset", Vector3.ZERO)
		for side in 4:
			var normal: Vector3i = Sides.SIDES[side]
			var tangent := Vector3i(normal.z, 0, -normal.x)
			# Do not grow on the shared wall between adjoining rooms.
			if world.buildings.get(cell + normal * 2, {}).get("kind") in Catalog.NATURAL_ROOFS: continue
			for u in range(-1, 2):
				for h in 3:
					# Leave the actual entrance open, including foliage clearance.
					if side == int(building.direction) and u == 0 and h < 2: continue
					var key := base + normal + tangent * u + Vector3i.UP * h
					if key.y < root.y or key.y > root.y + REACH: continue
					var point := Vector3(key) * Grid.CELL_SIZE + offset + Vector3(normal) * 0.065
					if not result.has(key): result[key] = {"point": point, "normal": Vector3(normal), "normals": []}
					if Vector3(normal) not in result[key].normals: result[key].normals.append(Vector3(normal))
	return result

static func directions() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var step := Vector3i(x, y, z)
				if step.length_squared() in [1, 2]: result.append(step)
	return result

static func connected(faces: Dictionary, a: Vector3i, b: Vector3i) -> bool:
	if not faces.has(a) or not faces.has(b): return false
	var step := b - a
	var length := step.length_squared()
	if length not in [1, 2]: return false
	if faces[a].point.distance_to(faces[b].point) > sqrt(float(length)) + 0.4: return false
	if length == 1: return true
	# A diagonal needs a continuous wall square. Never cut across an entrance,
	# missing wall or the empty space between two perpendicular faces.
	for normal: Vector3 in faces[a].get("normals", [faces[a].normal]):
		if normal not in faces[b].get("normals", [faces[b].normal]) or absf(normal.dot(Vector3(step))) > 0.01: continue
		var supported := true
		for axis: Vector3i in [Vector3i(step.x, 0, 0), Vector3i(0, step.y, 0), Vector3i(0, 0, step.z)]:
			if axis == Vector3i.ZERO: continue
			var corner := a + axis
			if not faces.has(corner) or normal not in faces[corner].get("normals", [faces[corner].normal]):
				supported = false
		if supported: return true
	return false

static func first_node(world, root: Vector3i, faces: Dictionary, offset := Vector3.ZERO) -> Variant:
	var nearest: Variant = null
	var distance := 1.65
	for key: Vector3i in faces:
		if key.y != root.y: continue
		var candidate: float = faces[key].point.distance_to(Nav.point(root) + offset)
		if candidate < distance:
			distance = candidate
			nearest = key
	return nearest

static func placement_error(world, root: Vector3i, offset := Vector3.ZERO, ignored_plan_id := -1) -> String:
	if not world.ground.has(root) or world.terrain_shapes.has(root): return "Choose level ground"
	if world.vines.has(root): return "This space is occupied"
	if world.Farming.occupied(world, "seed_vine", root, offset): return "This space is occupied"
	for plan: Dictionary in world.plans.values():
		if plan.id == ignored_plan_id or world.Deconstruction.is_salvage(plan): continue
		if (plan.kind == "seed_vine" and plan.cell == root) or world.Farming.overlaps("seed_vine", root, plan.kind, plan.cell, offset, plan.get("placement_offset", Vector3.ZERO)):
			return "Already planned"
	return ""

static func request_collect(world, cell: Vector3i) -> bool:
	if not world.vines.has(cell) or world.vines[cell].health <= 0 or world.Relocation.locked(world, cell): return false
	if not world.exploration.contains(Nav.point(cell)): return false
	var id: int = world.next_plan_id
	world.next_plan_id += 1
	world.plans[id] = {"id": id, "kind": "vine_tree", "cell": cell, "direction": 0,
		"installed": 0, "required": 0, "reserved": 0, "materials": {}, "used": {}, "claims": {},
		"collect_vine": true, "relocation": {"source": cell, "pickup_cell": cell,
		"stage": "dismantle", "parts": world.Inventory.new(), "payload": {}, "owner": -1,
		"labour": world.Jobs.Labour.new(3.0)}}
	world.revision += 1
	return true

static func finish_collect(world, worker: Dictionary, plan: Dictionary) -> void:
	world.vines.erase(plan.cell)
	world.vine_roots += 1
	world.vine_discovered = true
	world.plans.erase(plan.id)
	for citizen: Dictionary in world.workers:
		if citizen.get("assigned_plan_id", -1) == plan.id: citizen.assigned_plan_id = -1
	worker.job = {}
	world.revision += 1

static func water(plant: Dictionary, amount: float) -> void:
	plant.water = clampf(float(plant.water) + maxf(0.0, amount), 0.0, WATER_CAPACITY)

static func prune(plant: Dictionary, faces: Dictionary) -> bool:
	var kept: Array = []
	var parents: Array = []
	var indices := {}
	for i in plant.nodes.size():
		var parent: int = plant.parents[i]
		if not faces.has(plant.nodes[i]) or (parent >= 0 and (not indices.has(parent) or not connected(faces, plant.nodes[parent], plant.nodes[i]))): continue
		indices[i] = kept.size()
		kept.append(plant.nodes[i])
		parents.append(indices.get(parent, -1))
	var changed: bool = kept.size() != plant.nodes.size()
	plant.nodes = kept
	plant.parents = parents
	return changed

static func grow(world, root: Vector3i, plant: Dictionary, faces: Dictionary) -> bool:
	if plant.nodes.size() >= MAX_NODES: return false
	if plant.nodes.is_empty():
		var first: Variant = first_node(world, root, faces, plant.get("placement_offset", Vector3.ZERO))
		if first == null: return false
		plant.nodes.append(first)
		plant.parents.append(-1)
		return true
	var steps := directions()
	var radius := float(plant.get("radius", REACH))
	var origin := Vector3(root.x, root.y, root.z) + Vector3(plant.get("placement_offset", Vector3.ZERO))
	var candidates := {}
	var children := {}
	var occupied := {}
	for node: Vector3i in plant.nodes: occupied[node] = true
	for parent: int in plant.parents:
		children[parent] = int(children.get(parent, 0)) + 1
	# Advance several competing tips from the same frontier. An expanding wet
	# radius and a stable habitat field produce a branching, uneven radial fan.
	for i in plant.nodes.size():
		var current: Vector3i = plant.nodes[i]
		for direction: Vector3i in steps:
			var next := current + direction
			if occupied.has(next) or Vector3(next).distance_to(origin) > radius or not connected(faces, current, next): continue
			var neighbours := 0
			for step: Vector3i in steps:
				if occupied.has(next + step): neighbours += 1
			var outward := (Vector3(next) - origin).normalized().dot(Vector3(direction).normalized())
			var habitat := Random.world_fraction(next.x, next.z, world.world_seed, 831 + next.y * 31)
			var continuation := 0.0
			if plant.parents[i] >= 0:
				continuation = Vector3(current - plant.nodes[plant.parents[i]]).normalized().dot(Vector3(direction).normalized())
			var score := habitat * 0.7 + outward * 0.55 + continuation * 0.25 - neighbours * 0.16 - int(children.get(i, 0)) * 0.2
			if not candidates.has(next) or score > candidates[next].score:
				candidates[next] = {"node": next, "parent": i, "score": score}
	var frontier: Array = candidates.values()
	frontier.sort_custom(func(a, b):
		if a.score != b.score: return a.score > b.score
		if a.node.x != b.node.x: return a.node.x < b.node.x
		if a.node.y != b.node.y: return a.node.y < b.node.y
		return a.node.z < b.node.z)
	var used_tips := {}
	var added := 0
	for tip: Dictionary in frontier:
		if used_tips.has(tip.parent): continue
		plant.nodes.append(tip.node)
		plant.parents.append(tip.parent)
		used_tips[tip.parent] = true
		added += 1
		if added >= TIPS_PER_PULSE or plant.nodes.size() >= MAX_NODES: break
	return added > 0

static func tick_second(world) -> void:
	for root: Vector3i in world.vines:
		var plant: Dictionary = world.vines[root]
		if world.Relocation.locked(world, root): continue
		var before := int(float(plant.health) * 12.0)
		# Rain reaches the roots and wall runoff; no citizen tending needed yet.
		if world.weather.raining: water(plant, 16.0)
		else: plant.water = maxf(0.0, float(plant.water) - 1.0)
		if plant.water <= 0.0: plant.health = maxf(0.0, float(plant.health) - 1.0 / 90.0)
		elif plant.health > 0.0: plant.health = minf(1.0, float(plant.health) + 1.0 / 60.0)
		var changed := before != int(float(plant.health) * 12.0)
		plant.growth += 1.0
		if plant.growth >= GROW_SECONDS:
			plant.growth = 0.0
			var faces := surfaces(world, root)
			changed = prune(plant, faces) or changed
			if plant.health > 0.45 and plant.water > 0.0:
				plant.radius = minf(REACH, float(plant.get("radius", REACH)) + RADIUS_STEP)
				changed = grow(world, root, plant, faces) or changed
		if changed: world.revision += 1

static func valid(plants: Variant, height_scale := 1) -> bool:
	if not plants is Dictionary: return false
	for root: Variant in plants:
		if not root is Vector3i or not Catalog.in_bounds(root): return false
		var plant: Variant = plants[root]
		if not plant is Dictionary: return false
		if not Catalog.valid_placement_offset("seed_vine", plant.get("placement_offset", Vector3.ZERO)): return false
		if not plant.get("wild", false) is bool: return false
		var radius: Variant = plant.get("radius", REACH)
		if not (radius is float or radius is int) or not is_finite(float(radius)) or radius < START_RADIUS or radius > REACH: return false
		for key in ["water", "health", "growth"]:
			if not (plant.get(key) is float or plant.get(key) is int) or not is_finite(float(plant[key])): return false
		if plant.water < 0 or plant.water > WATER_CAPACITY or plant.health < 0 or plant.health > 1 or plant.growth < 0 or plant.growth >= GROW_SECONDS: return false
		if not plant.get("nodes") is Array or not plant.get("parents") is Array or plant.nodes.size() != plant.parents.size() or plant.nodes.size() > MAX_NODES: return false
		var seen := {}
		for i in plant.nodes.size():
			var node: Variant = plant.nodes[i]
			var parent: Variant = plant.parents[i]
			if not node is Vector3i or seen.has(node) or not parent is int or parent < -1 or parent >= i: return false
			if (i == 0) != (parent == -1): return false
			if absi(node.x - root.x) > REACH + 1 or absi(node.z - root.z) > REACH + 1 or node.y < root.y * height_scale or node.y > root.y * height_scale + REACH: return false
			if parent >= 0 and (node - plant.nodes[parent]).length_squared() not in [1, 2]: return false
			seen[node] = true
	return true
