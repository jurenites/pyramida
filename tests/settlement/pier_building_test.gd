extends SceneTree
const Fixture = preload("res://tests/settlement/reviewed_balance_test.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Elevation = preload("res://scripts/settlement/structure_elevation.gd")
const Foundation = preload("res://scripts/settlement/support_foundation.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func finish(world, kind: String, cell: Vector3i, direction := 0) -> bool:
	var placed: bool = world.request_build(kind,cell,direction,Vector3.ZERO,false)
	check(placed,"Queue %s at %s: %s" % [kind,cell,world.last_message])
	if not placed: return false
	var done: bool = world.debug_finish_plan(world.next_plan_id-1)
	check(done,"Complete %s at %s" % [kind,cell])
	return done
func run() -> void:
	var fixture := Fixture.new(); var world = fixture.fixture()
	world.generator_version = 4
	for x in range(2,9):
		for z in range(-4,8):
			world.ground.erase(Vector3i(x,0,z))
			for y in range(-4,0): world.volume_edits[Vector3i(x,y,z)] = "water"
	world.rebuild_navigation()
	for x in range(2,8):
		for z in range(-3,8):
			if not finish(world,"support",Vector3i(x,0,z)): fixture.free(); quit(1); return
	var floor_y := Foundation.water_level(world)+Foundation.DECK_CLEARANCE
	for z in range(-2,1): check(finish(world,"support",Vector3i(1,0,z)),"Add dry bearings beside the pier")
	check(world.build_error("house",Vector3i(2,1,-1)) == "Supports must meet at one height", "Buildings cannot straddle low and raised bearings")
	var house := Vector3i(5,1,0)
	check(is_equal_approx(Elevation.base_shift(world,house,"house"),floor_y-1),"Placement inherits the real pier bearing")
	check(world.request_build("house",house,0,Vector3.ZERO,false),"Home can be planned directly on the low pier: "+world.last_message)
	if world.plans.is_empty(): fixture.free(); quit(1); return
	var id: int = world.next_plan_id-1
	var view := View.new(); root.add_child(view); view.setup(world)
	var planned: Node3D = view.entity_views["plan:%s" % id]
	check(is_equal_approx(planned.position.y,floor_y),"Construction site rests directly on the deck")
	check(world.debug_finish_plan(id),"Pier Home completes")
	view.sync(world,0,-1)
	var node: Node3D = view.entity_views["building:%s" % house]
	check(is_equal_approx(node.position.y,floor_y),"Completed Home sits on the low pier, without tall extra posts")
	check(is_equal_approx(world.navigation.surface_point(house).y,floor_y+0.06),"Home floor navigation follows its actual floorboards")
	var door := house+Vector3i.BACK
	var approach := house+Vector3i.BACK*2
	check(not world.navigation.route(approach,house).is_empty(),"Pier connects through the Home doorway")
	for points: Array in world.navigation.room_paths.get(door,{}).values():
		for point: Vector3 in points: check(point.y>=floor_y-0.001 and point.y<=floor_y+0.1,"Doorway path never drops below the pier or floats above it")
	# A separate one-metre flight connects two real platform levels.
	var stair := Vector3i(3,1,-2)
	var upper := Vector3i(4,1,-2)
	check(finish(world,"support",upper),"Upper platform carries a separate second level")
	var lower_landing := Vector3i(2,1,-2)
	var upper_landing := upper+Vector3i.UP
	check(world.navigation.route(lower_landing,upper_landing).is_empty(),"Stacked levels have no phantom route before stairs")
	check(finish(world,"stair",stair,0),"Stair creates the explicit level connection")
	check(not world.navigation.route(lower_landing,upper_landing).is_empty(),"Stair connects the lower pier to the upper platform")
	var path: Array = world.navigation.room_paths.get(lower_landing,{}).get(upper_landing,[])
	check(path.size()>=4,"Stair connection contains its physical approach and landings")
	if path.size()>=4:
		check(is_equal_approx(path.front().y,floor_y) and is_equal_approx(path.back().y,floor_y+1),"Both stair endpoints match their deck heights")
	view.sync(world,0,-1)
	check(is_equal_approx(view.entity_views["building:%s" % stair].position.y,floor_y),"Stair model and walking connector start on the same low floor")
	# Larger ordinary buildings also inherit the deck elevation.
	check(finish(world,"log_shed",Vector3i(3,1,1)),"Shed can stand on the pier")
	# A two-metre paid flight has a deck landing outside the upper Home's door.
	check(finish(world,"house",house),"Reinforce the Home for another storey")
	var upper_home := house + Vector3i.UP * 2
	check(finish(world,"house",upper_home),"Upper Home follows the lower Home's real elevation")
	check(finish(world,"support",Vector3i(5,1,2)),"Build the first landing frame")
	check(finish(world,"support",Vector3i(5,2,2)),"Build the upper landing frame")
	check(world.StructureLayout.restore_deck(world,Vector3i(5,2,2)),"Open the deck at the upper doorway's level")
	var stair_base := Vector3i(5,1,4)
	var approach_from_pier := Vector3i(5,1,6)
	check(world.navigation.route(approach_from_pier,upper_home).is_empty(),"The second storey requires a physical connector")
	check(finish(world,"stairs",stair_base,3),"Build a two-metre flight to the upper doorway landing")
	check(not world.navigation.route(approach_from_pier,upper_home).is_empty(),"Pier route reaches the upper building through stairs, landing and doorway")
	view.sync(world,0,-1)
	check(is_equal_approx(view.entity_views["building:%s" % upper_home].position.y,floor_y+2),"Upper building is exactly one storey above the lower building")
	check(is_equal_approx(view.entity_views["stairs:%s" % stair_base].position.y,floor_y),"Two-metre stair geometry starts at pier level")
	check(world.order_move(0,upper_home),"Citizen accepts the route from shore to the upper Home")
	for step in 2000:
		world.time += 0.05; world.Jobs.prepare_decisions(world)
		world.workers[0].hunger = 0
		world.Citizens.tick(world,world.workers[0],0.05)
		if world.workers[0].cell == upper_home: break
	check(world.workers[0].cell == upper_home,"Citizen walks through the real level connection")
	check(world.workers[0].position.distance_to(world.navigation.surface_point(upper_home)) < 0.01,"Citizen arrives on the upper floor, without floating")
	var restored := Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Pier buildings and level connectors survive saves")
	check(is_equal_approx(restored.navigation.surface_point(house).y,floor_y+0.06),"Restored Home retains its physical floor height")
	check(not restored.navigation.route(lower_landing,upper_landing).is_empty(),"Restored stairs still connect levels")
	check(not restored.navigation.route(approach_from_pier,upper_home).is_empty(),"Reload preserves the whole route between building levels")
	view.free(); fixture.free()
	if failures.is_empty(): print("PASS: low-pier buildings, sites, doorway access, physical stair landings and persistence")
	quit(int(not failures.is_empty()))
