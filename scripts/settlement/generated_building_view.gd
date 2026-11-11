extends RefCounted
const View = preload("res://scripts/settlement/modular_house_view.gd")
const Rules = preload("res://scripts/settlement/modular_house_rules.gd")
const Generator = preload("res://scripts/settlement/modular_house_generator.gd")
const Rooms = preload("res://scripts/settlement/room_construction.gd")

static func draw(parent: Node3D, room: Dictionary, model, network: Array, town=null) -> Node3D:
	var node := Node3D.new(); parent.add_child(node)
	var cell := Vector3(Rooms.Layout.vec(room.cells[0]))
	node.position = cell; node.scale = Vector3.ONE * 0.5
	node.set_meta("exemplar_state",room.generated.exemplar)
	node.set_meta("detailed",true)
	if room.shape == "cube":
		var hole := AABB()
		if town!=null:
			var utilities=load("res://scripts/settlement/room_utilities.gd")
			for owner in utilities.states(town):
				var source: Dictionary=utilities.room(town,owner)
				if Rooms.Layout.vec(source.cells[0])+Vector3i.UP!=Vector3i(cell): continue
				var center: Vector3=utilities.chimney(town,owner)[0]-Vector3(Rooms.base(town,Vector3i(cell)))+Vector3(0.5,0,0.5)
				hole=AABB(Vector3(center.x-0.38,-1,center.z-0.38),Vector3(0.76,3,0.76))
		View.deck(node,Rect2(0,0,2,2),0,hole)
		for direction in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			if network.any(func(other):return other.cells.has(Rooms.Layout.arr(Vector3i(cell)+direction))): continue
			if model.room_ports(room,network).any(func(port):return port.normal==direction and model.port_linked(room,port,network)): continue
			var center := Vector3(1,0,1)+Vector3(direction)
			var tangent := Vector3(-direction.z,0,direction.x)
			View.rail(node,center-tangent,center+tangent)
		return node
	var generated := Generator.generate(Rules.layout(room.generated.seed),room.generated.seed,0)
	var profile: Dictionary = generated.rooms[room.generated.source].duplicate(true)
	profile.gutter=false
	var origin: Vector3 = profile.record.origin
	# Follow the live model's reciprocal doors after rotation, moving or grouping.
	var ports: Array = model.room_ports(room,network)
	for wall in profile.walls:
		var local_normal: Vector3i = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK][wall.side]
		var normal := Rooms.Layout.rotate_point(local_normal,room.generated.yaw)
		var matching := ports.filter(func(port):return port.normal == normal)
		if not matching.is_empty():
			wall.opening = "door"
			wall.offset = float(matching[0].get("across",0)) * 2 * (-local_normal.x if local_normal.x else -local_normal.z)
			wall.width = 0.76 if matching[0].has("across") else 0.84
		elif wall.opening == "door": wall.opening = ""
	var geometry := Node3D.new(); node.add_child(geometry)
	geometry.rotation.y = -room.generated.yaw * PI / 2
	# Rotate around the room center, retaining exact cell-space placement.
	geometry.position = Vector3.ONE * 0; geometry.position = Vector3(1,0,1)-geometry.basis*(origin+Vector3(1,0,1))
	View.room(geometry,profile,0,1,false)
	return node

static func stair_supports(parent: Node3D, room: Dictionary) -> void:
	var node := Node3D.new(); parent.add_child(node)
	node.position=Vector3(Rooms.Layout.vec(room.cells[0]))+Vector3(0.5,0,0.5)
	node.scale=Vector3.ONE*0.5
	var normal := Rooms.Layout.vec(room.normal)
	node.rotation.y=atan2(-float(normal.x),-float(normal.z))
	# Match the existing two-flight stair's actual treads and turning landing.
	for x in [-0.9,0.9]:
		View.Frame.log_member(node,"LandingPost",Vector3(x,0,0.8),Vector3(x,0.95,0.8))
	for x in [-0.86,-0.14]:
		View.Frame.log_member(node,"Stringer",Vector3(x,0,-1),Vector3(x,0.95,0))
	for x in [0.14,0.86]:
		View.Frame.log_member(node,"Stringer",Vector3(x,0.95,0),Vector3(x,1.95,-1))
	View.Frame.log_member(node,"LandingBeam",Vector3(-0.9,0.9,0.8),Vector3(0.9,0.9,0.8))
