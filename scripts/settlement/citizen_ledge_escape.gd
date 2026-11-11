extends RefCounted
## Local recovery only: ordinary travel still uses stairs, slopes and bridges.
const MAX_RISE := 2.0
const SEARCH_LIMIT := 256
const Routes = preload("res://scripts/settlement/room_navigation.gd")

static func valid(worker: Dictionary) -> bool:
	if not worker.has("rescue_route"): return not worker.has("rescue_index") and not worker.has("rescue_paths")
	if not worker.rescue_route is Array or not worker.get("rescue_index") is int or not worker.get("rescue_paths") is Dictionary: return false
	if worker.rescue_route.size() > SEARCH_LIMIT or worker.rescue_index < 1 or worker.rescue_index >= worker.rescue_route.size(): return false
	for cell: Variant in worker.rescue_route:
		if not cell is Vector3i: return false
	for cell: Variant in worker.rescue_paths:
		if not cell is Vector3i or not worker.rescue_paths[cell] is Dictionary: return false
		for next: Variant in worker.rescue_paths[cell]:
			var path: Variant = worker.rescue_paths[cell][next]
			if not next is Vector3i or not path is Array or path.size() != 4: return false
			for point: Variant in path:
				if not point is Vector3 or not point.is_finite(): return false
	return true

static func safe_component(world, worker: Dictionary) -> int:
	var nav = world.navigation
	if worker.has("home_cell"):
		for access in nav.access_cells(worker.home_cell):
			if nav.walkable(access): return nav._component_root(access)
	var biggest := -1
	var count := 0
	for id in nav._component_sizes:
		if nav._component_parents[id] == id and nav._component_sizes[id] > count:
			biggest = id; count = nav._component_sizes[id]
	return biggest

static func body_clear(world, feet: Vector3) -> bool:
	# Sample actual height, including natural slopes, rather than the y grid alone.
	var surface: Vector3i = world.surface_at(roundi(feet.x), roundi(feet.z))
	if world.ground.has(surface) and world.navigation.surface_height(surface, feet) > feet.y + 0.08: return false
	for cell: Vector3i in world.buildings:
		var building: Dictionary = world.buildings[cell]
		var kind: String = building.kind
		if kind in ["road", "hay_field"]: continue
		var box: Rect2 = world.Farming.footprint(kind, cell, building.get("placement_offset", Vector3.ZERO), int(building.direction))
		if not box.grow(0.12).has_point(Vector2(feet.x, feet.z)): continue
		var top: float = float(cell.y) + world.Catalog.building_height(kind)
		if feet.y >= top - 0.04 or feet.y + 1.4 <= cell.y: continue
		if kind == "support":
			if world.StructureLayout.has_deck(world, cell) and feet.y < cell.y + 0.98 and feet.y + 1.4 > cell.y + 0.9: return false
			continue
		return false
	for cell: Vector3i in world.platforms:
		if absf(feet.x - cell.x) < 1.0 and absf(feet.z - cell.z) < 1.0 and feet.y < cell.y - 0.04 and feet.y + 1.4 > cell.y - 0.12: return false
	for y in range(floori(feet.y) - 2, ceili(feet.y + 1.4)):
		var cell := Vector3i(roundi(feet.x), y, roundi(feet.z))
		if (world.trees.has(cell) or world.deposits.has(cell)) and Vector2(feet.x - cell.x, feet.z - cell.z).length() < 0.4 and feet.y < cell.y + 2.0 and feet.y + 1.4 > cell.y: return false
	return true

static func path_clear(world, path: Array) -> bool:
	for i in range(1, path.size()):
		var steps := maxi(1, ceili(path[i - 1].distance_to(path[i]) / 0.15))
		for step in range(steps + 1):
			if not body_clear(world, path[i - 1].lerp(path[i], float(step) / steps)): return false
	return true

static func climb_path(world, a: Vector3i, b: Vector3i) -> Array:
	var nav = world.navigation
	if not nav.walkable(b) or absi(a.x - b.x) + absi(a.z - b.z) != 1: return []
	var start: Vector3 = nav.surface_point(a); var end: Vector3 = nav.surface_point(b)
	var rise := absf(start.y - end.y)
	if rise < 0.15 or rise > MAX_RISE + 0.001: return []
	var low: Vector3 = start if start.y < end.y else end
	var high: Vector3 = end if start.y < end.y else start
	var along := Vector3(high.x - low.x, 0, high.z - low.z).normalized()
	# Stay outside the upper cell's wall until the feet clear its lip.
	var outside := Vector3(high.x, low.y, high.z) - along * 0.72
	var path: Array = [low, outside, Vector3(outside.x, high.y + 0.05, outside.z), high]
	if start.y > end.y: path.reverse()
	return path if path_clear(world, path) else []

static func find_route(world, worker: Dictionary) -> Dictionary:
	var nav = world.navigation
	var refuge := safe_component(world, worker)
	if refuge < 0: return {}
	if nav.walkable(worker.cell) and nav._component_root(worker.cell) == refuge: return {}
	var queue: Array[Vector3i] = [worker.cell]
	var previous := {worker.cell: worker.cell}; var paths := {}; var index := 0
	while index < queue.size() and index < SEARCH_LIMIT:
		var cell := queue[index]; index += 1
		if cell != worker.cell and nav.walkable(cell) and nav._component_root(cell) == refuge:
			var route: Array[Vector3i] = [cell]
			while cell != worker.cell:
				cell = previous[cell]; route.push_front(cell)
			return {"route": route, "paths": paths}
		var next_cells: Array = nav.edges.get(cell, []).duplicate()
		for direction: Vector3i in world.DIRECTIONS:
			for height in [-2, -1, 1, 2]:
				var next: Vector3i = cell + direction + Vector3i.UP * height
				if previous.has(next): continue
				var path := climb_path(world, cell, next)
				if path.is_empty(): continue
				if not paths.has(cell): paths[cell] = {}
				paths[cell][next] = path
				next_cells.append(next)
		for next: Vector3i in next_cells:
			if previous.has(next): continue
			previous[next] = cell; queue.append(next)
	return {}

static func clear(worker: Dictionary) -> void:
	for key in ["rescue_route", "rescue_index", "rescue_paths", "rescue_climbing"]: worker.erase(key)

static func tick(world, worker: Dictionary, delta: float) -> bool:
	if not worker.has("rescue_route"):
		var stamp := [world.navigation.revision, worker.cell]
		if world.ledge_escape_checks.get(worker.id, []) == stamp: return false
		world.ledge_escape_checks[worker.id] = stamp
		var found := find_route(world, worker)
		if found.is_empty(): return false
		worker.rescue_route = found.route; worker.rescue_paths = found.paths; worker.rescue_index = 1
	var next: Vector3i = worker.rescue_route[worker.rescue_index]
	var path: Array = worker.rescue_paths.get(worker.cell, {}).get(next, [])
	worker.rescue_climbing = not path.is_empty()
	if not path.is_empty():
		if not path_clear(world, path): clear(worker); return false
	elif not world.navigation.edges.get(worker.cell, []).has(next):
		clear(worker); return false
	if not world.RopeBridges.can_step(world, worker, next): return true
	var target: Vector3 = Routes.target(path, worker.position) if not path.is_empty() else world.navigation.movement_target(worker.cell, next, worker.position)
	var old: Vector3 = worker.position
	worker.position = old.move_toward(target, delta * (0.8 if worker.rescue_climbing else 2.0))
	worker.distance += old.distance_to(worker.position)
	if worker.position.distance_to(world.navigation.surface_point(next)) < 0.001:
		worker.cell = next; worker.rescue_index += 1
		if worker.rescue_index >= worker.rescue_route.size():
			clear(worker)
			worker.erase("clearance_route"); worker.erase("clearance_index")
			if not worker.job.is_empty() or worker.route_index < worker.route.size():
				var destination: Vector3i = worker.route.back() if not worker.route.is_empty() else worker.job.get("work_cell", worker.job.get("target", worker.cell))
				var resumed: Array = world.navigation.route(worker.cell, destination)
				worker.route = resumed; worker.route_index = 1 if not resumed.is_empty() else 0
				if resumed.is_empty() and not worker.job.is_empty(): world.Jobs._cancel_job(world, worker)
	return true
