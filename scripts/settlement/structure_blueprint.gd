extends RefCounted
## Authoring data uses occupied world cells, never a rectangular collision proxy.
## One work unit is one worker-second; hauling is outside this authoring estimate.
const Desires = preload("res://scripts/desire_state.gd")
const Parts = preload("res://scripts/settlement/structure_parts.gd")
const Life = preload("res://scripts/settlement/structure_life.gd")
const MIN_LEVEL := -6
const MAX_LEVEL := 12
const RADIUS := 12
const MATERIALS := ["stone", "timber", "clay"]
const SIDES := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK]
const MAX_CELLS := 2048
const MAX_INSTANCES := 64

static func empty(title := "Untitled structure") -> Dictionary:
	return {"name": title, "cells": {}, "braces": [], "work_per_cell": 6.0, "work_per_brace": 3.0}

static func in_bounds(cell: Vector3i) -> bool:
	return absi(cell.x) <= RADIUS and absi(cell.z) <= RADIUS and cell.y >= MIN_LEVEL and cell.y <= MAX_LEVEL

static func rotate_cell(cell: Vector3i, turns: int) -> Vector3i:
	for index in posmod(turns, 4):
		cell = Vector3i(-cell.z, cell.y, cell.x)
	return cell

static func transformed(blueprint: Dictionary, origin: Vector3i, turns: int) -> Dictionary:
	var result := empty(blueprint.name)
	result.desires = blueprint.get("desires", {}).duplicate(true)
	result.work_per_cell = blueprint.work_per_cell
	result.work_per_brace = blueprint.work_per_brace
	for cell: Vector3i in blueprint.cells:
		result.cells[rotate_cell(cell, turns) + origin] = blueprint.cells[cell]
	for brace: Dictionary in blueprint.braces:
		result.braces.append({"from": rotate_cell(brace.from, turns) + origin, "to": rotate_cell(brace.to, turns) + origin})
	if blueprint.has("door"):
		result.door = {}
		if not blueprint.door.is_empty():
			result.door = {"cell": rotate_cell(blueprint.door.cell, turns) + origin, "side": rotate_cell(blueprint.door.side, turns)}
	for field in ["utilities", "ladders", "extra_doors"]:
		result[field] = []
		for entry: Dictionary in blueprint.get(field, []):
			var copy := entry.duplicate(true)
			copy.cell = rotate_cell(entry.cell, turns) + origin
			copy.side = rotate_cell(entry.side, turns)
			result[field].append(copy)
	Life.normalize(result)
	return result

static func valid_brace(a: Vector3i, b: Vector3i) -> bool:
	var offset := b - a
	return offset.y == 1 and absi(offset.x) + absi(offset.z) == 1

static func merged(instances: Array, extra: Dictionary = {}) -> Dictionary:
	var result := empty("Assembly")
	for item: Dictionary in instances:
		result.cells.merge(item.cells)
		result.braces.append_array(item.braces)
	if not extra.is_empty():
		result.cells.merge(extra.cells)
		result.braces.append_array(extra.braces)
	return result

static func joined(buildings: Array, selected: int) -> Dictionary:
	# Coalesce only actual same-floor door links, never touching walls or roofs.
	var members: Array[int] = [selected]
	var cursor := 0
	while cursor < members.size():
		var current: Dictionary = buildings[members[cursor]]
		cursor += 1
		for index in buildings.size():
			if index in members: continue
			var neighbour: Dictionary = buildings[index]
			var linked := false
			for door: Dictionary in Life.doors(current):
				if neighbour.cells.has(door.cell + door.side): linked = true
			for door: Dictionary in Life.doors(neighbour):
				if current.cells.has(door.cell + door.side): linked = true
			if linked: members.append(index)
	if members.size() == 1: return {"instances": buildings, "selected": selected}
	members.sort()
	var result := empty(buildings[members[0]].name)
	var entrances: Array = []
	var cell_work := 0.0
	var brace_work := 0.0
	result.desires = {}
	result.utilities = []
	result.ladders = []
	for index in members:
		var building: Dictionary = buildings[index]
		for field in ["hot", "thirsty", "requires_electricity"]:
			result.desires[field] = result.desires.get(field, false) or building.get("desires", {}).get(field, false)
		if building.get("desires", {}).get("requires_electricity", false):
			result.desires.electricity_connected = result.desires.get("electricity_connected", true) and building.desires.get("electricity_connected", false)
		result.cells.merge(building.cells)
		result.braces.append_array(building.braces.duplicate(true))
		result.utilities.append_array(building.get("utilities", []).duplicate(true))
		result.ladders.append_array(building.get("ladders", []).duplicate(true))
		entrances.append_array(Life.doors(building).duplicate(true))
		cell_work += building.cells.size() * float(building.work_per_cell)
		brace_work += building.braces.size() * float(building.work_per_brace)
	# Keep every exterior entrance; the joining door becomes interior space.
	entrances = entrances.filter(func(entry): return Life.exposed_door(result, entry))
	if entrances.is_empty() or result.cells.size() > MAX_CELLS:
		return {"instances": buildings, "selected": selected}
	result.door = entrances.pop_front()
	result.extra_doors = entrances
	result.work_per_cell = cell_work / result.cells.size()
	result.work_per_brace = brace_work / result.braces.size() if not result.braces.is_empty() else buildings[members[0]].work_per_brace
	Life.normalize(result)
	var output: Array = []
	var joined_index := 0
	for index in buildings.size():
		if index == members[0]:
			joined_index = output.size()
			output.append(result)
		elif index not in members: output.append(buildings[index])
	return {"instances": output, "selected": joined_index}

static func unsupported(assembly: Dictionary) -> Array[Vector3i]:
	var stable := {}
	var anchors := {}
	for brace: Dictionary in assembly.braces:
		if valid_brace(brace.from, brace.to):
			if not anchors.has(brace.to):
				anchors[brace.to] = []
			anchors[brace.to].append(brace.from)
	var result: Array[Vector3i] = []
	var ordered: Array = assembly.cells.keys()
	ordered.sort_custom(func(a: Vector3i, b: Vector3i): return a.y < b.y)
	for cell: Vector3i in ordered:
		# This workshop exposes excavated below-grade volumes against earth bearings.
		# Terrain excavation and structural capacity are separate simulation systems.
		var supported: bool = cell.y <= 0 or stable.has(cell + Vector3i.DOWN)
		if not supported:
			for anchor: Vector3i in anchors.get(cell, []):
				if stable.has(anchor):
					supported = true
					break
		if supported:
			stable[cell] = true
		else:
			result.append(cell)
	return result

static func placement_error(blueprint: Dictionary, instances: Array) -> String:
	if blueprint.cells.is_empty():
		return "Add at least one occupied unit."
	if instances.size() >= MAX_INSTANCES:
		return "The test assembly is full (64 buildings)."
	var assembly := merged(instances)
	for cell: Vector3i in blueprint.cells:
		if not in_bounds(cell):
			return "Outside the workshop: X/Z ±12, levels −6 to 12."
		if assembly.cells.has(cell):
			return "Occupied units overlap. Move or rotate the building."
	assembly = merged(instances, blueprint)
	for brace: Dictionary in assembly.braces:
		if not assembly.cells.has(brace.from) or not assembly.cells.has(brace.to):
			return "A brace endpoint needs an occupied unit."
	var floating := unsupported(assembly)
	if not floating.is_empty():
		return "%d unsupported units. Add a floor below or diagonal braces." % floating.size()
	for building: Dictionary in instances + [blueprint]:
		for utility: Dictionary in building.get("utilities", []):
			if not Life.attachment_error(building, assembly.cells, utility, true).is_empty():
				return "Keep installed utilities clear and supported."
	return Life.access_error(instances + [blueprint])

static func suggest_braces(blueprint: Dictionary, instances: Array) -> Array:
	var assembly := merged(instances, blueprint)
	var additions: Array = []
	# Resolve lower units first, so new braces can safely carry higher units.
	var floating := unsupported(assembly)
	for cell: Vector3i in floating:
		if not blueprint.cells.has(cell):
			continue
		for side: Vector3i in SIDES:
			var anchor := cell + Vector3i.DOWN + side
			if assembly.cells.has(anchor) and anchor not in unsupported(assembly):
				var brace := {"from": anchor, "to": cell}
				assembly.braces.append(brace)
				additions.append(brace)
				break
	return additions

static func work(blueprint: Dictionary) -> float:
	return blueprint.cells.size() * float(blueprint.work_per_cell) + blueprint.braces.size() * float(blueprint.work_per_brace)

static func bounds(blueprint: Dictionary) -> Vector3i:
	if blueprint.cells.is_empty():
		return Vector3i.ZERO
	var low: Vector3i = blueprint.cells.keys()[0]
	var high := low
	for cell: Vector3i in blueprint.cells:
		low = Vector3i(mini(low.x, cell.x), mini(low.y, cell.y), mini(low.z, cell.z))
		high = Vector3i(maxi(high.x, cell.x), maxi(high.y, cell.y), maxi(high.z, cell.z))
	return high - low + Vector3i.ONE

static func preset(index: int) -> Dictionary:
	var result := empty(["Corner house", "T-shaped hall", "Stepped tower", "Courtyard", "Cellar house", "Single unit"][index])
	var cells: Array[Vector3i] = []
	match index:
		0: cells.assign([Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)])
		1: cells.assign([Vector3i(-1, 0, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)])
		2:
			for x in 3:
				for y in 3 - x:
					cells.append(Vector3i(x, y, 0))
		3:
			for x in range(-1, 2):
				for z in range(-1, 2):
					if x != 0 or z != 0:
						cells.append(Vector3i(x, 0, z))
		4:
			for y in range(-2, 1):
				cells.append(Vector3i(0, y, 0))
			cells.append(Vector3i(1, 0, 0))
		5: cells.append(Vector3i.ZERO)
	for cell in cells:
		result.cells[cell] = "stone"
	Life.normalize(result)
	return result

static func encode(blueprint: Dictionary) -> Dictionary:
	var cells: Array = []
	for cell: Vector3i in blueprint.cells:
		cells.append({"at": [cell.x, cell.y, cell.z], "material": blueprint.cells[cell]})
	var braces: Array = []
	for brace: Dictionary in blueprint.braces:
		braces.append({"from": [brace.from.x, brace.from.y, brace.from.z], "to": [brace.to.x, brace.to.y, brace.to.z]})
	var result := {"name": blueprint.name, "cells": cells, "braces": braces,
		"work_per_cell": blueprint.work_per_cell, "work_per_brace": blueprint.work_per_brace}
	result.desires = blueprint.get("desires", {}).duplicate(true)
	for field in ["door", "extra_doors", "utilities", "ladders"]:
		var entries: Array = [blueprint.get("door", Life.default_door(blueprint.cells))] if field == "door" else blueprint.get(field, [])
		var encoded: Array = []
		for entry: Dictionary in entries:
			if entry.is_empty(): continue
			var copy := entry.duplicate(true)
			for key in ["cell", "side"]: copy[key] = [entry[key].x, entry[key].y, entry[key].z]
			if entry.has("offset"): copy.offset = [entry.offset.x, entry.offset.y]
			encoded.append(copy)
		result[field] = encoded
	return result

static func _coordinate(value: Variant, offset := false) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)) or float(number) != floorf(float(number)) or absf(float(number)) > 100:
			return false
	var cell := Vector3i(int(value[0]), int(value[1]), int(value[2]))
	if offset:
		return absi(cell.x) <= RADIUS * 2 and absi(cell.z) <= RADIUS * 2 and absi(cell.y) <= MAX_LEVEL - MIN_LEVEL
	return in_bounds(cell)

static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("name") is String or value.name.length() > 80:
		return {}
	if not value.get("cells") is Array or value.cells.size() > MAX_CELLS or not value.get("braces") is Array or value.braces.size() > MAX_CELLS:
		return {}
	for field in ["work_per_cell", "work_per_brace"]:
		var amount: Variant = value.get(field)
		if not (amount is int or amount is float) or not is_finite(float(amount)) or amount < 0.1 or amount > 3600:
			return {}
	if not Desires.valid(value.get("desires", {})): return {}
	var result := empty(value.name)
	result.desires = value.get("desires", {}).duplicate(true)
	result.work_per_cell = float(value.work_per_cell)
	result.work_per_brace = float(value.work_per_brace)
	for entry: Variant in value.cells:
		if not entry is Dictionary or not _coordinate(entry.get("at")) or entry.get("material") not in MATERIALS:
			return {}
		var cell := Vector3i(int(entry.at[0]), int(entry.at[1]), int(entry.at[2]))
		if result.cells.has(cell):
			return {}
		result.cells[cell] = entry.material
	for entry: Variant in value.braces:
		if not entry is Dictionary or not _coordinate(entry.get("from")) or not _coordinate(entry.get("to")):
			return {}
		var a := Vector3i(int(entry.from[0]), int(entry.from[1]), int(entry.from[2]))
		var b := Vector3i(int(entry.to[0]), int(entry.to[1]), int(entry.to[2]))
		var brace := {"from": a, "to": b}
		if not valid_brace(a, b) or brace in result.braces:
			return {}
		result.braces.append(brace)
	for field in ["door", "extra_doors", "utilities", "ladders"]:
		var entries: Variant = value.get(field, [])
		if not entries is Array or entries.size() > (1 if field == "door" else MAX_CELLS): return {}
		var decoded: Array = []
		for entry: Variant in entries:
			if not entry is Dictionary or not _coordinate(entry.get("cell")) or not _coordinate(entry.get("side")): return {}
			var cell := Vector3i(int(entry.cell[0]), int(entry.cell[1]), int(entry.cell[2]))
			var side := Vector3i(int(entry.side[0]), int(entry.side[1]), int(entry.side[2]))
			if not result.cells.has(cell) or side not in Life.SIDES or result.cells.has(cell + side): return {}
			var copy := {"cell": cell, "side": side}
			if field == "utilities":
				var offset: Variant = entry.get("offset")
				if entry.get("kind") not in Life.KINDS or entry.get("mount") not in ["wall", "ground"] or not offset is Array or offset.size() != 2: return {}
				for number: Variant in offset:
					if not (number is float or number is int) or not is_finite(float(number)): return {}
				if absf(float(offset[0])) > 0.3 or float(offset[1]) < 0.15 or float(offset[1]) > 0.8: return {}
				copy.merge({"kind": entry.kind, "mount": entry.mount, "offset": Vector2(offset[0], offset[1])})
				if not Life.attachment_error(result, result.cells, copy, false, false).is_empty(): return {}
				for previous: Dictionary in decoded:
					if previous.cell == cell and previous.side == side and (previous.offset - copy.offset).length() < 0.42: return {}
			if copy in decoded: return {}
			decoded.append(copy)
		if field == "door":
			result.door = decoded[0] if not decoded.is_empty() else {}
		else: result[field] = decoded
	Life.normalize(result)
	return result

static func document(draft: Dictionary, instances: Array, workspace: Dictionary = {}) -> Dictionary:
	return {"format": "pyramida-structure-workshop", "version": 1,
		"draft": encode(draft), "assembly": instances.map(func(item): return encode(item)), "workspace": workspace}

static func parse_document(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("format") != "pyramida-structure-workshop" or value.get("version") != 1 or not value.get("assembly") is Array or value.assembly.size() > MAX_INSTANCES:
		return {}
	var draft := decode(value.get("draft"))
	if draft.is_empty():
		return {}
	var instances: Array = []
	for entry: Variant in value.assembly:
		var item := decode(entry)
		if item.is_empty():
			return {}
		instances.append(item)
	# Relocation can change bearing order. Validate the complete assembly, not list order.
	var occupied := {}
	for item: Dictionary in instances:
		for cell: Vector3i in item.cells:
			if occupied.has(cell): return {}
			occupied[cell] = true
	var whole := merged(instances)
	if not unsupported(whole).is_empty(): return {}
	for brace: Dictionary in whole.braces:
		if not whole.cells.has(brace.from) or not whole.cells.has(brace.to): return {}
	for item: Dictionary in instances:
		for utility: Dictionary in item.get("utilities", []):
			if not Life.attachment_error(item, whole.cells, utility, true).is_empty(): return {}
	var workspace: Variant = value.get("workspace", {})
	if not workspace is Dictionary:
		return {}
	if not preload("res://scripts/settlement/asset_workspace.gd").valid(workspace.get("authoring", {})): return {}
	if Parts.decode(workspace.get("parts", [])).is_empty() or not workspace.get("piece_editing", false) is bool:
		return {}
	if not preload("res://scripts/settlement/asset_workspace.gd").valid_links(workspace.get("authoring", {}), Parts.decode(workspace.get("parts", [])).parts): return {}
	if workspace.get("building_kind", "") not in [""] + Parts.Appearance.buildings(): return {}
	if not workspace.get("building_drafts", {}) is Dictionary: return {}
	for key: Variant in workspace.get("building_drafts", {}):
		if key not in [""] + Parts.Appearance.buildings() or Parts.decode(workspace.building_drafts[key]).is_empty(): return {}
	if not workspace.get("manual_level", false) is bool:
		return {}
	if not workspace.is_empty():
		if not _coordinate(workspace.get("origin"), true):
			return {}
		for field: String in {"turns": [0, 3], "mode": [0, 1], "layer": [MIN_LEVEL, MAX_LEVEL], "workers": [1, 20]}:
			var limits: Array = {"turns": [0, 3], "mode": [0, 1], "layer": [MIN_LEVEL, MAX_LEVEL], "workers": [1, 20]}[field]
			var number: Variant = workspace.get(field)
			if not (number is int or number is float) or not is_finite(float(number)) or float(number) != floorf(float(number)) or number < limits[0] or number > limits[1]:
				return {}
	return {"draft": draft, "instances": instances, "workspace": workspace}
