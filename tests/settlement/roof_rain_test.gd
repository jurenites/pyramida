extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Fixture=preload("res://tests/settlement/reviewed_balance_test.gd")
const Rain=preload("res://scripts/settlement/roof_rain.gd")
const RainView=preload("res://scripts/settlement/roof_rain_view.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func finish(world,spec: Dictionary) -> int:
	check(Rain.request(world,spec),"Queue fitting: "+world.last_message)
	var id: int=world.next_plan_id-1
	if not world.plans.has(id): return -1
	check(world.debug_finish_plan(id),"Finish fitting: "+world.last_message)
	return world.roof_rain.next_id-1
func connect_roof(world,key: String,target: Vector3i) -> void:
	var id:=finish(world,{"kind":"gutter","lane":key})
	if id<0: return
	var start: Vector3=Rain.roof_lanes(world)[key].b
	var end:=Rain.inlet(world,target)
	var front:= -4.0 if target.z<0 else 4.0
	var path: Array=[start,Vector3(start.x,start.y-0.02,front),Vector3(end.x,start.y-0.03,front),end]
	finish(world,{"kind":"pipe","gutter":id,"target":target,"path":path})
func run() -> void:
	var fixture:=Fixture.new(); var world=fixture.fixture(); world.generator_version=4; world.roof_rain=Rain.fresh(true)
	for x in [-9,-6,-3,0,3,6,9,12]: fixture.finish(world,"house",Vector3i(x,0,0))
	check(fixture.failures.is_empty(),"Eight roofs build normally")
	var a:=Vector3i(-3,0,-4); var b:=Vector3i(6,0,-4)
	finish(world,{"kind":"barrel","cell":a,"offset":Vector3.ZERO})
	finish(world,{"kind":"barrel","cell":b,"offset":Vector3.ZERO})
	var lanes:=Rain.roof_lanes(world)
	check(lanes.size()==80 and Rain.roof_lanes(world,true).size()==64,"Eight roofs expose quarter-metre sections and retain legacy half-roof addresses")
	var selected:=0
	for key: String in lanes:
		if not key.ends_with(":0"): continue
		connect_roof(world,key,a if selected<4 else b); selected+=1
	check(world.roof_rain.pipes.size()==8,"Half the eight-roof catchment is connected")
	world.weather.seconds=89; world.weather.raining=false
	world.Hydrology.tick(world,8)
	var restored:=Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Mid-rain fittings and fractional runoff save")
	world.Hydrology.tick(world,8); restored.Hydrology.tick(restored,8)
	check(world.water_sources[a].inventory.count("water")==2 and world.water_sources[b].inventory.count("water")==2,"Half of eight 2 x 2 roofs collects four droplets per rain event")
	check(restored.water_sources[a].inventory.count("water")==2 and restored.water_sources[b].inventory.count("water")==2,"Reload does not duplicate or lose rainfall")
	var before: int=world.water_sources[a].inventory.count("water")
	world.Hydrology.tick(world,80)
	check(world.water_sources[a].inventory.count("water")==before,"Containers do not evaporate in dry weather")
	check(not Rain.request(world,{"kind":"gutter","lane":lanes.keys()[0]}),"Duplicate gutters cannot multiply collection")
	var saved_pipe: Dictionary=world.roof_rain.pipes.values()[0]
	var bad: Dictionary=saved_pipe.duplicate(true); bad.path[1].y=bad.path[0].y+1
	check(Rain.path_error(world,bad)=="Water needs a downhill route","Uphill pipe flow is rejected")
	var vase:=Vector3i(1,0,0)
	check(Rain.tank_error(world,{"kind":"vase","cell":vase,"offset":Vector3(0.5,0,0)}).is_empty(),"Vase fits the actual gap between two buildings")
	check(not Rain.tank_error(world,{"kind":"vase","cell":Vector3i.ZERO,"offset":Vector3.ZERO}).is_empty(),"Container cannot overlap a room")
	finish(world,{"kind":"vase","cell":vase,"offset":Vector3(0.5,0,0)})
	check(world.water_sources[vase].inventory.capacity==1,"Vase holds one droplet")
	check(not world.navigation._touching(vase,vase+Vector3i.RIGHT),"A gap vessel blocks paths crossing its actual occupied space")
	fixture.finish(world,"well",Vector3i(0,0,5))
	check(world.wells[Vector3i(0,0,5)].capacity==3,"Default Well holds three droplets")
	var extra:=0
	for key: String in lanes:
		if key.ends_with(":1") and extra<2: connect_roof(world,key,Vector3i(0,0,5)); extra+=1
	world.weather.seconds=209; world.Hydrology.tick(world,16)
	check(world.wells[Vector3i(0,0,5)].count("water")==1,"The Well receives roof runoff through its connected pipe")
	check(world.roof_rain.overflow>0,"A second shower overflows full barrels instead of duplicating storage")
	var view:=RainView.new(); root.add_child(view); view.sync(world)
	check(view.levels.size()==3 and view.drops.size()==10,"Containers and flowing half-round gutters have world models")
	view.free()
	# A real citizen must deliver the Clay and fit a vase, not gain a free item.
	var paid=fixture.fixture(); paid.generator_version=4; paid.rebuild_navigation(); paid.add_store(Vector3i(-4,0,-4),{"clay":4})
	check(Rain.request(paid,{"kind":"vase","cell":Vector3i(2,0,2),"offset":Vector3.ZERO}),"Queue paid vase")
	check(paid.order_build(0,paid.next_plan_id-1),"Citizen accepts vase fitting")
	for step in 2500:
		paid.time+=0.1; paid.Jobs.prepare_decisions(paid); paid.workers[0].hunger=0; paid.Citizens.tick(paid,paid.workers[0],0.1)
		if paid.plans.is_empty(): break
	check(paid.roof_rain.tanks.size()==1 and paid.plans.is_empty(),"Citizen completes vessel through normal construction")
	check(paid.stores[Vector3i(-4,0,-4)].count("clay")==2,"Vase costs exactly two delivered Clay")
	paid.water_sources[Vector3i(2,0,2)].inventory.store("water")
	check(Rain.move_tank(paid,Vector3i(2,0,2),Vector3i(3,0,2),Vector3.ZERO),"A filled vessel can be moved")
	check(paid.water_sources[Vector3i(3,0,2)].inventory.count("water")==1,"Moving preserves the actual water inventory")
	paid.water_sources[Vector3i(3,0,2)].inventory.amounts.water=0
	check(Rain.remove(paid,{"kind":"tank","cell":Vector3i(3,0,2)}),"An empty fitting can be dismantled")
	check(paid.plans.values().any(func(p):return p.get("dropped_cargo",false) and p.relocation.parts.count("clay")==2),"Removing recovers paid Clay as physical salvage")
	check(restored.restore(JSON.parse_string(JSON.stringify(paid.snapshot()))),"Recovered fitting materials save normally")
	check(Rain.request(paid,{"kind":"vase","cell":Vector3i(2,0,2),"offset":Vector3.ZERO}),"Queue cancellable fitting")
	var cancelled: int=paid.next_plan_id-1
	paid.plans[cancelled].used={"clay":1}; paid.plans[cancelled].installed=1
	check(paid.delete_plan(cancelled),"Cancel a partly installed fitting")
	check(restored.restore(JSON.parse_string(JSON.stringify(paid.snapshot()))),"Cancelled fittings preserve their salvage through saves")
	var start:=Model.new(); start.setup(1409,"easy")
	check(start.water_sources.values().all(func(source):return source.kind!="puddle"),"New settlement does not require a starting puddle")
	var salvaged: Vector3i=start.roof_rain.tanks.keys()[0]
	check(start.roof_rain.tanks[salvaged].salvaged and start.roof_rain.tanks[salvaged].owner==0 and start.water_sources[salvaged].inventory.count("water")==1,"First person starts with a filled salvaged vase")
	start.water_sources[salvaged].inventory.amounts.water=0; start.weather.seconds=89; start.Hydrology.tick(start,16)
	check(start.water_sources[salvaged].inventory.count("water")==1,"Starter vase catches the first shower without puddles or a pipe")
	check(restored.restore(JSON.parse_string(JSON.stringify(start.snapshot()))),"Starter vase survives save/load")
	var remote:=Vector3i(160,0,160)
	start.roof_rain.tanks[remote]={"kind":"vase","cell":remote,"offset":Vector3.ZERO}
	check(start.Chunks.required(start,Vector3.ZERO,1).has(start.Chunks.chunk_for(remote)),"Placed vessels keep their terrain chunk resident")
	start.roof_rain.tanks.erase(remote)
	fixture.free()
	if failures.is_empty(): print("PASS: event rain budget, paid fittings, gap placement, capacities, starter vase and persistence")
	quit(int(not failures.is_empty()))
