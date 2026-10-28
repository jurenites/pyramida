extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Cable=preload("res://scripts/block_city/cable.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var m=Model.new()
	for x in 2:
		m.queue[0]={"shape":"cube","color":0}
		check(m.drop(x,0,0,false,0),"Place fixture")
	for slot in 2: check(m.connect_power(Vector3i.ZERO,Vector3i.FORWARD,{},slot),"Tall pole accepts two remaining feeds beside its starter transformer")
	check(not m.connect_power(Vector3i.ZERO,Vector3i.FORWARD,{},2),"Fourth total heavy feed rejected")
	check(not m.powered_cells().has(Vector3i(1,0,0)),"Touching room remains unpowered without its own fuse connection")
	var source: Dictionary={"cell":[0,0,0],"normal":[0,0,-1],"slot":0}
	check(m.connect_power(Vector3i(1,0,0),Vector3i.RIGHT,source,1),"Local wall wire turns around a 90 degree corner")
	check(m.powered_cells().has(Vector3i(1,0,0)),"Fuse box supplies the destination room")
	var cable: Dictionary=m.cables[-1]
	var route: PackedVector3Array=m.cable_points(cable)
	check(route.size()>3,"Wall cable follows surface borders instead of a diagonal chord")
	for cell in m.occupied(): check(not Cable.path_hits(route,Cable.bounds(cell)),"Routed cable clears every room")
	var node: Dictionary={"cell":[1,0,0],"normal":[1,0,0],"slot":1}
	check(m.connect_power(Vector3i(1,0,0),Vector3i.BACK,node,2),"Daisy chain turns a second corner")
	var saved: Dictionary=m.snapshot()
	check(m.move_power_node(node,Vector3i(1,0,0),Vector3i.RIGHT,0),"Move a socket and reroute its attached wires")
	check(m.cables[-1].source_slot==0,"Downstream branch follows the moved socket")
	var loaded=Model.new()
	check(loaded.load_state(JSON.parse_string(JSON.stringify(m.snapshot()))),"Quadrants and wall routes survive JSON save/load")
	check(m.undo() and m.snapshot()==saved,"One undo restores socket movement and its branch")
	check(m.remove_power_node(Vector3i.ZERO,Vector3i.FORWARD,0),"Delete exact quadrant")
	check(m.cables.size()==1 and not m.powered_cells().has(Vector3i(1,0,0)),"Deletion prunes only the selected transformer branch")
	for normal in Model.DIRECTIONS:
		var solo=Model.new(); solo.queue[0]={"shape":"cube","color":0}; solo.drop(0,0,0,false,0)
		var right:=Vector3i(-normal.z,0,normal.x)
		for from_slot in 4:
			for to_slot in 4:
				var points:=Cable.wall_route(Vector3i.ZERO,normal,from_slot,Vector3i.ZERO,right,to_slot,solo.occupied())
				check(points.size()>2 and not Cable.path_hits(points,Cable.bounds(Vector3i.ZERO)),"All corner orientations and quadrants route outside the wall")
	var inset: Dictionary={Vector3i.ZERO:0,Vector3i(1,0,0):1,Vector3i(0,0,1):2}
	var corner_path:=Cable.wall_route(Vector3i(1,0,0),Vector3i.BACK,1,Vector3i(0,0,1),Vector3i.RIGHT,0,inset)
	var length:=0.0
	for i in range(1,corner_path.size()): length+=corner_path[i-1].distance_to(corner_path[i])
	check(corner_path.size()>2 and length<1.0,"Inside corner takes the short wall bend, not a detour around the building")
	for cell in inset: check(not Cable.path_hits(corner_path,Cable.bounds(cell)),"Inset-corner wire clears both walls")
	print("Block City power distribution: ",failures," failures")
	quit(1 if failures else 0)
