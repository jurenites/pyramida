extends RefCounted
## Blueprint-only access graph and attachments. Walking never follows utility links.
const SIDES := [Vector3i.BACK, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.LEFT]
const KINDS := ["ac", "dish"]

static func default_door(cells: Dictionary, utilities: Array = []) -> Dictionary:
	var ordered := cells.keys()
	ordered.sort_custom(func(a: Vector3i, b: Vector3i):
		if absi(a.y) != absi(b.y): return absi(a.y) < absi(b.y)
		if a.z != b.z: return a.z > b.z
		return a.x < b.x)
	for cell: Vector3i in ordered:
		for side: Vector3i in SIDES:
			if not cells.has(cell + side):
				var occupied := false
				for utility: Dictionary in utilities:
					if utility.cell == cell and utility.side == side: occupied = true
				if occupied: continue
				return {"cell": cell, "side": side}
	return {}

static func doors(building: Dictionary) -> Array:
	var result: Array = building.get("extra_doors", []).duplicate()
	if not building.get("door", {}).is_empty(): result.push_front(building.door)
	return result

static func exposed_door(building: Dictionary, entry: Dictionary) -> bool:
	return not entry.is_empty() and entry.get("side") in SIDES and building.cells.has(entry.get("cell")) and not building.cells.has(entry.cell + entry.side)

static func normalize(building: Dictionary) -> void:
	if building.get("door", {}).is_empty() or not building.cells.has(building.door.cell) or building.cells.has(building.door.cell + building.door.side):
		var remaining: Array = building.get("extra_doors", []).filter(func(entry): return exposed_door(building, entry))
		building.door = remaining[0] if not remaining.is_empty() else default_door(building.cells, building.get("utilities", []))
	building.extra_doors = building.get("extra_doors", []).filter(func(entry): return exposed_door(building, entry) and entry != building.door)
	if not building.has("utilities"): building.utilities = []
	if not building.has("ladders"): building.ladders = []
	building.utilities = building.utilities.filter(func(a): return building.cells.has(a.cell) and not building.cells.has(a.cell + a.side))
	building.ladders = building.ladders.filter(func(a): return building.cells.has(a.cell) and not building.cells.has(a.cell + a.side))

static func occupancy(buildings: Array) -> Dictionary:
	var cells := {}
	for building: Dictionary in buildings: cells.merge(building.cells)
	return cells

static func reachable(buildings: Array) -> Dictionary:
	var cells := occupancy(buildings)
	var owners := {}
	for index in buildings.size():
		for cell: Vector3i in buildings[index].cells: owners[cell] = index
	var surfaces := {}
	for x in range(-12, 13):
		for z in range(-12, 13):
			var p := Vector3i(x, 0, z)
			if not cells.has(p): surfaces[p] = true
	for cell: Vector3i in cells:
		if not cells.has(cell + Vector3i.UP): surfaces[cell + Vector3i.UP] = true
	# Sidewalk equipment occupies walking space; facade equipment does not.
	for building: Dictionary in buildings:
		for utility: Dictionary in building.get("utilities", []):
			if utility.mount == "ground": cells[utility.cell + utility.side] = "utility"
	var links := {}
	for building: Dictionary in buildings:
		for ladder: Dictionary in building.get("ladders", []):
			var lower: Vector3i = ladder.cell + ladder.side
			var upper: Vector3i = ladder.cell + Vector3i.UP
			if cells.has(lower) or cells.has(lower + Vector3i.UP): continue
			# A ladder may continue up another wall; an intermediate rung is a node.
			surfaces[lower + Vector3i.UP] = true
			for destination in [lower + Vector3i.UP, upper]:
				if cells.has(destination): continue
				_link(links, lower, destination)
	# Doors open through neighbouring walls in both directions. Touching walls
	# and stacked floors alone never connect. Ladders can supply outdoor thresholds.
	for building: Dictionary in buildings:
		for door: Dictionary in doors(building):
			if not exposed_door(building, door): continue
			var threshold: Vector3i = door.cell + door.side
			if owners.has(threshold) or (surfaces.has(threshold) and not cells.has(threshold)):
				_link(links, door.cell, threshold)
	var reached := {}
	var queue: Array = []
	for p: Vector3i in surfaces:
		if p.y == 0 and not cells.has(p) and (absi(p.x) == 12 or absi(p.z) == 12):
			reached[p] = true
			queue.append(p)
	var cursor := 0
	while cursor < queue.size():
		var p: Vector3i = queue[cursor]
		cursor += 1
		var neighbours: Array = links.get(p, []).duplicate()
		for side: Vector3i in SIDES:
			var next := p + side
			if owners.has(p):
				if owners.get(next, -1) == owners[p]: neighbours.append(next)
			elif not cells.has(next):
				neighbours.append(next)
		for next: Vector3i in neighbours:
			if (owners.has(next) or (surfaces.has(next) and not cells.has(next))) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	return reached

static func _link(links: Dictionary, a: Vector3i, b: Vector3i) -> void:
	if not links.has(a): links[a] = []
	if not links.has(b): links[b] = []
	if b not in links[a]: links[a].append(b)
	if a not in links[b]: links[b].append(a)

static func valid_door(building: Dictionary) -> bool:
	return exposed_door(building, building.get("door", {}))

static func connected(building: Dictionary, reached: Dictionary, _cells: Dictionary) -> bool:
	for door: Dictionary in doors(building):
		if exposed_door(building, door) and reached.has(door.cell): return true
	return false

static func access_error(buildings: Array) -> String:
	var reached := reachable(buildings)
	for building: Dictionary in buildings:
		if not connected(building, reached, {}): return "No entrance access."
	return ""

static func loses_access(before: Array, after: Array) -> bool:
	var old_reached := reachable(before)
	var new_reached := reachable(after)
	# Retained room cells identify buildings even when their entrance is edited.
	for building: Dictionary in after:
		if connected(building, new_reached, {}): continue
		for cell: Vector3i in building.cells:
			if old_reached.has(cell): return true
	return false

static func attachment_error(building: Dictionary, cells: Dictionary, entry: Dictionary, installed := false, check_floor := true) -> String:
	if not building.cells.has(entry.cell) or entry.side not in SIDES or cells.has(entry.cell + entry.side):
		return "Choose an exposed wall."
	for door: Dictionary in doors(building):
		if door.cell == entry.cell and door.side == entry.side:
			return "Keep the doorway clear."
	if check_floor and entry.mount == "ground" and entry.cell.y != 0 and not cells.has(entry.cell + entry.side + Vector3i.DOWN):
		return "This unit needs a floor."
	for other: Dictionary in building.get("utilities", []):
		if installed and other == entry: continue
		if other.cell == entry.cell and other.side == entry.side and (other.offset - entry.offset).length() < 0.42:
			return "This spot is occupied."
	return ""

static func automatic(building: Dictionary, cells: Dictionary, kind: String, rng: RandomNumberGenerator) -> Dictionary:
	# An upgrade is idempotent. Manual additions can still be used as decoration.
	for entry: Dictionary in building.get("utilities", []):
		if entry.kind == kind: return {}
	var options: Array = []
	for cell: Vector3i in building.cells:
		for side: Vector3i in SIDES:
			var entry := {"kind": kind, "cell": cell, "side": side, "mount": "wall", "offset": Vector2(rng.randf_range(-0.26, 0.26), rng.randf_range(0.38, 0.76))}
			if attachment_error(building, cells, entry).is_empty(): options.append(entry)
	return {} if options.is_empty() else options[rng.randi_range(0, options.size() - 1)]
