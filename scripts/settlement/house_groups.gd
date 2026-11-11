extends RefCounted
## One connected house, with physical room addresses retained for labour and saves.
const ROOM_RESIDENTS := 1
const ROOM_FOOD := 4
const ROOM_STORAGE := 32
const Grid = preload("res://scripts/settlement/world_grid.gd")
const SIDES := [Vector3i.BACK, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.RIGHT]

static func is_house(model, cell: Vector3i) -> bool:
	return model.buildings.get(cell, {}).get("kind") == "house"

static func linked(a: Vector3i, a_direction: int, b: Vector3i, b_direction: int) -> bool:
	var difference := b - a
	if difference.y != 0: return false
	# A doorway facing the other room establishes a connection. Wall contact
	# alone leaves two independent houses, even when their footprints touch.
	return difference == SIDES[posmod(a_direction, 4)] * Grid.CELLS_PER_ROOM or -difference == SIDES[posmod(b_direction, 4)] * Grid.CELLS_PER_ROOM

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

static func stamp(model, start: Vector3i, rooms: Array[Vector3i] = []) -> Array:
	var result: Array = []
	var direction: int = model.buildings[start].direction
	for cell in (members(model, start) if rooms.is_empty() else rooms):
		result.append({"source": cell, "relative": cell - start, "direction": int(model.buildings[cell].direction), "base_direction": direction,"offset_delta":model.buildings[cell].get("placement_offset",Vector3.ZERO)-model.buildings[start].get("placement_offset",Vector3.ZERO)})
	return result

static func targets(stamp_: Array, target: Vector3i, direction: int) -> Array:
	var result: Array = []
	for room: Dictionary in stamp_:
		var turns := posmod(direction - int(room.base_direction), 4)
		var relative: Vector3i = room.relative
		for turn in turns: relative = Vector3i(-relative.z, relative.y, relative.x)
		result.append({"source": room.source, "cell": target + relative, "direction": posmod(int(room.direction) + turns, 4),"offset_delta":Vector3(room.get("offset_delta",Vector3.ZERO)).rotated(Vector3.UP,-turns*PI/2)})
	return result

static func placement_error(model, stamp_: Array, target: Vector3i, direction: int, offset: Vector3, moving := false) -> String:
	if not moving and not model.building_unlocked("house"): return "Build the material producer first"
	for room: Dictionary in targets(stamp_, target, direction):
		var error: String = model.Relocation.destination_error(model, room.source, room.cell, room.direction, offset+room.offset_delta) if moving else model.build_error("house", room.cell, room.direction, offset+room.offset_delta)
		if not error.is_empty(): return error
	return ""

static func stamp_offset(model, stamp_: Array, target: Vector3i, direction: int, offset: Vector3) -> Vector3:
	for room: Dictionary in targets(stamp_, target, direction):
		var snapped := snap_offset(model, room.cell, room.direction, offset+room.offset_delta)
		if snapped != offset+room.offset_delta: return snapped-room.offset_delta
	return offset

static func request(model, stamp_: Array, target: Vector3i, direction: int, offset: Vector3, moving := false) -> bool:
	model.last_message = placement_error(model, stamp_, target, direction, offset, moving)
	if not model.last_message.is_empty(): return false
	# Validate the whole footprint before any plans or reservations change.
	for room: Dictionary in targets(stamp_, target, direction):
		if moving: model.Relocation.request(model, room.source, room.cell, room.direction, offset+room.offset_delta)
		else: model.request_build("house", room.cell, room.direction, offset+room.offset_delta, false)
	return true

static func remove(model, start: Vector3i, rooms: Array[Vector3i] = []) -> bool:
	if rooms.is_empty(): rooms = members(model, start)
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

static func totals(model, start: Vector3i, rooms: Array[Vector3i] = []) -> Dictionary:
	var result := {"residents": 0, "capacity": 0, "food": 0, "food_capacity": 0}
	for cell in (members(model, start) if rooms.is_empty() else rooms):
		result.residents += room_occupancy(model, cell)
		result.capacity += ROOM_RESIDENTS
		if model.stores.has(cell):
			result.food += model.stores[cell].count("food")
			result.food_capacity += ROOM_FOOD
	return result

static func reconcile(model) -> void:
	# Keep each resident's room identity through saves and connected-room changes.
	var occupied := {}
	for cell: Vector3i in model.buildings:
		if not is_house(model, cell): continue
		if not model.stores.has(cell):
			model.add_store(cell)
		model.stores[cell].capacity = maxi(ROOM_STORAGE, model.stores[cell].total())
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

static func construction_quote(world, cell: Vector3i, direction: int, offset: Vector3) -> Dictionary:
	var materials: Dictionary = world.Catalog.recipe("house").duplicate()
	var connected: Array[Vector3i] = []
	for side: Vector3i in SIDES:
		var next := cell + side * Grid.CELLS_PER_ROOM
		if not is_house(world, next) or world.Relocation.locked(world, next): continue
		if not linked(cell, direction, next, world.buildings[next].direction): continue
		if not offset.is_equal_approx(world.buildings[next].get("placement_offset", Vector3.ZERO)): continue
		for member: Vector3i in members(world, next):
			if member not in connected and not world.Relocation.locked(world, member): connected.append(member)
	var providers: Array[Vector3i] = []; var shared := 0
	for sign_: Vector3i in [Vector3i(-1, 0, -1), Vector3i(1, 0, -1), Vector3i(1, 0, 1), Vector3i(-1, 0, 1)]:
		var corner := cell + sign_
		for member: Vector3i in connected:
			var delta := corner - member
			if delta.y == 0 and absi(delta.x) == 1 and absi(delta.z) == 1:
				shared += 1
				if member not in providers: providers.append(member)
				break
	var brace_logs := preload("res://scripts/settlement/home_stack.gd").log_cost(world,cell,offset)
	var logs := int(materials.get("log", 0))
	# Four corner posts share the House's timber budget; round new work upwards.
	var new_logs := ceili(logs * (4 - shared) / 4.0)
	if new_logs+brace_logs > 0: materials.log = new_logs+brace_logs
	else: materials.erase("log")
	return {"materials": materials, "providers": providers, "posts": shared, "saving": logs - new_logs}

static func price_plan(world, plan: Dictionary) -> void:
	if plan.get("house_upgrade", false) or plan.kind != "house" or not plan.get("reviewed", false) or plan.has("relocation") or plan.has("shared_frame"): return
	if plan.installed != 0 or plan.reserved != 0 or not plan.used.is_empty() or not plan.claims.is_empty(): return
	if plan.has("delivered") and plan.delivered.total() > 0: return
	var quote := construction_quote(world, plan.cell, plan.direction, plan.get("placement_offset", Vector3.ZERO))
	if quote.saving <= 0 and quote.materials==plan.materials: return
	plan.materials = quote.materials
	plan.required = 0
	for amount: int in plan.materials.values(): plan.required += amount
	if quote.posts>0: plan.shared_frame = {"providers": quote.providers, "posts": quote.posts}

static func frame_needed(world, cell: Vector3i) -> bool:
	for plan: Dictionary in world.plans.values():
		if cell in plan.get("shared_frame", {}).get("providers", []): return true
	return false
