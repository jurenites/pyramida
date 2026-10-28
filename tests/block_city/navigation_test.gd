extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Nav=preload("res://scripts/block_city/room_navigation.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func place(m,shape: String,x: int,z: int,y:=0,color:=0,door: Array=[],normal: Array=[]) -> void:
	m.queue[0]={"shape":shape,"color":color}
	if not door.is_empty(): m.queue[0].merge({"door":door,"normal":normal})
	check(m.drop(x,z,0,false,y),"Place "+shape+": "+m.error)
func run() -> void:
	var m=Model.new()
	place(m,"small_square",0,0,0,1,[0,0,0],[0,0,-1])
	place(m,"room_domino",2,0,0,3,[0,0,1],[-1,0,0])
	check(m.rooms[1].color==1,"A doorway facing a parent room inherits that room's color")
	check(m.room_ports(m.rooms[0]).size()==2 and m.port_matches(m.rooms[0],Vector3i(1,0,1),Vector3i.RIGHT),"Parent gains a reciprocal opening at the child's door")
	check(m.room_ports(m.rooms[1]).size()==1,"Child keeps its single chosen entry")
	check(m.has_access(m.rooms[1]),"A child door connects through the parent wall without a pre-existing matching door")
	var route: Dictionary=m.route_to_room(1)
	check(route.reachable and route.cost==3 and route.path.size()==4,"Route counts cubes through the parent to the child, starting at zero at the main entrance")
	check(route.entry.cell==Vector3i.ZERO and route.path[-1]==Vector3i(2,0,1),"Main entry and destination doorway anchor the route")
	var saved: Dictionary=m.snapshot(); var loaded=Model.new()
	check(loaded.load_state(JSON.parse_string(JSON.stringify(saved))) and loaded.route_to_room(1)==route,"Door graph, color and distances survive save/load")
	check(m.undo() and m.rooms.size()==1 and m.room_ports(m.rooms[0]).size()==1,"Undo removes the reciprocal opening along with its child")
	# Cycles choose a stable existing color, rather than chasing each other forever.
	m.rooms=[{"id":0,"shape":"room_domino","color":1,"cells":[[0,0,0]],"door":[0,0,0],"normal":[1,0,0],"braces":[],"access_path":[]},
		{"id":1,"shape":"room_domino","color":3,"cells":[[1,0,0]],"door":[1,0,0],"normal":[-1,0,0],"braces":[],"access_path":[]}]
	m.apply_connection_colors()
	check(m.rooms[0].color==1 and m.rooms[1].color==1,"Mutually facing doors resolve color cycles deterministically")
	check(not m.route_to_room(1).reachable,"A connected pair without a main entrance is not reported as reachable")
	for kind in ["stairs","elevator"]:
		m=Model.new()
		for level in 4: place(m,kind,0,0,level)
		for level in range(1,4):
			route=m.route_to_room(level)
			check(route.reachable and route.cost==(level if kind=="stairs" else 2),"Each stair rise costs one; an elevator ride costs two regardless of height")
			if kind=="elevator": check(route.steps.size()==1 and route.steps[0].cost==2,"Elevator ride is a direct weighted edge, not repeated floor charges")
		check(m.route_to_room(0).cost==0,"Main entrance is the distance origin")
	m=Model.new(); place(m,"elevator",0,0); place(m,"cube",0,0,1); place(m,"elevator",0,0,2)
	check(not m.route_to_room(2).reachable,"An interrupted shaft cannot produce a false elevator shortcut")
	m=Model.new(); place(m,"stairs",0,0); place(m,"cube",1,0); place(m,"cube",1,0,1)
	# Put the upper hall in front of the virtual top landing through a rotated fixture.
	m.rooms[0].normal=[1,0,0]
	check(m.route_to_room(2).reachable,"Stair top landing connects to a neighboring upper hall")
	# Competing routes: stairs win one storey; the lift wins a long ascent.
	m=Model.new(); m.rooms=[]
	for level in 8:
		for definition in [["cube",0,0],["cube",1,0],["stairs",0,1],["elevator",1,1]]:
			var cell: Array=[definition[1],level,definition[2]]
			m.rooms.append({"id":m.rooms.size(),"shape":definition[0],"color":0,"cells":[cell],"door":cell.duplicate(),"normal":[0,0,-1],"braces":[],"access_path":[]})
	var near: Dictionary=m.route_to_room(6)
	var far: Dictionary=m.route_to_room(30)
	check(near.reachable and near.cost==2 and near.steps.any(func(step):return step.kind=="stairs"),"Shortest route prefers stairs for a nearby floor")
	check(far.reachable and far.cost==7 and far.steps.any(func(step):return step.kind=="elevator"),"Dijkstra prefers a flat-price elevator ride for a long ascent")
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_holding(true)
	game.set_process_unhandled_input(false)
	place(game.model,"small_square",0,0,0,1,[0,0,0],[0,0,-1])
	game.model.queue[0]={"shape":"room_domino","color":3,"door":[0,0,1],"normal":[-1,0,0]}
	game.anchor=Vector2i(2,0); game.snap_y=0; game.refresh()
	var expected: Color=game.model.CONCRETE_FLOOR
	check(Color(game.ghost.get_node("Floors").get_child(0).material_override.albedo_color,1.0)==expected,"Placement preview uses the shared dark concrete floor")
	game.drop()
	if game.drop_tween!=null: game.drop_tween.custom_step(2.0)
	game.set_holding(false); game.refresh()
	check(game.geometry.get_node("Room0/Door").has_node("ConnectionPoint"),"Connected rooms have one solid shared threshold and node")
	check(not game.route_cost.visible,"Unselected construction has no route display")
	game.begin_move(1,game.camera.unproject_position(Vector3(2.4,0.99,1.4)))
	check(game.selected_route.reachable and game.route_cost.visible and game.route_cost.text=="3","Selecting a connected room shows just its route and numeric cost")
	game.cancel_construction()
	check(game.selected_route.is_empty() and not game.route_cost.visible,"Escape hides the route and cost")
	game.free()
	print("Block City navigation: ",failures," failures")
	quit(1 if failures else 0)
