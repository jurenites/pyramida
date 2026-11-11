extends "res://tests/settlement/building_passage_edges_test.gd"
const Pose=preload("res://scripts/settlement/home_pose.gd")
const Preview=preload("res://scripts/settlement/home_placement_preview.gd")
func run() -> void:
	for seed_ in [0,1,42,1409,999]:
		for offset in [0.35,0.75,1.5]:
			var world=World.new(); world.world_seed=seed_; world.streaming_enabled=false
			for x in range(-7,8):
				for z in range(-7,8): world.ground[Vector3i(x,0,z)]=true
			for z in [0,2]: world.buildings[Vector3i(0,0,z)]={"kind":"house","direction":0,"house_tier":2}
			world.buildings[Vector3i(2,0,2)]={"kind":"house","direction":1,"house_tier":2}
			var cell:=Vector3i(roundi(offset),2,0); var shift:=Vector3(offset-cell.x,0,0)
			world.buildings[cell]={"kind":"house","direction":0,"house_tier":1,"placement_offset":shift}
			world.stairs[Vector3i(0,0,4)]=3; world.rebuild_navigation()
			var entries:=Layout.build(world)
			for entry in entries.values():
				check(entry.yaw>=0 and entry.yaw<=deg_to_rad(5),"Home yaw stays within five degrees")
				for rail in Layout.rails(entry,entries):
					var a:=Pose.unpoint(entry,rail[0]); var b:=Pose.unpoint(entry,rail[1])
					var x_edge: bool=is_equal_approx(a.x,b.x) and (is_equal_approx(a.x,entry.rect.position.x) or is_equal_approx(a.x,entry.rect.end.x))
					var z_edge: bool=is_equal_approx(a.z,b.z) and (is_equal_approx(a.z,entry.rect.position.y) or is_equal_approx(a.z,entry.rect.end.y))
					check(x_edge or z_edge,"Fence follows one actual edge and never cuts across a corner")
			check(not world.navigation.route(Vector3i(0,0,6),cell).is_empty(),"Ground, stairs, terrace and upper doorway stay connected "+str([seed_,offset]))
			multi_level_paths(world,"Rotated Home "+str([seed_,offset]))
			var node: Node3D=Assets.create("house"); root.add_child(node)
			node.position=Vector3(cell)+shift; node.set_meta("cell",cell); node.set_meta("asset","house")
			Preview.sync(node,world,cell,0,shift)
			var preview_stamp: Array=node.get_node("AssembledHome").get_meta("assembly_stamp").duplicate(true)
			Assembly.sync(world,{"home":node})
			check(node.get_node("AssembledHome").get_meta("assembly_stamp")==preview_stamp,"Hover and completed Home have the same rotation and seams")
			node.free()
	print("%s: %d rotated Home connection, geometry, and preview checks"%["PASS" if failures==0 else "FAIL",checks])
	quit(int(failures>0))
