extends RefCounted
## Colour-only construction lab. No money, building types, upgrades or switch state.
const Utilities = preload("res://scripts/block_city/utility_network.gd")
const Land = preload("res://scripts/block_city/land.gd")
const Cable = preload("res://scripts/block_city/cable.gd")
const Navigation = preload("res://scripts/block_city/room_navigation.gd")
const CONCRETE_WALL := Color("c5c8c3")
const CONCRETE_COLUMN := Color("a5aaa4")
const CONCRETE_FLOOR := Color("858b85")
const HALL_COLOR := CONCRETE_WALL
const STAIR_COLOR := CONCRETE_WALL
const DIRECTIONS := [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
var config: Dictionary
var transformer_cell := Vector3i(-1,0,0)
var utility_links: Array=[]
var defer_analysis := false
var cached_cable_paths: Dictionary={}
var owned_plots: Array = [Land.START]
var rooms: Array = []
var cables: Array = []
var queue: Array = []
var basement_queue: Array = []
var history: Array = []
var shape_uses: Dictionary = {}
var turn := 0
var error := ""

func _init(path := "res://data/block_city/balance.json", source_config: Dictionary = {}) -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(path)) if source_config.is_empty() else source_config
	if source_config.is_empty():
		assert(validate_config().is_empty(), validate_config())
		reset()

func validate_config() -> String:
	if not config.has_all(["colors", "shapes", "plot", "street"]): return "Missing balance sections"
	var total_weight := 0.0
	var ids := {}
	for shape in config.shapes:
		if ids.has(shape.id): return "Duplicate shape ID"
		ids[shape.id] = true
		if not shape.get("weight") is float and not shape.get("weight") is int: return "Each shape needs a numeric weight"
		if float(shape.weight) < 0: return "Weights cannot be negative"
		total_weight += float(shape.weight)
		if shape.cells.size() < 1 or shape.cells.size() > 6: return "Flat rooms must contain one to six cells"
		var cells := {}
		for raw in shape.cells:
			if raw.size() != 3: return "Cells use [x, height, depth]"
			var cell := vec(raw)
			if cell.y != 0 and shape.get("role","")!="pole": return "Room shapes must be one cube high"
			if cells.has(cell): return "Duplicate shape cell"
			cells[cell] = true
		if not cells.has(vec(shape.door)): return "Door must belong to its room"
		if not DIRECTIONS.has(vec(shape.get("normal",[0,0,-1]))): return "Invalid entrance direction"
		if cells.has(vec(shape.door) + vec(shape.get("normal",[0,0,-1]))): return "Door faces an internal cell"
		var visited := {vec(shape.cells[0]): true}
		var pending: Array = visited.keys()
		while not pending.is_empty():
			var p: Vector3i = pending.pop_front()
			for d in DIRECTIONS + [Vector3i.UP, Vector3i.DOWN]:
				if cells.has(p + d) and not visited.has(p + d):
					visited[p + d] = true
					pending.append(p + d)
		if visited.size() != cells.size(): return "Shape must be face-connected"
	if total_weight <= 0: return "Enable at least one shape with a positive weight"
	if not ids.has(config.get("supply", {}).get("starting_shape", "small_square")): return "Unknown starting shape"
	return ""

func reset() -> void:
	owned_plots=[Land.START]
	transformer_cell=Vector3i(-1,0,0)
	utility_links=[]
	rooms.clear()
	cables.clear()
	history.clear()
	shape_uses.clear()
	turn = 0
	queue = [make_card(config.supply.starting_shape, 0, int(config.supply.seed))]
	basement_queue = [make_card(config.supply.starting_shape, 4, int(config.supply.seed)+1)]
	fill_queues()

static func vec(a: Array) -> Vector3i:
	return Vector3i(int(a[0]), int(a[1]), int(a[2]))

static func arr(v: Vector3i) -> Array:
	return [v.x, v.y, v.z]

func rules() -> Dictionary:
	return config.plot

func owns_cell(cell: Vector3i, margin := 0) -> bool:
	return Land.contains(config,owned_plots,cell,margin)

func purchase_plot(id: int) -> bool:
	if id<0 or id>=Land.plots(config).size() or owned_plots.has(id) or Land.covered(config,owned_plots,id): return false
	checkpoint()
	owned_plots.append(id)
	return true

func land_bounds() -> Rect2i:
	var plots:=Land.plots(config)
	var result: Rect2i=plots[Land.START]
	for id in owned_plots: result=result.merge(plots[int(id)])
	return result

func shape_for(id: String) -> Dictionary:
	for s in config.shapes:
		if s.id == id: return s
	return {}

static func rotate_point(v: Vector3i, yaw: int) -> Vector3i:
	for i in posmod(yaw, 4): v = Vector3i(-v.z, v.y, v.x)
	return v

func entrance_options(id: String) -> Array:
	var shape := shape_for(id)
	var result := []
	var extent := Vector3i.ZERO
	var cells: Array=shape.cells.map(func(raw):return vec(raw))
	for raw in shape.cells: extent=extent.max(vec(raw)+Vector3i.ONE)
	for raw in shape.cells:
		var cell := vec(raw)
		for normal in DIRECTIONS:
			if cells.has(cell+normal): continue
			if shape.get("long_side_door",false):
				if extent.z>extent.x and normal.z!=0: continue
				if extent.x>extent.z and normal.x!=0: continue
			result.append({"door":arr(cell),"normal":arr(normal)})
	return result

func make_card(id: String, color: int, draw_seed: int = -1) -> Dictionary:
	var card := {"shape":id,"color":color}
	if room_role(card)!="room": return card
	var choices := entrance_options(id)
	var rng := RandomNumberGenerator.new()
	if draw_seed==-1: rng.randomize()
	else: rng.seed=draw_seed
	card.merge(choices[rng.randi_range(0,choices.size()-1)])
	return card

func oriented(card: Dictionary, yaw := 0) -> Dictionary:
	var shape := shape_for(card.shape)
	var cells: Array = []
	var minimum := Vector3i(100, 100, 100)
	for raw in card.get("cells",shape.get("cells",[])):
		var p := rotate_point(vec(raw), yaw)
		minimum = minimum.min(p)
		cells.append(p)
	for i in cells.size(): cells[i] -= minimum
	return {"cells": cells, "door": rotate_point(vec(card.get("door",shape.get("door",[0,0,0]))), yaw) - minimum,
		"normal": rotate_point(vec(card.get("normal",shape.get("normal",[0,0,-1]))), yaw)}

func occupied() -> Dictionary:
	var result := {}
	for room in rooms:
		for p in room.cells: result[vec(p)] = int(room.id)
	return result

func reserved() -> Dictionary:
	var result := {}
	for room in rooms:
		for key in ["access_path"]:
			for p in room[key]: result[vec(p)] = true
	return result

func fit_issues(cells: Array, occ: Dictionary, paths: Dictionary, underground: bool, role := "room", _check_cables := true) -> Array:
	var issues: Array=[]
	for p in cells:
		var kind := ""
		var margin := 0 if p.y <= 0 else int(rules().overhang)
		if occ.has(p) or p==transformer_cell: kind="occupied"
		elif paths.has(p): kind="path"
		elif role=="pole" and p.y<0: kind="height"
		elif p.y < -int(rules().bedrock) or p.y >= int(rules().ceiling) or (role=="stairs" and p.y>=int(rules().ceiling)-1): kind="height"
		elif (underground and p.y>=0) or (not underground and p.y<0): kind="height"
		elif not owns_cell(p,margin): kind="bounds"
		elif occ.has(p+Vector3i.DOWN) and room_role(rooms[int(occ[p+Vector3i.DOWN])])=="stairs" and role=="room": kind="stair_exit"
		if not kind.is_empty(): issues.append({"cell":p,"kind":kind})
	return issues

func fits(cells: Array, occ: Dictionary, paths: Dictionary, underground: bool, role := "room", check_cables := true) -> bool:
	return fit_issues(cells,occ,paths,underground,role,check_cables).is_empty()

func support(cells: Array, occ: Dictionary, underground: bool, role := "room") -> Dictionary:
	# Braced halls can carry vertical loads. New braces still terminate on
	# a grounded column, never on another cantilever or support beam.
	occ=occ.duplicate()
	for p in occ.keys():
		if int(occ[p])>=0 and int(occ[p])<rooms.size() and room_role(rooms[int(occ[p])])=="pole": occ.erase(p)
	var step := Vector3i.UP if underground else Vector3i.DOWN
	var primary_material := {}
	for p in occ:
		var cursor: Vector3i = p
		while occ.has(cursor) and (cursor.y < -1 if underground else cursor.y > 0): cursor += step
		if occ.has(cursor) and cursor.y == (-1 if underground else 0): primary_material[p] = true
	var carried: Dictionary=primary_material.duplicate()
	var ordered: Array=occ.keys()
	ordered.sort_custom(func(a,b):return a.y>b.y if underground else a.y<b.y)
	for p in ordered:
		if carried.has(p+step): carried[p]=true
		if int(occ[p])<0 or int(occ[p])>=rooms.size(): continue
		var supporting_room: Dictionary=rooms[int(occ[p])]
		if room_role(supporting_room)=="hall":
			for brace in supporting_room.braces:
				if vec(brace[0])==p and primary_material.has(vec(brace[1])): carried[p]=true
	var bases: Array = []
	var anchors: Array = []
	var braces: Array = []
	var issues: Array = []
	for p in cells:
		if cells.has(p+step): continue
		bases.append(p)
		if (p.y == -1 if underground else p.y == 0) or carried.has(p+step): anchors.append(p)
	for p in cells:
		for anchor in anchors:
			if p.x==anchor.x and p.z==anchor.z:
				primary_material[p]=true
				break
	for p in bases:
		if occ.has(p+step) and not carried.has(p+step):
			issues.append({"cell":p,"kind":"cantilever","related":p+step})
			continue
		if anchors.has(p): continue
		var found := false
		if not anchors.is_empty() or role=="hall":
			for d in DIRECTIONS:
				if primary_material.has(p+step+d):
					braces.append([arr(p),arr(p+step+d)])
					found=true
					break
		if not found: issues.append({"cell":p,"kind":"support","related":p+step})
	return {"ok":issues.is_empty(),"braces":braces,"issues":issues}

func landing(card: Dictionary, x: int, z: int, yaw := 0, underground := false, target_y := -100, carve := false) -> Dictionary:
	if carve: return hall_cut(card,x,z,yaw,underground,target_y)
	var form := oriented(card, yaw)
	var occ := occupied()
	var paths := reserved()
	var max_y := 0
	for p in form.cells: max_y = maxi(max_y, p.y)
	var start := -int(rules().bedrock) if underground else int(rules().ceiling) - max_y - 1
	if room_role(card)=="stairs" and not underground: start -= 1
	var end := -max_y if underground else -1
	var step := 1 if underground else -1
	if target_y != -100:
		start = target_y
		end = target_y+step
	var last: Dictionary = {}
	var blocked: Dictionary = {}
	for y in range(start, end, step):
		var offset := Vector3i(x, y, z)
		var cells: Array = []
		for p in form.cells: cells.append(p + offset)
		var issues := fit_issues(cells,occ,paths,underground,room_role(card),false)
		var candidate := {"cells":cells,"door":form.door+offset,"normal":form.normal,
			"origin":offset,"ok":false,"reason":"Support","braces":[],"issues":issues}
		if not issues.is_empty():
			blocked=candidate
			blocked.reason="No clearance"
			break
		last=candidate
	if last.is_empty(): return blocked
	if not fits(last.cells, occ, paths, underground, room_role(card)):
		last.reason = "Cable blocked"
		last.issues = fit_issues(last.cells,occ,paths,underground,room_role(card))
		return last
	var structure := support(last.cells, occ, underground, room_role(card))
	last.ok = structure.ok
	last.braces = structure.braces
	last.issues = structure.issues
	if last.ok: last.reason = ""
	return last

func hall_cut(card: Dictionary, x: int, z: int, yaw: int, underground: bool, y: int) -> Dictionary:
	var form := oriented(card,yaw)
	var offset := Vector3i(x,y,z)
	var cells: Array = form.cells.map(func(cell): return cell+offset)
	var result := {"cells":cells,"door":form.door+offset,"normal":form.normal,"origin":offset,
		"ok":false,"reason":"Hall only","braces":[],"issues":[],"carve":true,"affected":[],"remnants":[]}
	if room_role(card)!="hall" or y==-100:
		result.issues=cells.map(func(cell):return {"cell":cell,"kind":"protected"})
		return result
	var occ := occupied()
	for cell in cells:
		if not occ.has(cell): continue
		var id: int = occ[cell]
		if room_role(rooms[id])!="room":
			result.reason="Keep hall / stair"
			result.issues.append({"cell":cell,"kind":"protected"})
			continue
		if not result.affected.has(id): result.affected.append(id)
		occ.erase(cell)
	if not result.issues.is_empty(): return result
	if result.affected.is_empty():
		result.issues=cells.map(func(cell):return {"cell":cell,"kind":"protected"})
		return result
	if not fits(cells,occ,reserved(),underground,"hall"):
		result.reason="No clearance"
		result.issues=fit_issues(cells,occ,reserved(),underground,"hall")
		return result
	var structure := support(cells,occ,underground,"hall")
	if not structure.ok:
		result.reason="Support"
		result.issues=structure.issues
		return result
	result.braces=structure.braces
	for id in result.affected:
		var original: Dictionary = rooms[id]
		var remaining: Array = original.cells.map(func(raw): return vec(raw)).filter(func(cell): return not cells.has(cell))
		# A cut can divide a room. Each surviving connected part gets a real entrance.
		while not remaining.is_empty():
			var component: Array = [remaining.pop_front()]
			var cursor := 0
			while cursor<component.size():
				for direction in DIRECTIONS+[Vector3i.UP,Vector3i.DOWN]:
					var next: Vector3i = component[cursor]+direction
					if remaining.has(next):
						remaining.erase(next)
						component.append(next)
				cursor+=1
			var part: Dictionary = original.duplicate(true)
			part.cells=component.map(func(cell): return arr(cell))
			part.braces=original.braces.filter(func(brace): return component.has(vec(brace[0])))
			var found := false
			for cell in component:
				for direction in DIRECTIONS:
					if cells.has(cell+direction):
						part.door=arr(cell); part.normal=arr(direction); found=true
						break
				if found: break
			if not found and not component.has(vec(part.door)):
				for cell in component:
					for direction in DIRECTIONS:
						if not component.has(cell+direction):
							part.door=arr(cell); part.normal=arr(direction); found=true
							break
					if found: break
			if part.door!=original.door or part.normal!=original.normal: part.access_path=[]
			result.remnants.append(part)
	var proposed: Array = rooms.filter(func(room): return not result.affected.has(int(room.id))).duplicate(true)
	proposed.append_array(result.remnants)
	proposed.append({"id":proposed.size(),"shape":card.shape,"color":card.color,"cells":cells.map(func(cell): return arr(cell)),
		"door":arr(result.door),"normal":arr(result.normal),"braces":result.braces,"access_path":[]})
	for id in proposed.size(): proposed[id].id=id
	result.proposed_rooms=proposed
	result.ok=true
	result.reason=""
	return result

func legal_moves(card: Dictionary, underground := false, first_only := false) -> Array:
	var result: Array = []
	var margin := 0 if underground else int(rules().overhang)
	var candidates: Dictionary={}
	for id in owned_plots:
		var plot: Rect2i=Land.plots(config)[int(id)].grow(margin)
		for x in range(plot.position.x,plot.end.x):
			for z in range(plot.position.y,plot.end.y): candidates[Vector2i(x,z)]=true
	for yaw in 4:
		for at in candidates:
			var p := landing(card, at.x, at.y, yaw, underground)
			if p.ok:
				p.merge({"x": at.x, "z": at.y, "yaw": yaw})
				result.append(p)
				if first_only: return result
	return result

func current(underground := false) -> Dictionary:
	return (basement_queue if underground else queue)[0]

func tint(_card: Dictionary) -> Color:
	# Keep type/color IDs in saves; architecture now shares one concrete finish.
	return STAIR_COLOR

func snapshot() -> Dictionary:
	return {"version": 2, "transformer_cell":arr(transformer_cell), "owned_plots":owned_plots.duplicate(), "utility_links":utility_links.duplicate(true), "rooms": rooms.duplicate(true), "cables": cables.duplicate(true),
		"queue": queue.duplicate(true), "basement_queue": basement_queue.duplicate(true),
		"turn": turn, "shape_uses": shape_uses.duplicate(true)}

func restore(state: Dictionary) -> void:
	state = integer_state(state)
	owned_plots=state.get("owned_plots",[Land.START]).duplicate()
	utility_links=state.get("utility_links",[]).duplicate(true)
	rooms = state.rooms.duplicate(true)
	transformer_cell=vec(state.transformer_cell) if state.has("transformer_cell") else starter_transformer_cell(rooms)
	cables = state.cables.duplicate(true)
	queue = state.queue.duplicate(true)
	basement_queue = state.basement_queue.duplicate(true)
	turn = int(state.turn)
	shape_uses = state.shape_uses.duplicate(true)

static func integer_state(value):
	if value is float: return int(value)
	if value is Array:
		var result: Array = []
		for item in value: result.append(integer_state(item))
		return result
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = integer_state(value[key])
		return result
	return value

func checkpoint() -> void:
	history.append(snapshot())
	if history.size() > 80: history.pop_front()

func undo() -> bool:
	if history.is_empty(): return false
	restore(history.pop_back())
	return true

func fail(message: String) -> bool:
	error = message
	return false

func drop(x: int, z: int, yaw := 0, underground := false, target_y := -100, carve := false) -> bool:
	var card := current(underground)
	var p := landing(card, x, z, yaw, underground, target_y, carve)
	if not p.ok: return fail(p.reason)
	checkpoint()
	if p.get("carve",false):
		var kept: Array = rooms.filter(func(room): return not p.affected.has(int(room.id)))
		kept.append_array(p.remnants)
		rooms=kept
		for id in rooms.size(): rooms[id].id=id
	var cells: Array = []
	for c in p.cells: cells.append(arr(c))
	rooms.append({"id": rooms.size(), "color": card.color, "shape": card.shape, "cells": cells,
		"door": arr(p.door), "normal": arr(p.normal), "braces": p.braces, "access_path": []})
	utility_links=Utilities.prune(self,utility_links)
	if not defer_analysis: apply_connection_colors()
	turn += 1
	shape_uses[card.shape] = int(shape_uses.get(card.shape, 0)) + 1
	(basement_queue if underground else queue).pop_front()
	if defer_analysis:
		# Do not enumerate future placements while the player is placing a room.
		var cards: Array=basement_queue if underground else queue
		while cards.size()<2:
			var seed_value:=hash("%s:%s:%s:%s" % [config.supply.seed,turn,cards.size(),underground])
			cards.append(make_card(weighted_shape(config.shapes.filter(func(s):return float(s.weight)>0),seed_value),(turn+cards.size())%config.colors.size(),seed_value))
	else: fill_queues()
	return true

func relocation_card(id: int) -> Dictionary:
	var room: Dictionary=rooms[id]
	var origin := vec(room.cells[0])
	for raw in room.cells: origin=origin.min(vec(raw))
	return {"shape":room.shape,"color":room.color,"cells":room.cells.map(func(raw):return arr(vec(raw)-origin)),
		"door":arr(vec(room.door)-origin),"normal":room.normal.duplicate(),"origin":origin}

func relocation_context(id: int):
	var trial=get_script().new("",config)
	trial.owned_plots=owned_plots.duplicate()
	trial.transformer_cell=transformer_cell
	trial.rooms=rooms.duplicate(true)
	# Retain IDs while removing only this room's occupancy and old access path.
	trial.rooms[id].cells=[]
	trial.rooms[id].access_path=[]
	return trial

func relocation_plan(id: int, x: int, z: int, yaw: int, target_y: int) -> Dictionary:
	var card := relocation_card(id)
	var trial=relocation_context(id)
	var y := int(card.origin.y) if target_y==-100 else target_y
	var result: Dictionary=trial.landing(card,x,z,yaw,y<0,y)
	if not result.get("ok",false): return result
	var original: Dictionary=rooms[id]
	var moved: Dictionary=original.duplicate(true)
	moved.cells=result.cells.map(func(cell):return arr(cell))
	moved.door=arr(result.door); moved.normal=arr(result.normal); moved.braces=result.braces
	if moved.cells!=original.cells or moved.door!=original.door or moved.normal!=original.normal: moved.access_path=[]
	trial.rooms[id]=moved
	trial.apply_connection_colors()
	var mapping := {}
	for index in original.cells.size(): mapping[vec(original.cells[index])]=result.cells[index]
	trial.utility_links=Utilities.prune(trial,Utilities.transform(utility_links,mapping,yaw))
	trial.cables=cables.duplicate(true)
	for cable in trial.cables:
		if mapping.has(vec(cable.cell)):
			cable.cell=arr(mapping[vec(cable.cell)])
			cable.normal=arr(rotate_point(vec(cable.normal),yaw))
		if cable.has("source_cell") and mapping.has(vec(cable.source_cell)):
			cable.source_cell=arr(mapping[vec(cable.source_cell)])
			cable.source_normal=arr(rotate_point(vec(cable.source_normal),yaw))
	# Validate the whole resulting structure, not just the room being moved.
	var occ: Dictionary=trial.occupied()
	var paths: Dictionary=trial.reserved()
	var ordered: Array=trial.rooms.duplicate()
	ordered.sort_custom(func(a,b):return abs(int(a.cells[0][1]))<abs(int(b.cells[0][1])))
	for room in ordered:
		var cells: Array=room.cells.map(func(raw):return vec(raw))
		var other_occ: Dictionary=occ.duplicate()
		for cell in cells: other_occ.erase(cell)
		result.issues.append_array(trial.fit_issues(cells,other_occ,paths,cells[0].y<0,room_role(room),false))
		var structure: Dictionary=trial.support(cells,other_occ,cells[0].y<0,room_role(room))
		result.issues.append_array(structure.issues)
		room.braces=structure.braces
	for cable in trial.cables:
		for pair in [["cell","normal"],["source_cell","source_normal"]]:
			if cable.has(pair[0]):
				var endpoint := vec(cable[pair[0]])
				if endpoint.y<0:
					result.issues.append({"cell":endpoint,"kind":"cable"})
		if trial.cable_points(cable).size()<2: result.issues.append({"cell":vec(cable.cell),"kind":"cable"})

	result.issues.append_array(trial.transformer_plan(trial.transformer_cell).issues)
	trial.align_transformer_bundles()
	result.ok=result.issues.is_empty()
	result.reason="" if result.ok else "Move blocked"
	result.braces=trial.rooms[id].braces
	result.proposed_rooms=trial.rooms
	result.proposed_cables=trial.cables
	result.proposed_utilities=trial.utility_links
	return result

func relocate(id: int, x: int, z: int, yaw: int, target_y: int) -> bool:
	if id<0 or id>=rooms.size(): return false
	var plan := relocation_plan(id,x,z,yaw,target_y)
	if not plan.ok: return fail(plan.reason)
	if plan.proposed_rooms==rooms and plan.proposed_cables==cables: return true
	checkpoint()
	rooms=plan.proposed_rooms
	cables=plan.proposed_cables
	utility_links=plan.get("proposed_utilities",utility_links)
	return true

func removal_plan(id: int) -> Dictionary:
	var result := {"ok":false,"issues":[],"rooms":[],"cables":[]}
	if id<0 or id>=rooms.size(): return result
	var trial=get_script().new("",config)
	trial.owned_plots=owned_plots.duplicate()
	trial.transformer_cell=transformer_cell
	trial.rooms=rooms.filter(func(room):return int(room.id)!=id).duplicate(true)
	for index in trial.rooms.size(): trial.rooms[index].id=index
	var occ: Dictionary=trial.occupied()
	var ordered: Array=trial.rooms.duplicate()
	ordered.sort_custom(func(a,b):return abs(int(a.cells[0][1]))<abs(int(b.cells[0][1])))
	for room in ordered:
		var cells: Array=room.cells.map(func(raw):return vec(raw))
		var other_occ: Dictionary=occ.duplicate()
		for cell in cells: other_occ.erase(cell)
		var structure: Dictionary=trial.support(cells,other_occ,cells[0].y<0,room_role(room))
		result.issues.append_array(structure.issues)
		room.braces=structure.braces
	# Remove incident wires, then orphaned downstream links. Other powered
	# branches remain intact and the whole operation is one undo transaction.
	trial.cables=rooted_cables(cables.filter(func(cable):return occ.has(vec(cable.cell)) and (not cable.has("source_cell") or cable.get("source_device","")=="transformer" or occ.has(vec(cable.source_cell)))))
	trial.cables=trial.rooted_cables(trial.cables.filter(func(cable):return trial.cable_points(cable).size()>1))
	result.ok=result.issues.is_empty()
	result.rooms=trial.rooms
	result.cables=trial.cables
	result.issues.append_array(trial.transformer_plan(trial.transformer_cell).issues)
	result.ok=result.issues.is_empty()
	result.utilities=Utilities.prune(trial,utility_links)
	return result

func rooted_cables(candidates: Array) -> Array:
	var pending: Array=candidates.duplicate(true)
	var rooted := {}
	var kept := []
	while not pending.is_empty():
		var progress:=false
		for index in range(pending.size()-1,-1,-1):
			var cable: Dictionary=pending[index]
			if not source_rooted(cable,rooted,kept): continue
			rooted[Cable.key(cable)]=true
			kept.append(cable)
			pending.remove_at(index)
			progress=true
		if not progress: break
	# Preserve the original wire ordering for stable saves and rendering.
	return candidates.filter(func(cable):return kept.has(cable)).duplicate(true)

func remove_room(id: int) -> bool:
	var plan := removal_plan(id)
	if not plan.ok: return fail("Support")
	checkpoint()
	rooms=plan.rooms
	cables=plan.cables
	utility_links=plan.get("utilities",utility_links)
	return true

func weighted_shape(candidates: Array, draw_seed: int) -> String:
	var total := 0.0
	for shape in candidates: total += float(shape.weight)
	var rng := RandomNumberGenerator.new()
	rng.seed = draw_seed
	var roll := rng.randf() * total
	for shape in candidates:
		roll -= float(shape.weight)
		if roll < 0: return shape.id
	return candidates[-1].id

func choose_card(underground := false) -> Dictionary:
	var available := []
	var enabled := []
	var cards: Array = basement_queue if underground else queue
	for shape in config.shapes:
		if float(shape.weight) <= 0: continue
		enabled.append(shape)
		if not legal_moves({"shape":shape.id}, underground,true).is_empty(): available.append(shape)
	# Relative weights are actual draw odds among pieces that still fit.
	# A stable seed keeps undo/save/reload from rerolling the incoming supply.
	var draw_seed := hash("%s:%s:%s:%s" % [config.supply.seed,turn,cards.size(),underground])
	var id := weighted_shape(enabled if available.is_empty() else available, draw_seed)
	return make_card(id,(turn + cards.size()) % config.colors.size(),draw_seed)

func fill_queues() -> void:
	for underground in [false, true]:
		var cards: Array = basement_queue if underground else queue
		while cards.size() < 2:
			var card := choose_card(underground)
			cards.append(card)

func transformer_plan(at: Vector3i) -> Dictionary:
	var issues: Array=[]
	var occ:=occupied()
	if at.y<0 or at.y>=int(rules().ceiling): issues.append({"cell":at,"kind":"height"})
	elif occ.has(at): issues.append({"cell":at,"kind":"occupied"})
	elif not Land.bounds(config).has_point(Vector2i(at.x,at.z)): issues.append({"cell":at,"kind":"bounds"})
	elif at.y==0:
		if Land.roads(config).any(func(rect):return rect.has_point(Vector2i(at.x,at.z))) or (not owns_cell(at) and not street(at)):
			issues.append({"cell":at,"kind":"bounds"})
	elif not owns_cell(at,int(rules().overhang)):
		issues.append({"cell":at,"kind":"bounds"})
	elif not occ.has(at+Vector3i.DOWN) or room_role(rooms[int(occ[at+Vector3i.DOWN])]) in ["pole","stairs","elevator"]:
		issues.append({"cell":at,"kind":"support","related":at+Vector3i.DOWN})
	return {"ok":issues.is_empty(),"cells":[at],"origin":at,"issues":issues,"braces":[],"reason":"" if issues.is_empty() else "Placement blocked"}

func move_transformer(at: Vector3i) -> bool:
	if not transformer_plan(at).ok: return false
	if at==transformer_cell: return true
	checkpoint()
	transformer_cell=at
	for cable in cables:
		if cable.get("source_device","")=="transformer": cable.source_cell=arr(at)
	align_transformer_bundles()
	return true

func align_transformer_bundles() -> void:
	# Match the order of the source row to the pole crossarm, never criss-cross it.
	for room in rooms:
		if room_role(room)!="pole" or room.cells.is_empty(): continue
		var base: Array=room.cells[0]
		var links: Array=cables.filter(func(c):return c.get("source_device","")=="transformer" and c.get("device","")=="pole" and c.cell==base)
		if links.is_empty(): continue
		var used: Array=[]
		for c in cables:
			if c.get("device","")=="pole" and c.cell==base and not links.has(c): used.append(int(c.slot))
			if c.get("source_device","")=="pole" and c.source_cell==base: used.append(int(c.source_slot))
		var normal:=vec(room.normal)
		var reverse:=-normal.z<0 or (normal.z==0 and normal.x<0)
		links.sort_custom(func(a,b):return int(a.source_slot)<int(b.source_slot))
		for c in links:
			var preferred:=2-int(c.source_slot) if reverse else int(c.source_slot)
			var available: Array=[0,1,2].filter(func(slot):return not used.has(slot))
			if available.is_empty(): continue
			available.sort_custom(func(a,b):return absi(a-preferred)<absi(b-preferred))
			c.slot=int(available[0]); used.append(int(c.slot))

func transformer_bundle_points(cable: Dictionary) -> PackedVector3Array:
	var start:=cable_start(cable); var end:=Cable.endpoint(cable)
	var source_center:=Vector3(vec(cable.source_cell))+Vector3(0.5,1.02,0.70)
	var target_center:=Cable.equipment_socket(vec(cable.cell),vec(cable.normal),1,"pole")
	var start_offset:=start-source_center; var end_offset:=end-target_center
	var spine:=Cable.curve(target_center,source_center+Vector3.UP*0.18)
	var result:=PackedVector3Array([start])
	for i in spine.size():
		var t:=float(i)/float(spine.size()-1)
		result.append(spine[i]+start_offset.lerp(end_offset,t))
	return result

func starter_transformer_cell(network: Array) -> Vector3i:
	# Older saves may already occupy a sidewalk: find clear nearby paving.
	var occ: Dictionary={}
	for room in network:
		for raw in room.cells: occ[vec(raw)]=true
	var candidates: Array=[Vector3i(-1,0,0),Vector3i(0,0,-1),Vector3i(-1,0,1),Vector3i(1,0,-1),Vector3i(-1,0,2),Vector3i(2,0,-1)]
	for x in range(-6,10): candidates.append(Vector3i(x,0,-1))
	for cell in candidates:
		if occ.has(cell): continue
		var clear:=true
		for p in occ:
			if Cable.path_hits(transformer_feed(cell),Cable.bounds(p)): clear=false; break
		if clear: return cell
	return Vector3i(-7,0,-1)

func transformer_feed(at := Vector3i(100,100,100)) -> PackedVector3Array:
	if at.x==100: at=transformer_cell
	return Cable.curve(Vector3(at)+Vector3(0.5,0.78,-0.06),Cable.POLE+Vector3(0.25,0.08,0))

func transformer_source(slot: int) -> Dictionary:
	return {"device":"transformer","cell":arr(transformer_cell),"normal":[0,0,-1],"slot":slot}

func pole_at(cell: Vector3i) -> Dictionary:
	for room in rooms:
		if room_role(room)=="pole" and not room.cells.is_empty() and vec(room.cells[0])==cell: return room
	return {}

func solid_bounds(cell: Vector3i, network: Array = []) -> AABB:
	for room in (rooms if network.is_empty() else network):
		if room_role(room)=="pole" and room.cells.has(arr(cell)):
			var base:=vec(room.cells[0])
			return AABB(Vector3(cell)+Vector3(0.43,0,0.43),Vector3(0.14,0.30 if cell.y==base.y+2 else 1.0,0.14))
	return Cable.bounds(cell)

func power_source(cable: Dictionary) -> Dictionary:
	var source: Dictionary={}
	for key in ["cell","normal","slot","device"]:
		if cable.has("source_"+key): source[key]=cable["source_"+key]
	return source

func source_rooted(cable: Dictionary, rooted: Dictionary, kept: Array) -> bool:
	if not cable.has("source_cell"): return true
	if cable.get("source_device","")=="transformer": return true
	if cable.get("source_device","")=="pole":
		return kept.any(func(c):return c.get("device","")=="pole" and c.cell==cable.source_cell)
	return rooted.has(Cable.key(cable,true))

func terminal_used(terminal: Dictionary) -> bool:
	var key:=Cable.key(terminal)
	return cables.any(func(c):return Cable.key(c)==key or (c.has("source_cell") and Cable.key(c,true)==key))

func cable_start(cable: Dictionary) -> Vector3:
	if cable.has("source_cell"): return Cable.endpoint(power_source(cable))
	return Cable.POLE+Vector3((int(cable.feed)-1)*0.25,0.08,0) if cable.has("feed") else Cable.POLE

func next_power_feed() -> int:
	var used: Array=[2] # The starter transformer occupies the tall pole's third feed.
	for cable in cables:
		if not cable.has("source_cell"): used.append(int(cable.get("feed",used.size()-1)))
	for index in 3:
		if not used.has(index): return index
	return -1

func cable_points(cable: Dictionary, occ: Dictionary = {}) -> PackedVector3Array:
	if cached_cable_paths.has(Cable.key(cable)): return cached_cable_paths[Cable.key(cable)]
	if cable.get("wall",false) and cable.has("source_cell") and not cable.has("device") and not cable.has("source_device"):
		var walls: Dictionary=occupied() if occ.is_empty() else occ

		var route:=Cable.wall_route(vec(cable.source_cell),vec(cable.source_normal),int(cable.get("source_slot",-1)),vec(cable.cell),vec(cable.normal),int(cable.get("slot",-1)),walls)
		if not route.is_empty(): return route
	if cable.get("source_device","")=="transformer" and cable.get("device","")=="pole": return transformer_bundle_points(cable)
	if cable.get("source_device","")=="transformer":
		# Lead vertically off the insulator, then clear the cabinet before sagging.
		var start:=cable_start(cable); var end:=Cable.endpoint(cable)
		var center:=Vector3(vec(cable.source_cell))+Vector3(0.5,1.16,0.5)
		var direction:=Vector3(end.x-center.x,0,end.z-center.z)
		var extent:=maxf(absf(direction.x),absf(direction.z))
		if extent<0.001: return PackedVector3Array()
		var shoulder:=center+direction/extent*0.64
		var result:=PackedVector3Array([start,Vector3(start.x,float(cable.source_cell[1])+1.16,start.z),shoulder])
		var span:=Cable.curve(end,shoulder)
		for i in range(1,span.size()): result.append(span[i])
		return result
	return Cable.curve(Cable.endpoint(cable),cable_start(cable))

func socket_exists(cell: Vector3i, normal: Vector3i, slot: int = -1) -> bool:
	for cable in cables:
		if vec(cable.cell)==cell and vec(cable.normal)==normal and int(cable.get("slot",-1))==slot: return true
	return false

func connection(cell: Vector3i, normal: Vector3i, source: Dictionary = {}, slot: int = -1) -> Dictionary:
	var candidate: Dictionary={"cell":arr(cell),"normal":arr(normal),"slot":slot}
	var pole:=pole_at(cell)
	if not pole.is_empty(): candidate.device="pole"
	var result: Dictionary=candidate.duplicate(true)
	result.merge({"ok":false,"end":Cable.endpoint(candidate),"points":PackedVector3Array()})
	var occ:=occupied()
	if not occ.has(cell) or not DIRECTIONS.has(normal) or cell.y<0 or slot < -1 or slot > 3: return result
	if pole.is_empty():
		if occ.has(cell+normal): return result
	else:
		if slot<0 or slot>2 or normal!=vec(pole.normal) or terminal_used(candidate): return result

	if source.is_empty():
		if cables.filter(func(c):return not c.has("source_cell")).size()>=2 or next_power_feed()<0: return result
		if slot>=0: candidate.feed=next_power_feed()
	else:
		var device: String=source.get("device","")
		if device=="transformer":
			if source.get("cell",[])!=arr(transformer_cell) or int(source.get("slot",-1)) not in [0,1,2] or terminal_used(source): return result
		elif device=="pole":
			var parent:=pole_at(vec(source.cell))
			if parent.is_empty() or vec(source.normal)!=vec(parent.normal) or int(source.get("slot",-1)) not in [0,1,2] or terminal_used(source): return result
			if not rooted_cables(cables).any(func(c):return c.get("device","")=="pole" and c.cell==source.cell): return result
			if source.cell==candidate.cell: return result
		else:
			if not socket_exists(vec(source.cell),vec(source.normal),int(source.get("slot",-1))): return result
			if not rooted_cables(cables).any(func(c):return Cable.key(c)==Cable.key(source)): return result
		for key in ["cell","normal","slot","device"]:
			if source.has(key): candidate["source_"+key]=source[key]
		if not candidate.has("source_slot"): candidate.source_slot=-1
		candidate.wall=device.is_empty() and pole.is_empty()
		if Cable.key(candidate)==Cable.key(candidate,true): return result
	result.points=cable_points(candidate,occ)
	if result.points.size()<2: return result

	result.ok=true
	result.cable=candidate
	return result

func connect_power(cell: Vector3i, normal: Vector3i, source: Dictionary = {}, slot: int = -1) -> bool:
	var result:=connection(cell,normal,source,slot)
	if not result.ok: return fail("Blocked")
	if socket_exists(cell,normal,slot): return fail("Connected")
	checkpoint()
	var cable: Dictionary=result.cable
	# Keep the legacy representation of old centre sockets.
	if slot<0: cable.erase("slot")
	cables.append(cable)
	align_transformer_bundles()
	return true

func remove_equipment_branch(source: Dictionary) -> bool:
	var remaining: Array=cables.filter(func(c):return Cable.key(c)!=Cable.key(source) and (not c.has("source_cell") or Cable.key(c,true)!=Cable.key(source)))
	remaining=rooted_cables(remaining)
	if remaining==cables: return false
	checkpoint(); cables=remaining
	return true

func move_power_node(source: Dictionary, cell: Vector3i, normal: Vector3i, slot: int, commit := true) -> bool:
	if source.has("device") or not pole_at(cell).is_empty(): return false
	if not socket_exists(vec(source.cell),vec(source.normal),int(source.get("slot",-1))) or socket_exists(cell,normal,slot): return false
	var occ:=occupied()
	if not occ.has(cell) or cell.y<0 or not DIRECTIONS.has(normal) or occ.has(cell+normal) or slot<0 or slot>3: return false
	var moved: Array=cables.duplicate(true)
	var old_key:=Cable.key(source)
	for cable in moved:
		if Cable.key(cable)==old_key:
			cable.cell=arr(cell); cable.normal=arr(normal); cable.slot=slot
		if cable.has("source_cell") and Cable.key(cable,true)==old_key:
			cable.source_cell=arr(cell); cable.source_normal=arr(normal); cable.source_slot=slot
	for cable in moved:
		var points:=cable_points(cable,occ)
		if points.size()<2: return false

	if commit:
		checkpoint(); cables=moved
	return true

func remove_power_node(cell: Vector3i, normal: Vector3i, slot: int = -1) -> bool:
	if not socket_exists(cell,normal,slot): return false
	var remaining: Array=cables.filter(func(cable):return vec(cable.cell)!=cell or vec(cable.normal)!=normal or int(cable.get("slot",-1))!=slot)
	remaining=rooted_cables(remaining)
	checkpoint(); cables=remaining
	return true

func powered_cells() -> Dictionary:
	var result: Dictionary={}
	var occ:=occupied()
	# A transformer/fuse box supplies its room, not every touching room.
	for cable in rooted_cables(cables):
		var p:=vec(cable.cell)
		if occ.has(p):
			for raw in rooms[int(occ[p])].cells: result[vec(raw)]=true
	return Utilities.powered(self,result).cells

func valid_power_state() -> bool:
	var occ:=occupied()
	if not transformer_plan(transformer_cell).ok: return false
	var endpoints: Dictionary={}; var terminals: Dictionary={}
	for cable in cables:
		if not cable is Dictionary or not cable.has_all(["cell","normal"]) or not valid_point(cable.cell) or not valid_point(cable.normal): return false
		var cell:=vec(cable.cell); var normal:=vec(cable.normal)
		if not occ.has(cell) or not DIRECTIONS.has(normal): return false
		var slot=int(cable.get("slot",-1))
		if slot < -1 or slot>3: return false
		var key:=Cable.key(cable)
		if endpoints.has(key): return false
		endpoints[key]=true
		var pole:=pole_at(cell)
		if cable.has("device"):
			if cable.device!="pole" or pole.is_empty() or normal!=vec(pole.normal) or slot not in [0,1,2] or terminals.has(key): return false
			terminals[key]=true
		elif not pole.is_empty(): return false
		if cable.has("source_cell") or cable.has("source_normal"):
			if not valid_point(cable.get("source_cell")) or not valid_point(cable.get("source_normal")): return false
			var source:=power_source(cable); var device: String=source.get("device","")
			var source_slot=int(source.get("slot",-1))
			if not DIRECTIONS.has(vec(source.normal)) or source_slot < -1 or source_slot>3: return false
			if device=="transformer":
				if source.cell!=arr(transformer_cell) or source_slot not in [0,1,2] or source.normal!=[0,0,-1]: return false
			elif device=="pole":
				var parent:=pole_at(vec(source.cell))
				if parent.is_empty() or source.normal!=parent.normal or source_slot not in [0,1,2]: return false
			else:
				if not device.is_empty() or not occ.has(vec(source.cell)) or not pole_at(vec(source.cell)).is_empty(): return false
			if not device.is_empty():
				var source_key:=Cable.key(source)
				if terminals.has(source_key): return false
				terminals[source_key]=true
		elif cable.has("source_device"): return false
		var points:=cable_points(cable,occ)
		if points.size()<2: return false

	# Each small pole must reach the live service through an input; cycles cannot self-power.
	return rooted_cables(cables).size()==cables.size()

func save_game(path: String) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(snapshot(), "\t"))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

static func valid_point(value) -> bool:
	if not value is Array or value.size() != 3: return false
	for n in value:
		if not (n is float or n is int) or n != int(n) or abs(n) > 100: return false
	return true

func valid_card(card, allow_retired := false) -> bool:
	if card is Dictionary and (card.has("door") or card.has("normal")):
		if not valid_point(card.get("door")) or not valid_point(card.get("normal")): return false
		if not DIRECTIONS.has(vec(card.normal)): return false
		# Placed rooms use world coordinates and are validated separately below.
		if not card.has("cells"):
			var shape := shape_for(str(card.get("shape","")))
			if shape.is_empty():
				if not allow_retired: return false
			else:
				var cells: Array=shape.cells.map(func(raw):return vec(raw))
				if not cells.has(vec(card.door)) or cells.has(vec(card.door)+vec(card.normal)): return false
	return card is Dictionary and card.has_all(["shape", "color"]) and (not shape_for(card.shape).is_empty() or (allow_retired and card.shape in ["square","elbow","tee","step","corner","bridge","zigzag"])) and (card.color is int or card.color is float) and card.color == int(card.color) and card.color >= 0 and card.color < config.colors.size()

func load_game(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var state = JSON.parse_string(FileAccess.get_file_as_string(path))
	return load_state(state)

func load_legacy(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var old = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not old is Dictionary or old.get("version") != 1 or not old.has_all(["rooms","queue","basement_queue","turn","shape_uses"]): return false
	if not old.rooms is Array or not old.queue is Array or not old.basement_queue is Array: return false
	var names := ["home","shop","laundry","school","storage"]
	var state := {"version":2,"rooms":[],"cables":[],"queue":[],"basement_queue":[],"turn":old.turn,"shape_uses":old.shape_uses}
	for r in old.rooms:
		if not r is Dictionary or not r.has_all(["id","kind","shape","cells","door","normal","braces","access_path"]): return false
		state.rooms.append({"id":r.id,"color":maxi(0,names.find(r.kind)),"shape":r.shape,"cells":r.cells,
			"door":r.door,"normal":r.normal,"braces":r.braces,"access_path":r.access_path})
	for key in ["queue","basement_queue"]:
		for card in old[key].slice(0,2):
			if not card is Dictionary or not card.has_all(["shape","kind"]): return false
			state[key].append({"shape":card.shape,"color":maxi(0,names.find(card.kind))})
	# An expanded legacy plot cannot be squeezed into 3x3; keep that file intact.
	return load_state(state)

func load_state(state) -> bool:
	if not state is Dictionary or state.get("version") != 2 or not state.has_all(["rooms","cables","queue","basement_queue","turn","shape_uses"]): return false
	if not state.rooms is Array or not state.cables is Array or not state.queue is Array or not state.basement_queue is Array or not state.shape_uses is Dictionary: return false
	if state.rooms.size() > 256 or state.queue.size() != 2 or state.basement_queue.size() != 2: return false
	state = state.duplicate(true)
	var ownership=state.get("owned_plots",[Land.START])
	if not ownership is Array or ownership.size()>Land.plots(config).size(): return false
	var seen_plots: Dictionary={}
	for id in ownership:
		if (not id is int and not id is float) or int(id)!=id or id<0 or id>=Land.plots(config).size() or seen_plots.has(int(id)): return false
		seen_plots[int(id)]=true
	if not seen_plots.has(Land.START): return false
	# Keep existing geometry; retire old multi-storey cards from the incoming supply.
	for key in ["queue", "basement_queue"]:
		for index in state[key].size():
			var card = state[key][index]
			if valid_card(card, true) and shape_for(card.shape).is_empty():
				state[key][index]=make_card("rectangle" if card.shape=="square" else "small_square",int(card.color),hash("%s:%s:%s" % [state.turn,key,index]))
	for key in ["queue", "basement_queue"]:
		for index in state[key].size():
			var card = state[key][index]
			if card is Dictionary and card.get("shape","") in ["flat_l","flat_l_mirror"] and valid_card(card):
				state[key][index]=make_card("small_square",int(card.color),hash("%s:%s:%s" % [state.turn,key,index]))
	var taken := {}
	for i in state.rooms.size():
		var r = state.rooms[i]
		if not valid_card(r, true) or not r.has_all(["id", "cells", "door", "normal", "braces", "access_path"]): return false
		if r.id != i or not r.cells is Array or (r.cells.size() < 1 or r.cells.size() > 6) or not valid_point(r.door) or not valid_point(r.normal): return false
		if not DIRECTIONS.has(vec(r.normal)) or not r.braces is Array or not r.access_path is Array: return false
		if r.has("groups"):
			if not r.groups is Array: return false
			var unique_groups: Dictionary={}
			for group in r.groups:
				if (not group is int and not group is float) or int(group)!=group or int(group)<1 or unique_groups.has(group): return false
				unique_groups[group]=true
		var door_found := false
		for raw in r.cells:
			if not valid_point(raw): return false
			var p := vec(raw)
			var margin := 0 if p.y <= 0 else int(rules().overhang)
			if taken.has(p) or not Land.contains(config,ownership,p,margin) or p.y < -int(rules().bedrock) or p.y >= int(rules().ceiling): return false
			taken[p] = true
			if p == vec(r.door): door_found = true
		if not door_found: return false
		for step in r.access_path:
			if not valid_point(step) or taken.has(vec(step)): return false
		for brace in r.braces:
			if not brace is Array or brace.size() != 2 or not valid_point(brace[0]) or not valid_point(brace[1]): return false
	for r in state.rooms:
		for step in r.access_path:
			if taken.has(vec(step)): return false
	for card in state.queue + state.basement_queue:
		if not valid_card(card): return false
	if state.has("transformer_cell") and not valid_point(state.transformer_cell): return false
	var power_trial=get_script().new("",config)
	power_trial.restore(state)
	if not power_trial.valid_power_state(): return false
	if not state.get("utility_links",[]) is Array or state.get("utility_links",[]).size()>8192: return false
	var utility_trial=get_script().new("",config)
	utility_trial.restore(state)
	var utility_occ: Dictionary=utility_trial.occupied()
	var link_ids: Dictionary={}
	for link in utility_trial.utility_links:
		if not Utilities.valid_link(utility_trial,link,utility_occ) or link_ids.has(Utilities.link_key(link)): return false
		link_ids[Utilities.link_key(link)]=true
	restore(state)
	history.clear()
	return true
func approach(room: Dictionary) -> Vector3i:
	var port: Dictionary=room_ports(room)[0]
	return port.cell+port.normal

func street(p: Vector3i) -> bool:
	if p.y!=0 or owns_cell(p) or not Land.bounds(config).has_point(Vector2i(p.x,p.z)): return false
	# Unpurchased paving/streets remain public; private building lots do not.
	return not Land.plots(config).slice(0,9).any(func(plot):return plot.has_point(Vector2i(p.x,p.z)))

func path_to(room: Dictionary, port: Dictionary = {}) -> Array:
	var target: Vector3i = approach(room) if port.is_empty() else port.cell+port.normal
	var occ := occupied()
	if occ.has(target): return []
	var plot: Rect2i=Land.plots(config)[Land.START]
	for candidate in Land.plots(config):
		if candidate.has_point(Vector2i(vec(room.door).x,vec(room.door).z)): plot=candidate; break
	var start := Vector3i(plot.position.x-1, target.y, plot.position.y-1)
	var previous := {start: start}
	var pending: Array = [start]
	while not pending.is_empty():
		var p: Vector3i = pending.pop_front()
		if p == target: break
		for d in DIRECTIONS:
			var next: Vector3i = p + d
			if previous.has(next) or occ.has(next): continue
			if not plot.grow(1).has_point(Vector2i(next.x,next.z)): continue
			var perimeter := not plot.has_point(Vector2i(next.x,next.z))
			if not perimeter and next.y != 0 and not occ.has(next + Vector3i.DOWN): continue
			previous[next] = p
			pending.append(next)
	if not previous.has(target): return []
	var path: Array = []
	var cursor := target
	while cursor != start:
		path.push_front(arr(cursor))
		cursor = previous[cursor]
	path.push_front(arr(start))
	# An explicitly purchased staircase/riser at the NW corner joins the street.
	for y in range(target.y - signi(target.y), -signi(target.y), -signi(target.y) if target.y != 0 else 1):
		path.push_front([start.x, y, start.z])
	return path

func room_role(room: Dictionary) -> String:
	return str(shape_for(room.shape).get("role", "room"))

func authored_ports(room: Dictionary) -> Array:
	var result := []
	var role := room_role(room)
	var normal := vec(room.normal)
	if role=="pole": return []
	if role == "hall":
		for raw in room.cells:
			var cell := vec(raw)
			for d in DIRECTIONS:
				if not room.cells.has(arr(cell+d)): result.append({"cell":cell,"normal":d})

	else:
		result.append({"cell":vec(room.door),"normal":normal})
		if role == "stairs": result.append({"cell":vec(room.door)+Vector3i.UP,"normal":normal})
	return result

func room_ports(room: Dictionary, room_set: Array = []) -> Array:
	var result := authored_ports(room)
	if room_role(room)!="room": return result
	var network: Array=rooms if room_set.is_empty() else room_set
	# A real doorway aimed at a room creates its matching opening in that wall.
	for other in network:
		if other.get("id",-2)==room.get("id",-1) or room_role(other)=="hall": continue
		for port in authored_ports(other):
			var inside: Vector3i=port.cell+port.normal
			if room.cells.has(arr(inside)) and not result.any(func(existing):return existing.cell==inside and existing.normal==-port.normal):
				result.append({"cell":inside,"normal":-port.normal})
	return result

func connection_colors(room_set: Array = []) -> Dictionary:
	var network: Array=rooms if room_set.is_empty() else room_set
	var parents := {}
	var colors := {}
	var occ := {}
	for room in network:
		colors[int(room.id)]=int(room.color)
		for raw in room.cells: occ[vec(raw)]=int(room.id)
	for room in network:
		if room_role(room)!="room": continue
		var adjacent := vec(room.door)+vec(room.normal)
		if occ.has(adjacent) and int(occ[adjacent])!=int(room.id) and room_role(network[int(occ[adjacent])])=="room": parents[int(room.id)]=int(occ[adjacent])
	var result := colors.duplicate()
	for start in colors:
		var chain: Array=[]
		var at: int=start
		while parents.has(at) and not chain.has(at):
			chain.append(at); at=parents[at]
		if chain.has(at):
			var cycle: Array=chain.slice(chain.find(at))
			at=cycle.min()
		result[start]=colors[at]
	return result

func apply_connection_colors() -> void:
	var colors := connection_colors()
	for room in rooms: room.color=colors[int(room.id)]

func route_to_room(id: int, room_set: Array = []) -> Dictionary:
	return Navigation.route(self,id,rooms if room_set.is_empty() else room_set)

func port_matches(room: Dictionary, cell: Vector3i, normal: Vector3i, room_set: Array = []) -> bool:
	for port in room_ports(room,room_set):
		if port.cell==cell and port.normal==normal: return true
	return false

func port_linked(room: Dictionary, port: Dictionary, room_set: Array = []) -> bool:
	var network: Array=rooms if room_set.is_empty() else room_set
	var outside: Vector3i=port.cell+port.normal
	var occupied_outside:=false
	for other in network:
		if other.get("id",-2)==room.get("id",-1): continue
		if other.cells.has(arr(outside)): occupied_outside=true
		if port_matches(other,outside,-port.normal,network): return true
		if other.get("access_path",[]).has(arr(outside)): return true
	if occupied_outside: return false
	return street(outside) or room.get("access_path",[]).has(arr(outside))

func accessible_rooms(room_set: Array = []) -> Dictionary:
	var network: Array = rooms if room_set.is_empty() else room_set
	var reached := {}
	var ports := []
	var occ := {}
	for room in network:
		for raw in room.cells: occ[vec(raw)]=int(room.id)
	var paths := {}
	for room in network:
		for raw in room.access_path: paths[vec(raw)]=true
	var edges := {}
	for room in network:
		var id := int(room.id)
		edges[id] = []
		ports.append(room_ports(room,network))
		if ports[id].any(func(port):return room.access_path.has(arr(port.cell+port.normal))): reached[id] = true
		for port in ports[id]:
			if (street(port.cell+port.normal) or paths.has(port.cell+port.normal)) and not occ.has(port.cell+port.normal): reached[id] = true
	for room in network:
		var id := int(room.id)
		for port in ports[id]:
			var outside: Vector3i = port.cell+port.normal
			if not occ.has(outside): continue
			var other := int(occ[outside])
			if other!=id and port_matches(network[other],outside,-port.normal,network):
				edges[id].append(other); edges[other].append(id)
		# Only contiguous shaft sections form an elevator; never jump a gap.
		if room_role(room)=="elevator":
			var above := vec(room.cells[0])+Vector3i.UP
			if occ.has(above) and room_role(network[int(occ[above])])=="elevator":
				var other := int(occ[above])
				edges[id].append(other); edges[other].append(id)
		# A hall or another stair above the flight gets a real floor opening.
		if room_role(room)=="stairs":
			var upper := vec(room.door)+Vector3i.UP
			if occ.has(upper) and room_role(network[int(occ[upper])]) in ["hall","stairs"]:
				var other := int(occ[upper])
				edges[id].append(other); edges[other].append(id)
	var pending: Array = reached.keys()
	while not pending.is_empty():
		var id: int = pending.pop_front()
		for other in edges[id]:
			if not reached.has(other): reached[other]=true; pending.append(other)
	return reached

func has_access(room: Dictionary) -> bool:
	return accessible_rooms().has(int(room.id))

func connect_room(id: int, port: Dictionary = {}) -> bool:
	if id < 0 or id >= rooms.size(): return false
	var room: Dictionary = rooms[id]
	if has_access(room): return fail("Already connected")
	if not port.is_empty() and not port_matches(room,port.cell,port.normal): return fail("Door blocked")
	var path := path_to(room,port)
	if path.is_empty(): return fail("Door blocked")
	checkpoint()
	room.access_path = path
	return true

