extends Node3D
## Rebuild plumbing only when topology changes; animate fuel, flames and water in place.
const U = preload("res://scripts/settlement/room_utilities.gd")
const V = preload("res://scripts/settlement/modular_house_view.gd")
const P = preload("res://scripts/game_palette.gd")
var stamp: Array=[]
var geometry := Node3D.new()
var targets: Array=[]
var lamp_nodes := {}
var water_nodes := {}
var smoke_nodes := {}
var world
func _init() -> void: add_child(geometry)
func sync(model, pixels_per_metre: float) -> void:
	world=model
	var next: Array=[model.get_instance_id_for_source() if model.has_method("get_instance_id_for_source") else model.get_instance_id(),model.room_site.get("built",[]),U.geometry_key(model)]
	if next!=stamp:
		stamp=next.duplicate(true); rebuild()
	V.Exemplars.detail(geometry,pixels_per_metre)
	for key in lamp_nodes:
		var brightness := U.brightness(world,key.x,key.y)
		V.set_power(lamp_nodes[key],brightness)
		for item in lamp_nodes[key]:
			if item is OmniLight3D: item.shadow_enabled=pixels_per_metre>35
	for owner in smoke_nodes:
		var service := U.state(world,owner)
		var lit: bool= U.supply(world,owner) and service.lamps.values().any(func(lamp):return lamp.connected)
		for i in smoke_nodes[owner].size():
			var puff: Node3D=smoke_nodes[owner][i]
			puff.visible=lit
			puff.position=U.chimney(world,owner).back()+Vector3(sin(world.time+i)*0.025,fmod(world.time*0.22+i*0.14,0.85),0)
	for owner in water_nodes:
		var inventory=world.Hydrology.inventory_at(world,U.barrel_cell(world,owner))
		if inventory==null: continue
		var parts: Dictionary=water_nodes[owner]
		parts.level.visible=inventory.count("water")>0
		parts.level.position.y=U.barrel_position(world,owner).y+0.08+0.56*float(inventory.count("water"))/U.CAPACITY
		var flow: bool=world.weather.raining and U.state(world,owner).rain_connected
		parts.drop.visible=flow
		parts.drop.position=U.barrel_position(world,owner)+Vector3(0,0.72+fmod(-world.time*0.7,0.20),0)
func target(at: Vector3, owner: int, uid: int, action: String, radius := 0.24) -> void:
	targets.append({"box":AABB(at-Vector3.ONE*radius,Vector3.ONE*radius*2),"owner":owner,"uid":uid,"action":action})
func line(root: Node3D, points: Array, radius: float, color: Color) -> void:
	for i in range(1,points.size()):
		if points[i-1].distance_to(points[i])>0.005: V.Draw.beam(root,points[i-1],points[i],radius,color)
func rebuild() -> void:
	for child in geometry.get_children(): child.free()
	targets.clear(); lamp_nodes.clear(); water_nodes.clear(); smoke_nodes.clear()
	for entry in world.room_site.get("built",[]):
		if not entry.has("generated") or (entry.generated.source!=0 and not U.states(world).has(entry.uid)): continue
		var owner: int=entry.uid
		var service := U.state(world,owner)
		if service.is_empty():
			if not entry.has("home_cell"): target(U.pose(world,entry)*Vector3(1,1,1),owner,owner,"install",0.8)
			continue
		if service.stove:
			var root := Node3D.new(); geometry.add_child(root); root.transform=U.pose(world,entry)
			root.set_meta("exemplar_state",entry.generated.exemplar)
			V.brick_stack(root,Vector3(1.35,0,0.35),14,"town-stove-flue")
			V.box(root,Vector3(0.28,0.2,0.035),Vector3(1.35,0.36,0.71),P.HOME_DOORWAY)
			# Ceramic gas take-off is distinct from the broad exhaust chimney.
			line(root,[Vector3(1.35,0.75,0.35),Vector3(1.75,0.75,0.35),Vector3(1.75,1.78,0.15)],0.045,V.Resources.colour("pottery"))
			var end: Vector3=U.chimney(world,owner).back()
			target(end,owner,owner,"fuel",0.4)
			var puffs: Array=[]
			for i in 6:
				var puff := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius=0.045+i*0.009; mesh.height=mesh.radius*2
				mesh.radial_segments=6; mesh.rings=3; puff.mesh=mesh; puff.material_override=V.Draw.material(P.LIMESTONE_SIDE); geometry.add_child(puff); puffs.append(puff)
			smoke_nodes[owner]=puffs
		for uid in service.lamps:
			var host := U.room(world,uid,true)
			if host.is_empty(): continue
			var transform := U.pose(world,host)
			var root := Node3D.new(); geometry.add_child(root); root.set_meta("room_level",U.pose(world,host).origin.y)
			# Ceramic lamps: no unaccounted metal frames or electrical equipment.
			var at := transform*Vector3(1.7,1.55,2.12)
			V.bulb(root,at,2.6,3.0)
			for y in [-0.13,0.13]: V.box(root,Vector3(0.20,0.045,0.20),at+Vector3.UP*y,V.Resources.colour("pottery"))
			var ceiling := Node3D.new(); ceiling.set_meta("ceiling_fixture",true); root.add_child(ceiling)
			V.bulb(ceiling,transform*Vector3(1,1.63,1),2.8,2.8)
			var burner := transform*Vector3(1,1.75,1)
			V.box(ceiling,Vector3(0.16,0.06,0.16),burner,V.Resources.colour("pottery"))
			line(ceiling,[transform*Vector3(1.75,1.78,0.15),burner,transform*Vector3(1.7,1.78,2.12),at],0.025,V.Resources.colour("pottery"))
			var items: Array=[]
			for item in root.find_children("*","",true,false):
				if item is OmniLight3D or item.has_meta("powered_glow"): items.append(item)
			lamp_nodes[Vector2i(owner,uid)]=items
			var valve := at+Vector3.DOWN*0.25
			var handle := V.box(root,Vector3(0.16,0.055,0.06),valve,V.Resources.colour("pottery"))
			handle.rotation.z=0 if service.lamps[uid].connected else PI/2
			target(valve,owner,uid,"gas")
			if service.lamps[uid].pipe:
				var points := U.gas_path(world,owner,uid)
				if not service.lamps[uid].connected: points[-1]=points[-1].lerp(points[-2],0.08)
				line(root,points,0.035,V.Resources.colour("pottery"))
		if service.rain:
			for drain in U.drains(world,owner):
				var host := U.room(world,drain.uid,true)
				var root := Node3D.new(); geometry.add_child(root); root.transform=U.pose(world,host)
				var profile: Dictionary=host.home_profile if host.has("home_cell") else U.Generator.generate(U.Rules.layout(host.generated.seed),host.generated.seed,1).rooms[host.generated.source]
				if drain.roofed: V.roof_gutter(root,profile)
				else:
					for side in [-1,1]: V.box(root,Vector3(0.035,0.10,2.6),Vector3(drain.local_x+side*0.09,drain.local_y,1),V.Resources.colour("pottery"))
					V.box(root,Vector3(0.21,0.035,2.6),Vector3(drain.local_x,drain.local_y-0.05,1),V.Resources.colour("pottery"))
				var points: Array=drain.path.duplicate()
				if not service.rain_connected: points.pop_back()
				line(geometry,points,0.065,V.Resources.colour("pottery"))
			barrel(owner)
	V.Exemplars.consolidate(geometry)
	V.paint(geometry)
func barrel(owner: int) -> void:
	var at := U.barrel_position(world,owner)
	var root := Node3D.new(); geometry.add_child(root)
	# Fitted staves and floor consume twelve stock planks; rope holds the vessel.
	for i in 12:
		var angle := i*TAU/12
		var board := V.box(root,Vector3(0.16,0.7,0.05),at+Vector3(sin(angle)*0.30,0.35,cos(angle)*0.30),V.Wood.WOOD[0]); board.rotation.y=angle
	V.box(root,Vector3(0.52,0.055,0.52),at+Vector3.UP*0.04,V.Wood.WOOD[0])
	for y in [0.12,0.58]:
		var ring := MeshInstance3D.new(); var torus := TorusMesh.new(); torus.inner_radius=0.31; torus.outer_radius=0.335; torus.rings=12; torus.ring_segments=4
		ring.mesh=torus; ring.position=at+Vector3.UP*y; ring.material_override=V.Draw.material(V.Resources.colour("rope")); root.add_child(ring)
	var level := MeshInstance3D.new(); var disk := CylinderMesh.new(); disk.top_radius=0.28; disk.bottom_radius=0.28; disk.height=0.025; disk.radial_segments=12
	level.mesh=disk; level.position=at; level.material_override=V.Draw.material(P.WATER_BLUE); root.add_child(level)
	var drop := V.box(root,Vector3(0.05,0.12,0.05),at+Vector3.UP*0.8,P.WATER_BLUE)
	water_nodes[owner]={"level":level,"drop":drop}
	target(at+Vector3.UP*0.3,owner,owner,"collect",0.37)
	var tap := at+Vector3(0.12,1.02,0)
	V.box(root,Vector3(0.18,0.10,0.18),tap,V.Resources.colour("pottery")); target(tap,owner,owner,"rain",0.18)
func hit(origin: Vector3, direction: Vector3) -> Dictionary:
	var nearest := {}; var distance := INF
	for item in targets:
		var point: Variant=item.box.intersects_ray(origin,direction)
		if point is Vector3 and origin.distance_to(point)<distance:
			distance=origin.distance_to(point); nearest=item
	return nearest
func label_for(item: Dictionary) -> String:
	var owner: int=item.owner; var uid: int=item.uid; var service := U.state(world,owner)
	match str(item.action):
		"install": return "Fit utilities: "+U.cost_text(U.installation_cost(world,owner))
		"fuel": return ""
		"gas":
			var lamp: Dictionary=service.lamps[uid]
			return ("Gas: Disconnect" if lamp.connected else "Gas: Connect") if lamp.pipe else "Gas: "+U.cost_text(U.recipe(world,owner,uid,"gas"))
		"collect":
			var inventory=world.Hydrology.inventory_at(world,U.barrel_cell(world,owner))
			return "Water: %d / %d: Collect" % [inventory.count("water"),inventory.capacity]
		"rain": return "Drain: Disconnect" if service.rain_connected else "Drain: Connect"
	return ""
func activate(item: Dictionary) -> void:
	match str(item.action):
		"install": U.install(world,item.owner)
		"fuel": U.request(world,item.owner,item.owner,"fuel")
		"gas": U.toggle_gas(world,item.owner,item.uid)
		"collect": world.request_collect_water(U.barrel_cell(world,item.owner))
		"rain":
			var service := U.state(world,item.owner); service.rain_connected=not service.rain_connected; world.revision+=1

func set_cutaway(level: float, interiors := false) -> void:
	for node in geometry.find_children("*","Node3D",true,false):
		if node.has_meta("room_level"): node.visible=float(node.get_meta("room_level"))<=level
		if node.has_meta("ceiling_fixture"): node.visible=not interiors
