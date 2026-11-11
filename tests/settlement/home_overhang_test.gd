extends SceneTree
const World=preload("res://scripts/settlement/world_model.gd")
const Stack=preload("res://scripts/settlement/home_stack.gd")
const Assembly=preload("res://scripts/settlement/building_assembly.gd")
const Preview=preload("res://scripts/settlement/home_placement_preview.gd")
var failures:=0
var checks:=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func fixture():
	var world=World.new(); world.streaming_enabled=false
	for x in range(-6,7):
		for z in range(-6,7): world.ground[Vector3i(x,0,z)]=true
	world.buildings[Vector3i.ZERO]={"kind":"house","direction":0,"house_tier":2}
	world.rebuild_navigation()
	return world
func run() -> void:
	for amount in [0.0,0.3,0.5,0.5001,0.75,1.0,1.25,1.499,1.5,1.7]:
		var world=fixture()
		var cell:=Vector3i(roundi(amount),2,0); var offset:=Vector3(amount-cell.x,0,0)
		var original_windows: Dictionary=load("res://scripts/settlement/home_assembly.gd").profile(world,Vector3i.ZERO,[Vector3i.ZERO]).duplicate(true)
		var before: Dictionary=world.buildings.duplicate(true)
		var plan:=Stack.plan(world,cell,offset)
		check(plan.error.is_empty(),"Clear facade supports overhang "+str(amount)+": "+plan.error)
		check(plan.members.size()==(0 if amount<=0.5 else 2),"Threshold support count "+str(amount))
		for member in plan.members:
			check(member.kind==("post" if amount>=1.5 else "brace"),"Correct support type "+str(amount))
			check(Stack.clear_openings(Vector3(cell)+offset+member.a,Vector3(cell)+offset+member.b,Stack.opening_boxes(world)),"Support leaves every visible opening clear")
			if member.kind=="post": check(is_zero_approx(cell.y+member.a.y),"Vertical post reaches actual ground")
			else: check(is_equal_approx(absf(member.a.y-member.b.y),Vector2(member.a.x-member.b.x,member.a.z-member.b.z).length()),"Brace follows a 45 degree slope")
		check(world.request_build("house",cell,1,offset,false),"Real placement accepts supported overhang "+str(amount)+": "+world.last_message)
		if not world.plans.is_empty():
			var building_plan: Dictionary=world.plans.values()[0]
			check(world.Planning.ready(world,building_plan),"Completed bearings make the overhanging construction ready")
			check(int(building_plan.materials.log)==2+Stack.log_cost(world,cell,offset),"Construction pays only for required support stock")
			world.plans.clear()
		var node: Node3D=load("res://scripts/settlement/asset_library.gd").create("house"); root.add_child(node)
		node.position=Vector3(cell)+offset; node.rotation.y=-PI/2
		check(Preview.sync(node,world,cell,1,offset),"Hover builds the prospective Home")
		check(node.get_meta("support_preview").members==plan.members,"Hover shows the same planned supports")
		check(world.buildings==before,"Hover does not change real buildings")
		check(not Preview.sync(node,world,cell,1,offset),"Unchanged hover reuses geometry")
		var preview_members: Array=[]
		for part in node.get_node("AssembledHome").get_children():
			if part is MeshInstance3D and (str(part.name).begins_with("Stack") or part.get_meta("timber_stock","")=="log" and part.get_aabb().position.y< -0.2): preview_members.append(part.get_aabb())
		world.buildings[cell]={"kind":"house","direction":1,"placement_offset":offset,"house_tier":1}
		world.rebuild_navigation(); Assembly.sync(world,{"home":node})
		check(world.needs_stack_support(Vector3i.ZERO),"Offset upper Home protects its real roof bearing")
		check(load("res://scripts/settlement/home_assembly.gd").profile(world,Vector3i.ZERO,[Vector3i.ZERO]).walls==original_windows.walls,"Stack support never removes or moves a lower window")
		var built_members: Array=[]
		for part in node.get_node("AssembledHome").get_children():
			if part is MeshInstance3D and (str(part.name).begins_with("Stack") or part.get_meta("timber_stock","")=="log" and part.get_aabb().position.y< -0.2): built_members.append(part.get_aabb())
		check(preview_members==built_members,"Built timber geometry matches hover after rotation")
		check(not world.navigation.route(Vector3i(-4,0,2),Vector3i(4,0,2)).is_empty(),"Ground passage stays open beneath the overhang")
		for a in world.navigation.edges:
			for b in world.navigation.edges[a]:
				var points: Array=world.navigation.room_paths.get(a,{}).get(b,[world.navigation.surface_point(a),world.navigation.surface_point(b)])
				for box in world.navigation.stack_solids:
					for i in range(1,points.size()): check(box.intersects_segment(points[i-1],points[i])==null,"Walking edge avoids physical support stock")
		if is_equal_approx(amount,1.5):
			var route: Array=world.navigation.route(Vector3i(2,0,-3),Vector3i(2,0,3))
			check(Vector3i(2,0,0) in route,"Route passes underneath the post-supported upper Home")
			world.workers.append({"id":0,"cell":Vector3i(2,0,-3),"position":Vector3(2,0,-3),"route":[],"route_index":0,"job":{},"cargo":"","status":"idle","distance":0.0,"hunger":0.0,"role":"idle","life_stage":"adult","growth_seconds":0.0})
			check(world.order_move(0,Vector3i(2,0,3)),"Citizen accepts the route beneath the overhang")
			for i in 300:
				world.tick(0.04)
				if world.workers[0].cell==Vector3i(2,0,3): break
			check(world.workers[0].cell==Vector3i(2,0,3),"Citizen walks between the posts without getting stuck")
		node.free()
	var world=fixture()
	check(Stack.braces(world,Vector3i(0,2,0),Vector3(0.5,0,0.5)).is_empty(),"Half-metre overhang on both axes does not create a diagonal brace")
	world.ground.clear()
	check(not Stack.plan(world,Vector3i(2,2,0),Vector3(-0.5,0,0)).error.is_empty(),"Vertical supports cannot terminate in empty space")
	print("%s: %d overhang thresholds, preview, openings and passage checks"%["PASS" if failures==0 else "FAIL",checks])
	quit(int(failures>0))
