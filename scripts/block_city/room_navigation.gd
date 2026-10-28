extends RefCounted
## Weighted cell graph: horizontal step 1, stair rise 1, whole lift ride 2.
static func link(graph: Dictionary, a: Vector3i, b: Vector3i, cost: int, kind: String) -> void:
	if a==b: return
	if not graph.has(a): graph[a]={}
	if not graph.has(b): graph[b]={}
	if not graph[a].has(b) or cost<int(graph[a][b].cost):
		graph[a][b]={"cost":cost,"kind":kind}
		graph[b][a]={"cost":cost,"kind":kind}

static func build(model, rooms: Array) -> Dictionary:
	var graph := {}
	var occupied := {}
	var ports := {}
	var entry := {}
	var entries: Array=[]
	for room in rooms:
		ports[int(room.id)]=model.room_ports(room,rooms)
		for raw in room.cells:
			var cell: Vector3i=model.vec(raw)
			occupied[cell]=int(room.id)
			graph[cell]={}
	for room in rooms:
		for raw in room.cells:
			var cell: Vector3i=model.vec(raw)
			for direction in model.DIRECTIONS:
				if occupied.get(cell+direction,-1)==int(room.id): link(graph,cell,cell+direction,1,"walk")
		for port in ports[int(room.id)]:
			var outside: Vector3i=port.cell+port.normal
			if model.street(outside) and not occupied.has(outside):
				var entrance: Dictionary={"room":int(room.id),"cell":port.cell,"normal":port.normal}
				entries.append(entrance)
				if entry.is_empty(): entry=entrance
			if occupied.has(outside):
				var other: int=occupied[outside]
				if other!=int(room.id) and model.port_matches(rooms[other],outside,-port.normal,rooms): link(graph,port.cell,outside,1,"walk")
		if model.room_role(room)=="stairs":
			var base: Vector3i=model.vec(room.door)
			var top:=base+Vector3i.UP
			if not occupied.has(top) or model.room_role(rooms[int(occupied[top])]) in ["hall","stairs"]: link(graph,base,top,1,"stairs")
		if model.room_role(room)=="elevator":
			var base: Vector3i=model.vec(room.cells[0])
			var top:=base+Vector3i.UP
			while occupied.has(top) and model.room_role(rooms[int(occupied[top])])=="elevator":
				link(graph,base,top,2,"elevator")
				top+=Vector3i.UP
	# Existing saved exterior walkways stay traversable, including their stairs.
	for room in rooms:
		var path: Array=room.get("access_path",[])
		for i in range(1,path.size()): link(graph,model.vec(path[i-1]),model.vec(path[i]),1,"walk")
		for port in ports[int(room.id)]:
			if path.has(model.arr(port.cell+port.normal)): link(graph,port.cell,port.cell+port.normal,1,"walk")
	return {"graph":graph,"entry":entry,"entries":entries}

static func route(model, id: int, rooms: Array) -> Dictionary:
	var result := {"reachable":false,"cost":0,"path":[],"steps":[],"entry":{}}
	if id<0 or id>=rooms.size(): return result
	var built := build(model,rooms)
	var graph: Dictionary=built.graph
	var goal: Vector3i=model.vec(rooms[id].door)
	# Each disconnected building has its own main street entrance.
	var component: Dictionary={goal:true}
	var frontier: Array=[goal]
	while not frontier.is_empty():
		var at: Vector3i=frontier.pop_back()
		for next in graph.get(at,{}):
			if not component.has(next): component[next]=true; frontier.append(next)
	for entrance in built.entries:
		if component.has(entrance.cell): result.entry=entrance; break
	if result.entry.is_empty(): return result
	var start: Vector3i=result.entry.cell
	# The main entrance is distance zero; each transition pays its edge cost.
	var distance := {start:0}
	var previous := {}
	var pending: Array=[start]
	while not pending.is_empty():
		pending.sort_custom(func(a,b):return distance[a]<distance[b])
		var cell: Vector3i=pending.pop_front()
		if cell==goal: break
		for next in graph.get(cell,{}):
			var cost: int=int(distance[cell])+int(graph[cell][next].cost)
			if not distance.has(next) or cost<int(distance[next]):
				distance[next]=cost
				previous[next]=cell
				if not pending.has(next): pending.append(next)
	if not distance.has(goal): return result
	result.reachable=true; result.cost=distance[goal]
	var at:=goal
	result.path.push_front(at)
	while at!=start:
		var before: Vector3i=previous[at]
		result.steps.push_front({"from":before,"to":at,"cost":graph[before][at].cost,"kind":graph[before][at].kind})
		at=before; result.path.push_front(at)
	return result
