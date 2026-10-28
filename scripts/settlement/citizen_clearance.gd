extends RefCounted
## Soft occupancy: passing residents may overlap, but resting places are exclusive.
const MIN_SPACING := 0.65
const SEARCH_LIMIT := 128

static func _destination(worker: Dictionary) -> Vector3i:
	if worker.has("clearance_route"): return worker.clearance_route.back()
	if worker.route_index < worker.route.size(): return worker.route.back()
	return worker.cell

static func _free(world, worker: Dictionary, cell: Vector3i) -> bool:
	for other: Dictionary in world.workers:
		if other.id == worker.id: continue
		if _destination(other) == cell: return false
		if world.navigation.surface_point(cell).distance_to(other.position) < MIN_SPACING: return false
	return true

static func _crowded(world, worker: Dictionary) -> bool:
	for other: Dictionary in world.workers:
		if other.id == worker.id: continue
		# The lower id keeps its place when a save/spawn starts with a stack.
		if other.id < worker.id and worker.position.distance_to(other.position) < MIN_SPACING: return true
		# Step aside for an incoming resident; do not block a narrow passage.
		if _destination(other) == worker.cell and other.route_index < other.route.size(): return true
	return false

static func _vacant_route(world, worker: Dictionary) -> Array[Vector3i]:
	var queue: Array[Vector3i] = [worker.cell]
	var previous := {worker.cell: worker.cell}
	var index := 0
	while index < queue.size() and index < SEARCH_LIMIT:
		var cell := queue[index]
		index += 1
		if cell != worker.cell and _free(world, worker, cell):
			var result: Array[Vector3i] = [cell]
			while cell != worker.cell:
				cell = previous[cell]
				result.push_front(cell)
			return result
		for next: Vector3i in world.navigation.edges.get(cell, []):
			if previous.has(next): continue
			previous[next] = cell
			queue.append(next)
	return []

static func arrival_route(world, worker: Dictionary, route: Array) -> Array:
	# Reserve distinct perimeter arrivals, without blocking passing traffic.
	if route.is_empty() or worker.job.get("phase") == "pickup" or not worker.job.has("target"):
		return route.duplicate()
	if not world.navigation.at_access(route.back(), worker.job.target) or _free(world, worker, route.back()):
		return route.duplicate()
	var best: Array[Vector3i] = []
	var distance := INF
	for cell in world.navigation.access_cells(worker.job.target):
		if not _free(world, worker, cell): continue
		var candidate: Array[Vector3i] = world.navigation.route(worker.cell, cell)
		if not candidate.is_empty() and world.navigation.distance(candidate) < distance:
			best = candidate
			distance = world.navigation.distance(candidate)
	return best if not best.is_empty() else route.duplicate()

static func tick(world, worker: Dictionary, delta: float) -> bool:
	if not worker.has("clearance_route"):
		var route: Array[Vector3i] = []
		if world.navigation.blocked.has(worker.cell):
			route = world.navigation.escape_route(worker.cell)
		elif worker.route_index >= worker.route.size() and (worker.job.is_empty() or worker.has("retry_at")) and _crowded(world, worker):
			route = _vacant_route(world, worker)
		if route.size() < 2: return false
		worker.clearance_route = route
		worker.clearance_index = 1
	var next: Vector3i = worker.clearance_route[worker.clearance_index]
	if not world.navigation.edges.get(worker.cell, []).has(next) and not (world.navigation.blocked.has(worker.cell) and world.navigation._touching(worker.cell, next, true)):
		worker.erase("clearance_route")
		worker.erase("clearance_index")
		return true
	var old: Vector3 = worker.position
	var speed := 2.25 if world.Citizens.is_adult(worker) else 1.2
	worker.position = old.move_toward(world.navigation.movement_target(worker.cell, next, old), delta * speed)
	if worker.cell.y == next.y:
		worker.position = world.navigation.ground_position(worker.position, worker.cell.y)
	worker.distance += old.distance_to(worker.position)
	if worker.position.distance_to(world.navigation.surface_point(next)) < 0.001:
		worker.cell = next
		worker.clearance_index += 1
		if worker.clearance_index >= worker.clearance_route.size():
			if worker.route_index < worker.route.size():
				var resumed: Array[Vector3i] = world.navigation.route(worker.cell, worker.route.back())
				if not resumed.is_empty():
					worker.route = resumed
					worker.route_index = 1
			worker.erase("clearance_route")
			worker.erase("clearance_index")
	return true
