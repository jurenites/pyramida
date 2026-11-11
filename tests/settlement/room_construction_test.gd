extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Rooms=preload("res://scripts/settlement/room_construction.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
static func fixture():
	var world=Model.new()
	world.setup()
	world.streaming_enabled=false; world.soil_enabled=false
	world.loaded_chunks.clear(); world.dormant_chunks.clear(); world.chunk_details.clear()
	for field in ["buildings","stores","gardens","wells","trees","deposits","water_sources","platforms","stairs","plans","ground","terrain_shapes","terrain_ramps","soil_cuts"]: world.get(field).clear()
	world.roof_rain=preload("res://scripts/settlement/roof_rain.gd").fresh(true)
	for x in range(-10,11):
		for z in range(-10,11): world.ground[Vector3i(x,0,z)]=true
	world.workers.resize(2)
	for worker in world.workers:
		worker.cell=Vector3i(-3,0,worker.id); worker.position=Vector3(worker.cell)
		worker.role="builder"; worker.job={}; worker.route=[]; worker.route_index=0
	world.add_store(Vector3i(-5,0,0))
	world.stores[Vector3i(-5,0,0)].capacity=1000
	world.stores[Vector3i(-5,0,0)].store("log",100)
	world.stores[Vector3i(-5,0,0)].store("food",100)
	world.room_site=Rooms.fresh(Vector3i.ZERO); world.rebuild_navigation()
	return world
static func place(world,shape: String,at: Vector3i,door: Array=[],normal: Array=[]) -> bool:
	var design=Rooms.layout(world)
	design.queue[0]={"shape":shape,"color":0}
	if not door.is_empty(): design.queue[0].merge({"door":door,"normal":normal})
	var ok: bool=design.drop(at.x,at.z,0,false,at.y) and Rooms.commit(world,design)
	if not ok: print("Placement failure: ",design.error," / ",world.last_message)
	return ok
func finish_work(world,seconds:=300.0) -> void:
	for step in int(seconds/0.1):
		world.tick(0.1)
		if world.plans.is_empty(): return
	check(false,"Workers must complete reachable material-backed plans: "+str(world.plans)+" workers "+str(world.workers))
func run() -> void:
	var world=fixture()
	for level in 2:
		for x in 2:
			for z in 2: check(place(world,"cube",Vector3i(x,level,z)),"Queue hall module "+str(Vector3i(x,level,z)))
	check(world.navigation.room_nodes.is_empty(),"Planning does not rebuild physical room navigation")
	check(not world.TerrainEditor.edit_error(world,Vector3i(1,0,1),"terrain_dig",false).is_empty(),"Terrain tools cannot undermine a queued room frame")
	var invalid: Dictionary=world.room_site.duplicate(true); invalid.design[0].braces=["invalid"]
	check(not Rooms.valid(invalid,world.plans),"Reject malformed saved brace geometry safely")
	invalid=world.room_site.duplicate(true); invalid.design[0].groups=[{}]
	check(not Rooms.valid(invalid,world.plans),"Reject malformed saved group metadata safely")
	var corrupt_plans: Dictionary=world.plans.duplicate(true); corrupt_plans.values()[0].cell=Vector3i(8,0,8)
	check(not Rooms.valid(world.room_site,corrupt_plans),"Saved worker job must match its room's metric footprint")
	check(world.room_site.built.is_empty() and not world.navigation.surfaces.has(Vector3i(0,2,0)),"Blueprints do not create physical walking floors")
	check(Rooms.base(world,Vector3i(1,1,1))==Vector3i(2,2,2),"One demo cell is exactly 2 m on all three axes")
	var initial_stock: int=world.resource_total("log")
	finish_work(world)
	check(world.room_site.built.size()==8 and world.resource_total("log")==initial_stock-32,"Workers deliver and install every frame material")
	check(world.navigation.route(Vector3i(-3,0,0),Vector3i(0,2,0)).is_empty(),"Upper floor stays inaccessible without completed stairs")
	check(place(world,"stairs",Vector3i(0,0,1)),"Queue U-turn stairs inside an existing hall frame")
	check(place(world,"room_domino",Vector3i(1,1,0),[0,0,0],[-1,0,0]),"Queue upstairs room infill retaining the supported frame")
	check(Rooms.add_bed(world,Vector3i(1,1,0)),"Queue real bed equipment inside the upper room")
	check(world.room_site.built.any(func(room):return room.shape=="cube" and room.cells==[[0,0,1]]),"The physical frame remains while renovation is pending")
	var saved: Dictionary=world.snapshot(); var restored=Model.new()
	FileAccess.open("/tmp/room-construction-save.json",FileAccess.WRITE).store_string(JSON.stringify(saved))
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))),"Construction plans and physical frames survive save/load")
	finish_work(world)
	check(world.room_site.beds.size()==1,"Workers build the upstairs bed")
	if world.room_site.beds.is_empty(): quit(1); return
	check(world.resource_total("log")==initial_stock-41,"Renovation and bed consume materials without charging for the existing frame twice")
	var target:=Rooms.bed_access(world,world.room_site.beds[0])
	var route: Array=world.navigation.route(Vector3i(-3,0,0),target)
	check(not route.is_empty(),"Citizen navigation connects the main world through stairs and the room door to the upstairs bed")
	for node in world.navigation.room_nodes:
		for neighbor in world.navigation.edges.get(node,[]):
			if world.navigation.room_nodes.get(node,-1)!=world.navigation.room_nodes.get(neighbor,-1):
				check(world.navigation.room_paths.get(node,{}).has(neighbor),"Cross-room edges must pass through authored openings, never diagonal wall shortcuts")
	var lower:=Vector3i(0,0,1); var upper:=Vector3i(1,2,1)
	check(world.navigation.room_paths.get(lower,{}).has(upper),"Stairs return to the entrance side at the opposite corner, 2 m higher")
	if world.navigation.room_paths.get(lower,{}).has(upper):
		var path: Array=world.navigation.room_paths[lower][upper]
		check(path.any(func(p):return p.z>=2.99 and is_equal_approx(p.y,1.0)),"The route reaches the 1 m turning landing inside the 2×2 m footprint")
		check(path.any(func(p):return p.x>0.9 and p.y>1.0) and path.any(func(p):return p.x<0.1 and p.y<1.0),"Both flights use their own side of the stair room")
	world.workers[0].cell=Vector3i(-3,0,0); world.workers[0].position=Vector3(-3,0,0)
	world.workers[0].job={}; world.workers[0].route=[]; world.workers[0].route_index=0
	check(world.order_move(0,target),"Issue a real citizen move to the bed")
	var actor=preload("res://scripts/settlement/worker_view.gd").new(); actor.setup(0); root.add_child(actor)
	world.navigation.terrain_shapes[Vector3i(0,0,3)]=[0.0,0.0,0.0,0.0]
	var turned:=false; var visible_turn:=false
	for step in 1200:
		world.tick(0.05)
		actor.sync(world.workers[0],0.05,false,null,world.navigation)
		var position: Vector3=world.workers[0].position
		if position.z>2.9 and position.y>0.9 and position.y<1.1:
			turned=true; visible_turn=actor.position.y>0.7
		if world.workers[0].cell==target: break
	check(visible_turn,"Rendered citizen remains on the stair landing instead of snapping to terrain below")
	actor.free(); world.navigation.terrain_shapes.erase(Vector3i(0,0,3))
	check(turned and world.workers[0].cell==target,"Citizen physically walks both flights and the U turn, then reaches the bed")
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))) and not restored.navigation.route(lower,target).is_empty(),"Finished rooms, stairs, bed and traversal survive reload")
	var home:=Vector3i(-3,0,0)
	world.workers[0].job={}; world.workers[0].route=[]; world.workers[0].route_index=0
	check(world.order_move(0,home),"Upstairs citizen can leave the bedroom and descend")
	for step in 1600:
		world.tick(0.05)
		if world.workers[0].cell==home: break
	check(world.workers[0].cell==home,"Citizen also physically descends the turning stairs")
	for yaw in range(1,4):
		var rotated=Model.new(); rotated.ground=world.ground.duplicate(); rotated.room_site=world.room_site.duplicate(true)
		for field in ["design","built"]:
			for room in rotated.room_site[field]:
				for key in ["cells","frame_cells","access_path"]:
					if room.has(key): room[key]=room[key].map(func(raw):return Rooms.Layout.arr(Rooms.Layout.rotate_point(Rooms.Layout.vec(raw),yaw)))
				for key in ["door","normal"]: room[key]=Rooms.Layout.arr(Rooms.Layout.rotate_point(Rooms.Layout.vec(room[key]),yaw))
				room.braces=[]
		for bed in rotated.room_site.beds: bed.cell=Rooms.Layout.arr(Rooms.Layout.rotate_point(Rooms.Layout.vec(bed.cell),yaw))
		rotated.rebuild_navigation()
		check(not rotated.navigation.route(Vector3i(-6,0,-6),Rooms.bed_access(rotated,rotated.room_site.beds[0])).is_empty(),"Rotated stair and door still reach the upstairs bed: %d" % yaw)
	FileAccess.open("/tmp/room-milestone-complete.json",FileAccess.WRITE).store_string(JSON.stringify(world.snapshot()))
	print("PASS: Settlement room construction" if failures==0 else "FAIL: Settlement room construction: %d failures" % failures)
	quit(1 if failures else 0)
