extends SceneTree
const Basin=preload("res://scripts/settlement/puddle_basin.gd")
const Model=preload("res://scripts/settlement/world_model.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cell:=Vector3i(-8,0,7)
	var world=Model.new(); world.setup(1409,"easy",11)
	var inventory=world.Inventory.new(); inventory.capacity=3; inventory.store("water",3)
	world.water_sources[cell]={"kind":"puddle","inventory":inventory}; world.rebuild_navigation()
	assert(is_equal_approx(world.navigation.surface_point(cell).y,-Basin.DEPTH))
	assert(not world.SolidIslands.solid(world,Vector3(cell)+Vector3.DOWN*0.09))
	assert(world.SolidIslands.solid(world,Vector3(cell)+Vector3.DOWN*0.20))
	var previous_area:=0.0; var previous_height:=-1.0
	for amount in [1,2,3]:
		var mesh=Basin.water(cell,1409,amount/3.0)
		var bounds=mesh.get_aabb()
		assert(bounds.size.x*bounds.size.z>previous_area and bounds.position.y>previous_height)
		previous_area=bounds.size.x*bounds.size.z; previous_height=bounds.position.y
		for point in mesh.get_faces(): assert(point.y+0.0001>=Basin.height(cell,1409,Vector3(cell)+point))
	assert(Basin.water(cell,1409,0)==null)
	var restored=Model.new(); assert(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))))
	assert(is_equal_approx(restored.navigation.surface_point(cell).y,-Basin.DEPTH))
	# The rendered subtraction and real collision must agree with navigation.
	var solid=CSGCombiner3D.new(); solid.use_collision=true; root.add_child(solid)
	var ground=CSGBox3D.new(); ground.size=Vector3(2,0.5,2); ground.position.y=-0.25; solid.add_child(ground)
	var cut=CSGMesh3D.new(); cut.mesh=Basin.cutter(cell,1409); cut.operation=CSGShape3D.OPERATION_SUBTRACTION; solid.add_child(cut)
	for i in 8: await physics_frame
	for point in [Vector3.ZERO,Vector3(0.15,0,0.05),Vector3(0.7,0,0)]:
		var hit=solid.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP,point+Vector3.DOWN))
		assert(not hit.is_empty() and absf(hit.position.y-Basin.height(cell,1409,Vector3(cell)+point))<0.003,"Physical basin follows the same bowl")
	solid.free()
	print("PASS: basin terrain collision, navigation, solid queries, falling waterline and save reconstruction")
	quit()
