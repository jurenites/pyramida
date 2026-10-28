extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Cable=preload("res://scripts/block_city/cable.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func place(m, x: int, z: int) -> void:
	m.queue[0]={"shape":"cube","color":m.turn%5}
	check(m.drop(x,z),"Place test corridor")
func run() -> void:
	var m=Model.new()
	place(m,0,0)
	check(m.connect_power(Vector3i.ZERO,Vector3i.FORWARD),"Pole powers first socket")
	place(m,0,0)
	var source := {"cell":[0,0,0],"normal":[0,0,-1]}
	check(m.connect_power(Vector3i(0,1,0),Vector3i.FORWARD,source),"Lower socket daisy-links upper floor")
	check(m.powered_cells().has(Vector3i(0,1,0)),"Daisy-linked floor is energized")
	check(Cable.curve(Cable.socket(Vector3i(0,1,0),Vector3i.FORWARD),m.cable_start(m.cables[1]))[0].is_equal_approx(Cable.socket(Vector3i.ZERO,Vector3i.FORWARD)),"Daisy cable begins at source socket")
	place(m,0,0)
	check(m.connect_power(Vector3i(0,2,0),Vector3i.FORWARD,{"cell":[0,1,0],"normal":[0,0,-1]}),"Daisy links can continue across multiple floors")
	var saved: Dictionary = m.snapshot()
	var loaded=Model.new()
	check(loaded.load_state(saved) and loaded.snapshot()==saved and loaded.powered_cells().size()==3,"Daisy wiring survives save/load")
	m.cables.pop_front()
	check(m.powered_cells().is_empty(),"Disconnected chains do not create power")
	check(not loaded.connect_power(Vector3i(0,2,0),Vector3i.LEFT,{"cell":[2,0,2],"normal":[0,0,-1]}),"Cannot start from a nonexistent socket")
	check(loaded.connection(Vector3i(0,2,0),Vector3i.BACK,source).ok,"Wall cables route around corners to a rear face")
	check(m.undo() and m.cables.size()==2,"Undo removes only the last chain link")
	var bad: Dictionary = saved.duplicate(true)
	bad.cables[1].source_cell=[2,0,2]
	check(not loaded.load_state(bad) and loaded.snapshot()==saved,"Invalid chain source cannot corrupt loaded state")

	bad=saved.duplicate(true)
	bad.cables[0].source_cell=[0,1,0]; bad.cables[0].source_normal=[0,0,-1]
	check(not loaded.load_state(bad),"Unpowered circular wiring is rejected on load")

	var game=load("res://scripts/block_city/game.gd").new()
	game.restore_last=false; game.auto_save=false
	root.add_child(game)
	game.set_holding(true)
	for i in 3: await process_frame
	m=Model.new(); game.model=m
	place(m,0,0)
	m.queue[0]={"shape":"cube","color":1}
	game.refresh()
	var roof: Vector2 = game.camera.unproject_position(Vector3(0.5,0.975,0.5))
	check(game.position_anchor(roof) and game.anchor==Vector2i.ZERO and game.preview.origin==Vector3i(0,1,0),"Cursor snaps to the roof rather than the ground behind it")
	game.click_world(roof)
	game.refresh()
	check(m.rooms.size()==2 and m.rooms[1].cells==[[0,1,0]],"Click places precisely on the snapped roof")
	check(game.geometry.get_node("Room1/Door").get_child_count()==0,"Unconnected upper hall remains open scaffolding without a misleading single door")
	check(game.geometry.get_node("Room0/Door/Doormat").material_override.albedo_color==game.ENTRY_CONNECTED,"Street-connected ground corridor has green mat")
	for angle in [-2.4,-0.8,0.8,2.4]:
		game.orbit=angle; game.update_camera()
		check(game.neighbours.any(func(n): return n.node.get_child(0).transparency==0.0),"Unobstructing neighbors remain solid")
		# Wider pedestrian setbacks can leave all real neighbors clear. Force a
		# foreground bounds fixture to verify fading independently of street size.
		var original: AABB=game.neighbours[0].bounds
		var target:=Vector3(0.5,0.25,0.5)
		var ray: Vector3=game.camera.project_ray_origin(game.camera.unproject_position(target))
		game.neighbours[0].bounds=AABB(target.lerp(ray,0.1)-Vector3.ONE,Vector3.ONE*2)
		game.update_neighbour_visibility()
		check(game.neighbours[0].node.get_child(0).transparency>0.9,"Foreground neighbors fade as camera turns")
		game.neighbours[0].bounds=original
		game.update_neighbour_visibility()
	game.orbit=-2.4; game.update_camera()
	game.set_holding(false)
	check(game.preview.is_empty() and game.ghost.get_child_count()==0,"Setting piece aside clears preview")
	game.click_world(game.camera.unproject_position(Cable.POLE))
	game.click_world(game.camera.unproject_position(Cable.socket(Vector3i.ZERO,Vector3i.FORWARD,0)))
	check(m.cables.size()==1 and not game.holding,"Wiring leaves piece put aside")
	game.set_holding(false)
	game.click_world(game.camera.unproject_position(Cable.endpoint(m.cables[0])))
	check(game.wiring and Cable.key(game.wire_source)==Cable.key(m.cables[0]),"Clicking an existing socket starts daisy wiring")
	game.click_world(game.camera.unproject_position(Cable.socket(Vector3i(0,1,0),Vector3i.FORWARD,0)))
	check(m.cables.size()==2 and m.powered_cells().size()==2,"World clicks complete powered daisy link")
	game.set_holding(true)
	check(game.holding and not game.wiring,"Current-piece thumbnail can resume placement")
	# A wire above the lot must not reserve its entire fall column.
	var test=Model.new()
	place(test,2,2)
	place(test,2,2)
	place(test,2,2)
	check(test.connect_power(Vector3i(2,2,2),Vector3i.FORWARD),"Create overhead wire")
	test.queue[0]={"shape":"cube","color":0}
	check(test.drop(0,0),"Construction may land safely below an overhead cable")
	check(test.fits([Vector3i(0,3,0)],{},{},false),"Cable geometry no longer blocks construction")
	game.free()
	print("Block City interaction: ",failures," failures")
	quit(1 if failures else 0)
