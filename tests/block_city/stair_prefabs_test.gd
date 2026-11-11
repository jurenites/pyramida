extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Stairs=preload("res://scripts/block_city/stair_geometry.gd")
const Navigation=preload("res://scripts/block_city/room_navigation.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func place(m,shape: String,cell: Vector3i,yaw:=0,extra: Dictionary={}) -> void:
	m.queue[0]={"shape":shape,"color":0}
	m.queue[0].merge(extra,true)
	check(m.drop(cell.x,cell.z,yaw,false,cell.y),"Place %s at %s: %s" % [shape,cell,m.error])
func fixture(m,shape: String,yaw: int) -> Dictionary:
	m.reset()
	place(m,shape,Vector3i(1,0,1),yaw)
	for x in 3:
		for z in 3:
			if x!=1 or z!=1: place(m,"cube",Vector3i(x,0,z))
	return m.authored_ports(m.rooms[0])[1]
func clear_body(game,flight: Node3D,foot: Vector3) -> bool:
	# Sample the body through actual mesh triangles, including the winding
	# treads, roofs and next floor. It must not pass through a solid surface.
	for dx in [-0.07,0.0,0.07]:
		for dz in [-0.07,0.0,0.07]:
			var start: Vector3=flight.to_global(foot+Vector3(dx,0.125,dz))
			var finish: Vector3=flight.to_global(foot+Vector3(dx,0.67,dz))
			for node in game.geometry.get_children():
				if not str(node.name).begins_with("Room"): continue
				for mesh in node.find_children("*","MeshInstance3D",true,false):
					var transform: Transform3D=mesh.global_transform.affine_inverse()
					var a: Vector3=transform*start
					var b: Vector3=transform*finish
					if not mesh.mesh.get_aabb().intersects_segment(a,b): continue
					var faces: PackedVector3Array=mesh.mesh.get_faces()
					for i in range(0,faces.size(),3):
						if Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2])!=null:
							print("Blocked body at ",foot," by ",mesh.get_path())
							return false
	return true
func run() -> void:
	for shape in ["stairs","stairs_quarter"]:
		for yaw in 4:
			var m=Model.new()
			var port: Dictionary=fixture(m,shape,yaw)
			var quarter: bool=shape=="stairs_quarter"
			var normal: Vector3i=Model.rotate_point(Vector3i.FORWARD,yaw)
			check(port.normal==Stairs.exit_normal(normal,quarter),"Exit direction follows variant and rotation")
			check(m.rooms[0].cells==[[1,0,1]],"Each 2 m prefab occupies one demo cell")
			check(m.has_access(m.rooms[0]) and m.port_linked(m.rooms[0],port),"A reached stair connects to the exposed receiving roof")
			var built: Dictionary=Navigation.build(m,m.rooms)
			check(built.graph[port.cell].has(port.cell+port.normal),"Roof is part of the walking graph")
			check(not built.graph[port.cell].has(port.cell-port.normal),"Upper exit does not connect through the back wall")
			# Place a two-cell room beside the shaft; it gains an offset doorway
			# that matches the actual stair exit rather than the centre of its wall.
			var target: Vector3i=port.cell+port.normal
			var second: Vector3i=target+(Vector3i.FORWARD if port.normal.x!=0 else Vector3i.LEFT)
			var anchor: Vector3i=target.min(second)
			var local_cells: Array=[Model.arr(target-anchor),Model.arr(second-anchor)]
			place(m,"room_domino",anchor,0,{"cells":local_cells,"door":local_cells[0],"normal":Model.arr(-port.normal)})
			var id: int=m.rooms.size()-1
			check(m.has_access(m.rooms[id]) and m.route_to_room(id).reachable,"Upper room is reachable through either prefab")
			var matching: Array=m.room_ports(m.rooms[id]).filter(func(p):return p.cell==target and p.normal==-port.normal)
			check(matching.size()==1 and is_equal_approx(float(matching[0].across),-float(port.across)),"Room opening aligns with the stair's offset exit")
			var loaded=Model.new()
			check(loaded.load_state(JSON.parse_string(JSON.stringify(m.snapshot()))),"Both prefabs round-trip through saved state")
			check(loaded.rooms[0].shape==shape and loaded.authored_ports(loaded.rooms[0])==m.authored_ports(m.rooms[0]),"Save preserves the variant and oriented ports")
			check(loaded.route_to_room(id)==m.route_to_room(id),"Saved roof and room routes agree")
			check(m.undo() and m.port_linked(m.rooms[0],port),"Undoing the room restores the roof destination")
			# Nothing adjacent at upper height means no phantom exit connection.
			m.reset(); place(m,shape,Vector3i(1,0,1),yaw)
			check(not m.port_linked(m.rooms[0],m.authored_ports(m.rooms[0])[1]),"An unsupported upper exit remains unconnected")
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.model.defer_analysis=false
	game.set_process_unhandled_input(false)
	for shape in ["stairs","stairs_quarter"]:
		game.select_debug_shape(shape)
		check(game.model.current().shape==shape and game.debug_palette.cards[shape].selected,"Palette switches between stair prefabs")
		check(game.debug_palette.cards[shape].tooltip_text.contains("90°" if shape=="stairs_quarter" else "180°"),"Palette names the turn and metric size")
		for yaw in 4:
			var port: Dictionary=fixture(game.model,shape,yaw)
			game.set_holding(false)
			for mode in [0,2]:
				game.view_mode=mode; game.refresh()
				var node: Node3D=game.geometry.get_node("Room0")
				var flight: Node3D=node.get_node("Staircase")
				check(not flight.has_node("ExitLanding"),"No extra landing is appended to the prefab")
				check(flight.has_node("UpperPlatform")==(shape=="stairs_quarter"),"Only the quarter-turn includes an upper platform")
				var upper: MeshInstance3D=node.get_node("Door/UpperDoormat")
				check(upper.material_override.albedo_color==game.ENTRY_CONNECTED,"A reached roof connection has a green upper mat")
				var expected:=Vector3(port.cell)+Vector3(0.5,0.08,0.5)+Vector3(port.normal)*0.64+Vector3(-port.normal.z,0,port.normal.x)*float(port.across)
				check(upper.position.is_equal_approx(expected),"Rendered mat follows the selected upper exit")
				var roof_cell: Vector3i=port.cell+port.normal-Vector3i.UP
				var roof_id: int=game.model.occupied()[roof_cell]
				var rim: Node=game.geometry.get_node("Room%d/RoofRim" % roof_id)
				check(not rim.get_children().any(func(edge):return edge.get_meta("normal",Vector3i.ZERO)==-port.normal),"Receiving roof rim leaves the exit open")
				for foot in Stairs.route(shape=="stairs_quarter"):
					check(clear_body(game,flight,foot),"Both stair routes have body clearance in every rotation/view")
			# Upper-floor openings follow the variant rather than covering its turn.
			place(game.model,"cube",Vector3i(1,1,1))
			game.view_mode=0; game.refresh()
			var flight: Node3D=game.geometry.get_node("Room0/Staircase")
			for foot in Stairs.route(shape=="stairs_quarter"):
				check(clear_body(game,flight,foot),"Receiving hall keeps the staircase shaft clear")
			game.model.undo()
			place(game.model,shape,Vector3i(1,1,1),yaw)
			game.refresh()
			flight=game.geometry.get_node("Room0/Staircase")
			for foot in Stairs.route(shape=="stairs_quarter"):
				check(clear_body(game,flight,foot),"Repeated stair prefabs preserve headroom")
			for sample in 12:
				var x: float=lerpf(0.25,-0.25,float(sample)/11)
				check(clear_body(game,flight,Vector3(x,1.1 if x<0.04 else 1.0,-0.45)),"Receiving floor connects to the next flight")
	game.free()
	print("Block City stair prefabs: ",failures," failures")
	quit(1 if failures else 0)
