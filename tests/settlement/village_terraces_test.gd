extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Islands=preload("res://scripts/settlement/solid_islands.gd")
const Deposits=preload("res://scripts/settlement/geological_deposits.gd")
var failures: Array[String]=[]
func check(value: bool,message: String) -> void:
	if not value: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for seed_value in [1409,42,9182,101,7,25,0,1,2,3,4,5,15]:
		var world:=Model.new(); world.setup(seed_value,"easy")
		var origin: Vector3i=world.workers[0].cell
		var village:=Vector2(world.STARTING_HOUSE.x,world.STARTING_HOUSE.z)
		var old_shore: float=-Islands.shore_distance(village,seed_value,11)
		var new_shore: float=-Islands.shore_distance(village,seed_value,world.generator_version)
		if world.generator_version>=15:
			check(new_shore>=7 and new_shore<=18,"Seeded bays remain near the protected village")
		else:
			check(new_shore<old_shore-0.5,"Bays reach measurably closer to the village")
		var bounds:=Rect2i(-17,-13,31,27)
		var old:=Islands.generate(seed_value,bounds,11)
		var low:=0; var previous:=0; var upper:=0
		for cell: Vector3i in old.ground:
			if cell.y==0: previous+=1
		for cell: Vector3i in world.ground:
			if not bounds.has_point(Vector2i(cell.x,cell.z)): continue
			if cell.y==0: low+=1
			elif cell.y in [2,4]: upper+=1
		check(low<previous*0.82,"Seed %d breaks up the central lowland"%seed_value)
		check(upper>90,"Seed %d offers substantial nearby elevated building land"%seed_value)
		for cell in [world.STARTING_HOUSE,Vector3i(-8,0,-4),Vector3i(6,0,-4),Vector3i(8,0,4)]:
			check(world.ground.has(cell) and not Islands.solid(world,Vector3(cell)+Vector3.UP*0.5),"Starting house and timber stay clear: %s seed %d"%[cell,seed_value])
		var freshwater:=0
		for cell: Vector3i in world.water_sources:
			if world.water_sources[cell].inventory.count("water")>0 and not world.navigation.route(origin,cell).is_empty(): freshwater+=1
		check(freshwater>0,"Starting freshwater remains reachable")
		var quarry_count:=0
		for cell: Vector3i in world.deposits:
			if world.deposits[cell].kind!="limestone": continue
			if Deposits.quarry_site(world,cell,origin)!=Vector3i.ZERO: quarry_count+=1
		check(quarry_count==2,"Two usable quarry sites survive the closer cliffs")
		var plots: Array[Vector3i]=[]
		for x in range(-12,11,2):
			for z in range(-8,11,2):
				var cell:=Vector3i(x,0,z)
				if not world.build_error("house",cell).is_empty() or world.navigation.route(origin,cell).is_empty(): continue
				plots.append(cell)
		check(plots.size()>=8,"Room remains for at least eight early 2x2 building plots")
		var farm_space:=false
		for cell in plots:
			if world.build_error("hay_field",cell).is_empty(): farm_space=true; break
		check(farm_space,"Lowland still has room for a full-size hay field")
		var stairs:=Vector3i.ZERO; var direction:=-1; var landing:=Vector3i.ZERO
		var approaches: Array=world.ground.keys()
		approaches.sort_custom(func(a,b): return a.distance_squared_to(world.STARTING_HOUSE)<b.distance_squared_to(world.STARTING_HOUSE))
		for cell: Vector3i in approaches:
			if cell.y!=0 or cell.distance_to(world.STARTING_HOUSE)>12 or world.navigation.route(origin,cell).is_empty(): continue
			for yaw in 4:
				var upper_cell: Vector3i=world.navigation.stair_landing(cell,yaw)
				if upper_cell.y!=2 or not world.ground.has(upper_cell) or not world.build_error("stairs",cell,yaw).is_empty(): continue
				# A valid placement alone is not enough: check actual navigation over
				# this particular cliff lip before choosing the construction fixture.
				world.stairs[cell]=yaw; world.rebuild_navigation()
				var accessible: bool=not world.navigation.route(origin,upper_cell).is_empty()
				var usable_plots:=0
				if accessible:
					for candidate: Vector3i in world.ground:
						if candidate.y==2 and world.build_error("house",candidate).is_empty() and not world.navigation.route(origin,candidate).is_empty(): usable_plots+=1
						if usable_plots>=2: break
				accessible=accessible and usable_plots>=2
				world.stairs.erase(cell); world.rebuild_navigation()
				if not accessible: continue
				stairs=cell; direction=yaw; landing=upper_cell; break
			if direction>=0: break
		check(direction>=0,"An ordinary staircase can reach a nearby two-metre terrace")
		if direction>=0:
			check(world.request_build("stairs",stairs,direction),"Terrace stair plan is valid")
			if not world.plans.is_empty(): world.debug_finish_plan(world.next_plan_id-1)
			check(not world.navigation.route(origin,landing).is_empty(),"Completed stairs unlock actual upper-land walking")
			var upper_plots:=0
			for cell: Vector3i in world.ground:
				if cell.y==2 and not world.navigation.route(origin,cell).is_empty() and world.build_error("house",cell).is_empty(): upper_plots+=1
			check(upper_plots>=2,"Stairs unlock buildable house sites, not just a narrow scenic ledge")
		var restored:=Model.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"New terrain and stairs survive save/load")
		print("Seed ",seed_value," central lowland ",previous," -> ",low," upper cells=",upper," early plots=",plots.size()," stair=",stairs," landing=",landing)
	if failures.is_empty(): print("PASS: compact village terraces, opening space, freshwater, quarries and stair expansion")
	quit(int(not failures.is_empty()))
