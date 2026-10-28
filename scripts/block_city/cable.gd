extends RefCounted
## Shared physical cable curve for rendering, visibility and construction clearance.
const POLE := Vector3(-0.6, 4.5, -0.6)
const SEGMENTS := 24

static func socket(cell: Vector3i, normal: Vector3i, slot: int = -1) -> Vector3:
	if slot<0: return Vector3(cell) + Vector3(0.5, 0.82, 0.5) + Vector3(normal) * 0.51
	var side:=Vector3(-normal.z,0,normal.x)
	return Vector3(cell)+Vector3(0.5,0.80 if slot<2 else 0.20,0.5)+Vector3(normal)*0.56+side*(-0.40 if slot%2==0 else 0.40)

static func curve(end: Vector3, start: Vector3 = POLE) -> PackedVector3Array:
	var points := PackedVector3Array()
	var horizontal := Vector2(end.x - start.x, end.z - start.z).length()
	var sag := minf(0.65, horizontal * 0.12)
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		points.append(start.lerp(end, t) - Vector3.UP * (4 * sag * t * (1 - t)))
	return points

static func intersects_box(end: Vector3, bounds: AABB, start: Vector3 = POLE, sight_line := true) -> bool:
	# Both direct visibility and the actual hanging curve must be clear.
	if sight_line and bounds.intersects_segment(start, end) != null: return true
	var points := curve(end, start)
	for i in range(1, points.size()):
		if bounds.intersects_segment(points[i - 1], points[i]) != null: return true
	return false

static func bounds(cell: Vector3i) -> AABB:
	return AABB(Vector3(cell) + Vector3.ONE * 0.025, Vector3.ONE * 0.95)

static func equipment_socket(cell: Vector3i, normal: Vector3i, slot: int, device: String) -> Vector3:
	var side:=Vector3(-normal.z,0,normal.x)
	if device=="pole":
		return Vector3(cell)+Vector3(0.5,2.33,0.5)+side*(slot-1)*0.25+Vector3(normal)*0.16
	return Vector3(cell)+Vector3(0.5,1.02,0.5)+Vector3((slot-1)*0.28,0,0.20)

static func endpoint(cable: Dictionary) -> Vector3:
	if cable.get("device","") in ["pole","transformer"]:
		return equipment_socket(Vector3i(cable.cell[0],cable.cell[1],cable.cell[2]),Vector3i(cable.normal[0],cable.normal[1],cable.normal[2]),int(cable.slot),str(cable.device))
	return socket(Vector3i(cable.cell[0],cable.cell[1],cable.cell[2]),Vector3i(cable.normal[0],cable.normal[1],cable.normal[2]),int(cable.get("slot",-1)))

static func key(cable: Dictionary, source := false) -> String:
	var prefix: String="source_" if source else ""
	var c: Array=cable.get(prefix+"cell",[0,0,0])
	var n: Array=cable.get(prefix+"normal",[0,0,0])
	return "%s:%s:%s:%s" % [cable.get(prefix+"device","wall"),Vector3i(c[0],c[1],c[2]),Vector3i(n[0],n[1],n[2]),int(cable.get(prefix+"slot",-1))]

static func path_hits(points: PackedVector3Array, bounds: AABB) -> bool:
	for i in range(1,points.size()):
		if bounds.intersects_segment(points[i-1],points[i])!=null: return true
	return false

# A surface graph follows wall borders, leaving windows and doorways clear.
# Rebuild only when occupancy changes, not on each mouse movement.
static var surface_signature: String=""
static var surface_nodes: Array=[]
static var surface_edges: Array=[]
static var surface_faces: Dictionary={}

static func wall_route(start_cell: Vector3i, start_normal: Vector3i, start_slot: int, end_cell: Vector3i, end_normal: Vector3i, end_slot: int, occ: Dictionary) -> PackedVector3Array:
	var signature:=str(occ.keys())
	if signature!=surface_signature:
		surface_signature=signature; surface_nodes=[]; surface_edges=[]; surface_faces={}
		var groups: Dictionary={}
		for cell in occ:
			if cell.y<0: continue
			for normal in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
				if occ.has(cell+normal): continue
				var side:=Vector3(-normal.z,0,normal.x)
				var ids: Array=[]
				for y in [0.06,0.94]:
					for x in [-0.56,0.56]:
						var tangent: Vector3i=Vector3i(side*signf(x))
						var extent: float=0.44 if occ.has(cell+normal+tangent) else 0.56
						var point: Vector3=Vector3(cell)+Vector3(0.5,y,0.5)+Vector3(normal)*0.56+side*signf(x)*extent
						var id:=surface_nodes.size()
						surface_nodes.append(point); surface_edges.append([]); ids.append(id)
						var corner:=Vector3i(point.round())
						for other in groups.get(corner,[]):
							var clear:=true
							for occupied_cell in occ:
								if bounds(occupied_cell).intersects_segment(point,surface_nodes[other])!=null: clear=false; break
							if clear: surface_edges[id].append(other); surface_edges[other].append(id)
						if not groups.has(corner): groups[corner]=[]
						groups[corner].append(id)
				for pair in [[0,1],[2,3],[0,2],[1,3]]:
					var clear:=true
					for occupied_cell in occ:
						if bounds(occupied_cell).intersects_segment(surface_nodes[ids[pair[0]]],surface_nodes[ids[pair[1]]])!=null: clear=false; break
					if clear:
						surface_edges[ids[pair[0]]].append(ids[pair[1]])
						surface_edges[ids[pair[1]]].append(ids[pair[0]])
				surface_faces["%s:%s" % [cell,normal]]=ids
	var from: Array=surface_faces.get("%s:%s" % [start_cell,start_normal],[])
	var to: Array=surface_faces.get("%s:%s" % [end_cell,end_normal],[])
	if from.is_empty() or to.is_empty(): return PackedVector3Array()
	var start:=socket(start_cell,start_normal,start_slot)
	var end:=socket(end_cell,end_normal,end_slot)
	var distance: Dictionary={}; var previous: Dictionary={}; var pending: Array=[]
	for id in from:
		distance[id]=absf(surface_nodes[id].y-start.y)+Vector2(surface_nodes[id].x-start.x,surface_nodes[id].z-start.z).length()
		pending.append(id)
	while not pending.is_empty():
		var best: int=pending[0]
		for id in pending:
			if distance[id]<distance[best]: best=id
		pending.erase(best)
		for next in surface_edges[best]:
			var cost: float=distance[best]+surface_nodes[best].distance_to(surface_nodes[next])
			if cost<distance.get(next,INF):
				distance[next]=cost; previous[next]=best
				if not pending.has(next): pending.append(next)
	var last: int=-1; var cost:=INF
	for id in to:
		var candidate: float=distance.get(id,INF)+absf(surface_nodes[id].y-end.y)+Vector2(surface_nodes[id].x-end.x,surface_nodes[id].z-end.z).length()
		if candidate<cost: last=id; cost=candidate
	if last<0: return PackedVector3Array()
	var route: Array=[surface_nodes[last]]
	while previous.has(last):
		last=previous[last]; route.push_front(surface_nodes[last])
	var first: Vector3=route[0]; var final: Vector3=route[-1]
	route.push_front(Vector3(first.x,start.y,first.z)); route.push_front(start)
	route.append(Vector3(final.x,end.y,final.z)); route.append(end)
	return PackedVector3Array(route)
