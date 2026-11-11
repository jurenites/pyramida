extends RefCounted
## Continuous bridge geometry; integer cells identify supporting floors only.
const Paths = preload("res://scripts/settlement/room_navigation.gd")
const MIN_SPAN := 2.0
const MAX_SPAN := 24.0
const MAX_GRADE := 0.75
const WIDTH := 0.9

static func deck(a: Vector3, b: Vector3, shoulders := 0.65) -> Array:
	var run := Vector2(b.x - a.x, b.z - a.z).length()
	var sag := minf(run * 0.035, 0.65)
	var count := maxi(8, ceili(a.distance_to(b) / 0.25))
	var result: Array = []
	for i in count + 1:
		var t := float(i) / count
		var margin := minf(shoulders / maxf(run, 0.001), 0.22)
		var suspended := clampf((t - margin) / (1.0 - margin * 2.0), 0.0, 1.0)
		var p := a.lerp(b, t)
		p.y = lerpf(a.y, b.y, suspended) - sin(suspended * PI) * sag
		result.append(p)
	return result

static func curve(record: Dictionary) -> Array:
	return deck(record.start, record.end, 0.65 if record.get("curve_version", 1) == 2 else 0.0)

static func record_cost(record: Dictionary) -> Dictionary:
	return cost_for_length(length(curve(record)))

static func cost_for_length(metres: float) -> Dictionary:
	var rules: Dictionary = preload("res://scripts/settlement/reviewed_balance.gd").data.rope_bridge_cost
	return {"plank": ceili(metres * float(rules.planks_per_metre)), "rope": ceili(metres * float(rules.rope_per_metre))}

static func length(points: Array) -> float:
	var total := 0.0
	for i in range(1, points.size()): total += points[i - 1].distance_to(points[i])
	return total

static func cost(a: Vector3, b: Vector3) -> Dictionary:
	return cost_for_length(length(deck(a, b)))

static func landing(nav, at: Vector3) -> Variant:
	if not at.is_finite(): return null
	# Never select a different floor merely because its X/Z coordinates match.
	for y in range(floori(at.y) - 1, ceili(at.y) + 2):
		var cell := Vector3i(roundi(at.x), y, roundi(at.z))
		if nav.walkable(cell) and absf(nav.surface_height(cell, at) - at.y) < 0.08:
			return cell
	return null

static func valid_record(record: Variant) -> bool:
	if not record is Dictionary: return false
	for key in ["start", "end"]:
		if not record.get(key) is Vector3 or not record[key].is_finite(): return false
	for key in ["a", "b"]:
		if not record.get(key) is Vector3i: return false
		if not preload("res://data/settlement/catalog.gd").in_bounds(record[key]): return false
		var p: Vector3 = record.start if key == "a" else record.end
		if absf(p.x - record[key].x) > 0.51 or absf(p.z - record[key].z) > 0.51 or absf(p.y - record[key].y) > 0.6: return false
	var span := Vector2(record.end.x - record.start.x, record.end.z - record.start.z).length()
	if span < MIN_SPAN or span > MAX_SPAN or record.a == record.b: return false
	if record.get("curve_version", 1) not in [1, 2]: return false
	var points := curve(record)
	for i in range(1, points.size()):
		var d: Vector3 = points[i] - points[i - 1]
		if absf(d.y) / maxf(Vector2(d.x, d.z).length(), 0.001) > MAX_GRADE: return false
	return true

static func supported_landing(world, at: Vector3) -> bool:
	var cell: Variant = landing(world.navigation, at)
	if cell == null: return false
	if world.ground.has(cell): return true
	# Roof navigation tiles touch the roof perimeter, but their whole tile area
	# is not necessarily physical support for freely positioned anchor posts.
	var on_roof := false
	for base: Vector3i in world.buildings:
		var building: Dictionary = world.buildings[base]
		if building.kind not in world.Catalog.ROOFS: continue
		if absf(at.y - base.y - world.Catalog.building_height(building.kind)) > 0.08: continue
		var rect: Rect2 = world.Farming.footprint(building.kind, base, building.get("placement_offset", Vector3.ZERO), int(building.get("direction",0)))
		if rect.has_point(Vector2(at.x,at.z)): return true
		if rect.grow(0.5).has_point(Vector2(at.x,at.z)): on_roof = true
	for base: Vector3i in world.platforms:
		if absf(at.y - base.y) > 0.08: continue
		var rect: Rect2 = world.Farming.footprint("platform",base)
		if rect.has_point(Vector2(at.x,at.z)): return true
		if rect.grow(0.5).has_point(Vector2(at.x,at.z)): on_roof = true
	return not on_roof

static func error(world, a: Vector3, b: Vector3, ignored_id := -1, curve_version := 2) -> String:
	if not a.is_finite() or not b.is_finite(): return "Choose a supported landing"
	var first: Variant = landing(world.navigation, a)
	var last: Variant = landing(world.navigation, b)
	if first == null or last == null: return "Choose a clear landing"
	var record := {"start": a, "end": b, "a": first, "b": last, "curve_version": curve_version}
	if not valid_record(record): return "Span or slope exceeds bridge limits"
	var existing: Array = []
	for id: int in world.bridges:
		if id != ignored_id: existing.append(world.bridges[id])
	for plan: Dictionary in world.plans.values():
		if plan.kind == "rope_bridge" and plan.id != ignored_id: existing.append(plan.bridge)
	for other: Dictionary in existing:
		if (other.a == first and other.b == last) or (other.b == first and other.a == last): return "These landings are already connected"
	var points := curve(record)
	var side := (b - a).cross(Vector3.UP).normalized() * (WIDTH * 0.5 + 0.12)
	var structures: Array = []
	for cell: Vector3i in world.buildings:
		var entry: Dictionary = world.buildings[cell].duplicate(); entry.cell = cell; structures.append(entry)
	for plan: Dictionary in world.plans.values():
		if plan.kind != "rope_bridge" and not plan.get("deconstruction", false): structures.append(plan)
	var volumes: Array = []
	var building_cells := {}
	for structure: Dictionary in structures:
		if structure.kind not in world.Catalog.ROOFS and structure.kind != "platform": continue
		for cell: Vector3i in world.Farming.cells(structure.kind,structure.cell,int(structure.get("direction",0)),structure.get("placement_offset",Vector3.ZERO)):
			building_cells[cell] = true
		volumes.append({"rect": world.Farming.footprint(structure.kind, structure.cell, structure.get("placement_offset", Vector3.ZERO), int(structure.get("direction", 0))),
			"bottom": structure.cell.y - (0.12 if structure.kind == "platform" else 0.0),
			"top": structure.cell.y if structure.kind == "platform" else structure.cell.y + world.Catalog.building_height(structure.kind)})
	var columns := {}
	for cell: Vector3i in world.ground:
		var column := Vector2i(cell.x, cell.z)
		if not columns.has(column): columns[column] = []
		columns[column].append(cell)
	for endpoint: Vector3 in [a, b]:
		for sign_ in [-1, 0, 1]:
			if not supported_landing(world, endpoint + side * sign_): return "Landing needs room for both anchors"
	for p: Vector3 in points:
		for shift in [-side, Vector3.ZERO, side]:
			var sample: Vector3 = p + shift
			for cell: Vector3i in columns.get(Vector2i(roundi(sample.x), roundi(sample.z)), []):
				if world.navigation.surface_height(cell, sample) > p.y + 0.05: return "Bridge crosses terrain"
			for cell: Vector3i in world.navigation.blocked:
				if building_cells.has(cell): continue # Exact footprint/height below.
				if absf(sample.x - cell.x) < 0.5 and absf(sample.z - cell.z) < 0.5 and p.y < cell.y + 2.0 and p.y + 1.5 > cell.y: return "Bridge crosses a building"
			for volume: Dictionary in volumes:
				if volume.rect.has_point(Vector2(sample.x, sample.z)) and p.y < volume.top - 0.02 and p.y + 1.5 > volume.bottom: return "Bridge crosses a building"
	for other: Dictionary in existing:
		if intersects(record, other): return "Bridge needs clearance from the other span"
	return ""

static func intersects(first: Dictionary, second: Dictionary) -> bool:
	var bounds := Rect2(Vector2(first.start.x, first.start.z), Vector2(first.end.x - first.start.x, first.end.z - first.start.z)).abs().grow(WIDTH + 0.18)
	var other_bounds := Rect2(Vector2(second.start.x, second.start.z), Vector2(second.end.x - second.start.x, second.end.z - second.start.z)).abs().grow(0.01)
	if not bounds.intersects(other_bounds): return false
	var left := curve(first); var right := curve(second)
	for i in range(1, left.size()):
		for j in range(1, right.size()):
			var a: Vector3 = left[i - 1]; var b: Vector3 = left[i]
			var c: Vector3 = right[j - 1]; var d: Vector3 = right[j]
			var a2 := Vector3(a.x, 0, a.z); var b2 := Vector3(b.x, 0, b.z)
			var c2 := Vector3(c.x, 0, c.z); var d2 := Vector3(d.x, 0, d.z)
			var closest := Geometry3D.get_closest_points_between_segments(a2, b2, c2, d2)
			if closest[0].distance_to(closest[1]) >= WIDTH + 0.18: continue
			var t := clampf((closest[0] - a2).dot(b2 - a2) / maxf(a2.distance_squared_to(b2), 0.00001), 0, 1)
			var u := clampf((closest[1] - c2).dot(d2 - c2) / maxf(c2.distance_squared_to(d2), 0.00001), 0, 1)
			var p := a.lerp(b, t); var q := c.lerp(d, u)
			if absf(p.y - q.y) >= 1.7: continue
			return true
	return false

static func request(world, a: Vector3, b: Vector3) -> bool:
	world.last_message = error(world, a, b)
	if not world.last_message.is_empty(): return false
	if not world.debug_mode and (not world.unlocked_materials.has("rope") or not world.unlocked_materials.has("plank")):
		world.last_message = "Build a Rope maker and Sawmill first"; return false
	var id: int = world.next_plan_id
	world.next_plan_id += 1
	var materials := cost(a, b)
	var record := {"start": a, "end": b, "a": landing(world.navigation, a), "b": landing(world.navigation, b), "curve_version": 2}
	world.plans[id] = {"id": id, "kind": "rope_bridge", "cell": record.a, "direction": 0,
		"installed": 0, "required": int(materials.plank) + int(materials.rope), "reserved": 0,
		"materials": materials, "used": {}, "claims": {}, "bridge": record}
	world.revision += 1
	return true

static func complete(world, plan: Dictionary) -> void:
	world.bridges[plan.id] = plan.bridge.duplicate(true)
	world.bridges[plan.id].materials = plan.materials.duplicate()
	world.plans.erase(plan.id)
	for worker: Dictionary in world.workers:
		if worker.get("assigned_plan_id", -1) == plan.id: worker.assigned_plan_id = -1
	world.rebuild_navigation()

static func configure(world) -> void:
	if world.bridges.is_empty(): return
	var nav = world.navigation
	for bridge: Dictionary in world.bridges.values():
		if landing(nav, bridge.start) != bridge.a or landing(nav, bridge.end) != bridge.b: continue
		var points: Array = [nav.surface_point(bridge.a)]
		for point: Vector3 in curve(bridge) + [nav.surface_point(bridge.b)]:
			if points.back().distance_to(point) > 0.0001: points.append(point)
		# Shared authored-path traversal already handles stairs and room doorways.
		Paths.add_path(nav, bridge.a, bridge.b, points)
		Paths.link(nav.edges, bridge.a, bridge.b)
		# Bridges attach after the ordinary graph rebuild. Remember their ends
		# so removing a span clears its old edges during the next local update.
		nav._built_connectors[bridge.a] = true
		nav._built_connectors[bridge.b] = true
	nav._searches.clear()
	nav._edge_lengths.clear()
	nav._rebuild_components()

static func occupied(world, bridge: Dictionary) -> bool:
	for worker: Dictionary in world.workers:
		var route: Array = worker.get("clearance_route", worker.route)
		var index: int = worker.get("clearance_index", worker.route_index)
		if index >= route.size(): continue
		var next: Vector3i = route[index]
		if (worker.cell == bridge.a and next == bridge.b) or (worker.cell == bridge.b and next == bridge.a): return true
	return false

static func crossing(world, worker: Dictionary) -> bool:
	if world.bridges.is_empty(): return false
	var route: Array = worker.get("clearance_route", worker.route)
	var index: int = worker.get("clearance_index", worker.route_index)
	if index >= route.size(): return false
	for bridge: Dictionary in world.bridges.values():
		if ((worker.cell == bridge.a and route[index] == bridge.b) or (worker.cell == bridge.b and route[index] == bridge.a)) and worker.position.distance_to(world.navigation.surface_point(worker.cell)) > 0.01: return true
	return false

static func can_step(world, worker: Dictionary, next: Vector3i) -> bool:
	if world.bridges.is_empty(): return true
	if crossing(world, worker): return true
	for bridge: Dictionary in world.bridges.values():
		if not ((worker.cell == bridge.a and next == bridge.b) or (worker.cell == bridge.b and next == bridge.a)): continue
		for other: Dictionary in world.workers:
			if other.id == worker.id or not crossing(world, other): continue
			var route: Array = other.get("clearance_route", other.route)
			var index: int = other.get("clearance_index", other.route_index)
			if other.cell in [bridge.a, bridge.b] and route[index] in [bridge.a, bridge.b]: return false
	return true

static func remove(world, id: int) -> bool:
	if not world.bridges.has(id): return false
	if occupied(world, world.bridges[id]):
		world.last_message = "Bridge in use"; return false
	var old: Dictionary = world.bridges[id]
	recover(world, old.a, old.get("materials", record_cost(old)))
	world.bridges.erase(id)
	world.last_message = ""
	world.rebuild_navigation()
	return true

static func get_record(world, id: int) -> Dictionary:
	return world.bridges.get(id, world.plans.get(id, {}).get("bridge", {}))

static func recover(world, at: Vector3i, materials: Dictionary) -> void:
	# Normal salvage preserves physical pickup, reservations and persistence.
	for resource: String in materials:
		if int(materials[resource]) == 0: continue
		world.Deconstruction.drop_cargo(world, {"cell": at, "cargo": resource, "cargo_amount": int(materials[resource])})

static func move_end(world, id: int, endpoint: int, at: Vector3) -> int:
	var old := get_record(world, id)
	if old.is_empty() or endpoint not in [0, 1]: return -1
	if world.bridges.has(id) and occupied(world, old):
		world.last_message = "Bridge in use"; return -1
	var a: Vector3 = at if endpoint == 0 else old.start
	var b: Vector3 = at if endpoint == 1 else old.end
	world.last_message = error(world, a, b, id)
	if not world.last_message.is_empty(): return -1
	if not world.building_unlocked("rope_bridge"):
		world.last_message = "Build the material producers first"; return -1
	if world.bridges.has(id): remove(world, id)
	elif not world.delete_plan(id): return -1
	if not request(world, a, b): return -1
	return world.next_plan_id - 1

static func protects(world, cell: Vector3i, columns := false) -> bool:
	var records: Array = world.bridges.values()
	for plan: Dictionary in world.plans.values():
		if plan.kind == "rope_bridge": records.append(plan.bridge)
	for bridge: Dictionary in records:
		var side: Vector3 = (bridge.end - bridge.start).cross(Vector3.UP).normalized() * 0.57
		for p: Vector3 in [bridge.start, bridge.end]:
			for offset in [-side, Vector3.ZERO, side]:
				var point: Vector3 = p + offset
				if roundi(point.x) == cell.x and roundi(point.z) == cell.z and (columns or absf(point.y - cell.y) < 0.6): return true
	return false

static func supports_bridge(world, base: Vector3i, kind: String) -> bool:
	if kind not in world.Catalog.ROOFS and kind != "platform": return false
	var height: int = 0 if kind == "platform" else int(world.Catalog.building_height(kind))
	for cell: Vector3i in world.Farming.cells(kind, base, int(world.buildings.get(base, {}).get("direction", 0))):
		if protects(world, cell + Vector3i.UP * height): return true
	return false

static func construction_error(world, kind: String, cell: Vector3i, direction: int, offset: Vector3) -> String:
	if world.bridges.is_empty() and not world.plans.values().any(func(p): return p.kind == "rope_bridge"): return ""
	if kind not in world.Catalog.ROOFS and kind != "platform": return ""
	var rect: Rect2 = world.Farming.footprint(kind, cell, offset, direction).grow(WIDTH * 0.5)
	var bottom := float(cell.y) - (0.12 if kind == "platform" else 0.0)
	var top: float = cell.y if kind == "platform" else cell.y + world.Catalog.building_height(kind)
	var records: Array = world.bridges.values()
	for plan: Dictionary in world.plans.values():
		if plan.kind == "rope_bridge": records.append(plan.bridge)
	for bridge: Dictionary in records:
		for p: Vector3 in curve(bridge):
			if rect.has_point(Vector2(p.x, p.z)) and p.y < top + 0.05 and p.y + 1.5 > bottom: return "Keep the bridge clear"
	return ""
