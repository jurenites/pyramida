extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func place(m,shape: String,x: int,z: int,yaw:=0,y:=-100) -> void:
	m.queue[0]={"shape":shape,"color":0}
	check(m.drop(x,z,yaw,false,y),"Place "+shape+": "+m.error)
func run() -> void:
	var m=Model.new()
	place(m,"elevator",0,1)
	check(not m.has_access(m.rooms[0]),"Inward elevator entrance remains pending")
	place(m,"cube",0,0)
	check(m.has_access(m.rooms[0]),"Hall grants access to the shaft entrance")
	place(m,"elevator",0,1,0,1)
	place(m,"cube",0,0,0,1)
	check(m.has_access(m.rooms[3]),"Upper hall reaches street through stacked elevator sections")
	check(m.room_ports(m.rooms[0]).size()==1,"Shaft has one doorway on its own floor")
	check(m.powered_cells().is_empty(),"Circulation does not grant electricity")
	var saved: Dictionary=m.snapshot(); var loaded=Model.new()
	check(loaded.load_state(JSON.parse_string(JSON.stringify(saved))) and loaded.has_access(loaded.rooms[3]),"Shaft connectivity survives persistence")
	check(m.undo() and m.rooms.size()==3 and m.has_access(m.rooms[2]),"Undo removes upper hall without breaking shaft")
	loaded.rooms[0].shape="cube"
	check(not loaded.has_access(loaded.rooms[3]),"A hall interrupting the shaft cannot provide vertical travel")
	m=Model.new(); place(m,"elevator",0,0)
	place(m,"elevator",0,0,1,1)
	check(m.has_access(m.rooms[1]),"Door may face a different side on the next shaft level")
	place(m,"cube",0,0,0,2); place(m,"elevator",0,0,0,3)
	check(not m.has_access(m.rooms[3]),"A gap in the shaft cannot be bridged invisibly")
	var retired: Dictionary=m.snapshot()
	retired.queue[0]={"shape":"flat_l","color":0}; retired.basement_queue[0]={"shape":"flat_l_mirror","color":0}
	check(m.load_state(retired) and m.current().shape=="small_square" and m.current(true).shape=="small_square","Already queued L shapes retire safely")
	check(m.config.shapes.filter(func(shape):return shape.id in ["flat_l","flat_l_mirror"]).all(func(shape):return shape.weight==0 and shape.palette_hidden),"L shapes have no draw weight or palette tile")
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process_unhandled_input(false)
	for yaw in 4:
		game.model.reset()
		for floor_level in 3: place(game.model,"elevator",1,1,(yaw+floor_level)%4,floor_level)
		game.set_holding(false); game.view_mode=1; game.refresh()
		var cabs:=0
		for level in 3:
			var room: Node=game.geometry.get_node("Room%d" % level)
			check(room.has_node("ElevatorShaft"),"Shaft geometry is present")
			check(room.has_node("ElevatorShaft/CounterweightCable")== (level==2),"No rear cable hangs beneath the raised counterweight")
			if level==2:
				var rear: MeshInstance3D=room.get_node("ElevatorShaft/CounterweightCable")
				var weight: MeshInstance3D=room.get_node("ElevatorShaft/Counterweight")
				check(is_equal_approx(rear.position.y-rear.mesh.size.y/2,weight.position.y+weight.mesh.size.y/2),"Rear rope terminates exactly at the counterweight top")
				check(room.get_node("ElevatorShaft").rotation.is_equal_approx(game.geometry.get_node("Room0/ElevatorShaft").rotation),"Rear suspension retains cabin alignment despite rotated landing doors")
			check(room.has_node("ElevatorShaft/Counterweight")== (level==2),"Continuous shaft has a single counterweight above the parked cabin")
			var door: Node=room.get_node("Door/ElevatorDoor")
			check(door.get_meta("floor_cell")==Vector3i(1,level,1),"Each floor has its own elevator doorway")
			check(door.get_meta("cabin_here")== (level==0),"Doors open only at the parked cabin")
			check(door.get_node("SlidingDoors").get_child_count()==2,"Each landing has paired sliding doors")
			check(room.has_node("ElevatorShaft/ElevatorCabin")== (level==0),"Only the bottom section contains a complete cabin")
			if level==0:
				var cabin: Node=room.get_node("ElevatorShaft/ElevatorCabin")
				check(cabin.get_child_count()>6,"Cabin includes walls, handrails and controls, not just a platform")
			check(room.get_node("Roofs").get_child_count()==0,"No slab caps the continuous shaft")
			for mesh in room.find_children("*","MeshInstance3D",true,false):
				if str(mesh.name).begins_with("CabPlatform"): cabs+=1
				if level>0 and mesh.mesh is BoxMesh and mesh.name!="HoistCable":
					var center:=Vector3(1.5,level+0.5,1.5)
					var travel:=AABB(center-Vector3(0.24,0.49,0.24),Vector3(0.48,0.98,0.48))
					var local_box: AABB=mesh.global_transform.affine_inverse()*travel
					check(not AABB(-mesh.mesh.size/2,mesh.mesh.size).intersects(local_box),"Shaft core stays clear apart from its intentional central suspension cable")
		check(cabs==1,"A continuous shaft has one resting platform at its base")
	game.model.reset()
	for level in 3:
		place(game.model,"elevator",0,1,0,level)
		place(game.model,"cube",0,0,0,level)
	game.refresh()
	for i in 120:
		await process_frame
		if game.analysis_thread==null and game.analysis_pending.is_empty() and game.room_redraw_queue.is_empty(): break
	check(game.model.accessible_rooms().size()==6,"Every floor landing and hall connects through the same shaft")
	for level in 3:
		var mat: MeshInstance3D=game.geometry.get_node("Room%d/Door/Doormat" % (level*2))
		check(mat.material_override.albedo_color==game.ENTRY_CONNECTED,"Each connected floor entrance has a green mat")
	var saved_stack: Dictionary=game.model.snapshot()
	check(game.model.load_state(saved_stack),"Door and cabin floor locations survive load")
	game.refresh()
	check(game.geometry.get_node("Room0/ElevatorShaft").has_node("ElevatorCabin") and not game.geometry.get_node("Room2/ElevatorShaft").has_node("ElevatorCabin"),"Reload does not duplicate the parked cabin")
	game.select_debug_shape("elevator")
	check(game.debug_palette.cards.elevator.role=="elevator" and game.model.current().shape=="elevator","Elevator has a dedicated selectable icon")
	game.begin_move(0,game.camera.unproject_position(Vector3(0.5,0.5,1.5)))
	game.anchor=Vector2i(2,2); game.snap_y=4; game.refresh_preview()
	check(not game.preview.ok and game.ghost.has_node("ElevatorShaft/HoistCable"),"Unsupported elevator move previews render suspension without relying on the old shaft cell")
	game.cancel_construction()
	game.free()
	print("Block City elevator: ",failures," failures")
	quit(1 if failures else 0)
