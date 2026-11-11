extends RefCounted
## Editor ownership is persistent; physical connections never union buildings.

static func next_id(rooms: Array) -> int:
	var result:=1
	for room in rooms: result=maxi(result,int(room.get("building_id",0))+1)
	return result

static func strongest(scores: Dictionary, preferred: int) -> int:
	if preferred>0 and scores.has(preferred): return preferred
	var winner:=0; var score: int=-1
	for id in scores:
		if int(scores[id])>score or (int(scores[id])==score and int(id)<winner):
			winner=int(id); score=int(scores[id])
	return winner

static func infer(model, room: Dictionary, network: Array, preferred := 0) -> int:
	if model.room_role(room)=="pole": return 0
	var occupied: Dictionary={}
	for other in network:
		if int(other.get("building_id",0))<=0 or model.room_role(other)=="pole": continue
		for raw in other.cells: occupied[model.vec(raw)]=int(other.building_id)
	var overlap: Dictionary={}; var vertical: Dictionary={}; var side: Dictionary={}
	for raw in room.cells:
		var cell: Vector3i=model.vec(raw)
		if occupied.has(cell):
			var id: int=occupied[cell]; overlap[id]=int(overlap.get(id,0))+1
		for direction in [Vector3i.DOWN,Vector3i.UP]:
			if occupied.has(cell+direction):
				var id: int=occupied[cell+direction]; vertical[id]=int(vertical.get(id,0))+1
		for direction in model.DIRECTIONS:
			if occupied.has(cell+direction):
				var id: int=occupied[cell+direction]; side[id]=int(side.get(id,0))+1
	# A cut retains its frame's owner; stacked floors follow their structure.
	if not overlap.is_empty(): return strongest(overlap,preferred)
	if not vertical.is_empty(): return strongest(vertical,preferred)
	return strongest(side,preferred)

static func assign(model, room: Dictionary, network: Array, preferred := 0) -> int:
	var id:=infer(model,room,network,preferred)
	return id if id>0 else next_id(network)

static func ensure(model) -> void:
	# Old saves have no ownership metadata. Replay their recorded room order:
	# separate starts create separate buildings; later connecting halls merge none.
	if model.rooms.all(func(room):return int(room.get("building_id",0))>0): return
	var assigned: Array=[]
	var next:=next_id(model.rooms)
	for room in model.rooms:
		if int(room.get("building_id",0))<=0:
			var id:=infer(model,room,assigned)
			if id<=0: id=next; next+=1
			room.building_id=id
		assigned.append(room)

static func members(model, id: int) -> Array:
	if id<0 or id>=model.rooms.size(): return []
	ensure(model)
	var building: int=model.rooms[id].building_id
	return model.rooms.filter(func(room):return int(room.building_id)==building).map(func(room):return int(room.id))

static func copy_owners(model, ids: Array, mapping: Dictionary, whole_building: bool) -> Dictionary:
	ensure(model)
	var parts: Dictionary={}
	for id in ids:
		var source: Dictionary=model.rooms[id]
		var owner: int=source.building_id
		if not parts.has(owner): parts[owner]={"shape":source.shape,"cells":[]}
		for raw in source.cells: parts[owner].cells.append(model.arr(mapping[model.vec(raw)]))
	var result: Dictionary={}; var next:=next_id(model.rooms)
	for owner in parts:
		var destination:=0 if whole_building else infer(model,parts[owner],model.rooms,int(owner))
		if destination<=0: destination=next; next+=1
		result[owner]=destination
	return result
