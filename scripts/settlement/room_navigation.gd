extends RefCounted
const Rooms=preload("res://scripts/settlement/room_construction.gd")
static func link(edges: Dictionary,a: Vector3i,b: Vector3i) -> void:
	if not edges.has(a): edges[a]=[]
	if not edges.has(b): edges[b]=[]
	if not edges[a].has(b): edges[a].append(b)
	if not edges[b].has(a): edges[b].append(a)
static func add_path(nav,a: Vector3i,b: Vector3i,points: Array) -> void:
	var clean: Array=[]
	for point in points:
		if clean.is_empty() or not point.is_equal_approx(clean.back()): clean.append(point)
	if clean.size()<2: return
	points=clean
	if not nav.room_paths.has(a): nav.room_paths[a]={}
	if not nav.room_paths.has(b): nav.room_paths[b]={}
	nav.room_paths[a][b]=points
	var reverse:=points.duplicate(); reverse.reverse(); nav.room_paths[b][a]=reverse
static func configure(world,surfaces: Dictionary) -> void:
	var nav=world.navigation
	nav.room_offsets={}; nav.room_nodes={}; nav.room_edges={}; nav.room_heights={}; nav.room_paths={}; nav.room_stair_contacts={}
	if world.room_site.is_empty(): return
	var layout=Rooms.layout(world,true); var occ: Dictionary=layout.occupied()
	for room in layout.rooms:
		for raw in room.cells:
			var cell:=Rooms.Layout.vec(raw)
			var below: int=occ.get(cell+Vector3i.DOWN,-1)
			var opening: bool=below>=0 and layout.room_role(layout.rooms[below])=="stairs"
			for p: Vector3i in Rooms.tile_nodes(world,cell):
				nav.room_nodes[p]=room.id
				if layout.room_role(room)=="stairs" or opening:
					nav.blocked[p]=true; continue
				surfaces[p]=true; nav.room_heights[p]=p.y+0.16
	for room in layout.rooms:
		if layout.room_role(room)=="stairs": continue
		for raw in room.cells:
			for p: Vector3i in Rooms.tile_nodes(world,Rooms.Layout.vec(raw)):
				for direction in world.DIRECTIONS:
					if nav.room_nodes.get(p+direction,-1)==room.id: link(nav.room_edges,p,p+direction)
		for port in layout.room_ports(room):
			var origin:=Rooms.base(world,port.cell)
			for lane in 2:
				var inside:=origin
				if port.normal.x!=0: inside+=Vector3i(1 if port.normal.x>0 else 0,0,lane)
				else: inside+=Vector3i(lane,0,1 if port.normal.z>0 else 0)
				var outside: Vector3i=inside+port.normal
				# A neighboring room must expose a reciprocal opening.
				if nav.room_nodes.has(outside):
					var other: Dictionary=layout.rooms[nav.room_nodes[outside]]
					if not layout.port_matches(other,port.cell+port.normal,-port.normal): continue
				link(nav.room_edges,inside,outside)
				if not surfaces.has(inside) or not surfaces.has(outside) or nav.blocked.has(inside) or nav.blocked.has(outside): continue
				# Tile centres lie beside a centred doorway. Walk through its actual
				# aperture instead of taking a straight edge through a wall pier.
				var n:=Vector3(port.normal)
				var center:=Vector3(origin)+Vector3(0.5,0.16,0.5)+n*1.0
				center+=Vector3(-n.z,0,n.x)*float(port.get("across",0))*2
				var start:=Vector3(inside)+Vector3.UP*float(nav.room_heights.get(inside,inside.y)-inside.y)
				var end:=Vector3(outside)+Vector3.UP*float(nav.room_heights.get(outside,outside.y)-outside.y)
				add_path(nav,inside,outside,[start,center-n*0.35,center+n*0.35,end])
	for room in layout.rooms:
		if layout.room_role(room)!="stairs": continue
		var normal:=Rooms.Layout.vec(room.normal)
		var yaw:=0
		while Rooms.Layout.rotate_point(Vector3i.FORWARD,yaw)!=normal: yaw+=1
		var center:=Vector3(Rooms.base(world,Rooms.Layout.vec(room.cells[0])))+Vector3(0.5,0,0.5)
		var lower:=Vector3i((center+Vector3(-0.5,0,-1.5).rotated(Vector3.UP,-yaw*PI/2)).round())
		var upper:=Vector3i((center+Vector3(0.5,2,-1.5).rotated(Vector3.UP,-yaw*PI/2)).round())
		if not surfaces.has(lower) or not surfaces.has(upper) or nav.blocked.has(lower) or nav.blocked.has(upper): continue
		# Endpoints must really open toward this shaft, not through an ordinary wall.
		if nav.room_nodes.has(lower) and not nav.room_edges.get(lower,[]).has(lower-normal): continue
		if nav.room_nodes.has(upper) and not nav.room_edges.get(upper,[]).has(upper-normal): continue
		var path: Array=[Vector3(lower)+Vector3.UP*(0.16 if nav.room_heights.has(lower) else 0)]
		for point in Rooms.Stair.route(): path.append(center+(point*2).rotated(Vector3.UP,-yaw*PI/2))
		path.append(Vector3(upper)+Vector3.UP*0.16)
		add_path(nav,lower,upper,path)
		preload("res://scripts/settlement/indoor_stair_contact.gd").register(nav,lower,upper,center,-yaw*PI/2,path)
	for bed in world.room_site.beds:
		var p:=Rooms.base(world,Rooms.Layout.vec(bed.cell))
		var access:=Rooms.bed_access(world,bed)
		var occupied:=p+Vector3i.RIGHT if access.x==p.x else p
		nav.blocked[occupied]=true; nav.blocked[occupied+Vector3i.BACK]=true

	var utilities=load("res://scripts/settlement/room_utilities.gd")
	for owner in utilities.states(world):
		var service: Dictionary=utilities.state(world,owner)
		if service.stove:
			var at: Vector3=utilities.pose(world,utilities.room(world,owner))*Vector3(1.35,0,0.35)
			nav.blocked[Vector3i(at.round())]=true
		if service.rain: nav.blocked[utilities.barrel_cell(world,owner)]=true

static func target(path: Array,position: Vector3) -> Vector3:
	# Project onto the authored walking polyline; never shortcut across its U turn.
	var nearest:=INF; var segment:=1; var fraction:=0.0
	for i in range(1,path.size()):
		var from: Vector3=path[i-1]; var delta: Vector3=path[i]-from
		var t:=clampf((position-from).dot(delta)/maxf(delta.length_squared(),0.00001),0,1)
		var distance:=position.distance_squared_to(from+delta*t)
		if distance<nearest: nearest=distance; segment=i; fraction=t
	if fraction>0.999 and segment<path.size()-1: segment+=1
	return path[segment]
