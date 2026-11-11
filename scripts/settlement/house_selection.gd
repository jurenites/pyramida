extends RefCounted
## Inspection ownership is independent of walking routes and same-floor roof joins.
const Houses = preload("res://scripts/settlement/house_groups.gd")
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Tiers = preload("res://scripts/settlement/house_tiers.gd")

static func is_house(target: Dictionary) -> bool:
	return target.get("kind") == "house" and target.has("cell") and not str(target.get("entity_key", "")).begins_with("plan:")

static func structure(model, start: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if not Houses.is_house(model, start): return result
	var pending: Array[Vector3i] = [start]
	var seen := {start: true}
	while not pending.is_empty():
		var cell: Vector3i = pending.pop_back()
		result.append(cell)
		var adjacent := Houses.members(model, cell)
		for step: Vector3i in [Grid.STOREY, -Grid.STOREY]:
			var next := cell + step
			if not Houses.is_house(model, next): continue
			var lower := cell if step.y > 0 else next
			if Tiers.tier(model.buildings[lower]) < 2: continue
			adjacent.append(next)
		for next: Vector3i in adjacent:
			if seen.has(next): continue
			seen[next] = true
			pending.append(next)
	result.sort_custom(func(a, b): return a.y < b.y if a.y != b.y else (a.x < b.x if a.x != b.x else a.z < b.z))
	return result

static func members(model, target: Dictionary) -> Array[Vector3i]:
	if not is_house(target): return []
	var rooms := structure(model, target.cell)
	match target.get("house_scope", "structure"):
		"floor": return rooms.filter(func(cell): return cell.y == target.cell.y)
		"room": return rooms.filter(func(cell): return cell == target.cell)
	return rooms

static func select(model, previous: Dictionary, hit: Dictionary) -> Dictionary:
	if not is_house(hit): return hit
	var result := hit.duplicate()
	var rooms := structure(model, hit.cell)
	var scope := "structure"
	if is_house(previous) and previous.cell in rooms:
		if previous.get("house_scope", "structure") == "structure" or previous.cell.y != hit.cell.y:
			scope = "floor"
		else:
			scope = "room"
	result.house_scope = scope
	return result

static func key(model, target: Dictionary) -> String:
	var rooms := members(model, target)
	return "house:%s:%s" % [target.get("house_scope", "structure"), rooms[0]] if not rooms.is_empty() else ""

static func covers(model, selection: Dictionary, target: Dictionary) -> bool:
	return is_house(selection) and is_house(target) and target.cell in members(model, selection)

static func source_error(model, selection: Dictionary) -> String:
	for cell in members(model, selection):
		var error: String = model.Relocation.source_error(model, cell)
		if not error.is_empty(): return error
	return ""
