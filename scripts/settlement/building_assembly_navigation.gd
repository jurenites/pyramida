extends RefCounted
## Mixed-room routes use the same portals as their visible walls.
const Layout=preload("res://scripts/settlement/building_assembly_layout.gd")
const Geometry=preload("res://scripts/settlement/building_walk_geometry.gd")
const Link=preload("res://scripts/settlement/room_navigation.gd")
const Railing=preload("res://scripts/settlement/terrace_railing.gd")
static func walk_inside(entry: Dictionary) -> bool:
	# Low storage roofs and closed metre decks lack adult headroom.
	return entry.height>=Geometry.BODY_HEIGHT+0.12 and entry.kind not in ["support","stair","well"]
static func anchor(entry: Dictionary) -> Vector3:
	var point: Vector3=entry.at+Vector3.UP*Geometry.floor_height(entry)
	if entry.kind!="house": point+=Vector3(entry.front)*((entry.rect.size.x if entry.front.x else entry.rect.size.y)/2-0.42)
	return point
static func obstacles(entry: Dictionary) -> Array[Rect2]:
	return Geometry.rectangles(entry)
static func free_anchor(entry: Dictionary,blocks: Array[Rect2]) -> Variant:
	var preferred:=anchor(entry)
	if clear(preferred,preferred,blocks): return preferred
	var best: Variant=null; var distance:=INF
	var inner: Rect2=entry.rect.grow(-Geometry.RADIUS-0.04)
	for x in range(ceili(inner.position.x*4),floori(inner.end.x*4)+1):
		for z in range(ceili(inner.position.y*4),floori(inner.end.y*4)+1):
			var candidate:=Vector3(x/4.0,preferred.y,z/4.0)
			if clear(candidate,candidate,blocks) and candidate.distance_squared_to(preferred)<distance: best=candidate; distance=candidate.distance_squared_to(preferred)
	return best
static func clear(a: Vector3,b: Vector3,blocks: Array[Rect2]) -> bool:
	for rect in blocks:
		var box:=AABB(Vector3(rect.position.x,-100,rect.position.y),Vector3(rect.size.x,200,rect.size.y))
		if box.intersects_segment(a,b)!=null: return false
	return true
static func path(entry: Dictionary,a: Vector3,b: Vector3,blocks: Array[Rect2]=[]) -> Array:
	if blocks.is_empty(): blocks=obstacles(entry)
	if not clear(a,a,blocks) or not clear(b,b,blocks): return []
	var nodes: Array[Vector3]=[a,b]
	for rect in blocks:
		for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
			var away: Vector2=(corner-rect.get_center()).normalized()*0.025
			var point:=Vector3(corner.x+away.x,a.y,corner.y+away.y)
			if entry.rect.grow(-Geometry.RADIUS).has_point(Vector2(point.x,point.z)) and clear(point,point,blocks): nodes.append(point)
	var distances: Array=[]; var previous: Array=[]; var visited: Array=[]
	for i in nodes.size(): distances.append(INF); previous.append(-1)
	distances[0]=0.0
	for _i in nodes.size():
		var current: int=-1
		for i in nodes.size():
			if i not in visited and (current<0 or distances[i]<distances[current]): current=i
		if current<0 or is_inf(distances[current]): break
		visited.append(current)
		for i in nodes.size():
			if i in visited or not clear(nodes[current],nodes[i],blocks): continue
			var cost: float=distances[current]+nodes[current].distance_to(nodes[i])
			if cost<distances[i]: distances[i]=cost; previous[i]=current
	if is_inf(distances[1]): return []
	var result: Array=[b]; var cursor: int=1
	while cursor!=0: cursor=previous[cursor]; result.push_front(nodes[cursor])
	return result
static func ports(entry: Dictionary,entries: Dictionary,blocks: Array[Rect2]) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var used: Dictionary={}
	for normal: Vector3i in Layout.SIDES:
		if not entry.open and not entry.socket and normal!=entry.front: continue
		var axis:=0 if normal.x else 1; var along:=1-axis
		var positive: bool=normal.x>0 or normal.z>0
		var edge: float=entry.rect.end[axis] if positive else entry.rect.position[axis]
		var outside_axis: int=ceili(edge+0.5) if positive else floori(edge-0.5)
		var positions: Array=[entry.rect.get_center()[along]]
		if entry.open or entry.socket:
			for i in range(ceili((entry.rect.position[along]+0.4)*2),floori((entry.rect.end[along]-0.4)*2)+1): positions.append(i/2.0)
		for across in positions:
			var threshold:=Vector3(edge if normal.x else across,entry.cell.y+Geometry.floor_height(entry),across if normal.x else edge)
			var inside:=threshold-Vector3(normal)*0.30
			var address:=Vector3i(outside_axis if normal.x else roundi(across),entry.cell.y,roundi(across) if normal.x else outside_axis)
			if used.has(address) or not clear(inside,threshold,blocks): continue
			var end:=Vector3(address)+Vector3.UP*0.06
			if not clear(threshold,end,blocks): continue
			var valid:=true
			for other in entries.values():
				if other.cell==entry.cell or other.cell.y!=entry.cell.y: continue
				var rect: Rect2=other.rect.grow(Geometry.RADIUS)
				if AABB(Vector3(rect.position.x,end.y-1,rect.position.y),Vector3(rect.size.x,2,rect.size.y)).intersects_segment(threshold,end)!=null: valid=false; break
			if not valid: continue
			used[address]=true; result.append({"cell":address,"inside":inside,"threshold":threshold})
	return result
static func configure(world,surfaces: Dictionary) -> void:
	var entries:=Layout.build(world); var nav=world.navigation
	nav.building_stock_state=stock_signature(world)
	nav.building_access.clear()
	var anchors: Dictionary={}; var solids: Dictionary={}; var entry_ports: Dictionary={}
	for cell in entries:
		var entry: Dictionary=entries[cell]
		if not walk_inside(entry): continue
		var blocks:=Geometry.rectangles(entry,world)
		blocks.append_array(natural_obstacles(world,entry)); solids[cell]=blocks
		var at: Variant=nav.surface_point(cell) if entry.kind=="house" else free_anchor(entry,blocks)
		if at==null or entry.kind=="stone_storage": continue
		anchors[cell]=at
		if entry.kind=="house": continue
		surfaces[cell]=true; nav.blocked.erase(cell); nav.room_nodes[cell]=hash([cell,entry.kind]); nav.room_offsets[cell]=at-Vector3(cell); nav.room_heights[cell]=at.y
		nav.access_overrides[cell]=[cell]
		var tangent:=Vector3(-entry.front.z,0,entry.front.x)
		for sign_ in ([-1,1] if entry.open or entry.socket else []):
			var point: Vector3=at+tangent*sign_*0.70
			if not entry.rect.grow(-Geometry.RADIUS-0.04).has_point(Vector2(point.x,point.z)) or not clear(point,point,blocks): continue
			var address:=Vector3i(point.round())
			if address==cell or nav.room_nodes.has(address) or entries.has(address): continue
			var points:=path(entry,at,point,blocks)
			if points.is_empty(): continue
			surfaces[address]=true; nav.blocked.erase(address); nav.room_nodes[address]=nav.room_nodes[cell]
			nav.room_offsets[address]=point-Vector3(address); nav.room_heights[address]=point.y
			Link.link(nav.room_edges,cell,address); Link.add_path(nav,cell,address,points)
			nav.access_overrides[cell].append(address)
		nav.building_access[cell]=nav.access_overrides[cell].duplicate()
	for cell in entries:
		var entry: Dictionary=entries[cell]
		if not walk_inside(entry) or entry.kind=="house": continue
		var blocks: Array[Rect2]=solids[cell]
		var entrances:=ports(entry,entries,blocks)
		entry_ports[cell]=entrances
		for port in entrances:
			if not surfaces.has(port.cell) or nav.blocked.has(port.cell): continue
			if anchors.has(cell):
				var points:=path(entry,anchors[cell],port.inside,blocks)
				if not points.is_empty():
					points.append(port.threshold); points.append(nav.surface_point(port.cell))
					Link.link(nav.room_edges,cell,port.cell); Link.add_path(nav,cell,port.cell,points)
			# Open rooms may have several clear lanes, even when equipment separates them.
			for other in entrances:
				if port.cell>=other.cell or not surfaces.has(other.cell) or nav.blocked.has(other.cell): continue
				var points:=path(entry,port.inside,other.inside,blocks)
				if points.is_empty(): continue
				points.push_front(port.threshold); points.push_front(nav.surface_point(port.cell))
				points.append(other.threshold); points.append(nav.surface_point(other.cell))
				Link.link(nav.room_edges,port.cell,other.cell); Link.add_path(nav,port.cell,other.cell,points)
	for cell in entries:
		var entry: Dictionary=entries[cell]
		if not walk_inside(entry): continue
		for join in entry.joins:
			var other: Dictionary=entries[join.other]
			if not walk_inside(other) or cell>other.cell: continue
			var point: Vector3=join.point+Vector3.UP*Geometry.floor_height(entry)
			var first_options: Array=entry_ports.get(cell,[]).duplicate()
			if anchors.has(cell): first_options.push_front({"cell":cell,"inside":anchors[cell],"threshold":anchors[cell]})
			var second_options: Array=entry_ports.get(other.cell,[]).duplicate()
			if anchors.has(other.cell): second_options.push_front({"cell":other.cell,"inside":anchors[other.cell],"threshold":anchors[other.cell]})
			for first_port in first_options:
				if not surfaces.has(first_port.cell) or nav.blocked.has(first_port.cell): continue
				var first:=path(entry,first_port.inside,point-Vector3(join.normal)*0.30,solids[cell])
				if first.is_empty(): continue
				for second_port in second_options:
					if first_port.cell==second_port.cell or not surfaces.has(second_port.cell) or nav.blocked.has(second_port.cell): continue
					var second:=path(other,join.far+Vector3.UP*Geometry.floor_height(other)+Vector3(join.normal)*0.30,second_port.inside,solids[other.cell])
					if second.is_empty(): continue
					var points: Array=first.duplicate()
					if first_port.cell!=cell: points.push_front(first_port.threshold); points.push_front(nav.surface_point(first_port.cell))
					points.append(point); points.append(join.far+Vector3.UP*Geometry.floor_height(other)); points.append_array(second)
					if second_port.cell!=other.cell: points.append(second_port.threshold); points.append(nav.surface_point(second_port.cell))
					Link.link(nav.room_edges,first_port.cell,second_port.cell); Link.add_path(nav,first_port.cell,second_port.cell,points)
	# Roof sockets remain available to construction; only real terraces carry pedestrians.
	var terraces: Dictionary={}; var rail_blocks: Dictionary={}; var roof_sockets: Dictionary={}
	for entry in entries.values():
		if entry.socket: continue
		var level: int=entry.cell.y+int(entry.height)
		if not entry.terrace:
			for roof in world.structural_roof_cells(entry.cell,world.buildings[entry.cell]):
				if surfaces.has(roof) and not nav.room_nodes.has(roof) and not world.ground.has(roof) and not world.platforms.has(roof):
					nav.room_nodes[roof]=hash([entry.cell,"roof_socket"]); roof_sockets[roof]=true
			continue
		if not rail_blocks.has(level): rail_blocks[level]=[]
		for rail in Layout.rails(entry,entries):
			var box:=Rect2(Vector2(rail[0].x,rail[0].z),Vector2.ZERO).expand(Vector2(rail[1].x,rail[1].z)).grow(Geometry.RADIUS+Railing.CLEARANCE)
			rail_blocks[level].append(box)
		for x in range(ceili(entry.rect.position.x),floori(entry.rect.end.x)+1):
			for z in range(ceili(entry.rect.position.y),floori(entry.rect.end.y)+1):
				var at:=Vector3i(x,level,z)
				if nav.room_nodes.has(at): continue
				var inner: Rect2=entry.rect.grow(-Geometry.RADIUS-Railing.CLEARANCE-0.015)
				var local_point:=Vector3(clampf(x,inner.position.x,inner.end.x),entry.at.y,clampf(z,inner.position.y,inner.end.y))
				var placed:=Layout.Pose.point(entry,local_point)
				var point:=Vector2(placed.x,placed.z)
				if not Layout.roof_open(entry,point,entries): surfaces.erase(at); continue
				var blocked:=false
				for upper in entry.above:
					if Layout.Pose.bounds(entries[upper]).grow(Geometry.RADIUS).has_point(point): blocked=true; break
				if blocked: surfaces.erase(at); continue
				surfaces[at]=true; nav.blocked.erase(at); nav.room_nodes[at]=hash([entry.cell,"terrace"]); nav.room_heights[at]=level+0.06
				nav.room_offsets[at]=Vector3(point.x-x,0,point.y-z); terraces[at]=true
	for cell in terraces:
		for side in Layout.SIDES:
			var other: Vector3i=cell+side
			if roof_sockets.has(other): continue
			if not terraces.has(other) and (not nav.room_nodes.has(other) or nav.blocked.has(other) or entries.has(other)): continue
			var a: Vector3=nav.surface_point(cell); var b: Vector3=nav.surface_point(other)
			var solids_: Array[Rect2]=[]; solids_.assign(rail_blocks.get(cell.y,[]))
			var approach: Vector3=b
			for upper in entries.values():
				if upper.cell.y!=cell.y: continue
				solids_.append(Layout.Pose.bounds(upper).grow(Geometry.RADIUS+0.01))
				if not terraces.has(other) and upper.kind=="house":
					for normal in Layout.SIDES:
						if upper.cell+normal==other: approach=b+Vector3(normal)*0.32
			if not clear(a,approach,solids_): continue
			Link.link(nav.room_edges,cell,other); Link.add_path(nav,cell,other,[a,approach,b])
	# Terrace poses may have moved a boundary node inward from its grid address.
	for a in nav.room_paths:
		for b in nav.room_paths[a]:
			nav.room_paths[a][b][0]=nav.surface_point(a); nav.room_paths[a][b][-1]=nav.surface_point(b)
	# Native Home edges must obey the same utility and obstacle clearance as mixed rooms.
	for a in nav.room_paths.keys():
		for b in nav.room_paths[a].keys():
			if a>=b: continue
			var points: Array=nav.room_paths[a][b]
			var valid:=true
			for cell in solids:
				if a.y!=cell.y or b.y!=cell.y: continue
				for i in range(1,points.size()):
					if not clear(points[i-1],points[i],solids[cell]): valid=false; break
				if not valid: break
			if valid: continue
			nav.room_paths[a].erase(b); nav.room_paths[b].erase(a)
			nav.room_edges.get(a,[]).erase(b); nav.room_edges.get(b,[]).erase(a)
static func restore_access(world) -> void:
	# Farming's legacy perimeter pass runs after navigation; keep native room access.
	for entry in Layout.build(world).values():
		if walk_inside(entry) and entry.kind!="house" and world.navigation.room_nodes.has(entry.cell) and not world.navigation.blocked.has(entry.cell): world.navigation.access_overrides[entry.cell]=world.navigation.building_access.get(entry.cell,[entry.cell])

static func stock_signature(world) -> Array:
	var result: Array=[]
	for cell in world.stores:
		var kind: String=world.buildings.get(cell,{}).get("kind","")
		if not Layout.supported(kind) or kind in ["house","well","support","stair","small_warehouse","log_shed","hay_barn"]: continue
		var inventory=world.stores[cell]
		result.append([cell,inventory.amounts.duplicate(),inventory.slots.duplicate()])
	return result

static func storage_busy(world,cell: Vector3i) -> bool:
	# Bulk stock is handed over from outside. Let a current crossing finish before
	# filling its aisle with the next delivered stone; pickup only frees space.
	if world.buildings.get(cell,{}).get("kind","")!="stone_storage": return false
	var entry: Dictionary=Layout.build(world)[cell]
	var rect: Rect2=entry.rect.grow(Geometry.RADIUS)
	var box:=AABB(Vector3(rect.position.x,cell.y-0.05,rect.position.y),Vector3(rect.size.x,Geometry.BODY_HEIGHT,rect.size.y))
	for worker in world.workers:
		if box.has_point(worker.position): return true
		var route: Array=worker.get("clearance_route",worker.route)
		var index: int=worker.get("clearance_index",worker.route_index)
		if index>=route.size(): continue
		var points: Array=world.navigation.room_paths.get(worker.cell,{}).get(route[index],[])
		for i in range(1,points.size()):
			if box.intersects_segment(points[i-1],points[i])!=null: return true
	return false

static func natural_obstacles(world,entry: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	for collection in [world.trees,world.wells,world.deposits]:
		for cell in collection:
			if cell.y!=entry.cell.y or Vector2(cell.x-entry.cell.x,cell.z-entry.cell.z).length()>5.0: continue
			if collection==world.deposits and (cell==entry.cell or collection[cell].get("kind","")=="berry" or (collection[cell].get("kind","")=="limestone" and collection[cell].inventory.count("stone")==0)): continue
			var radius:=0.35 if collection==world.trees else 0.5
			result.append(Rect2(Vector2(cell.x-radius,cell.z-radius),Vector2.ONE*radius*2).grow(Geometry.RADIUS))
	return result
