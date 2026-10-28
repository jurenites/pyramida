extends RefCounted
const Cable=preload("res://scripts/block_city/cable.gd")

static func line(game, parent: Node3D, points: PackedVector3Array, color: Color, radius: float) -> void:
	for i in range(1,points.size()): game.beam(parent,points[i-1],points[i],color,radius)

static func draw(game, parent: Node3D, cable: Dictionary, occupancy: Dictionary = {}) -> void:
	var node:=Node3D.new()
	node.name="PowerConnection"
	parent.add_child(node)
	var heavy: bool=not cable.has("source_cell")
	var wire:=Node3D.new(); wire.name="Wire"; node.add_child(wire)
	var points: PackedVector3Array=game.model.cable_points(cable,occupancy)
	line(game,wire,points,game.INK,0.026 if heavy else 0.011)
	var loose: bool=heavy or cable.has("device") or cable.has("source_device") or points==Cable.curve(Cable.endpoint(cable),game.model.cable_start(cable))
	if loose:
		wire.set_meta("loose",true); wire.set_meta("points",points)
	else:
		for point in points:
			game.box(node,point,Vector3.ONE*0.035,Color("84918d"))
	if cable.get("device","")=="pole": return
	var box_root:=Node3D.new()
	box_root.name="Transformer" if heavy else "FuseBox"
	box_root.position=Cable.endpoint(cable)
	var normal: Vector3i=game.model.vec(cable.normal)
	box_root.rotation.y=atan2(-float(normal.x),-float(normal.z))
	node.add_child(box_root)
	var width:=0.14 if heavy else 0.10
	var height:=0.28 if heavy else 0.16
	game.box(box_root,Vector3(0,0,-0.025),Vector3(width,height,0.10),Color("687e79") if heavy else Color("bcc6be"))
	game.box(box_root,Vector3(0,0,-0.082),Vector3(width*0.72,height*0.78,0.018),Color("d4d6c7"))
	if heavy:
		for x in [-0.085,0.085]:
			for y in [-0.09,-0.03,0.03,0.09]: game.box(box_root,Vector3(x,y,-0.02),Vector3(0.02,0.018,0.1),Color("566b66"))
		for segment in [[Vector3(0.025,0.06,-0.095),Vector3(-0.025,0,-0.095)],[Vector3(-0.025,0,-0.095),Vector3(0.025,0,-0.095)],[Vector3(0.025,0,-0.095),Vector3(-0.025,-0.06,-0.095)]]:
			game.beam(box_root,segment[0],segment[1],game.ACCESS,0.009)
	else:
		game.box(box_root,Vector3(0,0.025,-0.095),Vector3(0.022,0.04,0.012),game.POWER)
	# Feed through the wall to a small interior service outlet. Cutaways reveal it.
	var inner: Vector3=Cable.endpoint(cable)-Vector3(normal)*0.14
	var outlet:=Vector3(inner.x,float(cable.cell[1])+0.18,inner.z)
	game.beam(node,inner,outlet,game.INK,0.004)
	game.box(node,outlet,Vector3(0.06,0.07,0.02) if normal.z!=0 else Vector3(0.02,0.07,0.06),Color("e5e4d8"))

static func animate(root: Node3D, time: float) -> void:
	for connection in root.get_children():
		var wire:=connection.get_node_or_null("Wire")
		if wire==null or not wire.has_meta("loose"): continue
		var points: PackedVector3Array=wire.get_meta("points")
		var span: Vector3=points[-1]-points[0]
		var side:=Vector3(-span.z,0,span.x).normalized()
		for i in wire.get_child_count():
			var a:=points[i]+side*(sin(time*1.4+float(i)*0.07)*sin(PI*i/(points.size()-1))*0.018)
			var b:=points[i+1]+side*(sin(time*1.4+float(i+1)*0.07)*sin(PI*(i+1)/(points.size()-1))*0.018)
			var mesh: MeshInstance3D=wire.get_child(i)
			mesh.position=(a+b)*0.5
			var up: Vector3=(b-a).normalized()
			var right:=up.cross(Vector3.FORWARD).normalized()
			if right.length_squared()<0.1: right=up.cross(Vector3.RIGHT).normalized()
			mesh.basis=Basis(right,up,right.cross(up).normalized()).scaled_local(Vector3(1,a.distance_to(b)/mesh.mesh.height,1))
