extends SceneTree
const World=preload("res://scripts/settlement/world_model.gd")
const Layout=preload("res://scripts/settlement/building_assembly_layout.gd")
const Paths=preload("res://scripts/settlement/building_assembly_navigation.gd")
const Geometry=preload("res://scripts/settlement/building_walk_geometry.gd")
const Assembly=preload("res://scripts/settlement/building_assembly.gd")
const Assets=preload("res://scripts/settlement/asset_library.gd")
const THROUGH=["sawmill","pottery_workshop","masonry","rope_maker","stone_storage","brickyard","mill","mine","quarry"]
var checks:=0
var failures:=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		if failures<35: printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func fixture(kind: String,direction:=0,offset:=Vector3.ZERO):
	var world=World.new(); world.streaming_enabled=false
	for x in range(-6,7):
		for z in range(-6,7): world.ground[Vector3i(x,0,z)]=true
	world.buildings[Vector3i.ZERO]={"kind":kind,"direction":direction,"placement_offset":offset}
	world.rebuild_navigation()
	return world
func rendered_solids(world) -> Array[AABB]:
	var kind: String=world.buildings[Vector3i.ZERO].kind
	var root_: Node3D=Assets.create(kind); root.add_child(root_)
	root_.position=world.buildings[Vector3i.ZERO].get("placement_offset",Vector3.ZERO)
	root_.rotation.y=-world.buildings[Vector3i.ZERO].direction*PI/2
	root_.set_meta("cell",Vector3i.ZERO); root_.set_meta("asset",kind)
	Assembly.sync(world,{"one":root_})
	var result: Array[AABB]=[]
	for mesh: MeshInstance3D in root_.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh==null: continue
		var box: AABB=mesh.global_transform*mesh.mesh.get_aabb()
		if box.end.y<=0.23 or box.position.y>=Geometry.BODY_HEIGHT+0.06: continue
		# Inflate only horizontally, like the citizen body.
		box.position-=Vector3(Geometry.RADIUS,0,Geometry.RADIUS); box.size+=Vector3(Geometry.RADIUS*2,0,Geometry.RADIUS*2)
		result.append(box)
	for batch: MultiMeshInstance3D in root_.find_children("*","MultiMeshInstance3D",true,false):
		if not batch.is_visible_in_tree() or batch.multimesh==null: continue
		for i in batch.multimesh.instance_count:
			var box: AABB=batch.global_transform*batch.multimesh.get_instance_transform(i)*batch.multimesh.mesh.get_aabb()
			if box.end.y<=0.23 or box.position.y>=Geometry.BODY_HEIGHT+0.06: continue
			box.position-=Vector3(Geometry.RADIUS,0,Geometry.RADIUS); box.size+=Vector3(Geometry.RADIUS*2,0,Geometry.RADIUS*2); result.append(box)
	root_.free(); return result
func check_paths(world,label: String,actual: Array[AABB]) -> int:
	var through:=0
	for a in world.navigation.room_paths:
		for b in world.navigation.room_paths[a]:
			if a>=b: continue
			var route: Array=world.navigation.room_paths[a][b]
			if a.x*b.x<0 or a.z*b.z<0: through+=1
			for i in range(1,route.size()):
				var valid:=true
				for box in actual:
					var high:=box; high.position.y=-1; high.size.y=3
					if high.intersects_segment(route[i-1],route[i])!=null: valid=false; break
				check(valid,label+" path hits a visible wall, post or machine: "+str([a,b,route[i-1],route[i]]))
	return through
func run() -> void:
	var terrain=["road","garden","soil_bed","hay_field","stockpile"]
	var connectors=["platform","stairs","rope_bridge"]
	var solids=["goods_rack"]
	for kind in World.Catalog.COSTS:
		check(Layout.supported(kind) or kind in terrain+connectors+solids+World.Catalog.SEEDS,"Every buildable kind has an explicit passage policy: "+kind)
	for kind in Layout.ENCLOSED+Layout.OPEN+Layout.SOCKETS:
		if kind in ["support","stair"]: continue
		var before:=failures
		for direction in 4:
			var world=fixture(kind,direction,Vector3(0.13,0,-0.11) if direction%2 else Vector3.ZERO)
			var through:=check_paths(world,kind+"/"+str(direction),rendered_solids(world))
			if kind in THROUGH: check(through>0,kind+" has a real through passage at rotation "+str(direction))
			if kind in Layout.ENCLOSED: check(not world.navigation.access_cells(Vector3i.ZERO).is_empty(),kind+" has accessible entry")
		if failures>before: print("CLEARANCE FAILURES ",kind,": ",failures-before)
	# A narrow street has no alternative path around the open workplace.
	var world=fixture("sawmill")
	for cell in world.ground.keys():
		if absi(cell.z)>1: world.ground.erase(cell)
	world.rebuild_navigation()
	check(not world.navigation.route(Vector3i(-5,0,1),Vector3i(5,0,1)).is_empty(),"Open sawmill does not cut an east-west walking corridor")
	world=fixture("stone_storage")
	world.add_store(Vector3i.ZERO); world.stores[Vector3i.ZERO].capacity=18; world.stores[Vector3i.ZERO].enable_slots()
	world.stores[Vector3i.ZERO].store("stone",18); world.rebuild_navigation()
	var entry: Dictionary=Layout.build(world)[Vector3i.ZERO]
	var blocks:=Geometry.rectangles(entry,world)
	for a in world.navigation.room_paths:
		for b in world.navigation.room_paths[a]:
			var path: Array=world.navigation.room_paths[a][b]
			for i in range(1,path.size()): check(Paths.clear(path[i-1],path[i],blocks),"Loaded Depot routes avoid the real stock")
	var old_state: Array=world.navigation.building_stock_state.duplicate(true)
	world.stores[Vector3i.ZERO].reserve(100,"stone"); world.stores[Vector3i.ZERO].pickup(100)
	check(Paths.stock_signature(world)!=old_state,"Collecting stock invalidates passage layout")
	world.tick(0.001)
	check(Paths.stock_signature(world)==world.navigation.building_stock_state,"Simulation refreshes changed cargo passages before citizens move")
	print("%s: %d building passage and visible clearance checks, %d failures"%["PASS" if failures==0 else "FAIL",checks,failures])
	quit(int(failures>0))
