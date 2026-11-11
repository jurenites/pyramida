extends RefCounted
## Town-owned fuel, gas and rain connections. Builders install and deliver every input.
const Rooms = preload("res://scripts/settlement/room_construction.gd")
const Generator = preload("res://scripts/settlement/modular_house_generator.gd")
const Rules = preload("res://scripts/settlement/modular_house_rules.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
const CHARGE := 35.0
const FUEL_SECONDS := 120.0
const CAPACITY := 2
static var drain_cache := {}
const ACTIONS := ["stove","lamp","gas","rain","fuel"]

static func room(world, uid: int, built := false) -> Dictionary:
	for entry in world.room_site.get("built" if built else "design",[]):
		if entry.uid==uid: return entry
	return {}
static func states(world) -> Dictionary:
	return world.utility_states() if world.has_method("utility_states") else world.room_site.get("utilities",{})
static func state(world, owner: int) -> Dictionary: return states(world).get(owner,{})
static func owner_for(world, target: Dictionary) -> int:
	for entry in world.room_site.get("design",[]):
		if entry.building_id==target.building_id and entry.get("generated",{}).get("source",-1)==0: return entry.uid
	return -1
static func pose(world, entry: Dictionary) -> Transform3D:
	if entry.has("home_cell"):
		var basis:=Basis(Vector3.UP,preload("res://scripts/settlement/home_pose.gd").angle(world,entry.home_cell))
		return Transform3D(basis,Vector3(entry.home_cell)+entry.home_offset-basis*Vector3(1,0,1))
	var basis := Basis(Vector3.UP,-int(entry.generated.yaw)*PI/2)
	return Transform3D(basis,Vector3(Rooms.base(world,Rooms.Layout.vec(entry.cells[0])))-Vector3(0.5,0,0.5)+Vector3(1,0,1)-basis*Vector3(1,0,1))
static func barrel_cell(world, owner: int) -> Vector3i:
	var entry := room(world,owner)
	if entry.has("home_cell"):
		if state(world,owner).has("barrel_cell"): return state(world,owner).barrel_cell
		for direction in [Vector3i.BACK,Vector3i.LEFT,Vector3i.FORWARD,Vector3i.RIGHT]:
			var candidate: Vector3i=entry.home_cell+direction*2
			var doors=preload("res://scripts/settlement/house_groups.gd").SIDES
			if world.buildings.keys().any(func(at):return world.buildings[at].kind=="house" and at+doors[world.buildings[at].direction]*2==candidate): continue
			if world.ground.has(candidate) and not world.buildings.has(candidate) and not world.stores.has(candidate) and not world.water_sources.has(candidate): return candidate
		return entry.home_cell+Vector3i.BACK*2
	return Rooms.base(world,Rooms.Layout.vec(entry.cells[0]))+Rooms.Layout.rotate_point(Vector3i(0,0,2),entry.generated.yaw)
static func barrel_position(world, owner: int) -> Vector3:
	return Vector3(barrel_cell(world,owner))+Vector3(0,0.02,0)
static func chimney(world, owner: int) -> Array[Vector3]:
	var transform := pose(world,room(world,owner))
	return [transform*Vector3(1.35,0.8,0.35),transform*Vector3(1.35,2.8,0.35)]
static func blocked(world, owner: int) -> bool:
	var points := chimney(world,owner)
	for entry in world.room_site.get("built",[]):
		if entry.uid==owner or entry.shape in ["cube","stairs"]: continue
		for raw in entry.cells:
			var box := AABB(Vector3(Rooms.base(world,Rooms.Layout.vec(raw)))-(Vector3(1,0,1)-entry.home_offset if entry.has("home_cell") else Vector3(0.5,0,0.5)),Vector3(2,2,2)).grow(0.04)
			if box.intersects_segment(points[0],points[1]): return true
	# Native workplaces can cover a Home flue too; their real footprint is authoritative.
	if room(world,owner).has("home_cell"):
		var source: Vector3i=room(world,owner).home_cell
		for cell in world.buildings:
			if cell==source: continue
			var data: Dictionary=world.buildings[cell]
			var footprint:=preload("res://scripts/settlement/farming.gd").footprint(data.kind,cell,data.get("placement_offset",Vector3.ZERO),int(data.direction))
			var box:=AABB(Vector3(footprint.position.x,cell.y,footprint.position.y),Vector3(footprint.size.x,preload("res://data/settlement/catalog.gd").building_height(data.kind),footprint.size.y)).grow(0.04)
			if box.intersects_segment(points[0],points[1])!=null: return true
	return false
static func gas_path(world, owner: int, target: int) -> Array[Vector3]:
	var a := pose(world,room(world,owner))*Vector3(1.65,1.78,0.15)
	var b := pose(world,room(world,target))*Vector3(1.75,1.78,0.15)
	# A service chase runs above lintels and rises at the room's corner.
	return [a,Vector3(b.x,a.y,a.z),Vector3(b.x,b.y,a.z),b]
static func length(points: Array) -> float:
	var total := 0.0
	for i in range(1,points.size()): total+=points[i-1].distance_to(points[i])
	return total
static func recipe(world, owner: int, target: int, action: String) -> Dictionary:
	match action:
		"stove": return {"brick":56,"pottery":2,"log":1}
		"lamp": return {"pottery":2,"log":1}
		"gas": return {"pottery":maxi(1,ceili(length(gas_path(world,owner,target))/2))}
		"rain":
			var total := 0.0
			for drain in drains(world,owner,false): total+=length(drain.path)+2.5
			return {"pottery":2+ceili(total/2),"plank":12,"rope":2}
		"fuel": return {"log":1}
	return {}
static func ensure(world, owner: int) -> void:
	if not world.room_site.has("utilities"): world.room_site.utilities={}
	if not states(world).has(owner):
		var barrel := barrel_cell(world,owner)
		world.room_site.utilities[owner]={"stove":false,"rain":false,"rain_connected":true,"rain_roofs":[],"fuel":0.0,"lamps":{},"materials":{},"runoff":0.0,"overflow":0,"spilled":0}
		if room(world,owner).has("home_cell"): world.room_site.utilities[owner].barrel_cell=barrel
static func request(world, owner: int, target: int, action: String) -> bool:
	if action not in ACTIONS or room(world,owner).is_empty() or room(world,target).is_empty(): return false
	if world.has_method("utility_kind"):
		if room(world,owner).building_id!=room(world,target).building_id: return false
	elif owner_for(world,room(world,target))!=owner: return false
	ensure(world,owner)
	var service := state(world,owner)
	if action in ["stove","rain"] and service[action]: return false
	if action=="lamp" and service.lamps.has(target): return false
	if action=="gas" and service.lamps.get(target,{}).get("pipe",false): return false
	if action=="fuel" and service.fuel>FUEL_SECONDS: return false
	if world.plans.values().any(func(plan):return plan.get("utility_owner",-1)==owner and plan.get("utility_target",-1)==target and plan.get("utility_action")==action): return false
	var materials := recipe(world,owner,target,action)
	var id: int=world.next_plan_id; world.next_plan_id+=1
	world.plans[id]={"id":id,"kind":world.utility_kind() if world.has_method("utility_kind") else "room_utility","cell":Rooms.base(world,Rooms.Layout.vec(room(world,target).cells[0])),"direction":0,
		"utility_owner":owner,"utility_target":target,"utility_action":action,"materials":materials,"used":{},"claims":{},
		"required":materials.values().reduce(func(a,b):return a+b,0),"installed":0,"reserved":0}
	if action=="rain": world.plans[id].utility_roofs=drains(world,owner,false).map(func(drain):return drain.uid)
	world.revision+=1
	return true
static func ready(world, plan: Dictionary) -> bool:
	if room(world,plan.utility_target,true).is_empty(): return false
	var service := state(world,plan.utility_owner)
	if plan.utility_action=="rain" and world.buildings.has(barrel_cell(world,plan.utility_owner)): return false
	if plan.utility_action in ["gas","fuel"] and not service.get("stove",false): return false
	if plan.utility_action=="gas" and not service.lamps.has(plan.utility_target): return false
	return true
static func complete(world, plan: Dictionary) -> void:
	var service := state(world,plan.utility_owner)
	match str(plan.utility_action):
		"stove": service.stove=true; service.fuel+=FUEL_SECONDS
		"lamp": service.lamps[plan.utility_target]={"pipe":false,"connected":false,"charge":CHARGE}
		"gas": service.lamps[plan.utility_target].pipe=true; service.lamps[plan.utility_target].connected=true
		"fuel": service.fuel+=FUEL_SECONDS
		"rain":
			service.rain=true; service.rain_roofs=plan.utility_roofs.duplicate()
			var inventory := Inventory.new(); inventory.capacity=CAPACITY
			world.water_sources[barrel_cell(world,plan.utility_owner)]={"kind":"cistern","owner":plan.utility_owner,"inventory":inventory}
	for resource in plan.materials: service.materials[resource]=int(service.materials.get(resource,0))+int(plan.materials[resource])
	world.plans.erase(plan.id); world.rebuild_navigation(); world.revision+=1
static func supply(world, owner: int) -> bool:
	var service := state(world,owner)
	return service.get("stove",false) and service.fuel>0 and not blocked(world,owner)
static func brightness(world, owner: int, target: int) -> float:
	var lamp: Dictionary=state(world,owner).get("lamps",{}).get(target,{})
	if lamp.is_empty(): return 0
	if lamp.connected and supply(world,owner): return 1
	return smoothstep(0,5,float(lamp.charge))
static func toggle_gas(world, owner: int, target: int) -> bool:
	var lamp: Dictionary=state(world,owner).get("lamps",{}).get(target,{})
	if lamp.is_empty(): return false
	if not lamp.pipe: return request(world,owner,target,"gas")
	lamp.connected=not lamp.connected; world.revision+=1; return true
static func tick(world, delta: float) -> void:
	for owner in states(world):
		var service := state(world,owner)
		var demand: bool=service.lamps.values().any(func(lamp):return lamp.connected)
		var available: float=minf(delta,service.fuel) if demand and supply(world,owner) else 0.0
		service.fuel=maxf(0,service.fuel-available)
		for lamp in service.lamps.values():
			lamp.charge=maxf(0,float(lamp.charge)-delta+(available if lamp.connected else 0.0))
		if demand and service.stove and service.fuel<10 and not blocked(world,owner): request(world,owner,owner,"fuel")
static func rain_second(world) -> void:
	if not world.weather.raining: return
	for owner in states(world):
		var service := state(world,owner)
		if not service.rain: continue
		var source: Dictionary=world.water_sources.get(barrel_cell(world,owner),{})
		if source.is_empty(): continue
		var routes := drains(world,owner,true)
		# A complete shower contributes one droplet per exposed 2 x 2 roof.
		var covered := routes.filter(func(route):return not world.roof_rain.gutters.values().any(func(g):return g.lane.begins_with(str(route.uid)+":")))
		var incoming := covered.size()/float(world.Hydrology.RAIN_END-world.Hydrology.RAIN_START)
		if not service.rain_connected:
			service.spilled+=incoming; continue
		service.runoff+=incoming
		var units := floori(service.runoff); service.runoff-=units
		var accepted := mini(units,maxi(0,CAPACITY-source.inventory.total()))
		source.inventory.store("water",accepted); service.overflow+=units-accepted
		if units>0: world.revision+=1
static func native_building_boxes(world) -> Array[AABB]:
	var result: Array[AABB]=[]
	if not world.room_site.get("design",[]).any(func(entry):return entry.has("home_cell")): return result
	for cell in world.buildings:
		var data: Dictionary=world.buildings[cell]
		var footprint:=preload("res://scripts/settlement/farming.gd").footprint(data.kind,cell,data.get("placement_offset",Vector3.ZERO),int(data.direction))
		result.append(AABB(Vector3(footprint.position.x,cell.y,footprint.position.y),Vector3(footprint.size.x,preload("res://data/settlement/catalog.gd").building_height(data.kind),footprint.size.y)))
	return result
static func drains(world, owner: int, built := true) -> Array[Dictionary]:
	var source := room(world,owner)
	if source.is_empty(): return []
	var allowed: Array=state(world,owner).get("rain_roofs",[])
	var native_boxes:=native_building_boxes(world)
	var cache_key := str([world.room_site.get("origin"),owner,built,world.room_site.get("built" if built else "design",[]),allowed,native_boxes]).sha256_text()
	if drain_cache.has(cache_key): return drain_cache[cache_key]
	var network: Array=world.room_site.get("built" if built else "design",[])
	var members: Array=network.filter(func(entry):return entry.building_id==source.building_id and entry.has("generated") and entry.shape=="room_domino")
	var bounds := AABB()
	for entry in members:
		var box := AABB(Vector3(Rooms.base(world,Rooms.Layout.vec(entry.cells[0])))-(Vector3(1,0,1)-entry.home_offset if entry.has("home_cell") else Vector3(0.5,0,0.5)),Vector3(2,2,2))
		bounds=box if not bounds.has_volume() else bounds.merge(box)
	var end := barrel_position(world,owner)+Vector3.UP*0.8
	var result: Array[Dictionary]=[]
	for entry in members:
		if built and not allowed.is_empty() and entry.uid not in allowed: continue
		var cell := Rooms.Layout.vec(entry.cells[0])
		if members.any(func(other):return Rooms.Layout.vec(other.cells[0])==cell+Vector3i.UP): continue
		if entry.has("home_cell"):
			var roof_center: Vector3=Vector3(entry.home_cell)+entry.home_offset+Vector3.UP*2.05
			if native_boxes.any(func(box):return box.has_point(roof_center)): continue
		var profile: Dictionary=entry.home_profile if entry.has("home_cell") else Generator.generate(Rules.layout(entry.generated.seed),entry.generated.seed,1).rooms[entry.generated.source]
		var roofed: bool=entry.get("home_roof",cell.y>0)
		var x: float=-profile.roof_overhang-0.06 if profile.roof_slope>0 else 2+profile.roof_overhang+0.06
		var y: float=2.1+profile.roof_slope*(x-1) if roofed else 2.08
		var transform := pose(world,entry)
		var chosen: Array[Vector3]=[]
		for z in [-0.34,2.34]:
			var start: Vector3=transform*Vector3(x,y,z)
			var ground_route:=ground_drain_route(world,network,start,end)
			if not ground_route.is_empty() and (chosen.is_empty() or length(ground_route)+ground_route[2].y*5<length(chosen)+chosen[2].y*5): chosen=ground_route
			for edge in [bounds.position.x-0.36,bounds.end.x+0.36]:
				for front in [bounds.position.z-0.36,bounds.end.z+0.36]:
					for candidate in [[start,Vector3(start.x,start.y-0.02,front),Vector3(start.x,0.95+end.y-0.8,front),Vector3(end.x,0.93+end.y-0.8,front),Vector3(end.x,0.89+end.y-0.8,end.z),end],[start,Vector3(edge,start.y-0.02,start.z),Vector3(edge,0.95+end.y-0.8,start.z),Vector3(edge,0.93+end.y-0.8,front),Vector3(end.x,0.91+end.y-0.8,front),Vector3(end.x,0.89+end.y-0.8,end.z),end],[start,Vector3(edge,start.y-0.02,start.z),Vector3(edge,start.y-0.04,front),Vector3(end.x,start.y-0.06,front),Vector3(end.x,start.y-0.08,end.z),end]]:
						var path: Array[Vector3]=[]; path.assign(candidate)
						if path[-2].y<=end.y: continue
						var clear := true
						for obstacle in network:
							if obstacle.shape=="cube": continue
							for raw in obstacle.cells:
								var box := AABB(Vector3(Rooms.base(world,Rooms.Layout.vec(raw)))-(Vector3(1,0,1)-obstacle.home_offset if obstacle.has("home_cell") else Vector3(0.5,0,0.5)),Vector3(2,2,2)).grow(0.04)
								for i in range(1,path.size()):
									if box.intersects_segment(path[i-1],path[i]): clear=false
						for box in native_boxes:
							for i in range(1,path.size()):
								if box.grow(0.04).intersects_segment(path[i-1],path[i])!=null: clear=false
						if clear and (chosen.is_empty() or length(path)+path[2].y*5<length(chosen)+chosen[2].y*5): chosen=path
		if not chosen.is_empty(): result.append({"uid":entry.uid,"path":chosen,"roofed":roofed,"local_x":x,"local_y":y})
	if drain_cache.size()>128: drain_cache.clear()
	drain_cache[cache_key]=result
	return result

static func geometry_key(world) -> Array:
	var key: Array=[native_building_boxes(world)]
	for owner in states(world):
		var service := state(world,owner)
		key.append([owner,service.stove,service.rain,service.rain_connected,service.lamps.keys(),service.lamps.values().map(func(lamp):return [lamp.pipe,lamp.connected])])
	return key
static func valid(site: Dictionary, plans: Dictionary, native := false) -> bool:
	if not site.get("utilities",{}) is Dictionary: return false
	var by_uid := {}
	for entry in site.get("design",[]): by_uid[entry.uid]=entry
	for owner in site.get("utilities",{}):
		var service: Variant=site.utilities[owner]
		if not owner is int or not by_uid.has(owner) or not by_uid[owner].has("generated") or by_uid[owner].generated.source!=0 or not service is Dictionary: return false
		if not service.get("stove") is bool or not service.get("rain") is bool or not service.get("rain_connected") is bool or not service.get("lamps") is Dictionary or not service.get("materials") is Dictionary or not service.get("rain_roofs") is Array: return false
		for uid in service.rain_roofs:
			if not uid is int or not by_uid.has(uid) or by_uid[uid].building_id!=by_uid[owner].building_id: return false
		for resource in service.materials:
			if resource not in ["brick","pottery","plank","rope","log"] or not service.materials[resource] is int or service.materials[resource]<0: return false
		for field in ["fuel","runoff","overflow","spilled"]:
			if not (service.get(field) is int or service.get(field) is float) or not is_finite(float(service[field])) or service[field]<0: return false
		if service.fuel>FUEL_SECONDS*2 or service.runoff>=1: return false
		for target in service.lamps:
			if not by_uid.has(target) or by_uid[target].building_id!=by_uid[owner].building_id: return false
			var lamp: Variant=service.lamps[target]
			if not lamp is Dictionary or not lamp.get("pipe") is bool or not lamp.get("connected") is bool or (lamp.connected and not lamp.pipe): return false
			if not (lamp.get("charge") is int or lamp.get("charge") is float) or not is_finite(float(lamp.charge)) or lamp.charge<0 or lamp.charge>CHARGE: return false
	for plan in plans.values():
		if plan.kind!=("home_utility" if native else "room_utility"): continue
		if plan.get("utility_action") not in ACTIONS or not by_uid.has(plan.get("utility_owner")) or not by_uid.has(plan.get("utility_target")): return false
		if not site.get("utilities",{}).has(plan.utility_owner): return false
		if plan.cell!=(by_uid[plan.utility_target].home_cell if native else site.origin+Rooms.Layout.vec(by_uid[plan.utility_target].cells[0])*2): return false
		if by_uid[plan.utility_target].building_id!=by_uid[plan.utility_owner].building_id: return false
		if plan.utility_action=="rain":
			if not plan.get("utility_roofs") is Array or plan.utility_roofs.is_empty(): return false
			for uid in plan.utility_roofs:
				if not by_uid.has(uid) or by_uid[uid].building_id!=by_uid[plan.utility_owner].building_id: return false
			if plan.materials.keys().size()!=3 or plan.materials.get("plank")!=12 or plan.materials.get("rope")!=2 or int(plan.materials.get("pottery",0))<3: return false
		if plan.utility_action=="gas" and (plan.materials.keys()!=["pottery"] or plan.materials.pottery<1): return false
		if plan.utility_action=="stove" and plan.materials!={"brick":56,"pottery":2,"log":1}: return false
		if plan.utility_action=="lamp" and plan.materials!={"pottery":2,"log":1}: return false
		if plan.utility_action=="fuel" and plan.materials!={"log":1}: return false
	return true

static func installation_cost(world, owner: int) -> Dictionary:
	var service := state(world,owner)
	var result := {} if service.get("stove",false) else recipe(world,owner,owner,"stove")
	if not service.get("rain",false):
		for resource in recipe(world,owner,owner,"rain"):
			result[resource]=int(result.get(resource,0))+int(recipe(world,owner,owner,"rain")[resource])
	for target in world.room_site.get("design",[]):
		if target.building_id!=room(world,owner).building_id or target.shape!="room_domino" or service.get("lamps",{}).has(target.uid): continue
		for resource in recipe(world,owner,target.uid,"lamp"):
			result[resource]=int(result.get(resource,0))+int(recipe(world,owner,target.uid,"lamp")[resource])
	return result
static func install(world, owner: int) -> bool:
	var cell := barrel_cell(world,owner)
	if not world.ground.has(cell): return false
	if world.water_sources.has(cell) and world.water_sources[cell].get("owner",-1)!=owner: return false
	for collection in [world.buildings,world.stores,world.wells,world.trees]:
		if collection.has(cell): return false
	request(world,owner,owner,"stove"); request(world,owner,owner,"rain")
	for target in world.room_site.get("design",[]):
		if target.building_id==room(world,owner).building_id and target.shape=="room_domino": request(world,owner,target.uid,"lamp")
	return true
static func cost_text(materials: Dictionary) -> String:
	var parts := PackedStringArray()
	for resource in materials: parts.append("%d %s" % [materials[resource],str(resource).capitalize()])
	return " + ".join(parts)

static func ground_drain_route(world, network: Array, start: Vector3, end: Vector3) -> Array[Vector3]:
	# Follow the actual concave footprint rather than its enclosing rectangle.
	var level := end.y+0.12
	var foot := Vector3(start.x,level,start.z)
	var boxes: Array[AABB]=native_building_boxes(world)
	var nodes: Array[Vector3]=[foot,Vector3(end.x,level,end.z)]
	for obstacle in network:
		if obstacle.shape=="cube": continue
		for raw in obstacle.cells:
			var box := AABB(Vector3(Rooms.base(world,Rooms.Layout.vec(raw)))-(Vector3(1,0,1)-obstacle.home_offset if obstacle.has("home_cell") else Vector3(0.5,0,0.5)),Vector3(2,2,2))
			if box.grow(0.04).intersects_segment(start,foot): return []
			if level<box.position.y or level>box.end.y: continue
			boxes.append(box.grow(0.04))
			var margin:=box.grow(0.14)
			for x in [margin.position.x,margin.end.x]:
				for z in [margin.position.z,margin.end.z]: nodes.append(Vector3(x,level,z))
	var distance: Array=[]; var previous: Array=[]; var visited: Array=[]
	for i in nodes.size(): distance.append(INF); previous.append(-1); visited.append(false)
	distance[0]=0.0
	for iteration in nodes.size():
		var at := -1
		for i in nodes.size():
			if not visited[i] and (at<0 or distance[i]<distance[at]): at=i
		if at<0 or is_inf(distance[at]): return []
		if at==1: break
		visited[at]=true
		for next in nodes.size():
			if visited[next]: continue
			if boxes.any(func(box):return box.intersects_segment(nodes[at],nodes[next])!=null): continue
			var candidate: float=distance[at]+nodes[at].distance_to(nodes[next])
			if candidate<distance[next]: distance[next]=candidate; previous[next]=at
	if previous[1]<0: return []
	var reversed: Array[Vector3]=[]; var cursor := 1
	while cursor>=0: reversed.append(nodes[cursor]); cursor=previous[cursor]
	reversed.reverse()
	var result: Array[Vector3]=[start]
	for i in reversed.size():
		var point: Vector3=reversed[i]; point.y=level-0.08*float(i)/maxi(1,reversed.size()-1); result.append(point)
	result.append(end)
	return result
