extends RefCounted
## Utility stock is intentionally as readable as the 0.23 m structural Log.
const DIAMETER := 0.25
const SECTION := 0.25
const WALL := 0.03
const CLAY := Color("d88965")
const SOCKET := Color("eba47d")
const WATER := Color("60d5dd")
const Draw = preload("res://scripts/settlement/rope_visuals.gd")

static func material(colour: Color) -> StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	result.albedo_color=colour; result.roughness=0.86
	# Ceramic rims remain readable in the shadow beneath a roof overhang.
	result.emission_enabled=true; result.emission=colour; result.emission_energy_multiplier=0.18
	result.cull_mode=BaseMaterial3D.CULL_DISABLED
	return result

static func mesh_node(parent: Node3D, mesh: Mesh, colour: Color, title: String) -> MeshInstance3D:
	var node:=MeshInstance3D.new(); node.name=title; node.mesh=mesh; node.material_override=material(colour); parent.add_child(node)
	return node

static func rounded(path: Array) -> Array:
	if path.size()<2: return path.duplicate()
	var result: Array=[path[0]]
	for i in range(1,path.size()-1):
		var corner: Vector3=path[i]
		var trim:=minf(0.25,minf(corner.distance_to(path[i-1]),corner.distance_to(path[i+1]))*0.35)
		var a:=corner.move_toward(path[i-1],trim); var b:=corner.move_toward(path[i+1],trim)
		result.append(a)
		for step in range(1,9):
			var t:=step/8.0
			result.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
	result.append(path.back()); return result

static func tube(path: Array, radius := DIAMETER/2, wall := WALL, half := false) -> ArrayMesh:
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frames: Array=[]
	for i in path.size():
		var tangent: Vector3=(path[mini(i+1,path.size()-1)]-path[maxi(0,i-1)]).normalized()
		var side:=tangent.cross(Vector3.UP if absf(tangent.y)<0.95 else Vector3.FORWARD).normalized()
		frames.append([side,tangent.cross(side).normalized()])
	var segments:=16
	for index in range(1,path.size()):
		for shell in 2:
			var r:=radius if shell==0 else radius-wall
			for j in segments:
				var vertices: Array=[]
				for sample in [[index-1,j],[index,j],[index,j+1],[index-1,j+1]]:
					var angle: float=sample[1]*(PI if half else TAU)/segments
					var radial: Vector3=frames[sample[0]][0]*cos(angle)+frames[sample[0]][1]*sin(angle)
					vertices.append([path[sample[0]]+radial*r,radial*(1 if shell==0 else -1)])
				for k in ([0,1,2,0,2,3] if shell==0 else [0,2,1,0,3,2]):
					surface.set_normal(vertices[k][1]); surface.add_vertex(vertices[k][0])
	# Closed ceramic rims at the two open ends. The bore stays empty.
	for index in [0,path.size()-1]:
		for j in segments:
			var a: float=j*(PI if half else TAU)/segments; var b: float=(j+1)*(PI if half else TAU)/segments
			var p: Vector3=frames[index][0]*cos(a)+frames[index][1]*sin(a)
			var q: Vector3=frames[index][0]*cos(b)+frames[index][1]*sin(b)
			var normal: Vector3=(path[index]-path[1 if index==0 else index-1]).normalized()
			for point in [p*radius,q*radius,q*(radius-wall),p*radius,q*(radius-wall),p*(radius-wall)]:
				surface.set_normal(normal); surface.add_vertex(path[index]+point)
	if half:
		for index in range(1,path.size()):
			for side in [-1,1]:
				var a: Vector3=path[index-1]+frames[index-1][0]*radius*side; var b: Vector3=path[index]+frames[index][0]*radius*side
				var c: Vector3=path[index]+frames[index][0]*(radius-wall)*side; var d: Vector3=path[index-1]+frames[index-1][0]*(radius-wall)*side
				for point in [a,b,c,a,c,d]: surface.set_normal(Vector3.UP); surface.add_vertex(point)
	return surface.commit()

static func at_distance(path: Array,distance: float) -> Dictionary:
	for i in range(1,path.size()):
		var length_: float=path[i-1].distance_to(path[i])
		if distance<=length_ or i==path.size()-1:
			return {"at":path[i-1].lerp(path[i],clampf(distance/maxf(length_,0.001),0,1)),"direction":(path[i]-path[i-1]).normalized()}
		distance-=length_
	return {"at":path[0],"direction":Vector3.DOWN}

static func pipe(parent: Node3D,path: Array,preview := false) -> Array:
	var smooth:=rounded(path)
	if smooth.size()<2: return smooth
	mesh_node(parent,tube(smooth),Color("89c6c4") if preview else CLAY,"ClayPipe")
	var length_:=0.0
	for i in range(1,smooth.size()): length_+=smooth[i-1].distance_to(smooth[i])
	for i in maxi(1,ceili(length_/0.5)):
		var p:=at_distance(smooth,minf(length_-0.025,i*0.5+0.025))
		mesh_node(parent,tube([p.at-p.direction*0.035,p.at+p.direction*0.035],0.155,0.03),SOCKET,"Socket")
	return smooth

static func gutter(parent: Node3D,a: Vector3,b: Vector3,mount: Vector3,preview := false) -> void:
	var count:=maxi(1,roundi(a.distance_to(b)/SECTION)); var axis: Vector3=(b-a).normalized()
	for i in count:
		var start:=a.lerp(b,float(i)/count); var end:=a.lerp(b,float(i+1)/count)
		mesh_node(parent,tube([start,end],DIAMETER/2,WALL,true),Color("89c6c4") if preview else CLAY.lightened(0.025*(i%2)),"ClayGutterSection")
		mesh_node(parent,tube([start-axis*0.012,start+axis*0.048],0.165,0.035,true),SOCKET,"GutterSocket")
		var at:=start.lerp(end,0.5)
		# Two-legged saddles screw into the low eave fascia, below the tile lip.
		Draw.beam(parent,at-Vector3.UP*0.135,at+mount-Vector3.UP*0.135,0.035,Color("665652"))
		Draw.beam(parent,at+mount-Vector3.UP*0.135,at+mount+Vector3.UP*0.055,0.035,Color("665652"))
		var bolt:=SphereMesh.new(); bolt.radius=0.025; bolt.height=0.05
		mesh_node(parent,bolt,Color("e0cbb3"),"BracketFastener").position=at+mount

static func end_cap(parent: Node3D,at: Vector3,axis: Vector3,half := true,radius := 0.14) -> MeshInstance3D:
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side:=axis.cross(Vector3.UP if absf(axis.y)<0.95 else Vector3.FORWARD).normalized()
	var down:=axis.cross(side).normalized()
	for i in 16:
		var a:=i*(PI if half else TAU)/16; var b: float=(i+1)*(PI if half else TAU)/16
		var p: Vector3=(side*cos(a)+down*sin(a))*radius; var q: Vector3=(side*cos(b)+down*sin(b))*radius
		for face in [-1,1]:
			for point in [Vector3.ZERO,p,q]:
				surface.set_normal(axis*face); surface.add_vertex(at+axis*0.018*face+point)
		for point in [p-axis*0.018,q-axis*0.018,q+axis*0.018,p-axis*0.018,q+axis*0.018,p+axis*0.018]:
			surface.set_normal((p+q).normalized()); surface.add_vertex(at+point)
	if half:
		for point in [-side*radius-axis*0.018,side*radius-axis*0.018,side*radius+axis*0.018,-side*radius-axis*0.018,side*radius+axis*0.018,-side*radius+axis*0.018]:
			surface.set_normal(Vector3.UP); surface.add_vertex(at+point)
	return mesh_node(parent,surface.commit(),SOCKET,"GutterEndCap" if half else "PipeEndCap")

static func gutter_outlet(parent: Node3D,at: Vector3,axis: Vector3,through := false) -> Vector3:
	var unit:=Node3D.new(); unit.name="TOutlet" if through else "LOutlet"; parent.add_child(unit)
	# A closed crown and side inlet replace the exposed top of the downpipe.
	mesh_node(unit,tube([at+Vector3.UP*0.08,at-Vector3.UP*0.25],0.14,0.03),CLAY,"DownSocket")
	end_cap(unit,at+Vector3.UP*0.09,Vector3.UP,false)
	mesh_node(unit,tube([at-axis*0.18-Vector3.UP*0.05,at-Vector3.UP*0.05],0.125,0.03),CLAY,"SideInlet")
	if through:
		mesh_node(unit,tube([at-Vector3.UP*0.05,at+axis*0.18-Vector3.UP*0.05],0.125,0.03),CLAY,"ThroughInlet")
	else: end_cap(unit,at+axis*0.13-Vector3.UP*0.05,axis,false)
	mesh_node(unit,tube([at-Vector3.UP*0.18,at-Vector3.UP*0.26],0.165,0.035),SOCKET,"DownCollar")
	return at-Vector3.UP*0.26

static func stream(parent: Node3D,a: Vector3,b: Vector3,width := 0.045) -> MeshInstance3D:
	var line:=CylinderMesh.new(); line.top_radius=width/2; line.bottom_radius=width/2; line.height=maxf(0.001,a.distance_to(b)); line.radial_segments=10
	var node:=mesh_node(parent,line,WATER,"Runoff")
	node.position=(a+b)*0.5
	if not a.is_equal_approx(b): node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return node
