extends SceneTree
const Fixture=preload("res://tests/settlement/room_construction_test.gd")
const Homes=preload("res://scripts/settlement/home_assembly.gd")
const U=Homes.U
const Save=preload("res://scripts/settlement/save_codec.gd")
var failures:=0
func check(value: bool,message: String) -> void:
	if not value: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
static func step(world, limit:=12000) -> void:
	for i in limit:
		for worker in world.workers: worker.hunger=0
		world.birth_clock=0; world.tick(0.1)
		if world.plans.is_empty(): return
static func fixture():
	var world=Fixture.fixture(); world.vines.clear()
	var stock=world.stores.values()[0]
	for resource in ["grain","plank","rope","brick","pottery"]: stock.store(resource,150)
	return world
func build(world,at: Vector3i,direction:=0) -> void:
	check(world.request_build("house",at,direction),"Queue normal Home: "+world.last_message)
	step(world)
	check(world.plans.is_empty(),"Normal Home builders finish "+str(at))
	if not world.plans.is_empty():
		print(world.plans,world.workers); quit(1); return
func run() -> void:
	var world=fixture()
	build(world,Vector3i.ZERO)
	build(world,Vector3i(2,0,0),1)
	build(world,Vector3i(2,0,0),1) # Paid reinforcement.
	check(world.request_build("house",Vector3i(2,2,0),1),"Queue upper Home")
	check(world.request_build("stairs",Vector3i(0,0,2),3),"Queue ordinary stairs to the terrace")
	step(world)
	check(world.plans.is_empty(),"Builders reach upper Home using paid stairs")
	check(world.buildings.size()==3,"Ordinary Home records remain authoritative")
	var top:=Vector3i(2,2,0)
	var offset: Vector3=world.buildings[top].placement_offset
	check(offset!=Vector3.ZERO and offset==preload("res://scripts/settlement/home_stack.gd").offset(world,top),"Upper Home keeps a deterministic off-grid placement")
	var stamp: Array=world.Houses.stamp(world,Vector3i.ZERO,Homes.members(world,Vector3i.ZERO))
	var copied: Array=world.Houses.targets(stamp,Vector3i(6,0,0),0)
	check(copied.filter(func(entry):return entry.source==top)[0].offset_delta.is_equal_approx(offset),"Copy retains the upper floor offset")
	check(world.construction_materials[top].log==2,"Small upper overhang adds no support timber cost")
	check(world.navigation.surface_point(top).is_equal_approx(Vector3(top)+offset+Vector3.UP*0.06),"Citizen destination follows the physical room")
	check(Homes.members(world,Vector3i.ZERO).size()==3,"Stacked and door-linked Homes share an assembly")
	check(Homes.terrace(world,Vector3i.ZERO,Homes.members(world,Vector3i.ZERO)),"Exposed lower roof becomes terrace")
	check(not world.navigation.route(Vector3i.ZERO,Vector3i(2,0,0)).is_empty(),"Citizens pass through the shared doorway")
	var context=Homes.contexts(world)[0]
	var owner: int=U.owner_for(context,context.room_site.design[0])
	check(not U.blocked(context,owner),"Initial stove chooses an uncovered ground Home")
	var obstruction: Dictionary=U.room(context,owner).duplicate(true); obstruction.uid=999; obstruction.cells=[U.Rooms.Layout.arr(U.Rooms.Layout.vec(obstruction.cells[0])+Vector3i.UP)]; obstruction.home_cell+=Vector3i.UP*2
	context.room_site.built.append(obstruction)
	check(U.blocked(context,owner),"A room above a native Home blocks its exhaust")
	context.room_site.built.pop_back()
	var cost:=U.installation_cost(context,owner)
	var stock=world.stores.values()[0]; var before: Dictionary=stock.amounts.duplicate()
	check(U.install(context,owner),"Install functional fixtures on normal Home")
	var restored=fixture()
	check(Save.restore(restored,JSON.parse_string(JSON.stringify(Save.snapshot(world)))),"Pending Home utility jobs survive JSON save")
	var Pose=preload("res://scripts/settlement/home_pose.gd")
	for cell in world.buildings:
		if world.buildings[cell].kind=="house": check(is_equal_approx(Pose.angle(world,cell),Pose.angle(restored,cell)),"Home yaw persists through a real save and reload")
	step(world,26000)
	check(world.plans.is_empty(),"Citizens build every Home utility with real materials")
	if not world.plans.is_empty(): print(world.plans.values().map(func(p):return [p.kind,p.get("utility_action"),p.installed,p.required]))
	for resource in cost: check(before.get(resource,0)-stock.count(resource)==cost[resource],"Utility cost conserved: "+resource)
	var service:=U.state(context,owner)
	check(service.stove and service.rain and service.lamps.size()==3,"Three Homes have installed lamps, a stove and rain container")
	check(U.drains(context,owner).size()==2,"Terrace and upper roof both drain")
	for uid in service.lamps: check(U.toggle_gas(context,owner,uid),"Queue gas pipe")
	step(world,18000)
	check(service.lamps.values().all(func(lamp):return lamp.pipe and lamp.connected),"Builders connect every lamp")
	world.weather.raining=true
	for second in 12: Homes.rain_second(world)
	check(world.water_sources[U.barrel_cell(context,owner)].inventory.count("water")>0,"Home rainwater enters real inventory")
	check(Save.restore(restored,JSON.parse_string(JSON.stringify(Save.snapshot(world)))),"Installed native Home utility graph round-trips")
	var loaded_context=Homes.context_for(restored,owner)
	var loaded:=U.state(loaded_context,owner)
	check(is_equal_approx(loaded.fuel,service.fuel) and loaded.lamps.keys()==service.lamps.keys() and loaded.lamps.keys().all(func(uid):return is_equal_approx(loaded.lamps[uid].charge,service.lamps[uid].charge) and loaded.lamps[uid].pipe==service.lamps[uid].pipe and loaded.lamps[uid].connected==service.lamps[uid].connected) and loaded.rain_roofs==service.rain_roofs and restored.home_utilities.next_id==world.home_utilities.next_id,"Saved charge, fuel and exemplar identities persist")
	var bad=world.home_utilities.duplicate(true); bad.services[owner].lamps[owner].charge=-1
	check(not Homes.valid(bad,world.buildings,world.plans),"Reject corrupted Home utility state")
	check(not world.Relocation.source_error(world,Vector3i.ZERO).is_empty(),"Attached utilities prevent unsafe relocation")
	var view=preload("res://scripts/settlement/world_view.gd").new(); root.add_child(view); view.setup(world)
	for cell in world.buildings:
		check(view.entity_views["building:%s" % cell].has_node("AssembledHome"),"Ordinary Home renders assembled geometry")
	view.free()
	print("PASS: normal Home construction, assembly, utilities, costs, navigation and saves" if failures==0 else "FAIL: %d checks" % failures)
	quit(failures)
