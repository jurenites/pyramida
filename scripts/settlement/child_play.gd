extends RefCounted
## Local, deterministic games of tag. Steering chooses legal graph edges,
## so flocking never bypasses buildings, cliff edges or explicit floor access.
const RUN_SPEED := 1.6
const CATCHER_BOOST := 0.2
const PLAY_RADIUS := 6.0
const NEIGHBOUR_RADIUS := 3.0
const CIRCLE_RADIUS := 2.5
const TAG_DISTANCE := 0.7
const TAG_GRACE := 1.5
const ROUND_SECONDS := 18.0
const REST_SECONDS := 12.0
const MAX_PLAYERS := 6
const SCAN_SECONDS := 2.0

static func eligible(world, kid: Dictionary) -> bool:
	if kid.route_index < kid.route.size() and kid.route[kid.route_index].y != kid.cell.y: return false
	return not world.Citizens.is_adult(kid) and kid.job.is_empty() and kid.cargo.is_empty() \
		and kid.hunger < 30.0 and not kid.has("clearance_route") and world.navigation.walkable(kid.cell)

static func bucket(kid: Dictionary) -> Vector3i:
	return Vector3i(floori(kid.position.x / PLAY_RADIUS), kid.cell.y, floori(kid.position.z / PLAY_RADIUS))

static func area(world, anchor: Vector3i) -> Dictionary:
	if not world.navigation.walkable(anchor): return {}
	var found := {anchor: true}
	var queue: Array[Vector3i] = [anchor]
	var index := 0
	var centre: Vector3 = world.navigation.surface_point(anchor)
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for next: Vector3i in world.navigation.edges.get(cell, []):
			if found.has(next) or next.y != anchor.y: continue
			if world.navigation.surface_point(next).distance_to(centre) > PLAY_RADIUS: continue
			found[next] = true
			queue.append(next)
	return found

static func _rest(world, id: int) -> void:
	world.workers[id].play_rest_until = world.time + REST_SECONDS + id % 5

static func tick(world) -> void:
	world.child_players.clear()
	var scan: bool = _due(world.time, world.child_play.next_scan)
	var games: Array = []
	for game: Dictionary in world.child_play.games:
		var reachable: Dictionary = area(world, game.anchor) if scan else {}
		var members: Array = []
		for id: int in game.members:
			var kid: Dictionary = world.workers[id]
			if eligible(world, kid) and not _due(world.time, game.until) and kid.cell.y == game.anchor.y \
				and kid.position.distance_to(world.navigation.surface_point(game.anchor)) <= PLAY_RADIUS \
				and (not scan or reachable.has(kid.cell)):
				members.append(id)
			else:
				_rest(world, id)
		game.members = members
		if members.size() < 2:
			for id: int in members: _rest(world, id)
			continue
		if not members.has(game.catcher):
			game.catcher = members[0]
			game.tag_ready = world.time + TAG_GRACE
		games.append(game)
		for id: int in members: world.child_players[id] = game
	world.child_play.games = games
	if scan:
		world.child_play.next_scan = world.time + SCAN_SECONDS
		_start_games(world)
	for game: Dictionary in world.child_play.games:
		_tag(world, game)
		# Plan from the same positions before any child moves this fixed tick.
		for id: int in game.members:
			var kid: Dictionary = world.workers[id]
			if kid.route_index >= kid.route.size(): _new_leg(world, game, kid)

static func _start_games(world) -> void:
	# Spatial buckets prevent distant children from influencing a local game.
	var buckets := {}
	var available: Array[Dictionary] = []
	for kid: Dictionary in world.workers:
		if world.child_players.has(kid.id) or not eligible(world, kid) or not _due(world.time, kid.get("play_rest_until", 0.0)): continue
		var key := bucket(kid)
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(kid)
		available.append(kid)
	for host: Dictionary in available:
		if world.child_players.has(host.id): continue
		var local: Array[Dictionary] = []
		var key := bucket(host)
		for x in range(-1, 2):
			for z in range(-1, 2):
				for kid: Dictionary in buckets.get(key + Vector3i(x, 0, z), []):
					if not world.child_players.has(kid.id) and kid.position.distance_to(host.position) <= PLAY_RADIUS:
						local.append(kid)
		if local.size() < 2: continue
		local.sort_custom(func(a, b): return a.id < b.id)
		var reachable := area(world, host.cell)
		if reachable.size() < 8: continue
		var centre: Vector3 = world.navigation.surface_point(host.cell)
		var members: Array = [host.id]
		for kid: Dictionary in local:
			if kid.position.distance_to(centre) > PLAY_RADIUS: continue
			if kid.route_index < kid.route.size() and world.navigation.surface_point(kid.route[kid.route_index]).distance_to(centre) > PLAY_RADIUS: continue
			if kid.id != host.id and reachable.has(kid.cell) and members.size() < MAX_PLAYERS:
				members.append(kid.id)
		if members.size() < 2: continue
		var game := {"anchor": host.cell, "members": members, "catcher": host.id,
			"until": world.time + ROUND_SECONDS, "tag_ready": world.time + TAG_GRACE,
			"direction": 1 if host.id % 2 == 0 else -1, "tags": 0}
		world.child_play.games.append(game)
		for id: int in members:
			world.child_players[id] = game
			var kid: Dictionary = world.workers[id]
			# Finish the current edge smoothly, then steer locally. Old saves can
			# contain long solitary routes aimed at the original settlement.
			if kid.route_index < kid.route.size():
				kid.route = kid.route.slice(0, kid.route_index + 1)

static func _tag(world, game: Dictionary) -> void:
	if not _due(world.time, game.tag_ready): return
	var catcher: Dictionary = world.workers[game.catcher]
	for id: int in game.members:
		if id == game.catcher: continue
		var other: Dictionary = world.workers[id]
		if catcher.position.distance_to(other.position) > TAG_DISTANCE: continue
		# No tagging through a wall, across unsupported corners or between floors.
		if catcher.cell != other.cell and not world.navigation.edges.get(catcher.cell, []).has(other.cell): continue
		game.catcher = id
		game.tag_ready = world.time + TAG_GRACE
		game.tags += 1
		return

static func heading(kid: Dictionary) -> Vector3:
	if kid.route_index >= kid.route.size(): return Vector3.ZERO
	var next: Vector3i = kid.route[kid.route_index]
	return Vector3(next.x - kid.cell.x, 0, next.z - kid.cell.z).normalized()

static func _new_leg(world, game: Dictionary, kid: Dictionary) -> void:
	var centre: Vector3 = world.navigation.surface_point(game.anchor)
	var radial: Vector3 = kid.position - centre
	radial.y = 0
	if radial.length() < 0.1: radial = Vector3.RIGHT.rotated(Vector3.UP, kid.id * 2.4)
	var outward := radial.normalized()
	var tangent := Vector3(-outward.z, 0, outward.x) * int(game.direction)
	var desired := tangent + outward * clampf((CIRCLE_RADIUS - radial.length()) * 0.7, -1.5, 1.5)
	var alignment := Vector3.ZERO
	var cohesion := Vector3.ZERO
	var separation := Vector3.ZERO
	var neighbours := 0
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for id: int in game.members:
		if id == kid.id: continue
		var other: Dictionary = world.workers[id]
		var offset: Vector3 = kid.position - other.position
		offset.y = 0
		var distance := offset.length()
		if distance < nearest_distance:
			nearest = other
			nearest_distance = distance
		if distance > NEIGHBOUR_RADIUS: continue
		neighbours += 1
		alignment += heading(other)
		cohesion -= offset
		if distance < 1.2 and distance > 0.001:
			separation += offset.normalized() * (1.2 - distance)
		elif distance <= 0.001:
			# A shared spawn needs a deterministic opposite nudge; normalizing
			# a zero offset would keep equal-speed runners stacked all round.
			var angle := (mini(kid.id, id) * 13 + maxi(kid.id, id) * 7) * 2.4
			separation += Vector3.RIGHT.rotated(Vector3.UP, angle) * (1.2 if kid.id > id else -1.2)
	if neighbours > 0:
		desired += alignment / neighbours * 0.35 + cohesion / neighbours * 0.12
	if kid.id == game.catcher and not nearest.is_empty():
		# Pursuit predicts a short distance ahead of the fleeing child.
		desired = (nearest.position + heading(nearest) * 0.45 - kid.position).normalized()
	else:
		var away: Vector3 = kid.position - world.workers[game.catcher].position
		away.y = 0
		if away.length() < 2.0: desired += away.normalized() * 0.8
		desired += separation * 1.4
	var best: Variant = null
	var best_score := -INF
	for next: Vector3i in world.navigation.edges.get(kid.cell, []):
		if next.y != game.anchor.y: continue
		var point: Vector3 = world.navigation.surface_point(next)
		if point.distance_to(centre) > PLAY_RADIUS: continue
		var direction: Vector3 = (point - kid.position).normalized()
		var score := direction.dot(desired.normalized()) + direction.dot(heading(kid)) * 0.08
		if score > best_score:
			best = next
			best_score = score
	if best != null:
		kid.route = [kid.cell, best]
		kid.route_index = 1

static func speed(world, kid: Dictionary) -> float:
	if not world.child_players.has(kid.id): return 1.2
	return RUN_SPEED + (CATCHER_BOOST if world.child_players[kid.id].catcher == kid.id else 0.0)

static func valid(state: Variant, workers: Array) -> bool:
	if not state is Dictionary or not state.get("games") is Array or not _time_valid(state.get("next_scan")): return false
	var seen := {}
	for game: Variant in state.games:
		if not game is Dictionary or not game.get("anchor") is Vector3i or not game.get("members") is Array: return false
		if game.members.size() < 2 or game.members.size() > MAX_PLAYERS: return false
		if not game.get("catcher") is int or not game.members.has(game.catcher): return false
		if game.get("direction") not in [-1, 1] or not game.get("tags") is int or game.tags < 0: return false
		if not _time_valid(game.get("until")) or not _time_valid(game.get("tag_ready")): return false
		for id: Variant in game.members:
			if not id is int or id < 0 or id >= workers.size() or seen.has(id): return false
			seen[id] = true
	for kid: Dictionary in workers:
		if not _time_valid(kid.get("play_rest_until", 0.0)): return false
	return true

static func _time_valid(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0.0

static func _due(now: float, deadline: float) -> bool:
	# JSON round trips can change the last bit of a simulation timestamp.
	return now + 0.00000001 >= deadline
