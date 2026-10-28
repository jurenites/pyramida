extends RefCounted
## Explicit walkable surfaces. A floor above another floor has its own identity.
## Natural slopes follow their mesh; cliffs and built floors need explicit connectors.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const CELL_SIZE := Grid.CELL_SIZE
const ROOM_SIZE := Grid.ROOM_SIZE
const LEVEL_HEIGHT := Grid.LEVEL_HEIGHT
const DIRECTIONS := [Vector3i.RIGHT, Vector3i.BACK, Vector3i.LEFT, Vector3i.FORWARD]
const DIAGONALS := [Vector3i(1, 0, 1), Vector3i(1, 0, -1), Vector3i(-1, 0, 1), Vector3i(-1, 0, -1)]
var access_overrides: Dictionary = {}
var surfaces: Dictionary = {}
# Keep support surfaces separate from pedestrian clearance.
var blocked: Dictionary = {}
var edges: Dictionary = {}
var terrain_links: Dictionary = {}
var terrain_shapes: Dictionary = {}
var stair_links: Dictionary = {}
var roads: Dictionary = {}
var revision := 0
const MAX_CACHED_SOURCES := 32
var _searches: Dictionary = {}
var searches_built := 0
var nodes_expanded := 0
var _components: Dictionary = {}
var _component_parents: Dictionary = {}
var _component_sizes: Dictionary = {}
var _next_component := 0

static func point(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, cell.y * LEVEL_HEIGHT, cell.z * CELL_SIZE)

func rebuild(next_surfaces: Dictionary, stairs: Dictionary, terrain_ramps: Dictionary = {}, shapes: Dictionary = {}) -> void:
	surfaces = next_surfaces.duplicate()
	terrain_shapes = shapes.duplicate()
	terrain_links = terrain_ramps.duplicate()
	stair_links.clear()
	edges.clear()
	_searches.clear()
	for cell: Vector3i in surfaces:
		edges[cell] = _surface_neighbours(cell)
	# The ladder occupies B; its traversable edge connects A -> C through B.
	for cell: Vector3i in stairs:
		var direction: Vector3i = DIRECTIONS[int(stairs[cell])]
		var lower := cell - direction * Grid.CELLS_PER_ROOM
		var upper := stair_landing(cell, int(stairs[cell]))
		if walkable(cell) and walkable(lower) and walkable(upper):
			if not stair_links.has(lower):
				stair_links[lower] = {}
			stair_links[lower][upper] = cell
			edges[lower].append(upper)
			edges[upper].append(lower)
	for lower: Vector3i in terrain_ramps:
		var upper: Vector3i = terrain_ramps[lower]
		if walkable(lower) and walkable(upper) and not edges[lower].has(upper):
			edges[lower].append(upper)
			edges[upper].append(lower)
	_rebuild_components()
	revision += 1

func update_ground(added: Dictionary, removed: Dictionary, shapes: Dictionary = {}) -> void:
	# Streaming changes only natural ground. Built surfaces and all active
	# connectors are pinned by the model, so their identities stay untouched.
	terrain_shapes = shapes.duplicate()
	var affected := {}
	for cell: Vector3i in removed:
		surfaces.erase(cell)
		edges.erase(cell)
	for cell: Vector3i in added:
		surfaces[cell] = true
	for cells in [added, removed]:
		for cell: Vector3i in cells:
			affected[cell] = true
			for direction: Vector3i in DIRECTIONS + DIAGONALS:
				affected[cell + direction] = true
	for cell: Vector3i in affected:
		if not surfaces.has(cell): continue
		edges[cell] = _surface_neighbours(cell)
	for lower: Vector3i in stair_links:
		for upper: Vector3i in stair_links[lower]:
			_restore_edge(lower, upper)
	for lower: Vector3i in terrain_links:
		_restore_edge(lower, terrain_links[lower])
	_searches.clear()
	if not removed.is_empty():
		# Deletions can split a component; additions only need local unions.
		_rebuild_components()
	else:
		for cell: Vector3i in added:
			if not _components.has(cell):
				_components[cell] = _next_component
				_component_parents[_next_component] = _next_component
				_component_sizes[_next_component] = 1
				_next_component += 1
		for cell: Vector3i in affected:
			for neighbour: Vector3i in edges.get(cell, []):
				_join_components(cell, neighbour)
	revision += 1

func surface_height(cell: Vector3i, position: Vector3) -> float:
	if not terrain_shapes.has(cell): return cell.y * LEVEL_HEIGHT
	var h: Array = terrain_shapes[cell]
	var u := clampf(position.x / CELL_SIZE - cell.x + 0.5, 0.0, 1.0)
	var v := clampf(position.z / CELL_SIZE - cell.z + 0.5, 0.0, 1.0)
	if h.size() == 5:
		# Four triangles meet at the sampled centre, matching the soil mesh.
		if v <= u and v <= 1.0 - u: return h[0] * (1.0 - u - v) + h[1] * (u - v) + h[4] * 2.0 * v
		if u >= v and u >= 1.0 - v: return h[1] * (u - v) + h[2] * (u + v - 1.0) + h[4] * 2.0 * (1.0 - u)
		if v >= u and v >= 1.0 - u: return h[2] * (u + v - 1.0) + h[3] * (v - u) + h[4] * 2.0 * (1.0 - v)
		return h[3] * (v - u) + h[0] * (1.0 - u - v) + h[4] * 2.0 * u
	# Same diagonal and barycentric interpolation as terrain_mesh.gd's two triangles.
	if v <= u: return h[0] * (1.0 - u) + h[1] * (u - v) + h[2] * v
	return h[0] * (1.0 - v) + h[2] * u + h[3] * (v - u)

func surface_point(cell: Vector3i) -> Vector3:
	var result := point(cell)
	result.y = surface_height(cell, result)
	return result

func ground_position(position: Vector3, level: int) -> Vector3:
	var cell := Vector3i(roundi(position.x / CELL_SIZE), level, roundi(position.z / CELL_SIZE))
	if surfaces.has(cell): position.y = surface_height(cell, position)
	return position

func _touching(a: Vector3i, b: Vector3i, escaping := false) -> bool:
	if not escaping and (blocked.has(a) or blocked.has(b)): return false
	if not surfaces.has(a) or not surfaces.has(b): return false
	if not terrain_shapes.has(a) and not terrain_shapes.has(b): return true
	var middle := (point(a) + point(b)) * 0.5
	var across := Vector3(b.z - a.z, 0, a.x - b.x) * CELL_SIZE * 0.5
	for sample in [middle - across, middle + across]:
		if absf(surface_height(a, sample) - surface_height(b, sample)) > 0.001: return false
	return true

func _surface_neighbours(cell: Vector3i) -> Array:
	var result: Array = []
	for direction: Vector3i in DIRECTIONS:
		if _touching(cell, cell + direction): result.append(cell + direction)
	for direction: Vector3i in DIAGONALS:
		var side_x := cell + Vector3i(direction.x, 0, 0)
		var side_z := cell + Vector3i(0, 0, direction.z)
		var next := cell + direction
		# All four edges must meet; diagonals never cut across gaps or cliffs.
		# The two edges from this cell were already checked above. Reuse them
		# while integrating terrain instead of resampling their slopes twice.
		if result.has(side_x) and result.has(side_z) and _touching(side_x, next) and _touching(side_z, next):
			result.append(next)
	return result

func slope_waypoints(current: Vector3i, next: Vector3i, position: Vector3) -> Array[Vector3]:
	var start := surface_point(current)
	var finish := surface_point(next)
	var middle := (start + finish) * 0.5
	middle.y = surface_height(current, middle)
	var direction := Vector3(finish.x - start.x, 0, finish.z - start.z)
	var result: Array[Vector3] = []
	if (position - start).dot(direction) < direction.length_squared() * 0.5 - 0.001:
		result.append(middle)
	result.append(finish)
	return result

func _rebuild_components() -> void:
	_components.clear()
	_component_parents.clear()
	_component_sizes.clear()
	_next_component = 0
	for start: Vector3i in surfaces:
		if _components.has(start): continue
		var id := _next_component
		_next_component += 1
		_component_parents[id] = id
		_components[start] = id
		var queue: Array[Vector3i] = [start]
		var index := 0
		while index < queue.size():
			var current := queue[index]
			index += 1
			for neighbour: Vector3i in edges[current]:
				if not _components.has(neighbour):
					_components[neighbour] = id
					queue.append(neighbour)
		_component_sizes[id] = queue.size()

func _component_root(cell: Vector3i) -> int:
	var id: int = _components[cell]
	while _component_parents[id] != id:
		_component_parents[id] = _component_parents[_component_parents[id]]
		id = _component_parents[id]
	_components[cell] = id
	return id

func _join_components(a: Vector3i, b: Vector3i) -> void:
	var root_a := _component_root(a)
	var root_b := _component_root(b)
	if root_a == root_b: return
	if _component_sizes[root_a] < _component_sizes[root_b]:
		var swap := root_a
		root_a = root_b
		root_b = swap
	_component_parents[root_b] = root_a
	_component_sizes[root_a] += _component_sizes[root_b]

func _restore_edge(lower: Vector3i, upper: Vector3i) -> void:
	if not walkable(lower) or not walkable(upper): return
	if not edges[lower].has(upper): edges[lower].append(upper)
	if not edges[upper].has(lower): edges[upper].append(lower)

func walkable(cell: Vector3i) -> bool:
	return surfaces.has(cell) and not blocked.has(cell)

func access_cells(cell: Vector3i) -> Array[Vector3i]:
	if access_overrides.has(cell):
		var allowed: Array[Vector3i] = []
		for candidate: Vector3i in access_overrides[cell]:
			if walkable(candidate): allowed.append(candidate)
		return allowed
	if walkable(cell): return [cell]
	var result: Array[Vector3i] = []
	if not blocked.has(cell): return result
	# Solid objects are used from their perimeter, never their centre.
	for radius in range(1, 4):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius: continue
				var candidate := cell + Vector3i(x, 0, z)
				if walkable(candidate): result.append(candidate)
		if not result.is_empty(): break
	return result

func at_access(cell: Vector3i, target: Vector3i) -> bool:
	return access_cells(target).has(cell)

func escape_route(start: Vector3i) -> Array[Vector3i]:
	# A completed building or an old save can enclose a resident. Walk out on
	# the same connected floor; never snap them through a cliff or onto a roof.
	var queue: Array[Vector3i] = [start]
	var previous := {start: start}
	var index := 0
	while index < queue.size() and index < 128:
		var cell := queue[index]
		index += 1
		if walkable(cell):
			var result: Array[Vector3i] = [cell]
			while cell != start:
				cell = previous[cell]
				result.push_front(cell)
			return result
		for direction: Vector3i in DIRECTIONS:
			var next := cell + direction
			if not previous.has(next) and _touching(cell, next, true):
				previous[next] = cell
				queue.append(next)
	return []

func route(start: Vector3i, finish: Vector3i) -> Array[Vector3i]:
	if not blocked.has(start) and not blocked.has(finish): return _route(start, finish)
	var best: Array[Vector3i] = []
	var cost := INF
	for origin in access_cells(start):
		for destination in access_cells(finish):
			var candidate := _route(origin, destination)
			if not candidate.is_empty() and distance(candidate) < cost:
				best = candidate
				cost = distance(candidate)
	return best

func _route(start: Vector3i, finish: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if not surfaces.has(start) or not surfaces.has(finish):
		return result
	# Islands and roofs without ladders are rejected without exploring the map.
	if _component_root(start) != _component_root(finish):
		return result
	if start == finish:
		result.append(start)
		return result
	if not _searches.has(start):
		if _searches.size() >= MAX_CACHED_SOURCES:
			_searches.erase(_searches.keys()[0])
		_searches[start] = _new_search(start)
	var search: Dictionary = _searches[start]
	_advance_search(search, finish)
	if not search.settled.has(finish):
		return result
	var current := finish
	result.append(current)
	while current != start:
		current = search.previous[current]
		result.append(current)
	result.reverse()
	return result

func _new_search(start: Vector3i) -> Dictionary:
	# Keep the frontier: later destinations extend this tree instead of restarting.
	searches_built += 1
	return {"frontier": [[0.0, 0, start]], "sequence": 0,
		"costs": {start: 0.0}, "previous": {}, "settled": {}}

func _advance_search(search: Dictionary, finish: Vector3i) -> void:
	if search.settled.has(finish):
		return
	var frontier: Array = search.frontier
	var costs: Dictionary = search.costs
	var previous: Dictionary = search.previous
	while not frontier.is_empty():
		var entry: Array = _pop(frontier)
		var current: Vector3i = entry[2]
		if float(entry[0]) > float(costs[current]):
			continue
		search.settled[current] = true
		nodes_expanded += 1
		for neighbour: Vector3i in edges.get(current, []):
			var edge_length := edge_distance(current, neighbour)
			var next_cost := float(costs[current]) + edge_length / (1.35 if roads.has(neighbour) else 1.0)
			if not costs.has(neighbour) or next_cost < float(costs[neighbour]):
				costs[neighbour] = next_cost
				previous[neighbour] = current
				search.sequence += 1
				_push(frontier, [next_cost, search.sequence, neighbour])
		# A discovered node is only tentative. Stop after settling and relaxing it
		# so subsequent queries can safely resume, including beyond this target.
		if current == finish:
			return

static func _less(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])

static func _push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var index := heap.size() - 1
	while index > 0:
		# Heap parent indices deliberately round down.
		@warning_ignore("integer_division")
		var parent := (index - 1) / 2
		if not _less(entry, heap[parent]):
			break
		heap[index] = heap[parent]
		index = parent
	heap[index] = entry

static func _pop(heap: Array) -> Array:
	var first: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		var index := 0
		while index * 2 + 1 < heap.size():
			var child := index * 2 + 1
			if child + 1 < heap.size() and _less(heap[child + 1], heap[child]):
				child += 1
			if not _less(heap[child], last):
				break
			heap[index] = heap[child]
			index = child
		heap[index] = last
	return first

func distance(path: Array[Vector3i]) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		total += edge_distance(path[index - 1], path[index])
	return total

func edge_distance(a: Vector3i, b: Vector3i) -> float:
	if ladder_cell(a, b) != null:
		return ROOM_SIZE + Vector2(ROOM_SIZE, absf(point(a).y - point(b).y)).length()
	if terrain_links.get(a) == b or terrain_links.get(b) == a:
		# Climb to the cliff lip, then cross the upper half-cell.
		var run := Vector2(point(a).x - point(b).x, point(a).z - point(b).z).length()
		return Vector2(run * 0.5, absf(point(a).y - point(b).y)).length() + run * 0.5
	if terrain_shapes.has(a) or terrain_shapes.has(b):
		var middle := (point(a) + point(b)) * 0.5
		middle.y = surface_height(a, middle)
		return surface_point(a).distance_to(middle) + middle.distance_to(surface_point(b))
	return point(a).distance_to(point(b))

func movement_target(current: Vector3i, next: Vector3i, position: Vector3) -> Vector3:
	var destination := surface_point(next)
	if ladder_cell(current, next) != null:
		return ladder_waypoints(current, next, position)[0]
	if terrain_links.get(current) == next:
		if position.y < destination.y - 0.001:
			return (point(current) + destination) * 0.5 + Vector3.UP * absf(point(current).y - destination.y) * 0.5
	elif terrain_links.get(next) == current:
		var lip := (point(current) + destination) * 0.5 + Vector3.UP * absf(point(current).y - destination.y) * 0.5
		if position.y >= point(current).y - 0.001 and position.distance_to(lip) > 0.001:
			return lip
	if current.y == next.y and (terrain_shapes.has(current) or terrain_shapes.has(next)):
		return slope_waypoints(current, next, position)[0]
	return destination

func ladder_cell(a: Vector3i, b: Vector3i) -> Variant:
	return stair_links.get(a, {}).get(b, stair_links.get(b, {}).get(a))

func ladder_waypoints(current: Vector3i, next: Vector3i, position: Vector3) -> Array[Vector3]:
	var start := point(current)
	var finish := point(next)
	var direction := Vector3(finish.x - start.x, 0, finish.z - start.z).normalized()
	var progress := (position - start).dot(direction)
	var result: Array[Vector3] = []
	# Walk across half of A, climb edge-to-edge across B, then cross half of C.
	# Reversing the endpoints gives the same physical path when descending.
	if progress < ROOM_SIZE * 0.5 - 0.001:
		result.append(start + direction * ROOM_SIZE * 0.5)
	if progress < ROOM_SIZE * 1.5 - 0.001:
		result.append(finish - direction * ROOM_SIZE * 0.5)
	result.append(finish)
	return result

func stair_landing(cell: Vector3i, direction: int) -> Vector3i:
	var upper: Vector3i = cell + DIRECTIONS[direction] * Grid.CELLS_PER_ROOM + Grid.STOREY
	if not surfaces.has(upper) and surfaces.has(upper - Vector3i.UP): return upper - Vector3i.UP
	return upper
