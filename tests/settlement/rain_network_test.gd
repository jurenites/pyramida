extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Fixture=preload("res://tests/settlement/reviewed_balance_test.gd")
const Rain=preload("res://scripts/settlement/roof_rain.gd")
const Exposure=preload("res://scripts/settlement/rain_exposure.gd")
const Geometry=preload("res://scripts/settlement/rain_fitting_geometry.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func fit(world,spec: Dictionary) -> int:
	if not Rain.request(world,spec): check(false,"Fit "+str(spec)+": "+world.last_message); return -1
	var id: int=world.next_plan_id-1
	if world.plans.has(id): check(world.debug_finish_plan(id),"Complete fitting")
	return world.roof_rain.next_id-1
func run() -> void:
	var fixture:=Fixture.new(); var world=fixture.fixture(); world.generator_version=4; world.roof_rain=Rain.fresh(true)
	fixture.finish(world,"house",Vector3i(-3,0,0)); fixture.finish(world,"house",Vector3i(3,0,0))
	var basin:=Vector3i(0,0,6)
	fit(world,{"kind":"basin","cell":basin,"offset":Vector3.ZERO})
	var at:=Vector3(0,1.4,3)
	var joint:=fit(world,{"kind":"junction","cell":Vector3i(0,0,3),"position":at})
	var trunk:=fit(world,{"kind":"pipe","source_joint":joint,"target":basin,"path":[at,Vector3(0,1.3,5),Rain.inlet(world,basin)]})
	var lanes:=Rain.roof_lanes(world,true); var endings: Array=[]
	for key in lanes:
		var id:=fit(world,{"kind":"gutter","lane":key})
		if key.ends_with(":s7"): endings.append(id)
	for id in endings:
		var start: Vector3=Rain.start_point(world,{"gutter":id})
		fit(world,{"kind":"pipe","gutter":id,"target_joint":joint,"path":[start,Vector3(start.x,start.y-0.04,3),at]})
	check(world.roof_rain.gutters.size()==16 and world.roof_rain.pipes.size()==3,"Sixteen clay sections feed only two branches and one shared trunk")
	check(not Rain.request(world,{"kind":"gutter","lane":lanes.keys()[0].split(":")[0]+":0"}),"Legacy metre gutter cannot overlap quarter-metre sections")
	world.weather.raining=true
	for i in 8: Rain.rain_second(world)
	var loaded:=Model.new(); check(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Shared network and basin save mid-rain")
	for i in 8: Rain.rain_second(world); Rain.rain_second(loaded)
	check(world.water_sources[basin].inventory.count("water")==2 and loaded.water_sources[basin].inventory.count("water")==2,"Two complete roofs deliver exactly two droplets through a merged trunk")
	check(world.water_sources[basin].inventory.capacity==24,"Village basin holds twenty-four droplets")
	check(not world.navigation.route(Vector3i(0,0,3),basin).is_empty(),"The wide basin remains reachable from its perimeter")
	world.stores[Vector3i(-3,0,0)].store("pottery",1)
	world.workers[0].cell=Vector3i(0,0,3); world.workers[0].position=Vector3(0,0,3); world.exploration.update(world.workers)
	check(world.order_collect_water(0,basin),"A real citizen can collect from the village basin")
	for step in 500:
		world.time+=0.1; world.Jobs.prepare_decisions(world); world.workers[0].hunger=0; world.Citizens.tick(world,world.workers[0],0.1)
		if world.workers[0].cargo=="water": break
	check(world.workers[0].cargo=="water","Shared rainwater reaches the citizen's carried inventory")
	var changed: Dictionary=world.roof_rain.pipes[trunk].duplicate(true); changed.replace=trunk
	changed.path=[at,Vector3(4,1.3,3),Vector3(4,1.2,5),Vector3(0,1.1,5),Rain.inlet(world,basin)]
	check(Rain.request(world,changed),"Existing trunk can be rerouted")
	var plan: int=world.next_plan_id-1
	check(world.plans[plan].materials.clay==Rain.recipe(changed).clay-world.roof_rain.pipes[trunk].materials.clay,"Reroute charges only additional Clay")
	check(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Pending reroute preserves the old working network in saves")
	check(world.debug_finish_plan(plan),"Builders complete the longer drain")
	check(world.roof_rain.pipes.has(trunk) and world.roof_rain.pipes[trunk].path==changed.path,"Editing retains the junction connections and pipe identity")
	var joint2:=fit(world,{"kind":"junction","cell":Vector3i(-2,0,3),"position":Vector3(-2,1.4,3)})
	fit(world,{"kind":"pipe","source_joint":joint2,"target_joint":joint,"path":[Vector3(-2,1.4,3),at]})
	var loop: Dictionary={"kind":"pipe","replace":trunk,"source_joint":joint,"target_joint":joint2,"path":[at,Vector3(-2,1.4,3)]}
	check(Rain.error(world,loop)=="Pipe route forms a loop","A shared network rejects cycles before construction")
	fixture.finish(world,"support",Vector3i(0,0,-5))
	var terrace:=Vector3i(0,1,-5)
	for i in 12: Exposure.tick(world)
	check(float(world.roof_rain.wet.get(terrace,0))>0.8,"Uncovered timber terrace becomes wet in rain")
	check(not world.roof_rain.wet.has(Vector3i(-3,0,0)),"A finished roof protects its room floor")
	var worker: Dictionary=world.workers[0]; worker.cell=terrace; worker.position=world.navigation.surface_point(terrace)
	check(Exposure.movement(world,worker,terrace,0.1)<0.75,"Wet walking reduces hauling speed")
	for i in 100:
		Exposure.movement(world,worker,terrace,0.1)
		if worker.get("slip_remaining",0)>0: break
	check(worker.get("slip_remaining",0)>0,"Prolonged slippery walking triggers a seated recovery")
	var position: Vector3=worker.position
	world.Citizens.tick(world,worker,0.5)
	check(worker.position==position and worker.slip_remaining>0,"Slipping pauses movement without losing the citizen or cargo")
	var actor:=preload("res://scripts/settlement/worker_view.gd").new(); actor.setup(0); root.add_child(actor); actor.sync(worker,0.1,false,null,world.navigation)
	check(actor.body.position.y<0 and actor.body.get_node("LeftLeg").rotation.x>0.5,"Slips have a visible seated pose")
	actor.free()
	check(loaded.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Wet floors and recovery time survive a save")
	world.weather.raining=false
	for i in 40: Exposure.tick(world)
	check(world.roof_rain.wet.is_empty(),"Wet floors dry without creating collectible puddles")
	check(is_equal_approx(Geometry.DIAMETER,0.25) and Geometry.DIAMETER>preload("res://scripts/settlement/timber_kit.gd").LOG_DIAMETER,"Clay stock uses the Log as a scale reference")
	var curve:=Geometry.rounded([Vector3.ZERO,Vector3(1,0,0),Vector3(1,-1,0)])
	check(curve.size()>4 and not curve.has(Vector3(1,0,0)),"Pipe turns use curved elbows instead of square beam corners")
	var mesh:=Geometry.tube(curve)
	check(mesh.get_surface_count()==1 and mesh.get_aabb().size.z>=0.24,"Pipes have a visible round bore and full-size wall geometry")
	fixture.free()
	if failures.is_empty(): print("PASS: segmented gutters, merged drainage, basin storage, rerouting, wet floors, slips and ceramic geometry")
	quit(0 if failures.is_empty() else 1)
