extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const View=preload("res://scripts/block_city/room_view.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func place(m, shape: String, x: int, z: int, yaw := 0) -> void:
	m.queue[0]={"shape":shape,"color":m.turn % 5}
	check(m.drop(x,z,yaw),"Place "+shape+": "+m.error)
func clear_body(game, flight: Node3D, foot: Vector3) -> bool:
	# Sweep a person-sized volume through the rendered shaft, including the
	# next storey's floor, turn slab, divider and walls (not just its treads).
	# Leave the bottom 0.12 for feet stepping over 0.10 risers.
	var center: Vector3=flight.to_global(foot+Vector3(0,0.395,0))
	var body:=AABB(center-Vector3(0.08,0.275,0.08),Vector3(0.16,0.55,0.16))
	for node in game.geometry.get_children():
		if not str(node.name).begins_with("Room"): continue
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			if not mesh.mesh is BoxMesh: continue
			var local_body: AABB=mesh.global_transform.affine_inverse()*body
			if AABB(-mesh.mesh.size/2,mesh.mesh.size).intersects(local_body):
				return false
	return true

func run() -> void:
	var m=Model.new()
	check(m.room_role({"shape":"cube"})=="hall" and m.room_role({"shape":"domino"})=="hall","Small blocks are corridors")
	place(m,"stairs",0,0)
	check(m.rooms[0].cells==[[0,0,0]],"Stair occupies exactly one cube")
	check(m.has_access(m.rooms[0]),"Ground stair entrance reaches street")
	check(not m.landing({"shape":"small_square"},0,0).ok,"Ordinary floor cannot cap a stair shaft")
	place(m,"cube",0,0)
	check(m.has_access(m.rooms[1]),"Upper corridor connects through stair floor opening")
	place(m,"cube",1,0)
	place(m,"cube",1,0)
	check(m.has_access(m.rooms[3]),"Upper corridor connects horizontally from stair landing")
	place(m,"small_square",1,1)
	place(m,"small_square",1,1)
	check(m.has_access(m.rooms[5]),"Upper room door reaches the stair via a corridor")
	check(m.powered_cells().is_empty(),"Walking routes never imply electrical service")
	var saved: Dictionary = m.snapshot()
	var loaded=Model.new()
	check(loaded.load_state(saved) and loaded.has_access(loaded.rooms[5]),"Hall and stair connectivity survives save/load")
	loaded.rooms[0].shape="cube"
	check(not loaded.has_access(loaded.rooms[5]),"Stacked halls alone do not connect floors")
	loaded=Model.new(); loaded.load_state(saved)
	loaded.rooms[5].door=[2,1,2]; loaded.rooms[5].normal=[0,0,1]
	check(not loaded.has_access(loaded.rooms[5]),"A room facing away from the hall is not connected")
	var rotated=Model.new()
	place(rotated,"cube",2,1)
	place(rotated,"stairs",1,1,1)
	place(rotated,"cube",2,1)
	check(rotated.has_access(rotated.rooms[2]),"Rotated stair connects its upper side landing to a corridor")
	var points: Array = View.stair_points()
	check(is_equal_approx(points[-1].y-points[0].y,1.0),"Stair rises exactly one floor")
	var first: Vector3 = points[1]-points[0]
	var last: Vector3 = points[-1]-points[-2]
	check(Vector2(first.x,first.z).normalized().dot(Vector2(last.x,last.z).normalized()) < -0.99,"Exit travel reverses 180 degrees")
	for point in points: check(absf(point.x)<=0.5 and absf(point.z)<=0.5 and point.y>=0 and point.y<=1,"Stair route stays within one cube")
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_holding(true)
	game.set_process_unhandled_input(false)
	for rotation in 4:
		game.model.reset()
		place(game.model,"stairs",1,1,rotation)
		place(game.model,"stairs",1,1,rotation)
		game.set_holding(false)
		for mode in 3:
			game.view_mode=mode; game.refresh()
			for floor_index in 2:
				var room: Dictionary=game.model.rooms[floor_index]
				check(game.model.tint(room)==Model.STAIR_COLOR,"Stairs ignore room color on every level")
				var node: Node3D=game.geometry.get_node("Room%d" % floor_index)
				var lower: MeshInstance3D=node.get_node("Door/Doormat")
				var upper: MeshInstance3D=node.get_node("Door/UpperDoormat")
				check(is_equal_approx(upper.position.y-lower.position.y,1.0),"Stair has two mats exactly one floor apart")
				var normal:=Vector3(Model.vec(room.normal))
				var side:=Vector3(-normal.z,0,normal.x)
				check((upper.position-lower.position).is_equal_approx(Vector3.UP+side*0.44),"Both mats follow rotated lower and upper flight endpoints")
				check(not lower.material_override.no_depth_test and not upper.material_override.no_depth_test,"Stair mats respect wall and floor depth")
				check(node.get_node("Walls").get_child_count()==3,"Three solid stair walls have no window cutouts")
				for wall_mesh in node.get_node("Walls").get_children():
					check(wall_mesh.material_override.albedo_color==Model.STAIR_COLOR,"Stair shell is neutral concrete")
				var edges: Array=node.get_node("Staircase").get_children().filter(func(mesh):return mesh.material_override.albedo_color==game.ACCESS)
				check(edges.size()==10,"Both flights retain yellow concrete-step edges")
	# Three repeated storeys must leave room for an actual body, not merely
	# have connected logical ports. Run in each orientation with full walls.
	for rotation in 4:
		game.model.reset()
		for level in 3: place(game.model,"stairs",1,1,rotation)
		game.view_mode=0; game.refresh()
		for level in 2:
			var flight: Node3D=game.geometry.get_node("Room%d/Staircase" % level)
			for step in 5:
				check(clear_body(game,flight,Vector3(-0.22,(step+1)*0.1,-0.236+step*0.088)),"Lower flight has headroom below the next storey")
				check(clear_body(game,flight,Vector3(0.22,0.6+step*0.1,0.116-step*0.088)),"Returning flight is not filled by upper-floor concrete")
			for sample in 12:
				var across: float=lerpf(-0.22,0.22,float(sample)/11)
				check(clear_body(game,flight,Vector3(across,0.5,0.30)),"Rear turn has an open passage and headroom")
				check(clear_body(game,flight,Vector3(across,1,-0.38)),"Intermediate landing lets people cross to the next flight")
			for sample in 8:
				var forward: float=lerpf(-0.38,-0.22,float(sample)/7)
				check(clear_body(game,flight,Vector3(0.22,1,forward)),"Upper exit joins the intermediate landing without a slab blocking it")
	# The terminal rooftop enclosure must shelter the opening without sealing
	# the final flight or rear turn. Intermediate stairs keep their open shaft.
	for rotation in 4:
		game.model.reset(); place(game.model,"stairs",1,1,rotation)
		game.view_mode=0; game.refresh()
		var flight: Node3D=game.geometry.get_node("Room0/Staircase")
		check(game.geometry.get_node("Room0").has_node("RooftopAccess"),"An uncovered stair has a rooftop exit enclosure")
		for step in 5:
			check(clear_body(game,flight,Vector3(-0.22,(step+1)*0.1,-0.236+step*0.088)),"Rooftop cover leaves headroom on the lower flight")
			check(clear_body(game,flight,Vector3(0.22,0.6+step*0.1,0.116-step*0.088)),"Half-width enclosure leaves the returning flight clear")
		for sample in 12:
			check(clear_body(game,flight,Vector3(lerpf(-0.22,0.22,float(sample)/11),0.5,0.30)),"Covered rear turn remains passable")
		for z in [-0.38,-0.50,-0.64]: check(clear_body(game,flight,Vector3(0.22,1,z)),"Miniature door leaves a clear exit onto the roof")
		game.view_mode=1; game.refresh()
		check(not game.geometry.get_node("Room0").has_node("RooftopAccess"),"Roofless view reveals the stair beneath its enclosure")
		place(game.model,"cube",1,1); game.view_mode=0; game.refresh()
		check(not game.geometry.get_node("Room0").has_node("RooftopAccess"),"Building above replaces the rooftop enclosure with normal stair continuity")
	game.free()
	print("Block City interiors: ",failures," failures")
	quit(1 if failures else 0)
