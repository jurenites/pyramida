extends RefCounted
## Face-attached tile networks. No dependence on room IDs or screen coordinates.
const KINDS := ["power","pipe","vent"]
const SIDES := [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
static func vec(a: Array) -> Vector3i: return Vector3i(int(a[0]),int(a[1]),int(a[2]))
static func arr(v: Vector3i) -> Array: return [v.x,v.y,v.z]
static func key(node: Dictionary) -> String: return "%s:%s:%s" % [vec(node.cell),vec(node.normal),node.surface]
static func node(cell: Vector3i, normal: Vector3i, surface: String) -> Dictionary: return {"cell":arr(cell),"normal":arr(normal),"surface":surface}
static func from_hit(hit: Dictionary) -> Dictionary: return node(hit.cell,hit.normal,hit.surface)
static func valid(model, value, occ: Dictionary) -> bool:
	if not value is Dictionary or not value.has_all(["cell","normal","surface"]): return false
	if not model.valid_point(value.cell) or not model.valid_point(value.normal): return false
	var cell:=vec(value.cell); var normal:=vec(value.normal)
	if value.surface=="ground": return normal==Vector3i.UP and cell.y==0 and model.owns_cell(cell) and not occ.has(cell)
	if not occ.has(cell) or model.room_role(model.rooms[int(occ[cell])])=="pole": return false
	if value.surface=="wall": return SIDES.has(normal) and not occ.has(cell+normal)
	if value.surface=="floor": return normal==Vector3i.UP
	if value.surface=="roof": return normal==Vector3i.UP and not occ.has(cell+Vector3i.UP)
	return false

static func corners(n: Dictionary) -> Array:
	var p:=vec(n.cell); var normal:=vec(n.normal)
	if normal.y!=0:
		var h:=1 if n.surface=="roof" else 0
		return [p+Vector3i(0,h,0),p+Vector3i(1,h,0),p+Vector3i(1,h,1),p+Vector3i(0,h,1)]
	if normal.x!=0:
		var x:=1 if normal.x>0 else 0
		return [p+Vector3i(x,0,0),p+Vector3i(x,1,0),p+Vector3i(x,1,1),p+Vector3i(x,0,1)]
	var z:=1 if normal.z>0 else 0
	return [p+Vector3i(0,0,z),p+Vector3i(1,0,z),p+Vector3i(1,1,z),p+Vector3i(0,1,z)]

static func shared(a: Dictionary,b: Dictionary) -> Array:
	var result: Array=[]; var bc:=corners(b)
	for p in corners(a):
		if bc.has(p): result.append(p)
	return result if result.size()==2 else []

static func link_key(link: Dictionary) -> String:
	var ends: Array=[key(link.a),key(link.b)]; ends.sort()
	return "%s:%s:%s" % [link.kind,ends[0],ends[1]]

static func valid_link(model, link, occ: Dictionary) -> bool:
	if not link is Dictionary or not link.has_all(["kind","a","b"]) or not KINDS.has(link.kind): return false
	if not valid(model,link.a,occ) or not valid(model,link.b,occ): return false
	return key(link.a)==key(link.b) or not shared(link.a,link.b).is_empty()

static func prune(model, links: Array) -> Array:
	var occ: Dictionary=model.occupied()
	return links.filter(func(link):return valid_link(model,link,occ))

static func graph(model, mode: int, level: int, underground: bool) -> Dictionary:
	var nodes: Dictionary={}; var edges: Dictionary={}; var seams: Dictionary={}
	var occ: Dictionary=model.occupied()
	for cell in occ:
		if model.room_role(model.rooms[int(occ[cell])])=="pole": continue
		if cell.y>level or (cell.y<0)!=underground: continue
		var list: Array=[]
		for normal in SIDES:
			if not occ.has(cell+normal): list.append(node(cell,normal,"wall"))
		if mode>0: list.append(node(cell,Vector3i.UP,"floor"))
		elif not occ.has(cell+Vector3i.UP): list.append(node(cell,Vector3i.UP,"roof"))
		for n in list: nodes[key(n)]=n
	if not underground:
		var bounds: Rect2i=model.land_bounds()
		for x in range(bounds.position.x,bounds.end.x):
			for z in range(bounds.position.y,bounds.end.y):
				var n:=node(Vector3i(x,0,z),Vector3i.UP,"ground")
				if valid(model,n,occ): nodes[key(n)]=n
	for id in nodes:
		edges[id]=[]
		var points:=corners(nodes[id])
		for i in 4:
			var ends: Array=[str(points[i]),str(points[(i+1)%4])]; ends.sort()
			var seam: String=ends[0]+":"+ends[1]
			if not seams.has(seam): seams[seam]=[]
			for other in seams[seam]:
				# A shared edge is a physical 90-degree or straight connection.
				if shared(nodes[id],nodes[other]).size()==2: edges[id].append(other); edges[other].append(id)
			seams[seam].append(id)
	return {"nodes":nodes,"edges":edges}

static func route(net: Dictionary,a: Dictionary,b: Dictionary) -> Array:
	var start:=key(a); var goal:=key(b)
	if not net.nodes.has(start) or not net.nodes.has(goal): return []
	var pending: Array=[start]; var previous: Dictionary={start:start}; var index:=0
	while index<pending.size():
		var at: String=pending[index]; index+=1
		if at==goal: break
		# Bias equal-length paths toward the tile under the cursor.
		var nexts: Array=net.edges[at].duplicate()
		nexts.sort_custom(func(x,y):return vec(net.nodes[x].cell).distance_squared_to(vec(b.cell))<vec(net.nodes[y].cell).distance_squared_to(vec(b.cell)))
		for next in nexts:
			if not previous.has(next): previous[next]=at; pending.append(next)
	if not previous.has(goal): return []
	var path: Array=[net.nodes[goal]]; var at:=goal
	while at!=start: at=previous[at]; path.push_front(net.nodes[at])
	return path

static func links(kind: String,path: Array) -> Array:
	var result: Array=[]
	if path.size()==1: return [{"kind":kind,"a":path[0].duplicate(true),"b":path[0].duplicate(true)}]
	for i in range(1,path.size()): result.append({"kind":kind,"a":path[i-1].duplicate(true),"b":path[i].duplicate(true)})
	return result

static func add(model,kind: String,path: Array) -> bool:
	if not KINDS.has(kind) or path.is_empty() or path.size()>2048: return false
	var occ: Dictionary=model.occupied(); var seen: Dictionary={}; var additions: Array=[]
	for link in model.utility_links: seen[link_key(link)]=true
	for link in links(kind,path):
		if not valid_link(model,link,occ): return false
		var id:=link_key(link)
		if not seen.has(id): additions.append(link); seen[id]=true
	if additions.is_empty() or model.utility_links.size()+additions.size()>8192: return false
	model.checkpoint(); model.utility_links.append_array(additions)
	return true

static func remove_at(model,kind: String,n: Dictionary) -> bool:
	var id:=key(n)
	var remaining: Array=model.utility_links.filter(func(link):return link.kind!=kind or (key(link.a)!=id and key(link.b)!=id))
	if remaining.size()==model.utility_links.size(): return false
	model.checkpoint(); model.utility_links=remaining; return true

static func powered(model, base: Dictionary) -> Dictionary:
	var occ: Dictionary=model.occupied(); var nodes: Dictionary={}; var edges: Dictionary={}
	for link in model.utility_links:
		if link.kind!="power": continue
		for n in [link.a,link.b]:
			var id:=key(n); nodes[id]=n
			if not edges.has(id): edges[id]=[]
		edges[key(link.a)].append(key(link.b)); edges[key(link.b)].append(key(link.a))
	var reached: Dictionary={}; var pending: Array=[]
	for id in nodes:
		if base.has(vec(nodes[id].cell)): reached[id]=true; pending.append(id)
	while not pending.is_empty():
		var at: String=pending.pop_back()
		for next in edges[at]:
			if not reached.has(next): reached[next]=true; pending.append(next)
	var cells: Dictionary=base.duplicate()
	for id in reached:
		var cell:=vec(nodes[id].cell)
		if occ.has(cell):
			for raw in model.rooms[int(occ[cell])].cells: cells[vec(raw)]=true
	return {"cells":cells,"nodes":reached}

static func transform(links_in: Array,mapping: Dictionary,yaw: int) -> Array:
	var result: Array=links_in.duplicate(true)
	for link in result:
		for n in [link.a,link.b]:
			if mapping.has(vec(n.cell)) and n.surface!="ground":
				n.cell=arr(mapping[vec(n.cell)])
				var normal:=vec(n.normal)
				for i in posmod(yaw,4): normal=Vector3i(-normal.z,normal.y,normal.x)
				n.normal=arr(normal)
	return result
