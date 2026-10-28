extends RefCounted
## One architectural shell for placed rooms and placement previews.
const Lighting=preload("res://scripts/block_city/room_lighting.gd")
const Equipment=preload("res://scripts/block_city/power_equipment.gd")
const Model = preload("res://scripts/block_city/model.gd")

static func draw(game, parent: Node3D, room: Dictionary, view_mode: int, powered: Dictionary, reached: bool, room_set: Array = []) -> void:
	var role: String = game.model.room_role(room)
	if role=="pole":
		Equipment.pole(game,parent,Model.vec(room.cells[0]),Model.vec(room.normal))
		return
	var cells: Array = room.cells.map(func(raw): return Model.vec(raw))
	var network: Array=game.model.rooms if room_set.is_empty() else room_set
	if not room.has("id"):
		network=network.duplicate()
		var candidate: Dictionary=room.duplicate(true)
		candidate.id=network.size(); candidate.access_path=[]
		network.append(candidate)
	var color: Color=game.model.tint(room)
	var occ := {}
	for member in network:
		for raw in member.cells: occ[Model.vec(raw)]=int(member.id)
	var entries := {}
	for port in game.model.room_ports(room,network):
		var linked: bool=game.model.port_linked(room,port,network)
		if role!="hall" or linked:
			entries["%s:%s" % [port.cell,port.normal]]={"port":port,"connected":linked and reached,"linked":linked}
	var door_root := Node3D.new()
	door_root.name = "Door"
	parent.add_child(door_root)
	if role=="stairs":
		# Match the two ends of the U-turn: front-left below, front-right above.
		doormat(game,door_root,room,reached,-0.22,0.0,"Doormat",0.34)
		doormat(game,door_root,room,reached,0.22,1.0,"UpperDoormat",0.34)
	else:
		var index:=0
		for entry in entries.values():
			var doorway: Dictionary=room.duplicate()
			doorway.door=Model.arr(entry.port.cell); doorway.normal=Model.arr(entry.port.normal)
			doormat(game,door_root,doorway,entry.connected,0,0,"Doormat" if index==0 else "Doormat%d" % index)
			var mat: Node=door_root.get_child(door_root.get_child_count()-1)
			mat.set_meta("port_cell",entry.port.cell); mat.set_meta("port_normal",entry.port.normal)
			if game.ghost!=null and (game.ghost.is_ancestor_of(parent) or parent==game.ghost):
				if occ.has(entry.port.cell+entry.port.normal) and not entry.linked: mat.material_override.albedo_color=Color("d56e60")
			index+=1
	# A continuous threshold fills the seam between two connected rooms.
	for entry in entries.values():
		var other: Vector3i=entry.port.cell+entry.port.normal
		if entry.linked and occ.has(other) and int(room.get("id",-1))<int(occ[other]):
			var joint := Node3D.new()
			joint.name="ConnectionPoint"
			door_root.add_child(joint)
			var normal: Vector3=Vector3(entry.port.normal)
			var center:=Vector3(entry.port.cell)+Vector3(0.5,0.07,0.5)+normal*0.5
			var dimensions:=Vector3(0.54,0.06,0.22) if normal.z!=0 else Vector3(0.22,0.06,0.54)
			game.box(joint,center,dimensions,game.entry_color(entry.connected))
			var dot:=MeshInstance3D.new()
			var sphere:=SphereMesh.new()
			sphere.radius=0.055; sphere.height=0.11
			dot.mesh=sphere
			dot.position=center+Vector3.UP*0.08
			var material:=StandardMaterial3D.new()
			material.albedo_color=game.entry_color(entry.connected)
			dot.material_override=material
			joint.add_child(dot)
	var walls := Node3D.new()
	walls.name = "Walls"
	parent.add_child(walls)
	var floors := Node3D.new()
	floors.name = "Floors"
	parent.add_child(floors)
	var roofs := Node3D.new()
	roofs.name = "Roofs"
	parent.add_child(roofs)
	var rim := Node3D.new()
	rim.name = "RoofRim"
	parent.add_child(rim)
	for cell in cells:
		var floor_color := Model.CONCRETE_FLOOR
		var lower: Vector3i = cell+Vector3i.DOWN
		var hatch: bool = occ.has(lower) and game.model.room_role(network[int(occ[lower])])=="stairs"
		var cabin_here := false
		if role=="elevator":
			var stack:=elevator_stack(game,cell,network,room)
			cabin_here=stack.bottom
			elevator(game,parent,cell,stack.normal,color,view_mode,cabin_here,stack.top,stack.top and not occ.has(cell+Vector3i.UP))
		elif hatch:
			# Leave the flights and rear turn open, including headroom from below.
			# The landing meets the final tread at the storey plane, not above it.
			var opening := Node3D.new()
			opening.name="StairOpening"
			floors.add_child(opening)
			opening.position=Vector3(cell)+Vector3(0.5,0,0.5)
			var exit_normal := Model.vec(network[int(occ[lower])].normal)
			opening.rotation.y=atan2(-float(exit_normal.x),-float(exit_normal.z))
			for x in [-0.45,0.45]: game.box(opening,Vector3(x,-0.035,0),Vector3(0.06,0.07,0.96),floor_color)
			game.box(opening,Vector3(0,-0.035,-0.38),Vector3(0.84,0.07,0.20),floor_color)
		else:
			game.box(floors,Vector3(cell)+Vector3(0.5,0.035,0.5),Vector3(0.96,0.07,0.96),floor_color)
		if role=="hall" and not hatch:
			game.box(floors,Vector3(cell)+Vector3(0.5,0.075,0.5),Vector3(0.65,0.01,0.65),floor_color)
		if powered.has(cell) and view_mode>0:
			Lighting.interior(game,parent,cell,role,hatch)
		if view_mode==0 and (role=="room" or (role=="hall" and not occ.has(cell+Vector3i.UP))):
			# Full tile spans and one concrete material join adjacent roofs without seams.
			game.box(roofs,Vector3(cell)+Vector3(0.5,0.965,0.5),Vector3(1.0,0.07,1.0),Model.CONCRETE_FLOOR)
			if not occ.has(cell+Vector3i.UP): roof_rim(game,rim,cell,occ)
		for normal in Model.DIRECTIONS:
			if cells.has(cell+normal): continue
			var key: String="%s:%s" % [cell,normal]
			var entry: bool=entries.has(key)
			var adjacent: Vector3i=cell+normal
			var opening: bool=entry
			if role=="hall" and not opening: continue
			var connected: bool=entries[key].connected if entry else false
			var outside := not occ.has(adjacent)
			if role=="elevator" and entry:
				elevator_door(game,door_root,cell,normal,color,view_mode,game.entry_color(connected),cabin_here)
				continue
			if role=="stairs" and entry:
				for side in [-1,1]: wall_box(game,door_root,cell,normal,side*0.45,0.45,0.06,0.90,0.10,color)
				wall_box(game,door_root,cell,normal,-0.22,0.008 if hatch else 0.08,0.38,0.016,0.12,game.ACCESS)
				wall_box(game,door_root,cell,normal,0.22,1.0,0.38,0.025,0.12,game.ACCESS)
				continue
			wall(game,door_root if opening else walls,cell,normal,color,opening,outside and role=="room",view_mode,game.entry_color(connected),Lighting.UNLIT_GLASS,outside and role in ["room","hall"],role=="room" and not occ.has(cell+Vector3i.UP),powered.has(cell))
	if role=="hall":
		var supports := Node3D.new()
		supports.name="Supports"
		parent.add_child(supports)
		var minimum: Vector3i = cells[0]
		var maximum: Vector3i = cells[0]
		for cell in cells:
			minimum=minimum.min(cell); maximum=maximum.max(cell)
		for x in [minimum.x+0.07,maximum.x+0.93]:
			for z in [minimum.z+0.07,maximum.z+0.93]:
				game.box(supports,Vector3(x,minimum.y+0.5,z),Vector3(0.12,1.0,0.12),Model.CONCRETE_COLUMN)
	if role=="stairs":
		var base:=Model.vec(room.door)
		var covered: bool=occ.has(base+Vector3i.UP)
		stairs(game,parent,base,Model.vec(room.normal),color,covered)
		if view_mode==0 and not covered: stair_rooftop_access(game,parent,base,Model.vec(room.normal),color)

static func roof_rim(game, parent: Node3D, cell: Vector3i, occ: Dictionary) -> void:
	# Only the outer boundary gets a lip, never a divider between neighboring cells.
	for normal in Model.DIRECTIONS:
		if occ.has(cell+normal): continue
		var center:=Vector3(cell)+Vector3(0.5,1.045,0.5)+Vector3(normal)*0.47
		var size:=Vector3(0.06,0.09,1.0)
		if normal.z!=0:
			# Meet the perpendicular strips without overlapping coplanar corner faces.
			var left:=0.06 if not occ.has(cell+Vector3i.LEFT) else 0.0
			var right:=0.06 if not occ.has(cell+Vector3i.RIGHT) else 0.0
			size=Vector3(1.0-left-right,0.09,0.06)
			center.x+=(left-right)*0.5
		var edge: MeshInstance3D=game.box(parent,center,size,Model.STAIR_COLOR)
		edge.set_meta("cell",cell); edge.set_meta("normal",normal)
	# At an inset corner the two boundary strips belong to different cells.
	# Fill their shared inside corner so the rim remains continuous there too.
	for x in [-1,1]:
		for z in [-1,1]:
			if occ.has(cell+Vector3i(x,0,0)) and occ.has(cell+Vector3i(0,0,z)) and not occ.has(cell+Vector3i(x,0,z)):
				var corner: MeshInstance3D=game.box(parent,Vector3(cell)+Vector3(0.5+x*0.47,1.045,0.5+z*0.47),Vector3(0.06,0.09,0.06),Model.STAIR_COLOR)
				corner.set_meta("cell",cell); corner.set_meta("inset_corner",true)

static func doormat(game, parent: Node3D, room: Dictionary, reached: bool, across:=0.0, rise:=0.0, title:="Doormat", width:=0.50) -> void:
	var normal := Vector3(Model.vec(room.normal))
	var side := Vector3(-normal.z,0,normal.x)
	var size := Vector3(width,0.025,0.28) if normal.z!=0 else Vector3(0.28,0.025,width)
	var center := Vector3(Model.vec(room.door))+Vector3(0.5,0.08+rise,0.5)+normal*0.64+side*across
	var mat: MeshInstance3D = game.box(parent,center,size,game.entry_color(reached))
	mat.name=title
	# Ordinary depth-tested geometry: walls and upper floors hide concealed mats.

static func wall_box(game, parent: Node3D, cell: Vector3i, normal: Vector3i, across: float, y: float, width: float, height: float, depth: float, color: Color) -> MeshInstance3D:
	var side := Vector3(-normal.z,0,normal.x)
	var size := Vector3(width,height,depth) if normal.z!=0 else Vector3(depth,height,width)
	return game.box(parent,Vector3(cell)+Vector3(0.5,y,0.5)+Vector3(normal)*0.45+side*across,size,color)

static func wall(game, parent: Node3D, cell: Vector3i, normal: Vector3i, color: Color, door: bool, window: bool, mode: int, frame: Color, glass:=Color("8cb3bc"), facade:=false, top_storey:=false, powered:=false) -> void:
	var height := 0.24 if mode==2 else 0.90
	var ground:=facade and cell.y==0
	var crown:=facade and top_storey and cell.y>=0
	var aperture:=0.58 if ground and door else (0.62 if ground else (0.48 if crown and window else 0.44))
	if door:
		if ground:
			var pier:=(0.96-aperture)*0.5
			for side in [-1,1]:
				wall_box(game,parent,cell,normal,side*(aperture*0.5+pier*0.5),height/2,pier,height,0.10,color)
				# A broad painted surround, with the connection color as an inset edge.
				wall_box(game,parent,cell,normal,side*0.315,minf(0.86,height)*0.5,0.075,minf(0.86,height),0.15,color.lightened(0.22))
				wall_box(game,parent,cell,normal,side*0.283,minf(0.84,height)*0.5,0.025,minf(0.84,height),0.17,frame)
			if mode!=2:
				wall_box(game,parent,cell,normal,0,0.87,aperture,0.06,0.10,color)
				wall_box(game,parent,cell,normal,0,0.865,0.70,0.07,0.15,color.lightened(0.22))
				wall_box(game,parent,cell,normal,0,0.832,0.59,0.025,0.17,frame)
			wall_box(game,parent,cell,normal,0,0.04,aperture,0.035,0.17,frame)
		else:
			for side in [-1,1]:
				wall_box(game,parent,cell,normal,side*0.34,height/2,0.28,height,0.10,color)
				wall_box(game,parent,cell,normal,side*0.205,minf(0.72,height)/2,0.035,minf(0.72,height),0.12,frame)
			if mode!=2:
				wall_box(game,parent,cell,normal,0,0.815,0.40,0.17,0.10,color)
				wall_box(game,parent,cell,normal,0,0.715,0.44,0.035,0.12,frame)
			wall_box(game,parent,cell,normal,0,0.04,0.40,0.035,0.16,frame)
	elif window and mode!=2:
		var sill:=0.14 if ground else (0.32 if crown else 0.36)
		var head:=0.86 if ground else (0.76 if crown else 0.72)
		var pier:=(0.96-aperture)*0.5
		for side in [-1,1]: wall_box(game,parent,cell,normal,side*(aperture+ pier)*0.5,0.45,pier,0.90,0.10,color)
		wall_box(game,parent,cell,normal,0,sill*0.5,aperture,sill,0.10,color)
		wall_box(game,parent,cell,normal,0,(head+0.90)*0.5,aperture,0.90-head,0.10,color)
		var pane:=wall_box(game,parent,cell,normal,0,(sill+head)*0.5,aperture-0.02,head-sill-0.02,0.018,Lighting.WARM if powered else glass)
		pane.name="PoweredWindow" if powered else "Window"
		if powered: Lighting.glow(pane,0.85)
		wall_box(game,parent,cell,normal,0,sill,aperture+0.04,0.035,0.14,color.lightened(0.3))
		if ground or crown:
			for side in [-1,1]: wall_box(game,parent,cell,normal,side*aperture*0.5,(sill+head)*0.5,0.025,head-sill,0.12,color.lightened(0.18))
			wall_box(game,parent,cell,normal,0,head,aperture+0.04,0.035,0.14,color.lightened(0.20))
	else:
		wall_box(game,parent,cell,normal,0,height/2,0.96,height,0.10,color)
	if ground:
		# Smooth plaster relief: a low plinth and shallow horizontal courses
		# on the piers, with no stone blocks, texture, or bars across openings.
		for y in [0.045,0.115]:
			if door:
				for side in [-1,1]: wall_box(game,parent,cell,normal,side*0.40,y,0.16,0.06 if y<0.1 else 0.025,0.16,color.lightened(0.08))
			else: wall_box(game,parent,cell,normal,0,y,0.98,0.06 if y<0.1 else 0.025,0.16,color.lightened(0.08))
		if mode!=2:
			for y in [0.30,0.50,0.70]:
				for side in [-1,1]: wall_box(game,parent,cell,normal,side*0.415,y,0.12,0.025,0.125,color.lightened(0.07))
			if not crown: wall_box(game,parent,cell,normal,0,0.915,0.98,0.03,0.14,color.lightened(0.16))
	if crown and mode!=2:
		wall_box(game,parent,cell,normal,0,0.90,0.98,0.035,0.14,color.lightened(0.10))
		wall_box(game,parent,cell,normal,0,0.965,1.0,0.06,0.16,color.lightened(0.22))

static func stair_points() -> Array:
	# Local coordinates: enter at front-left, turn on the rear landing,
	# and exit at front-right exactly one level above the entrance.
	return [Vector3(-0.22,0,-0.38),Vector3(-0.22,0.5,0.30),Vector3(0.22,0.5,0.30),Vector3(0.22,1,-0.38)]

static func stairs(game, parent: Node3D, cell: Vector3i, normal: Vector3i, color: Color, covered := false) -> void:
	var flight := Node3D.new()
	flight.name = "Staircase"
	parent.add_child(flight)
	flight.position = Vector3(cell)+Vector3(0.5,0,0.5)
	flight.rotation.y = atan2(-float(normal.x),-float(normal.z))
	if covered:
		# Match the hall's corner supports and meet the next floor exactly.
		# Keep the center clear for both flights and their transfer landings.
		for x in [-0.43,0.43]:
			for z in [-0.43,0.43]:
				var pillar: MeshInstance3D=game.box(flight,Vector3(x,0.5,z),Vector3(0.12,1.0,0.12),Model.CONCRETE_COLUMN)
				pillar.name="CornerPillar"
	var tread := Model.CONCRETE_FLOOR
	# Slender concrete treads, not columns filled down to the base. Repeating
	# this module one storey above leaves the full flight passage open below it.
	var thickness := 0.06
	for i in 5:
		var h := float(i+1)*0.1
		game.box(flight,Vector3(-0.22,h-thickness/2,-0.236+i*0.088),Vector3(0.38,thickness,0.088),tread)
		game.box(flight,Vector3(-0.22,h+0.008,-0.2675+i*0.088),Vector3(0.38,0.016,0.025),game.ACCESS)
	var turn: MeshInstance3D=game.box(flight,Vector3(0,0.5-thickness/2,0.30),Vector3(0.82,thickness,0.28),tread)
	turn.name="TurnLanding"
	for i in 5:
		var h := 0.6+float(i)*0.1
		game.box(flight,Vector3(0.22,h-thickness/2,0.116-i*0.088),Vector3(0.38,thickness,0.088),tread)
		game.box(flight,Vector3(0.22,h+0.008,0.1475-i*0.088),Vector3(0.38,0.016,0.025),game.ACCESS)
	# A full-width front landing joins this exit to the next stair's entrance.
	# Keep the divider behind it so people can cross between the two flights.
	var landing: MeshInstance3D=game.box(flight,Vector3(0,1-thickness/2,-0.38),Vector3(0.82,thickness,0.20),tread)
	landing.name="ExitLanding"
	game.box(flight,Vector3(0,0.34,-0.03),Vector3(0.04,0.68,0.42),color.darkened(0.12))

static func stair_rooftop_access(game, parent: Node3D, cell: Vector3i, normal: Vector3i, color: Color) -> void:
	var hut:=Node3D.new()
	hut.name="RooftopAccess"
	parent.add_child(hut)
	hut.position=Vector3(cell)+Vector3(0.5,0,0.5)
	hut.rotation.y=atan2(-float(normal.x),-float(normal.z))
	# The taller half sits over the returning flight, offset toward its exit.
	# A low covered shoulder seals the other half without closing its headroom.
	game.box(hut,Vector3(-0.24,1.23,0),Vector3(0.50,0.06,0.98),color)
	game.box(hut,Vector3(-0.45,1.05,0),Vector3(0.08,0.30,0.96),color)
	for z in [-0.45,0.45]: game.box(hut,Vector3(-0.24,1.05,z),Vector3(0.50,0.30,0.08),color)
	game.box(hut,Vector3(0,1.51,0),Vector3(0.06,0.50,0.96),color)
	game.box(hut,Vector3(0.45,1.33,0),Vector3(0.08,0.86,0.96),color)
	game.box(hut,Vector3(0.24,1.33,0.45),Vector3(0.50,0.86,0.08),color)
	var cap: MeshInstance3D=game.box(hut,Vector3(0.24,1.80,0),Vector3(0.54,0.08,1.02),color.lightened(0.14))
	cap.name="WeatherCap"
	# Small framed doorway and raised sill; no solid infill across the exit.
	for x in [0.025,0.415]: game.box(hut,Vector3(x,1.35,-0.45),Vector3(0.07,0.70,0.10),color.lightened(0.18))
	game.box(hut,Vector3(0.22,1.735,-0.45),Vector3(0.46,0.05,0.12),color.lightened(0.18))
	game.box(hut,Vector3(0.22,1.015,-0.46),Vector3(0.34,0.03,0.16),color.lightened(0.28))
	var hinge:=Node3D.new()
	hinge.name="MiniDoor"
	hut.add_child(hinge)
	hinge.position=Vector3(0.06,1.03,-0.49)
	hinge.rotation.y=deg_to_rad(80)
	game.box(hinge,Vector3(0.16,0.32,0),Vector3(0.32,0.64,0.035),color.darkened(0.18))
	game.box(hinge,Vector3(0.27,0.32,-0.03),Vector3(0.035,0.025,0.04),game.INK)

static func elevator(game, parent: Node3D, cell: Vector3i, normal: Vector3i, color: Color, mode: int, cabin_here: bool, counterweight_here: bool, machinery_here: bool) -> void:
	var shaft := Node3D.new()
	shaft.name="ElevatorShaft"
	parent.add_child(shaft)
	shaft.position=Vector3(cell)+Vector3(0.5,0,0.5)
	shaft.rotation.y=atan2(-float(normal.x),-float(normal.z))
	# Open storey ring: aligned sections retain continuous headroom.
	for x in [-0.41,0.41]:
		game.box(shaft,Vector3(x,0.035,0),Vector3(0.12,0.07,0.94),Model.CONCRETE_FLOOR)
	for z in [-0.41,0.41]:
		game.box(shaft,Vector3(0,0.035,z),Vector3(0.70,0.07,0.12),Model.CONCRETE_FLOOR)
	# The central suspension starts at the cabin roof, never through its floor.
	var start:=0.80 if cabin_here else 0.0
	var hoist: MeshInstance3D=game.box(shaft,Vector3(0,(start+1.0)*0.5,0),Vector3(0.025,1.0-start,0.025),game.INK)
	hoist.name="HoistCable"
	if counterweight_here:
		# One weight per continuous shaft, raised while the cabin rests below.
		# Its rope ends at the weight's top (0.55 + 0.50/2), not below it.
		var rear: MeshInstance3D=game.box(shaft,Vector3(0,0.90,0.36),Vector3(0.025,0.20,0.025),game.INK)
		rear.name="CounterweightCable"
		var weight: MeshInstance3D=game.box(shaft,Vector3(0,0.55,0.36),Vector3(0.28,0.50,0.055),Model.STAIR_COLOR)
		weight.name="Counterweight"
	if cabin_here: elevator_cabin(game,shaft,color,mode)
	if machinery_here: elevator_machine_room(game,shaft,color,mode)

static func elevator_machine_room(game, shaft: Node3D, color: Color, mode: int) -> void:
	var housing:=Node3D.new()
	housing.name="MachineRoom"
	shaft.add_child(housing)
	if mode==0:
		# Seal the exposed shaft around the narrower enclosure, leaving rope holes.
		var apron:=Node3D.new(); apron.name="RoofApron"; housing.add_child(apron)
		for x in [-0.27,0.27]: game.box(apron,Vector3(x,0.97,0),Vector3(0.46,0.06,1.0),Model.CONCRETE_FLOOR)
		for strip in [[-0.27,0.46],[0.18,0.28],[0.45,0.10]]:
			game.box(apron,Vector3(0,0.97,strip[0]),Vector3(0.08,0.06,strip[1]),Model.CONCRETE_FLOOR)
	# Compact headhouse: half the former height, narrower in both plan axes.
	# Keep its base at the shaft top and preserve the two suspension penetrations.
	for x in [-0.17,0.17]: game.box(housing,Vector3(x,1.02,0.06),Vector3(0.26,0.04,0.76),Model.CONCRETE_FLOOR)
	for strip in [[-0.18,0.28],[0.18,0.28],[0.42,0.08]]:
		game.box(housing,Vector3(0,1.02,strip[0]),Vector3(0.08,0.04,strip[1]),Model.CONCRETE_FLOOR)
	var height:=0.10 if mode==2 else 0.34
	for x in [-0.30,0.30]: game.box(housing,Vector3(x,1.04+height*0.5,0.06),Vector3(0.06,height,0.78),color)
	game.box(housing,Vector3(0,1.04+height*0.5,0.42),Vector3(0.54,height,0.06),color)
	for side in [-1,1]:
		game.box(housing,Vector3(side*0.225,1.04+height*0.5,-0.30),Vector3(0.21,height,0.06),color)
		game.box(housing,Vector3(side*0.135,1.04+minf(height,0.30)*0.5,-0.315),Vector3(0.03,minf(height,0.30),0.08),color.lightened(0.22))
	if mode!=2:
		game.box(housing,Vector3(0,1.36,-0.30),Vector3(0.30,0.04,0.08),color.lightened(0.22))
	var door:=Node3D.new()
	door.name="ServiceDoor"
	housing.add_child(door)
	door.position=Vector3(-0.12,1.04,-0.345); door.rotation.y=deg_to_rad(80)
	var door_height:=0.085 if mode==2 else 0.29
	game.box(door,Vector3(0.12,door_height*0.5,0),Vector3(0.24,door_height,0.025),color.darkened(0.18))
	game.box(door,Vector3(0.20,door_height*0.5,-0.02),Vector3(0.025,0.018,0.03),game.INK)
	if mode==0:
		var roof: MeshInstance3D=game.box(housing,Vector3(0,1.40,0.06),Vector3(0.70,0.04,0.84),color.lightened(0.15))
		roof.name="WeatherCap"
	game.box(housing,Vector3(-0.07,1.06,0.18),Vector3(0.40,0.03,0.18),color.darkened(0.08))
	var motor: MeshInstance3D=game.box(housing,Vector3(-0.17,1.20,0.18),Vector3(0.16,0.14,0.18),Color("849593"))
	motor.name="Motor"
	game.box(housing,Vector3(-0.17,1.11,0.18),Vector3(0.14,0.07,0.16),game.INK)
	game.beam(housing,Vector3(-0.17,1.22,0.18),Vector3(0.08,1.22,0.18),game.INK,0.025)
	var drum:=MeshInstance3D.new()
	drum.name="CableDrum"
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=0.11; cylinder.bottom_radius=0.11; cylinder.height=0.10; cylinder.radial_segments=24
	drum.mesh=cylinder; drum.material_override=game.material(Color("617570"))
	drum.position=Vector3(0,1.22,0.18); drum.rotation.z=PI*0.5
	housing.add_child(drum)
	# Short guides meet the unchanged shaft ropes before the smaller round drum.
	for pair in [[0.0,0.06],[0.36,0.30]]:
		game.beam(housing,Vector3(0,1,pair[0]),Vector3(0,1.06,pair[0]),game.INK,0.0125)
		game.beam(housing,Vector3(0,1.06,pair[0]),Vector3(0,1.12,pair[1]),game.INK,0.0125)
		game.beam(housing,Vector3(0,1.12,pair[1]),Vector3(0,1.22,pair[1]),game.INK,0.0125)
	for step in 12:
		var a: float=PI*step/12.0; var b: float=PI*(step+1)/12.0
		game.beam(housing,Vector3(0,1.22+sin(a)*0.12,0.18+cos(a)*0.12),Vector3(0,1.22+sin(b)*0.12,0.18+cos(b)*0.12),game.INK,0.0125)

static func elevator_stack(game, cell: Vector3i, network: Array, drawn_room: Dictionary) -> Dictionary:
	var sections: Dictionary={}
	for other in network:
		if other.get("id",-2)==drawn_room.get("id",-1): continue
		if game.model.room_role(other)=="elevator":
			for raw in other.cells: sections[Model.vec(raw)]=other
	# Invalid move previews still render their proposed shaft, not the source.
	for raw in drawn_room.cells: sections[Model.vec(raw)]=drawn_room
	var bottom:=cell
	while sections.has(bottom+Vector3i.DOWN): bottom+=Vector3i.DOWN
	# Landing doors may rotate independently; the suspension stays aligned
	# with the bottom cabin throughout the uninterrupted shaft.
	return {"normal":Model.vec(sections[bottom].normal),"bottom":bottom==cell,"top":not sections.has(cell+Vector3i.UP)}

static func elevator_cabin(game, shaft: Node3D, color: Color, mode: int) -> void:
	var cabin := Node3D.new()
	cabin.name="ElevatorCabin"
	shaft.add_child(cabin)
	var lining := Color("e5e4d8")
	var height := 0.20 if mode==2 else 0.64
	var floor_mesh: MeshInstance3D=game.box(cabin,Vector3(0,0.09,0),Vector3(0.64,0.06,0.64),Model.CONCRETE_FLOOR)
	floor_mesh.name="CabPlatform"
	for x in [-0.30,0.30]:
		game.box(cabin,Vector3(x,0.12+height/2,0),Vector3(0.04,height,0.64),lining)
	game.box(cabin,Vector3(0,0.12+height/2,0.30),Vector3(0.56,height,0.04),lining.darkened(0.12))
	# Handrails and a small control panel make the resting car readable.
	if mode!=2:
		game.box(cabin,Vector3(0,0.43,0.266),Vector3(0.48,0.025,0.025),game.INK)
		for x in [-0.266,0.266]: game.box(cabin,Vector3(x,0.43,0),Vector3(0.025,0.025,0.48),game.INK)
		game.box(cabin,Vector3(0.271,0.48,-0.20),Vector3(0.018,0.14,0.065),game.INK)
		for y in [0.45,0.49,0.53]: game.box(cabin,Vector3(0.259,y,-0.20),Vector3(0.008,0.018,0.02),game.ACCESS)
	if mode==0: game.box(cabin,Vector3(0,0.78,0),Vector3(0.64,0.04,0.64),lining)
	game.box(cabin,Vector3(0,0.125,-0.30),Vector3(0.60,0.02,0.035),game.ACCESS)

static func elevator_door(game, parent: Node3D, cell: Vector3i, normal: Vector3i, color: Color, mode: int, frame: Color, cabin_here: bool) -> void:
	var doorway := Node3D.new()
	doorway.name="ElevatorDoor"
	doorway.set_meta("floor_cell",cell)
	doorway.set_meta("cabin_here",cabin_here)
	parent.add_child(doorway)
	var height := 0.24 if mode==2 else 0.90
	for side in [-1,1]:
		wall_box(game,doorway,cell,normal,side*0.39,height/2,0.18,height,0.10,color)
		wall_box(game,doorway,cell,normal,side*0.305,minf(0.74,height)/2,0.035,minf(0.74,height),0.12,frame)
	if mode!=2:
		wall_box(game,doorway,cell,normal,0,0.83,0.60,0.14,0.10,color)
		wall_box(game,doorway,cell,normal,0,0.745,0.64,0.035,0.12,frame)
	wall_box(game,doorway,cell,normal,0,0.07,0.60,0.025,0.24,frame)
	# Open doors reveal the parked car. Other floors keep their safety doors
	# shut while retaining their explicit access point in the construction graph.
	var leaves := Node3D.new()
	leaves.name="SlidingDoors"
	doorway.add_child(leaves)
	var leaf_height := 0.16 if mode==2 else 0.65
	for side in [-1,1]:
		wall_box(game,leaves,cell,normal,side*(0.41 if cabin_here else 0.147),0.09+leaf_height/2,0.16 if cabin_here else 0.28,leaf_height,0.035,Color("849593"))
	wall_box(game,doorway,cell,normal,0.40,0.43 if mode!=2 else 0.16,0.065,0.12,0.14,game.INK)
	wall_box(game,doorway,cell,normal,0.40,0.44 if mode!=2 else 0.17,0.025,0.025,0.16,game.ACCESS)
