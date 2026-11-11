extends "res://tests/settlement/building_passages_test.gd"
var labels: Dictionary={}
const Inventory=preload("res://scripts/settlement/inventory.gd")
func merged_solids(world) -> Array[AABB]:
	var result: Array[AABB]=[]
	labels.clear()
	var views: Dictionary={}
	for cell in world.buildings:
		var data: Dictionary=world.buildings[cell]
		var node: Node3D=Assets.create(data.kind); root.add_child(node)
		node.position=Vector3(cell)+data.get("placement_offset",Vector3.ZERO); node.rotation.y=-data.direction*PI/2
		node.set_meta("cell",cell); node.set_meta("asset",data.kind); views[str(cell)]=node
	Assembly.sync(world,views)
	for node in views.values():
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			if not mesh.is_visible_in_tree() or mesh.mesh==null: continue
			var box: AABB=mesh.global_transform*mesh.mesh.get_aabb()
			box.position-=Vector3(Geometry.RADIUS,0,Geometry.RADIUS); box.size+=Vector3(Geometry.RADIUS*2,0,Geometry.RADIUS*2)
			result.append(box); labels[str(box)]=str(node.name)+"/"+str(mesh.name)
		for batch: MultiMeshInstance3D in node.find_children("*","MultiMeshInstance3D",true,false):
			if not batch.is_visible_in_tree() or batch.multimesh==null: continue
			for i in batch.multimesh.instance_count:
				var box: AABB=batch.global_transform*batch.multimesh.get_instance_transform(i)*batch.multimesh.mesh.get_aabb()
				box.position-=Vector3(Geometry.RADIUS,0,Geometry.RADIUS); box.size+=Vector3(Geometry.RADIUS*2,0,Geometry.RADIUS*2)
				result.append(box); labels[str(box)]=str(node.name)+"/"+str(batch.name)
		node.free()
	return result
func multi_level_paths(world,label: String) -> void:
	var actual:=merged_solids(world)
	for a in world.navigation.room_paths:
		for b in world.navigation.room_paths[a]:
			if a>=b: continue
			var points: Array=world.navigation.room_paths[a][b]
			check(points[0].is_equal_approx(world.navigation.surface_point(a)) and points[-1].is_equal_approx(world.navigation.surface_point(b)),label+" route endpoints match arrival positions")
			for i in range(1,points.size()):
				var low: float=minf(points[i-1].y,points[i].y)
				var high: float=maxf(points[i-1].y,points[i].y)+Geometry.BODY_HEIGHT
				var clear_:=true
				for box in actual:
					if box.end.y<=low+0.23 or box.position.y>=high: continue
					var solid_name: String=labels.get(str(box),"unknown")
					box.position.y-=Geometry.BODY_HEIGHT; box.size.y+=Geometry.BODY_HEIGHT-0.23
					if box.intersects_segment(points[i-1],points[i])!=null:
						if failures<35: print("COLLISION ",solid_name," ",box)
						clear_=false; break
				check(clear_,label+" clear visible geometry "+str([a,b,points[i-1],points[i]]))
func run() -> void:
	for kind in Layout.ENCLOSED+Layout.OPEN:
		for direction in 4:
			var world=fixture(kind,direction)
			var entry: Dictionary=Layout.build(world)[Vector3i.ZERO]
			var next:=Vector3i(ceili(entry.rect.end.x+1.0),0,0)
			world.buildings[next]={"kind":"house","direction":1,"placement_offset":Vector3(0.12,0,0.07)}
			world.rebuild_navigation()
			multi_level_paths(world,kind+" mixed/"+str(direction))
			if Paths.walk_inside(entry) and not Layout.build(world)[Vector3i.ZERO].joins.is_empty():
				check(not world.navigation.route(Vector3i.ZERO,next).is_empty(),kind+" connects to Home through its actual doorway")
			world.buildings.erase(next); world.rebuild_navigation()
			check(Layout.build(world)[Vector3i.ZERO].joins.is_empty(),"Removal closes the former shared "+kind+" wall")
	for kind in ["house","bakery","sawmill","pottery_workshop","masonry","stone_storage"]:
		var world=fixture(kind)
		world.stairs[Vector3i(0,0,3)]=3
		world.rebuild_navigation()
		check(Layout.build(world)[Vector3i.ZERO].terrace,kind+" stair landing creates a real terrace")
		var landing:=Vector3i(0,2,1)
		check(not world.navigation.route(Vector3i(0,0,5),landing).is_empty(),kind+" roof can be reached by stairs")
		multi_level_paths(world,kind+" terrace")
		world.stairs.clear(); world.rebuild_navigation()
		check(not Layout.build(world)[Vector3i.ZERO].terrace,kind+" restores its roof after stair removal")
		world.buildings[Vector3i(0,2,0)]={"kind":"house","direction":0,"placement_offset":Vector3(0.3,0,-0.25)}
		world.stairs[Vector3i(0,0,3)]=3; world.rebuild_navigation()
		multi_level_paths(world,kind+" off-grid upper Home")
	# A moving adult actually follows the longer path through the open sawmill.
	var world=fixture("sawmill")
	for cell in world.ground.keys():
		if absi(cell.z)>1: world.ground.erase(cell)
	world.rebuild_navigation(); world.workers.append({"id":0,"cell":Vector3i(-5,0,1),"position":Vector3(-5,0,1),"route":[],"route_index":0,"job":{},"cargo":"","status":"idle","distance":0.0,"hunger":0.0,"role":"idle","life_stage":"adult","growth_seconds":0.0})
	var worker: Dictionary=world.workers[0]
	check(world.order_move(worker.id,Vector3i(5,0,1)),"Citizen accepts a destination across the open workplace")
	for i in 600:
		world.tick(0.04)
		if worker.cell==Vector3i(5,0,1): break
	check(worker.cell==Vector3i(5,0,1),"Citizen completes the open-workplace passage without getting stuck")
	# Receiving a solid bulk item waits while a citizen occupies the aisle.
	world=fixture("stone_storage"); world.add_store(Vector3i.ZERO)
	world.stores[Vector3i.ZERO].capacity=18; world.stores[Vector3i.ZERO].enable_slots(); world.rebuild_navigation()
	world.workers.append({"id":0,"cell":Vector3i(-2,0,0),"position":Vector3.ZERO,"route":[Vector3i(-2,0,0),Vector3i(2,0,0)],"route_index":1,"job":{},"cargo":"","status":"idle","distance":0.0,"hunger":0.0,"role":"idle","life_stage":"adult","growth_seconds":0.0})
	var carrier: Dictionary={"id":1,"cell":Vector3i(0,0,2),"position":Vector3(0,0,2),"route":[],"route_index":0,"job":{"kind":"restock","phase":"travel","target":Vector3i.ZERO},"cargo":"stone","cargo_amount":1,"status":"idle","distance":0.0,"hunger":0.0,"role":"idle","life_stage":"adult","growth_seconds":0.0}
	world.workers.append(carrier)
	world.Jobs._deliver_to_store(world,carrier)
	check(carrier.cargo=="stone" and world.stores[Vector3i.ZERO].total()==0,"Delivery keeps cargo until the occupied aisle is clear")
	world.workers[0].position=Vector3(3,0,0); world.workers[0].cell=Vector3i(3,0,0); world.workers[0].route=[]
	world.Jobs._deliver_to_store(world,carrier)
	check(carrier.cargo.is_empty() and world.stores[Vector3i.ZERO].count("stone")==1,"Delivery resumes once the aisle is clear without losing cargo")
	# A shallow storage roof is not an adult-height room connection.
	world=fixture("log_shed"); world.buildings[Vector3i(2,0,0)]={"kind":"house","direction":1}; world.rebuild_navigation()
	check(Layout.build(world)[Vector3i.ZERO].joins.is_empty(),"One-metre shelters retain their real headroom instead of creating a false doorway")
	print("%s: %d mixed-room, terrace, removal and live passage checks, %d failures"%["PASS" if failures==0 else "FAIL",checks,failures])
	quit(int(failures>0))
