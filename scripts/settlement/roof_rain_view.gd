extends Node3D
const Rain = preload("res://scripts/settlement/roof_rain.gd")
const V = preload("res://scripts/settlement/modular_house_view.gd")
var stamp := 0
var targets: Array = []
var levels := {}
var drops := {}
var model
const Geometry = preload("res://scripts/settlement/rain_fitting_geometry.gd")
var streams: Array=[]
var splashes: Array=[]
var damp: Node3D
var damp_stamp := -1
static func channel(a: Vector3, b: Vector3) -> ArrayMesh:
	return Geometry.tube([a,b],0.125,0.03,true)
static func junction(root: Node3D,at: Vector3,preview := false) -> void:
	Geometry.mesh_node(root,Geometry.tube([at-Vector3.UP*0.18,at+Vector3.UP*0.18],0.17,0.035),Color("89c6c4") if preview else Geometry.CLAY,"ClayJunction")
	Geometry.mesh_node(root,Geometry.tube([at+Vector3.UP*0.12,at+Vector3.UP*0.19],0.20,0.04),Geometry.SOCKET,"JunctionSocket")
	Geometry.end_cap(root,at+Vector3.UP*0.20,Vector3.UP,false,0.20)
static func vessel(root: Node3D, kind: String, ghost := false) -> MeshInstance3D:
	var colour: Color=V.Resources.colour("pottery") if kind=="vase" else V.Wood.WOOD[0]
	if ghost: colour=Color(0.6,0.8,0.8,0.4)
	if kind=="basin":
		V.box(root,Vector3(2.1,0.12,2.1),Vector3(0,0.06,0),Geometry.CLAY)
		for side in [-1,1]:
			V.box(root,Vector3(2.1,0.75,0.14),Vector3(0,0.375,side*0.98),Geometry.CLAY)
			V.box(root,Vector3(0.14,0.75,1.82),Vector3(side*0.98,0.375,0),Geometry.CLAY)
		var water:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(1.8,1.8); water.mesh=plane; water.material_override=Geometry.material(Geometry.WATER); root.add_child(water); return water
	if kind=="vase":
		var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Trace the outside, lip and complete inside down to the bowl floor.
		var rings: Array=[Vector2(0,0.14),Vector2(0.08,0.19),Vector2(0.3,0.23),Vector2(0.46,0.18),Vector2(0.56,0.17),Vector2(0.56,0.14),Vector2(0.48,0.15),Vector2(0.3,0.20),Vector2(0.09,0.16),Vector2(0.04,0.11),Vector2(0.04,0)]
		for row in range(1,rings.size()):
			for j in 16:
				var a:=Vector3(cos(j*TAU/16)*rings[row-1].y,rings[row-1].x,sin(j*TAU/16)*rings[row-1].y)
				var b:=Vector3(cos((j+1)*TAU/16)*rings[row-1].y,rings[row-1].x,sin((j+1)*TAU/16)*rings[row-1].y)
				var c:=Vector3(cos(j*TAU/16)*rings[row].y,rings[row].x,sin(j*TAU/16)*rings[row].y)
				var d:=Vector3(cos((j+1)*TAU/16)*rings[row].y,rings[row].x,sin((j+1)*TAU/16)*rings[row].y)
				# Godot front faces wind clockwise. Keep the exterior facing out.
				for vertex in [a,b,c]: surface.add_vertex(vertex)
				if not c.is_equal_approx(d):
					for vertex in [b,d,c]: surface.add_vertex(vertex)
				if row==1:
					for vertex in [Vector3.ZERO,b,a]: surface.add_vertex(vertex)
		surface.generate_normals()
		var shell:=MeshInstance3D.new(); shell.mesh=surface.commit(); shell.material_override=V.Draw.material(colour); root.add_child(shell)
	else:
		preload("res://scripts/settlement/rain_barrel.gd").build(root,ghost)
	var water:=MeshInstance3D.new(); var disk:=CylinderMesh.new(); disk.top_radius=0.14 if kind=="vase" else 0.225; disk.bottom_radius=disk.top_radius; disk.height=0.015; disk.radial_segments=16
	water.mesh=disk; water.material_override=V.Draw.material(V.P.WATER_BLUE); root.add_child(water)
	return water
func pipe_shape(spec: Dictionary,preview := false) -> Array:
	var path: Array=spec.path.duplicate()
	if spec.get("target_joint",-1)<0 and not spec.has("outfall") and path.size()>1:
		# Expose the spout and falling water above the receiver, with an air gap.
		var end: Vector3=path.back(); var above:=end+Vector3.UP*0.20
		if path[-2].y>=above.y: path[-1]=above
	return Geometry.pipe(self,path,preview)
func sync(world) -> void:
	model=world
	var lanes:=Rain.roof_lanes(world)
	var next:=hash([world.get_instance_id(),world.roof_rain.tanks,world.roof_rain.gutters,world.roof_rain.pipes,world.roof_rain.get("junctions",{}),lanes,world.plans.values().filter(func(p):return p.kind=="rain_fitting")])
	if next!=stamp:
		stamp=next
		for child in get_children(): child.free()
		damp=null; damp_stamp=-1; targets.clear(); levels.clear(); drops.clear(); streams.clear(); splashes.clear()
		for cell: Vector3i in world.roof_rain.tanks:
			var tank: Dictionary=world.roof_rain.tanks[cell]
			var holder:=Node3D.new(); add_child(holder); holder.position=Rain.tank_position(world,cell)
			levels[cell]=vessel(holder,tank.kind)
			var radius:=Rain.tank_radius(tank.kind)
			targets.append({"kind":"tank","cell":cell,"box":AABB(holder.position-Vector3(radius,0,radius),Vector3(radius*2,0.8,radius*2))})
		for id in world.roof_rain.gutters:
			var gutter: Dictionary=world.roof_rain.gutters[id]
			if not lanes.has(gutter.lane): continue
			var lane: Dictionary=lanes[gutter.lane]
			Geometry.gutter(self,lane.a,lane.b,lane.mount)
			targets.append({"kind":"gutter","id":id,"box":AABB(lane.a,lane.b-lane.a).abs().grow(0.19)})
			var water:=Geometry.stream(self,lane.a-Vector3.UP*0.065,lane.b-Vector3.UP*0.065,0.10)
			streams.append({"node":water,"gutter":id})
			var preceding: bool=world.roof_rain.gutters.values().any(func(g):return lanes.has(g.lane) and lanes[g.lane].roof==lane.roof and is_equal_approx(lanes[g.lane].to,lane.from))
			if not preceding: Geometry.end_cap(self,lane.a,(lane.b-lane.a).normalized())
			var continuing: bool=world.roof_rain.gutters.values().any(func(g):return lanes.has(g.lane) and lanes[g.lane].roof==lane.roof and is_equal_approx(lanes[g.lane].from,lane.to))
			var has_pipe: bool=world.roof_rain.pipes.values().any(func(p):return p.get("gutter")==id)
			if not continuing or has_pipe:
				var outlet:=Geometry.gutter_outlet(self,lane.b,(lane.b-lane.a).normalized(),continuing)
				var spill:=Geometry.stream(self,outlet,lane.b-Vector3.UP*0.85,0.055)
				streams.append({"node":spill,"leak":id})
			var bead:=SphereMesh.new(); bead.radius=0.05; bead.height=0.10
			drops[id]=Geometry.mesh_node(self,bead,Geometry.WATER,"RoofRunoffDrop")
		for id in world.roof_rain.get("junctions",{}):
			var joint: Dictionary=world.roof_rain.junctions[id]; junction(self,joint.position)
			targets.append({"kind":"junction","id":id,"box":AABB(joint.position-Vector3.ONE*0.22,Vector3.ONE*0.44)})
		for id in world.roof_rain.pipes:
			var spec: Dictionary=world.roof_rain.pipes[id]
			var path:=pipe_shape(spec)
			for i in range(1,path.size()):
				targets.append({"kind":"pipe","id":id,"a":path[i-1],"b":path[i],"box":AABB(path[i-1],Vector3.ZERO).expand(path[i]).grow(0.18)})
			if spec.get("target_joint",-1)<0:
				var end: Vector3=spec.path.back(); var cell: Variant=Rain.receiver(world,spec)
				var landing: Vector3=end-Vector3.UP*0.22
				if spec.has("outfall"): landing=Rain.inlet(world,cell)-Vector3.UP*0.12 if cell!=null else Rain.floor_position(world,spec.outfall)+Vector3.UP*0.025
				var water:=Geometry.stream(self,path.back(),landing,0.07)
				streams.append({"node":water,"pipe":id})
				var ring:=TorusMesh.new(); ring.inner_radius=0.045; ring.outer_radius=0.065; ring.rings=16; ring.ring_segments=4
				var splash:=Geometry.mesh_node(self,ring,Geometry.WATER,"ReceiverRipple"); splash.position=landing
				splashes.append({"node":splash,"cell":cell,"pipe":id})
		for plan in world.plans.values():
			if plan.kind!="rain_fitting": continue
			var spec: Dictionary=plan.rain_spec
			var holder:=Node3D.new(); add_child(holder)
			if spec.kind in Rain.CAPACITY:
				holder.position=Rain.floor_position(world,spec.cell,spec.offset); vessel(holder,spec.kind,true).hide()
				targets.append({"kind":"plan","id":plan.id,"box":AABB(holder.position-Vector3(0.3,0,0.3),Vector3(0.6,0.8,0.6))})
			elif spec.kind=="gutter" and lanes.has(spec.lane):
				var lane: Dictionary=lanes[spec.lane]; Geometry.gutter(holder,lane.a,lane.b,lane.mount,true)
				targets.append({"kind":"plan","id":plan.id,"box":AABB(lane.a,Vector3.ZERO).expand(lane.b).grow(0.19)})
			elif spec.kind=="junction":
				junction(holder,spec.position,true); targets.append({"kind":"plan","id":plan.id,"box":AABB(spec.position-Vector3.ONE*0.22,Vector3.ONE*0.44)})
			elif spec.kind=="pipe":
				var path:=pipe_shape(spec,true)
				for i in range(1,path.size()): targets.append({"kind":"plan","id":plan.id,"a":path[i-1],"b":path[i],"box":AABB(path[i-1],Vector3.ZERO).expand(path[i]).grow(0.18)})
	for cell in levels:
		var inventory=world.Hydrology.inventory_at(world,cell)
		if inventory==null: continue
		var fraction: float=(inventory.count("water")+float(world.roof_rain.fractions.get(cell,0)))/inventory.capacity
		levels[cell].visible=fraction>0
		levels[cell].position.y=0.12+fraction*(0.39 if world.roof_rain.tanks[cell].kind=="vase" else 0.52)
		if world.roof_rain.tanks[cell].kind=="barrel":
			var width:=preload("res://scripts/settlement/rain_barrel.gd").radius_at(levels[cell].position.y)-0.04
			levels[cell].scale=Vector3(width/0.225,1,width/0.225)
	var flowing: Dictionary={}
	for id in world.roof_rain.pipes:
		var spec: Dictionary=world.roof_rain.pipes[id]
		if spec.get("gutter",-1)<0 or not Rain.path_error(world,spec).is_empty(): continue
		var visited: Dictionary={}; var next_id: int=id
		while not visited.has(next_id):
			visited[next_id]=true; flowing[next_id]=true
			var pipe: Dictionary=world.roof_rain.pipes[next_id]
			if pipe.get("target_joint",-1)<0: break
			var next_pipe:=Rain.downstream(world,pipe.target_joint)
			if next_pipe.is_empty() or not Rain.path_error(world,next_pipe).is_empty(): break
			next_id=world.roof_rain.pipes.find_key(next_pipe)
	for item in streams:
		item.node.visible=world.weather.raining and (item.has("gutter") or flowing.has(item.get("pipe")))
		if item.has("leak"): item.node.visible=world.weather.raining and Rain.outlet_pipe(world,item.leak,lanes)<0
	for item in splashes:
		item.node.visible=world.weather.raining and flowing.has(item.pipe)
		if levels.has(item.cell): item.node.position.y=levels[item.cell].global_position.y+0.015
		var pulse:=0.5+fposmod(world.time*1.5+item.pipe*0.2,1)
		item.node.scale=Vector3(pulse,1,pulse)
	for id in drops:
		drops[id].visible=world.weather.raining
		var lane: Dictionary=lanes[world.roof_rain.gutters[id].lane]
		var t:=fposmod(world.time*1.4+id*0.21,1.0)
		var edge: Vector3=(lane.a+lane.b)*0.5+Vector3.UP*0.24
		drops[id].position=(lane.ridge+Vector3.UP*0.20).lerp(edge,t/0.75) if t<0.75 else edge.lerp((lane.a+lane.b)*0.5-Vector3.UP*0.06,(t-0.75)/0.25)
	update_damp(world)
func update_damp(world) -> void:
	var next:=hash(world.roof_rain.get("wet",{}))
	if next==damp_stamp: return
	damp_stamp=next
	if is_instance_valid(damp): damp.free()
	damp=Node3D.new(); add_child(damp)
	for cell: Vector3i in world.roof_rain.get("wet",{}):
		var amount: float=world.roof_rain.wet[cell]
		if amount<0.15: continue
		var at: Vector3=world.navigation.surface_point(cell)+Vector3.UP*0.018
		for i in 3:
			var sheen:=V.box(damp,Vector3(0.64,0.006,0.035),at+Vector3(0,0,(i-1)*0.21),Color("6ca5a4"))
			var paint:=Geometry.material(Color(0.30,0.52,0.53,amount*0.32)); paint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; paint.roughness=0.08; sheen.material_override=paint
func hit(origin: Vector3, ray: Vector3) -> Dictionary:
	var nearest: Dictionary={}; var distance:=INF
	for target in targets:
		var point: Variant=target.box.intersects_ray(origin,ray)
		if target.has("a"):
			var closest:=Geometry3D.get_closest_points_between_segments(origin,origin+ray*300,target.a,target.b)
			point=closest[0] if closest[0].distance_to(closest[1])<0.19 else null
		if point is Vector3 and origin.distance_to(point)<distance: distance=origin.distance_to(point); nearest=target
	return nearest
