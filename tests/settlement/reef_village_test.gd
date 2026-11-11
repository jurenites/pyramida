extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Islands = preload("res://scripts/settlement/solid_islands.gd")
const Foundation = preload("res://scripts/settlement/support_foundation.gd")
const Coast = preload("res://scripts/settlement/coastal_water.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func build_village(world, target: Vector3i) -> void:
	world.trees.clear(); world.deposits.clear(); world.rebuild_navigation()
	var queue: Array[Vector3i] = [target]
	var toward := {target:target}
	var shore: Variant = null
	var cursor := 0
	while cursor<queue.size() and cursor<3000 and shore==null:
		var cell := queue[cursor]; cursor+=1
		for direction: Vector3i in world.DIRECTIONS:
			var next := cell+direction
			if toward.has(next): continue
			if world.ground.has(next) and world.navigation.walkable(next) and not world.navigation.route(world.workers[0].cell,next).is_empty():
				toward[next]=cell; shore=next; break
			if Islands.shore_distance(Vector2(next.x,next.z),world.world_seed,world.generator_version)<=0: continue
			var clear := true
			for corner: Vector3 in preload("res://scripts/settlement/support_assembly.gd").CORNERS:
				if Islands.native_solid(world.world_seed,Vector3(next)+corner*0.76+Vector3.UP*(Foundation.water_level(world)+0.19),world.generator_version): clear = false
			if not clear: continue
			toward[next]=cell; queue.append(next)
	check(shore!=null,"Reef can be reached from a walkable shore with physical piers")
	if shore==null: return
	var at: Vector3i = toward[shore]
	while true:
		if not finish(world,"support",at): return
		if at==target: break
		at=toward[at]
	# Grow out from the arrived pier, preserving ordinary construction access.
	var pad: Array[Vector3i] = []
	for x in range(-2,3):
		for z in range(-2,3): pad.append(target+Vector3i(x,0,z))
	pad.sort_custom(func(a,b): return absi(a.x-target.x)+absi(a.z-target.z)<absi(b.x-target.x)+absi(b.z-target.z))
	for cell in pad:
		if world.buildings.has(cell): continue
		if not finish(world,"support",cell): return
	var home := target+Vector3i.UP
	if not finish(world,"house",home): return
	check(not world.navigation.route(shore,home).is_empty(),"Shore path reaches a Home built on the shallow reef")
func finish(world, kind: String, cell: Vector3i) -> bool:
	var placed: bool = world.request_build(kind,cell,0,Vector3.ZERO,false)
	check(placed,"Queue reef %s at %s: %s" % [kind,cell,world.last_message])
	if not placed: return false
	var done: bool = world.debug_finish_plan(world.next_plan_id-1)
	check(done,"Complete reef "+kind)
	return done
func run() -> void:
	check(Foundation.post_cost(0)==0,"Dry timber has no underwater surcharge")
	check(2+4*Foundation.post_cost(0.75)==6,"Shallow reef foundation stays affordable")
	check(2+4*Foundation.post_cost(3.0)==90,"Three-metre foundations require substantial bracing")
	check(2+4*Foundation.post_cost(5.0)==226,"Five-metre foundations discourage open-water sprawl")
	check(Foundation.post_cost(10)>3*Foundation.post_cost(5),"Deep-water price grows faster than length")
	for seed_value in [1409,42,9182,101]:
		var world := Model.new(); world.setup(seed_value,"easy",18)
		var islands := Islands.definitions(seed_value,world.generator_version)
		check(world.generator_version==18,"Legacy worlds retain their detached reef terrain")
		check(islands[0].reefs.size()==2,"Main island has two optional reef village sites")
		var repeat := Islands.make_islands(seed_value,world.generator_version)
		check(repeat[0].reefs==islands[0].reefs,"Reefs regenerate deterministically")
		for reef in islands[0].reefs:
			var centre := Vector2i(roundi(reef.centre.x),roundi(reef.centre.y))
			var affordable := 0
			for x in range(-3,4):
				for z in range(-3,4):
					var cell := Vector3i(centre.x+x,0,centre.y+z)
					var bed := Islands.seabed_height(Vector2(cell.x,cell.z),seed_value,world.generator_version)
					check(bed<Foundation.water_level(world)-0.4,"Reef remains submerged, never a free walking floor")
					if Foundation.recipe(world,cell).log<=10: affordable+=1
			check(affordable>=25,"Reef has a broad affordable building area, seed %s: %s cells" % [seed_value,affordable])
			var point := Vector2(centre)
			var bed := Islands.seabed_height(point,seed_value,world.generator_version)
			check(Islands.native_solid(seed_value,Vector3(point.x,bed-0.02,point.y),world.generator_version),"Reef posts have a real solid bearing")
			check(not Islands.native_solid(seed_value,Vector3(point.x,bed+0.02,point.y),world.generator_version),"Water remains clear above reef")
			if seed_value==1409:
				var mesh := Coast.physical_seabed({"islands":islands,"bounds":Rect2(point-Vector2.ONE*5,Vector2.ONE*10)})
				var shallow_vertices := 0
				for vertex in mesh.get_faces():
					check(absf(vertex.y-Islands.seabed_height(Vector2(vertex.x,vertex.z),seed_value,world.generator_version))<0.002,"Rendered reef and construction use the same bed")
					if vertex.y> -1.6: shallow_vertices+=1
				check(shallow_vertices>20,"Visible shallow shelf drives the lighter water colour")
		var old := Islands.definitions(seed_value,17)
		check(not old[0].has("reefs"),"Existing world versions retain their seabed")
		if seed_value==1409:
			var centre: Vector2 = islands[0].reefs[0].centre
			build_village(world,Vector3i(roundi(centre.x),0,roundi(centre.y)))
		var saved := Model.new()
		check(saved.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Reef world restores")
		check(Islands.definitions(saved.world_seed,saved.generator_version)[0].reefs==islands[0].reefs,"Save/load retains reef locations and depths")
	if failures.is_empty(): print("PASS: steep depth pricing, broad shallow reefs, matching physical/visible beds and persistence")
	quit(int(not failures.is_empty()))
