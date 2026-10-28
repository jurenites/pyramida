extends RefCounted
## One connected house, with physical room addresses retained for labour and saves.
const ROOM_RESIDENTS := 3
const ROOM_FOOD := 12
const Grid = preload("res://scripts/settlement/world_grid.gd")
const SIDES := [Vector3i.BACK, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.RIGHT]

static func is_house(model, cell: Vector3i) -> bool:
	return model.buildings.get(cell, {}).get("kind") == "house"

static func linked(a: Vector3i, a_direction: int, b: Vector3i, b_direction: int) -> bool:
	return a + SIDES[posmod(a_direction, 4)] * Grid.CELLS_PER_ROOM == b or b + SIDES[posmod(b_direction, 4)] * Grid.CELLS_PER_ROOM == a

static func members(model, start: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if not is_house(model, start): return result
	result.append(start)
	var cursor := 0
	while cursor < result.size():
		var cell := result[cursor]
		cursor += 1
		for side: Vector3i in SIDES:
			var next: Vector3i = cell + side * Grid.CELLS_PER_ROOM
			if next in result or not is_house(model, next): continue
			if not Vector3(model.buildings[cell].get("placement_offset", Vector3.ZERO)).is_equal_approx(model.buildings[next].get("placement_offset", Vector3.ZERO)): continue
			if linked(cell, model.buildings[cell].direction, next, model.buildings[next].direction): result.append(next)
	result.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.z < b.z)
	return result

static func snap_offset(model, cell: Vector3i, direction: int, offset: Vector3) -> Vector3:
	for side: Vector3i in SIDES:
		var next := cell + side * Grid.CELLS_PER_ROOM
		if is_house(model, next) and linked(cell, direction, next, model.buildings[next].direction):
			return model.buildings[next].get("placement_offset", Vector3.ZERO)
	for plan: Dictionary in model.plans.values():
		if plan.kind == "house" and not model.Deconstruction.is_salvage(plan) and linked(cell, direction, plan.cell, plan.direction):
			return plan.get("placement_offset", Vector3.ZERO)
	return offset

static func stamp(model, start: Vector3i) -> Array:
	var result: Array = []
	var direction: int = model.buildings[start].direction
	for cell in members(model, start):
		result.append({"source": cell, "relative": cell - start, "direction": int(model.buildings[cell].direction), "base_direction": direction})
	return result

static func targets(stamp_: Array, target: Vector3i, direction: int) -> Array:
	var result: Array = []
	for room: Dictionary in stamp_:
		var turns := posmod(direction - int(room.base_direction), 4)
		var relative: Vector3i = room.relative
		for turn in turns: relative = Vector3i(-relative.z, relative.y, relative.x)
		result.append({"source": room.source, "cell": target + relative, "direction": posmod(int(room.direction) + turns, 4)})
	return result

static func placement_error(model, stamp_: Array, target: Vector3i, direction: int, offset: Vector3, moving := false) -> String:
	for room: Dictionary in targets(stamp_, target, direction):
		var error: String = model.Relocation.destination_error(model, room.source, room.cell, room.direction, offset) if moving else model.build_error("house", room.cell, room.direction, offset)
		if not error.is_empty(): return error
	return ""

static func stamp_offset(model, stamp_: Array, target: Vector3i, direction: int, offset: Vector3) -> Vector3:
	for room: Dictionary in targets(stamp_, target, direction):
		var snapped := snap_offset(model, room.cell, room.direction, offset)
		if snapped != offset: return snapped
	return offset

static func request(model, stamp_: Array, target: Vector3i, direction: int, offset: Vector3, moving := false) -> bool:
	model.last_message = placement_error(model, stamp_, target, direction, offset, moving)
	if not model.last_message.is_empty(): return false
	# Validate the whole footprint before any plans or reservations change.
	for room: Dictionary in targets(stamp_, target, direction):
		if moving: model.Relocation.request(model, room.source, room.cell, room.direction, offset)
		else: model.request_build("house", room.cell, room.direction, offset, false)
	return true

static func remove(model, start: Vector3i) -> bool:
	var rooms := members(model, start)
	for cell in rooms:
		model.last_message = model.Relocation.source_error(model, cell)
		if not model.last_message.is_empty(): return false
	for cell in rooms:
		model.Relocation.request(model, cell, cell, model.buildings[cell].direction, model.buildings[cell].get("placement_offset", Vector3.ZERO), true)
	return not rooms.is_empty()


static func room_occupancy(model, cell: Vector3i) -> int:
	var count := 0
	for worker: Dictionary in model.workers:
		count += int(worker.get("home_cell") == cell)
	return count

static func totals(model, start: Vector3i) -> Dictionary:
	var result := {"residents": 0, "capacity": 0, "food": 0, "food_capacity": 0}
	for cell in members(model, start):
		result.residents += room_occupancy(model, cell)
		result.capacity += ROOM_RESIDENTS
		if model.stores.has(cell):
			result.food += model.stores[cell].count("food")
			result.food_capacity += model.stores[cell].capacity
	return result

static func reconcile(model) -> void:
	# Keep each resident's room identity through saves and connected-room changes.
	var occupied := {}
	for cell: Vector3i in model.buildings:
		if not is_house(model, cell): continue
		if not model.stores.has(cell):
			model.add_store(cell)
			model.stores[cell].capacity = ROOM_FOOD
	for worker: Dictionary in model.workers:
		var home: Variant = worker.get("home_cell")
		if home is Vector3i and is_house(model, home) and int(occupied.get(home, 0)) < ROOM_RESIDENTS:
			occupied[home] = int(occupied.get(home, 0)) + 1
		else:
			var moving := false
			for plan: Dictionary in model.plans.values():
				if plan.kind == "house" and plan.has("relocation") and not plan.get("deconstruction", false) and plan.relocation.source == home:
					moving = true
			if not moving: worker.erase("home_cell")
	for worker: Dictionary in model.workers:
		if worker.has("home_cell"): continue
		for cell: Vector3i in model.buildings:
			if not is_house(model, cell) or model.Relocation.locked(model, cell) or int(occupied.get(cell, 0)) >= ROOM_RESIDENTS: continue
			if model.navigation.route(worker.cell, cell).is_empty(): continue
			worker.home_cell = cell
			occupied[cell] = int(occupied.get(cell, 0)) + 1
			break
