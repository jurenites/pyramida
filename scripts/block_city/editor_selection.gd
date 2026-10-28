extends RefCounted
## Scene hierarchy and atomic editing operations; room IDs remain model indices.
const Utilities=preload("res://scripts/block_city/utility_network.gd")
const Model=preload("res://scripts/block_city/model.gd")
const Cable=preload("res://scripts/block_city/cable.gd")

static func cells(model, ids: Array) -> Array:
	var result: Array=[]
	for id in ids:
		if id>=0 and id<model.rooms.size():
			for raw in model.rooms[id].cells: result.append(Model.vec(raw))
	return result

static func building(model, id: int) -> Array:
	var occ: Dictionary=model.occupied()
	var found: Array=[id]; var pending: Array=[id]
	while not pending.is_empty():
		var current: int=pending.pop_front()
		for raw in model.rooms[current].cells:
			for direction in Model.DIRECTIONS+[Vector3i.UP,Vector3i.DOWN]:
				var next: Vector3i=Model.vec(raw)+direction
				if occ.has(next) and not found.has(int(occ[next])):
					found.append(int(occ[next])); pending.append(int(occ[next]))
	found.sort()
	return found

static func path(model, id: int) -> Array:
	if id<0 or id>=model.rooms.size(): return []
	var block:=building(model,id)
	var level:=int(model.rooms[id].cells[0][1])
	var floor_ids: Array=block.filter(func(i):return int(model.rooms[i].cells[0][1])==level)
	var result: Array=[]
	var building_added:=false
	var floor_added:=false
	for group in model.rooms[id].get("groups",[]):
		var members: Array=[]
		for room in model.rooms:
			if room.get("groups",[]).has(group): members.append(int(room.id))
		var same_building: bool=members.all(func(i):return block.has(i))
		if same_building and not building_added:
			result.append({"kind":"building","ids":block,"label":"Building"}); building_added=true
		var same_floor: bool=members.all(func(i):return int(model.rooms[i].cells[0][1])==level)
		if same_building and same_floor and not floor_added:
			result.append({"kind":"floor","ids":floor_ids,"label":"Floor %d" % (level+1) if level>=0 else "B%d" % -level}); floor_added=true
		result.append({"kind":"group","ids":members,"group":group,"label":"Group"})
	if not building_added: result.append({"kind":"building","ids":block,"label":"Building"})
	if not floor_added: result.append({"kind":"floor","ids":floor_ids,"label":"Floor %d" % (level+1) if level>=0 else "B%d" % -level})
	result.append({"kind":"room","ids":[id],"label":"Room"})
	return result

static func card(model, ids: Array) -> Dictionary:
	var points:=cells(model,ids)
	var origin: Vector3i=points[0]
	for p in points: origin=origin.min(p)
	return {"shape":"small_square","color":0,"origin":origin,"cells":points.map(func(p):return Model.arr(p-origin)),"door":[0,0,0],"normal":[0,0,-1]}

static func next_group(model) -> int:
	var value:=0
	for room in model.rooms:
		for group in room.get("groups",[]): value=maxi(value,int(group))
	return value+1

static func group_rooms(model, ids: Array) -> int:
	if ids.size()<2: return -1
	var next:=next_group(model)
	var paths: Dictionary={}
	# Partial selections leave their old groups; whole subgroups remain nested.
	for id in ids:
		var kept: Array=[]
		for group in model.rooms[id].get("groups",[]):
			if model.rooms.all(func(room):return not room.get("groups",[]).has(group) or ids.has(int(room.id))): kept.append(group)
		paths[id]=kept
	var common: Array=paths[ids[0]].duplicate()
	for id in ids:
		while not common.is_empty() and paths[id].slice(0,common.size())!=common: common.pop_back()
	model.checkpoint()
	for id in ids: model.rooms[id].groups=common+[next]+paths[id].slice(common.size())
	return next

static func validate(trial) -> Array:
	var issues: Array=[]; var seen: Dictionary={}
	for room in trial.rooms:
		for raw in room.cells:
			var p:=Model.vec(raw)
			if seen.has(p): issues.append({"cell":p,"kind":"occupied"})
			seen[p]=true
	var occ: Dictionary=trial.occupied()
	issues.append_array(trial.transformer_plan(trial.transformer_cell).issues)
	for room in trial.rooms:
		var points: Array=room.cells.map(func(raw):return Model.vec(raw))
		var others: Dictionary=occ.duplicate()
		for p in points: others.erase(p)
		issues.append_array(trial.fit_issues(points,others,trial.reserved(),points[0].y<0,trial.room_role(room),false))
		var support: Dictionary=trial.support(points,others,points[0].y<0,trial.room_role(room))
		issues.append_array(support.issues); room.braces=support.braces

	for cable in trial.cables:
		for pair in [["cell","normal"],["source_cell","source_normal"]]:
			if cable.has(pair[0]):
				var p:=Model.vec(cable[pair[0]])
				var device: String=cable.get("source_device" if pair[0]=="source_cell" else "device","")
				if device=="transformer": continue
				if not occ.has(p): issues.append({"cell":p,"kind":"cable"})
		var points: PackedVector3Array=trial.cable_points(cable)
		if points.size()<2: issues.append({"cell":Model.vec(cable.cell),"kind":"cable"})

	return issues

static func plan(model, ids: Array, target: Vector3i, yaw: int, copy: bool) -> Dictionary:
	var hand:=card(model,ids)
	var rotated: Array=hand.cells.map(func(raw):return Model.rotate_point(Model.vec(raw),yaw))
	var minimum: Vector3i=rotated[0]
	for p in rotated: minimum=minimum.min(p)
	var mapping: Dictionary={}
	for p in cells(model,ids): mapping[p]=Model.rotate_point(p-hand.origin,yaw)-minimum+target
	var trial=Model.new("",model.config)
	trial.restore(model.snapshot())
	var edited: Array=[]; var result_ids: Array=[]
	var group_map: Dictionary={}; var next:=next_group(model)
	for id in ids:
		var room: Dictionary=model.rooms[id].duplicate(true)
		room.cells=room.cells.map(func(raw):return Model.arr(mapping[Model.vec(raw)]))
		room.door=Model.arr(mapping[Model.vec(room.door)])
		room.normal=Model.arr(Model.rotate_point(Model.vec(room.normal),yaw)); room.access_path=[]
		if copy:
			var groups: Array=[]
			for group in room.get("groups",[]):
				if not model.rooms.all(func(member):return not member.get("groups",[]).has(group) or ids.has(int(member.id))): continue
				if not group_map.has(group): group_map[group]=next; next+=1
				groups.append(group_map[group])
			if not groups.is_empty(): room.groups=groups
			else: room.erase("groups")
			room.id=trial.rooms.size(); trial.rooms.append(room)
		else: trial.rooms[id]=room
		edited.append(room); result_ids.append(int(room.id))
	if not copy:
		for cable in trial.cables:
			for pair in [["cell","normal"],["source_cell","source_normal"]]:
				if cable.has(pair[0]) and mapping.has(Model.vec(cable[pair[0]])):
					cable[pair[0]]=Model.arr(mapping[Model.vec(cable[pair[0]])])
					cable[pair[1]]=Model.arr(Model.rotate_point(Model.vec(cable[pair[1]]),yaw))
	trial.utility_links=Utilities.prune(trial,trial.utility_links if copy else Utilities.transform(trial.utility_links,mapping,yaw))
	trial.align_transformer_bundles()
	var issues:=validate(trial)
	if trial.rooms.size()>256: issues.append({"cell":target,"kind":"bounds"})
	trial.apply_connection_colors()
	return {"ok":issues.is_empty(),"issues":issues,"origin":target,"cells":cells(trial,result_ids),"edited":edited,"ids":result_ids,"proposed_rooms":trial.rooms,"proposed_cables":trial.cables,"proposed_utilities":trial.utility_links,"braces":[],"reason":"" if issues.is_empty() else "Placement blocked"}

static func commit(model, result: Dictionary) -> bool:
	if not result.get("ok",false): return false
	if result.proposed_rooms==model.rooms and result.proposed_cables==model.cables: return true
	model.checkpoint()
	model.rooms=result.proposed_rooms.duplicate(true); model.cables=result.proposed_cables.duplicate(true)
	model.utility_links=result.get("proposed_utilities",model.utility_links).duplicate(true)
	return true

static func removal(model, ids: Array) -> Dictionary:
	var trial=Model.new("",model.config)
	trial.restore(model.snapshot())
	trial.rooms=trial.rooms.filter(func(room):return not ids.has(int(room.id)))
	for i in trial.rooms.size(): trial.rooms[i].id=i
	var occ: Dictionary=trial.occupied()
	trial.cables=trial.rooted_cables(trial.cables.filter(func(c):return occ.has(Model.vec(c.cell)) and (not c.has("source_cell") or c.get("source_device","")=="transformer" or occ.has(Model.vec(c.source_cell)))))
	trial.utility_links=Utilities.prune(trial,trial.utility_links)
	trial.align_transformer_bundles()
	var issues:=validate(trial)
	return {"ok":issues.is_empty(),"issues":issues,"proposed_rooms":trial.rooms,"proposed_cables":trial.cables,"proposed_utilities":trial.utility_links}
