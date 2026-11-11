extends RefCounted
## Small, deterministic spatial rules exercised by ModularHousePrototype.
## No settlement state, save access, simulation or rendering dependencies.
const ROOM_SIZE := Vector3(2, 2, 2)
const MAX_BRACE_REACH := 1.0 # Provisional gameplay threshold, not engineering.
const PIPE_RADIUS := 0.065

static func rooms(upper := true, overhang := 1.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"id": 0, "origin": Vector3(-2, 0, -1), "entry": Vector3(-1, 0, 1)},
		{"id": 1, "origin": Vector3(0, 0, -1), "entry": Vector3(0, 0, 0)}]
	if upper: result.append({"id": 2, "origin": Vector3(-1, 2, -1 - overhang), "entry": Vector3(0, 2, 1 - overhang)})
	return result

static func bounds(room: Dictionary) -> AABB:
	return AABB(room.origin, ROOM_SIZE)

static func layout(seed_: int, upper := true, staggered := false) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_ + 4711
	var origins: Array[Vector3] = [Vector3(-2, 0, -1), Vector3(0, 0, -1)]
	var count := 3 + posmod(seed_, 3)
	while origins.size() < count:
		var candidates: Array[Vector3] = []
		for at in origins:
			for d in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				var next: Vector3 = at + d * 2
				if next.x < -2 or next.x > 2 or next.z > -1 or next.z < -5 or next in origins or next in candidates: continue
				candidates.append(next)
		origins.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	var result: Array[Dictionary] = []
	for at in origins: result.append({"id":result.size(), "origin":at, "entry":at + Vector3(1, 0, 2)})
	if upper:
		var choices := origins.slice(1)
		for i in range(choices.size() - 1, 0, -1):
			var j := rng.randi_range(0, i); var old: Vector3 = choices[i]; choices[i] = choices[j]; choices[j] = old
		for i in 1 + posmod(seed_ + int(seed_ / 3), mini(3, choices.size())):
			var shift:=Vector3(0.22 if seed_%2 else -0.3,0,0.28 if seed_%3 else -0.18) if staggered else Vector3.ZERO
			var at: Vector3 = choices[i] + Vector3.UP * 2+shift
			result.append({"id":result.size(), "origin":at, "entry":at + Vector3(1, 0, 2)})
	return result

static func balcony(records: Array[Dictionary]) -> Vector3:
	var east := 2.0
	for room in records:
		if room.origin.y == 0 and room.origin.z == -1: east = maxf(east, room.origin.x + 2)
	return Vector3(east + 0.5, 2, 0.5)

static func terrace_tiles(records: Array[Dictionary]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for room in records:
		if room.origin.y != 0: continue
		for x in 2:
			for z in 2:
				var at: Vector3 = room.origin + Vector3(x + 0.5, 2, z + 0.5)
				if not records.any(func(other): return other.origin.y == 2 and bounds(other).has_point(at + Vector3.UP * 0.1)): result.append(at)
	result.append(balcony(records))
	return result

static func supports(records: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var east := balcony(records).x - 0.5
	var loaded := records.any(func(room):return room.origin.y==2 and bounds(room).has_point(balcony(records)+Vector3.UP*0.1))
	for z in [0.12, 0.88]:
		if loaded:
			result.append({"kind":"balcony_brace", "a":Vector3(east - 0.06, 1.04, z), "b":Vector3(east + 0.9, 2, z)})
			result.append({"kind":"anchor", "a":Vector3(east - 0.06, 0, z), "b":Vector3(east - 0.06, 2, z)})
		else:
			result.append({"kind":"balcony_joist", "a":Vector3(east - 0.8, 1.93, z), "b":Vector3(east + 0.95, 1.93, z)})
	for room in records:
		if room.origin.y == 0: continue
		var pillars: Array[Vector3] = []
		for x in [0.14, 1.86]:
			for z in [0.14, 1.86]:
				var top: Vector3 = room.origin + Vector3(x, 0, z)
				var nearest := Vector3.INF; var distance := INF
				for base in records:
					if base.origin.y != 0: continue
					var foot := Vector3(clampf(top.x, base.origin.x + 0.14, base.origin.x + 1.86), 2, clampf(top.z, base.origin.z + 0.14, base.origin.z + 1.86))
					if top.distance_to(foot) < distance: nearest = foot; distance = top.distance_to(foot)
				if distance < 0.01: continue
				if distance <= MAX_BRACE_REACH + 0.001:
					nearest.y -= distance
					result.append({"kind":"brace", "a":nearest, "b":top})
					result.append({"kind":"anchor", "a":Vector3(nearest.x, 0, nearest.z), "b":Vector3(nearest.x, 2, nearest.z)})
				else:
					result.append({"kind":"pillar", "a":Vector3(top.x, 0, top.z), "b":top}); pillars.append(top)
		if pillars.size() >= 2: result.append({"kind":"tie", "a":pillars[0] - Vector3.UP, "b":pillars[1] - Vector3.UP})
	return result

static func flue(records: Array[Dictionary], exterior := true) -> Array[Vector3]:
	var source := Vector3(-0.65, 0.75, -0.65)
	var upper := records.filter(func(room): return room.origin.y == 2)
	if not exterior or upper.is_empty(): return [source, Vector3(source.x, 2.7, source.z)]
	var target: Vector3 = upper[0].origin + Vector3(0.65, 2.9, 1)
	var west := -2.3
	for room in records: west = minf(west, room.origin.x - 0.3)
	return [source, Vector3(-0.65, 1.78, -0.65), Vector3(west, 1.78, -0.65),
		Vector3(west, 4.5, -0.65), Vector3(west, 4.5, target.z), Vector3(target.x, 4.5, target.z), target]

static func obstruction(records: Array[Dictionary], points: Array[Vector3]) -> Dictionary:
	# The source room owns the wall penetration. Upper rooms have no implicit shaft.
	for room in records:
		if room.id == 0: continue
		var box := bounds(room).grow(PIPE_RADIUS)
		for i in range(1, points.size()):
			if box.intersects_segment(points[i - 1], points[i]):
				return {"room": room.id, "point": Vector3(points[i].x, room.origin.y, points[i].z)}
	return {}
