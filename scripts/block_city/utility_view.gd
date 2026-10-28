extends RefCounted
const Net=preload("res://scripts/block_city/utility_network.gd")
static func color(kind: String) -> Color:
	return Color("65cbd0") if kind=="power" else (Color("6499dc") if kind=="pipe" else Color("b8bbc1"))
static func point(n: Dictionary,kind: String) -> Vector3:
	var p:=Vector3(Net.vec(n.cell)); var normal:=Net.vec(n.normal)
	var offset:=0.025+Net.KINDS.find(kind)*0.045
	if n.surface=="roof": return p+Vector3(0.5,1+offset,0.5)
	if n.surface in ["floor","ground"]: return p+Vector3(0.5,(0.09 if n.surface=="floor" else 0.02)+offset,0.5)
	var center:=p+Vector3(0.5,0.90,0.5)+Vector3(normal)*(0.5+offset)
	# Use the upper wall band and a jamb-aligned vertical lane, clear of windows.
	if normal.x!=0: center.z=p.z+0.12
	else: center.x=p.x+0.12
	return center
static func line_points(a: Dictionary,b: Dictionary,kind: String) -> PackedVector3Array:
	var start:=point(a,kind); var finish:=point(b,kind)
	if Net.key(a)==Net.key(b): return PackedVector3Array([start])
	var edge:=Net.shared(a,b)
	if edge.is_empty(): return PackedVector3Array()
	var middle: Vector3=(Vector3(edge[0])+Vector3(edge[1]))*0.5
	var delta: Vector3i=edge[1]-edge[0]
	var axis:=delta.abs().max_axis_index()
	middle[axis]=clampf(start[axis],minf(edge[0][axis],edge[1][axis]),maxf(edge[0][axis],edge[1][axis]))
	var offset:=0.025+Net.KINDS.find(kind)*0.045
	var an:=Vector3(Net.vec(a.normal)); var bn:=Vector3(Net.vec(b.normal))
	var hinge:=middle+(an+bn).normalized()*offset
	if an==bn: hinge=middle+an*offset
	# Floor pipes sit above their slab, not within it.
	if a.surface=="floor" and b.surface=="floor": hinge.y+=0.09
	var result:=PackedVector3Array([start])
	for pair in [[a,start,hinge],[b,hinge,finish]]:
		var n: Dictionary=pair[0]; var from: Vector3=pair[1]; var to: Vector3=pair[2]
		var bend:=from
		if Net.vec(n.normal).y!=0: bend.x=to.x
		elif Net.vec(n.normal).x!=0: bend.y=to.y
		else: bend.y=to.y
		if result[-1].distance_to(bend)>0.001: result.append(bend)
		if result[-1].distance_to(to)>0.001: result.append(to)
	return result
static func draw(game,parent: Node3D,links: Array,preview := false) -> void:
	var seen: Dictionary={}
	var powered: Dictionary=game.analysis_powered if game.model.defer_analysis else game.model.powered_cells()
	for link in links:
		var points:=line_points(link.a,link.b,link.kind)
		var tint:=color(link.kind)
		if preview: tint=tint.lightened(0.2)
		for i in range(1,points.size()):
			if points[i-1].distance_to(points[i])<0.002: continue
			if link.kind=="vent":
				var direction: Vector3=(points[i]-points[i-1]).normalized()
				var mesh: MeshInstance3D=game.box(parent,(points[i]+points[i-1])*0.5,Vector3(0.16,points[i-1].distance_to(points[i]),0.16),tint)
				var right:=direction.cross(Vector3.FORWARD).normalized()
				if right.length_squared()<0.1: right=direction.cross(Vector3.RIGHT).normalized()
				mesh.basis=Basis(right,direction,right.cross(direction).normalized())
			else: game.beam(parent,points[i-1],points[i],tint,0.025 if link.kind=="power" else 0.055)
		for n in [link.a,link.b]:
			var id: String=link.kind+Net.key(n)
			if seen.has(id): continue
			seen[id]=true
			var center:=point(n,link.kind)
			var cap_color:=Color("efc85b") if link.kind=="power" and not preview and not powered.has(Net.vec(n.cell)) else tint
			game.box(parent,center,Vector3.ONE*(0.065 if link.kind=="power" else (0.105 if link.kind=="pipe" else 0.19)),cap_color)
