extends RefCounted
var puddle_basins: Dictionary={}
const Perf = preload("res://scripts/settlement/performance_log.gd")
## Explicit walkable surfaces. A floor above another floor has its own identity.
## Natural slopes follow their mesh; cliffs and built floors need explicit connectors.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const CELL_SIZE := Grid.CELL_SIZE
const ROOM_SIZE := Grid.ROOM_SIZE
const LEVEL_HEIGHT := Grid.LEVEL_HEIGHT
const DIRECTIONS := [Vector3i.RIGHT, Vector3i.BACK, Vector3i.LEFT, Vector3i.FORWARD]
const DIAGONALS := [Vector3i(1, 0, 1), Vector3i(1, 0, -1), Vector3i(-1, 0, 1), Vector3i(-1, 0, -1)]
var stack_barriers: Dictionary={}
var _built_stack_barriers: Dictionary={}
var stack_solids: Array[AABB]=[]
var building_stock_state: Array=[]
var building_access: Dictionary={}
var room_nodes: Dictionary={}
var room_edges: Dictionary={}
var room_heights: Dictionary={}
var room_offsets: Dictionary={}
var room_paths: Dictionary={}
var room_stair_contacts: Dictionary={}
var access_overrides: Dictionary = {}
var surfaces: Dictionary = {}
var support_poses: Dictionary = {}
var terrain_barriers: Dictionary = {}
var _built_terrain_barriers: Dictionary = {}
var _built_support_poses: Dictionary = {}
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
var _edge_lengths: Dictionary = {}
var searches_built := 0
var nodes_expanded := 0
var _components: Dictionary = {}
var _component_parents: Dictionary = {}
var _component_sizes: Dictionary = {}
var _next_component := 0

static func point(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, cell.y * LEVEL_HEIGHT, cell.z * CELL_SIZE)

# Inputs that callers replace before rebuilding; retain the last built state.
var _built_blocked: Dictionary = {}
var _built_room_nodes: Dictionary = {}
var _built_room_edges: Dictionary = {}
var _built_connectors: Dictionary = {}

func _changed_cells(before: Dictionary, after: Dictionary, affected: Dictionary) -> void:
	for cell in before:
		if not after.has(cell) or before[cell] != after[cell]: affected[cell] = true
	for cell in after:
		if not before.has(cell): affected[cell] = true

func rebuild(next_surfaces: Dictionary, stairs: Dictionary, terrain_ramps: Dictionary = {}, shapes: Dictionary = {}) -> void:
	var changed := {}
	_changed_cells(_built_stack_barriers,stack_barriers,changed)
	_built_stack_barriers=stack_barriers.duplicate(true)
	_changed_cells(surfaces, next_surfaces, changed)
	_changed_cells(_built_terrain_barriers,terrain_barriers,changed)
	_built_terrain_barriers=terrain_barriers.duplicate(true)
	_changed_cells(_built_support_poses,support_poses,changed)
	_built_support_poses=support_poses.duplicate()
	_changed_cells(_built_blocked, blocked, changed)
	_changed_cells(terrain_shapes, shapes, changed)
	_changed_cells(_built_room_nodes, room_nodes, changed)
	_changed_cells(_built_room_edges, room_edges, changed)
	var affected := changed.duplicate()
	for cell: Vector3i in changed:
		for direction: Vector3i in DIRECTIONS + DIAGONALS: affected[cell + direction] = true
	# Old connector endpoints also need their ordinary edges restored on removal.
	affected.merge(_built_connectors)
	for cell in surfaces:
		if not next_surfaces.has(cell): edges.erase(cell)
	surfaces = next_surfaces.duplicate()
	terrain_shapes = shapes.duplicate(true)
	terrain_links = terrain_ramps.duplicate()
	stair_links.clear()
	_searches.clear()
	_edge_lengths.clear()
	_built_connectors.clear()
	# The ladder occupies B; its traversable edge connects A -> C through B.
	for cell: Vector3i in stairs:
		var direction: Vector3i = DIRECTIONS[int(stairs[cell])]
		var lower := cell - direction * Grid.CELLS_PER_ROOM
		var upper := stair_landing(cell, int(stairs[cell]))
		if walkable(cell) and walkable(lower) and walkable(upper):
			if not stair_links.has(lower): stair_links[lower] = {}
			stair_links[lower][upper] = cell
			_built_connectors[lower] = true
			_built_connectors[upper] = true
	for lower: Vector3i in terrain_links:
		_built_connectors[lower] = true
		_built_connectors[terrain_links[lower]] = true
	for lower in room_paths:
		_built_connectors[lower] = true
		for upper in room_paths[lower]: _built_connectors[upper] = true
	affected.merge(_built_connectors)
	_refresh_edges(affected)
	_rebuild_components()
	_built_blocked = blocked.duplicate()
	_built_room_nodes = room_nodes.duplicate()
	_built_room_edges = room_edges.duplicate(true)
	revision += 1

func update_ground(added: Dictionary, removed: Dictionary, shapes: Dictionary = {}) -> void:
	# Streaming changes only natural ground. Built surfaces and all active
	# connectors are pinned by the model, so their identities stay untouched.
	terrain_shapes = shapes.duplicate(true)
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
	_refresh_edges(affected)
	_invalidate_searches(affected)
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
		_join_affected(affected)
	revision += 1

func remove_obstacle(cell: Vector3i) -> void:
	# Removing a trunk only opens edges. Keep terrain, distant search frontiers
	# and existing component identities; no full-map connectivity pass is needed.
	if not blocked.erase(cell): return
	var started := Perf.begin()
	var affected := {cell: true}
	for direction: Vector3i in DIRECTIONS + DIAGONALS:
		affected[cell + direction] = true
	_refresh_edges(affected)
	_invalidate_searches(affected)
	_join_affected(affected)
	revision += 1
	Perf.end("navigation.remove_obstacle", started)

func _join_affected(affected: Dictionary) -> void:
	for cell: Vector3i in affected:
		for neighbour: Vector3i in edges.get(cell, []):
			_join_components(cell, neighbour)

func _refresh_edges(affected: Dictionary) -> void:
	for cell: Vector3i in affected:
		if not surfaces.has(cell): continue
		edges[cell] = _surface_neighbours(cell)
	for lower: Vector3i in stair_links:
		for upper: Vector3i in stair_links[lower]:
			_restore_edge(lower, upper)
	for lower: Vector3i in terrain_links:
		_restore_edge(lower, terrain_links[lower])
	for lower in room_paths:
		for upper in room_paths[lower]: _restore_edge(lower,upper)

func _invalidate_searches(affected: Dictionary) -> void:
	for cell in affected: _edge_lengths.erase(cell)
	# Unvisited distant chunks cannot change an already settled local route.
	# Invalidate any search whose settled OR tentative frontier touches an edit.
	for origin: Vector3i in _searches.keys():
		var costs: Dictionary = _searches[origin].costs
		for cell: Vector3i in affected:
			if costs.has(cell):
				_searches.erase(origin)
				break

func surface_height(cell: Vector3i, position: Vector3) -> float:
	if puddle_basins.has(cell): return preload("res://scripts/settlement/puddle_basin.gd").height(cell,puddle_basins[cell],position)
	if room_heights.has(cell): return float(room_heights[cell])
	if support_poses.has(cell): return support_poses[cell].origin.y
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
	var result: Vector3 = point(cell)+room_offsets[cell] if room_offsets.has(cell) else (support_poses[cell].origin if support_poses.has(cell) else point(cell))
	result.y = surface_height(cell, result)
	return result

func ground_position(position: Vector3, level: int) -> Vector3:
	var cell := Vector3i(roundi(position.x / CELL_SIZE), level, roundi(position.z / CELL_SIZE))
	if surfaces.has(cell): position.y = surface_height(cell, position)
	return position

func _support_contains(cell: Vector3i, position: Vector3) -> bool:
	var local: Vector3 = support_poses[cell].affine_inverse()*position if support_poses.has(cell) else position-point(cell)
	return absf(local.x)<=0.501 and absf(local.z)<=0.501

func _touching(a: Vector3i, b: Vector3i, escaping := false) -> bool:
	if stack_barriers.get(a,[]).has(b): return false
	if terrain_barriers.get(a,[]).has(b): return false
	if (room_nodes.has(a) or room_nodes.has(b)) and not room_edges.get(a,[]).has(b): return false
	if not escaping and (blocked.has(a) or blocked.has(b)): return false
	if not surfaces.has(a) or not surfaces.has(b): return false
	if room_nodes.has(a) or room_nodes.has(b): return true
	if support_poses.has(a) or support_poses.has(b):
		var pa := surface_point(a); var pb := surface_point(b)
		var axis := (pb-pa).normalized()
		var tangent := Vector3(-axis.z,0,axis.x)
		# A citizen needs a continuous strip, not merely nearby post centres.
		for step in 17:
			var centre := pa.lerp(pb,float(step)/16.0)
			for side in [-0.18,0.18]:
				var sample: Vector3 = centre+tangent*side
				if not _support_contains(a,sample) and not _support_contains(b,sample): return false
	if not terrain_shapes.has(a) and not terrain_shapes.has(b): return absf(surface_height(a, point(a)) - surface_height(b, point(b))) < 0.001
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
		if (room_nodes.has(cell) or room_nodes.has(next)) and room_nodes.get(cell,-1)!=room_nodes.get(next,-1): continue
		# All four edges must meet; diagonals never cut across gaps or cliffs.
		# The two edges from this cell were already checked above. Reuse them
		# while integrating terrain instead of resampling their slopes twice.
		if result.has(side_x) and result.has(side_z) and _touching(side_x, next) and _touching(side_z, next) and not stack_barriers.get(cell,[]).has(next):
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
	var points: Array=room_paths.get(lower,{}).get(upper,[surface_point(lower),surface_point(upper)])
	for box in stack_solids:
		for i in range(1,points.size()):
			if box.intersects_segment(points[i-1],points[i])!=null: return
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

func distance_lower_bound(start: Vector3i, finish: Vector3i) -> float:
	if not blocked.has(start) and not blocked.has(finish):
		return Vector2(start.x - finish.x, start.z - finish.z).length() * CELL_SIZE
	var result := INF
	for origin in access_cells(start):
		for destination in access_cells(finish):
			result = minf(result, Vector2(origin.x - destination.x, origin.z - destination.z).length() * CELL_SIZE)
	return result

func can_reach(start: Vector3i, finish: Vector3i) -> bool:
	# Connectivity is already maintained with the graph. Existence checks do
	# not need a shortest-path tree or a reconstructed route.
	if not blocked.has(start) and not blocked.has(finish):
		return surfaces.has(start) and surfaces.has(finish) and _component_root(start) == _component_root(finish)
	for origin in access_cells(start):
		for destination in access_cells(finish):
			if _component_root(origin) == _component_root(destination): return true
	return false

func route(start: Vector3i, finish: Vector3i) -> Array[Vector3i]:
	if not blocked.has(start) and not blocked.has(finish): return _route(start, finish)
	var best: Array[Vector3i] = []
	var cost := INF
	for origin in access_cells(start):
		for destination in access_cells(finish):
			# A solid building can have many perimeter access cells. Do not run
			# searches that cannot beat the route already found (physical length).
			var lower_bound := Vector2(origin.x - destination.x, origin.z - destination.z).length() * CELL_SIZE
			if lower_bound >= cost: continue
			var candidate := _route(origin, destination)
			if not candidate.is_empty() and distance(candidate) < cost:
				best = candidate
				cost = distance(candidate)
				if is_zero_approx(cost): return best
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
	var started := Perf.begin()
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
			Perf.end("navigation.search", started)
			return
	Perf.end("navigation.search", started)

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
	# Slopes and authored stair/bridge curves are shared by every journey.
	# Measure each edge once until the corresponding geometry changes.
	if not _edge_lengths.has(a): _edge_lengths[a] = {}
	if not _edge_lengths[a].has(b): _edge_lengths[a][b] = _measure_edge(a, b)
	return _edge_lengths[a][b]

func _measure_edge(a: Vector3i, b: Vector3i) -> float:
	if room_paths.get(a, {}).has(b):
		var total := 0.0
		var path: Array = room_paths[a][b]
		for i in range(1, path.size()): total += path[i - 1].distance_to(path[i])
		return total
	if ladder_cell(a, b) != null:
		return ROOM_SIZE + Vector2(ROOM_SIZE, absf(surface_point(a).y - surface_point(b).y)).length()
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
	if room_paths.get(current,{}).has(next): return preload("res://scripts/settlement/room_navigation.gd").target(room_paths[current][next],position)
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
	# Arrivals are tested against the actual floor, including soil and room height.
	var start := surface_point(current)
	var finish := surface_point(next)
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
