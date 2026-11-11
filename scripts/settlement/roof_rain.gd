extends RefCounted
## One droplet per four square metres per complete rain. Fittings are paid work sites.
const Inventory = preload("res://scripts/settlement/inventory.gd")
const Elevation = preload("res://scripts/settlement/structure_elevation.gd")
const Homes = preload("res://scripts/settlement/home_assembly.gd")
const U = preload("res://scripts/settlement/room_utilities.gd")
const CAPACITY = {"vase":1,"barrel":2,"basin":24}
const RECIPES = {"vase":{"clay":2},"barrel":{"plank":6},"basin":{"clay":24,"stone":12},"gutter":{"clay":1},"junction":{"clay":2}}
static func fresh(primary := false) -> Dictionary:
	return {"primary":primary,"next_id":1,"tanks":{},"gutters":{},"pipes":{},"junctions":{},"wet":{},"fractions":{},"overflow":0.0}
static func floor_position(world, cell: Vector3i, offset := Vector3.ZERO) -> Vector3:
	var point: Vector3=world.navigation.surface_point(cell)+offset
	if world.navigation.room_nodes.has(cell):
		var inside:=false
		for base: Vector3i in world.buildings:
			var data: Dictionary=world.buildings[base]
			if data.kind!="house" or base.y!=cell.y: continue
			var centre: Vector3=Vector3(base)+data.get("placement_offset",Vector3.ZERO)
			if absf(point.x-centre.x)<=1 and absf(point.z-centre.z)<=1: inside=true
		if not inside: point.y=cell.y+float(Elevation.maps(world,false).floors.get(cell,0))
	return point
static func tank_position(world, cell: Vector3i) -> Vector3:
	var tank: Dictionary=world.roof_rain.tanks.get(cell,{})
	return floor_position(world,cell,tank.get("offset",Vector3.ZERO))
static func inlet(world, cell: Vector3i) -> Vector3:
	return tank_position(world,cell)+Vector3.UP*(0.56 if world.roof_rain.tanks.get(cell,{}).get("kind")=="vase" else 0.8)
static func roof_lanes(world, sections_only := false) -> Dictionary:
	var result := {}
	var contexts: Array=Homes.contexts(world).duplicate()
	if not world.room_site.is_empty(): contexts.append(world)
	for context in contexts:
		for entry in context.room_site.get("built",[]):
			if not entry.has("generated") or entry.shape!="room_domino": continue
			var native: bool=entry.has("home_cell")
			var cell: Vector3i=entry.home_cell if native else world.Rooms.base(world,world.Rooms.Layout.vec(entry.cells[0]))
			if native and not entry.get("home_roof",true): continue
			if native and not preload("res://scripts/settlement/building_assembly_layout.gd").build(world).get(cell,{}).get("above",[]).is_empty(): continue
			if context.room_site.built.any(func(other):return other.uid!=entry.uid and world.Rooms.Layout.vec(other.cells[0])==world.Rooms.Layout.vec(entry.cells[0])+Vector3i.UP): continue
			var profile: Dictionary=entry.home_profile if native else U.Generator.generate(U.Rules.layout(entry.generated.seed),entry.generated.seed,1).rooms[entry.generated.source]
			var pose: Transform3D=U.pose(context,entry)
			if native: pose.origin.y+=Elevation.base_shift(world,cell,"house")
			# The thatch stock projects 0.14 m past the nominal roof grid.
			var fringe: float=0.14 if profile.get("covering")=="hay" else (0.06 if profile.get("covering")=="imbrex" else 0.0)
			var edge: float=-profile.roof_overhang-fringe if profile.roof_slope>0 else 2+profile.roof_overhang+fringe
			var x: float=edge+(-0.10 if profile.roof_slope>0 else 0.10)
			var y: float=2.1+profile.roof_slope*(edge-1)-0.07
			for lane in (8 if sections_only else 10):
				var legacy:=lane>=8
				var from: float=float(lane-8) if legacy else lane*0.25
				var to: float=from+(1.0 if legacy else 0.25)
				var key := "%s:%s" % [entry.uid,str(lane-8) if legacy else "s%d" % lane]
				var a := pose*Vector3(x,y-from*0.02,from)
				var b := pose*Vector3(x,y-to*0.02,to)
				if legacy:
					# Existing saves keep their original pipe sockets exactly.
					var old_x: float=-profile.roof_overhang-0.04 if profile.roof_slope>0 else 2+profile.roof_overhang+0.04
					var old_y: float=2.1+profile.roof_slope*(old_x-1)
					a=pose*Vector3(old_x,old_y-0.03,from); b=pose*Vector3(old_x,old_y-0.05,to)
				var ridge := pose*Vector3(2 if profile.roof_slope>0 else 0,2.12+absf(profile.roof_slope),(from+to)*0.5)
				result[key]={"cell":cell,"a":a,"b":b,"ridge":ridge,"area":(to-from)*2.0,"roof":entry.uid,"from":from,"to":to,"mount":pose.basis*Vector3(-x if profile.roof_slope>0 else 2-x,0,0)}
	return result
static func tank_radius(kind: String) -> float:
	return 1.05 if kind=="basin" else (0.22 if kind=="vase" else 0.33)
static func tank_error(world, spec: Dictionary, ignored := -1) -> String:
	var cell: Vector3i=spec.cell; var at:=floor_position(world,cell,spec.offset)
	if not world.navigation.surfaces.has(cell): return "Needs a floor"
	if (world.water_sources.has(cell) and cell!=spec.get("moving_from")) or world.wells.has(cell): return "Container space occupied"
	var radius := tank_radius(spec.kind)
	if spec.kind=="basin":
		for delta in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			if not world.navigation.surfaces.has(cell+delta) or absf(floor_position(world,cell+delta).y-at.y)>0.10: return "Basin needs a level 2 x 2 floor"
	for other: Vector3i in world.roof_rain.tanks:
		if other==spec.get("moving_from"): continue
		if tank_position(world,other).distance_to(at)<radius+tank_radius(world.roof_rain.tanks[other].kind)+0.04: return "Container space occupied"
	for base: Vector3i in world.buildings:
		var data: Dictionary=world.buildings[base]
		if data.kind in ["support","road"]: continue
		var shift:=Elevation.base_shift(world,base,data.kind)
		var width := 2.0 if data.kind=="house" else 1.0
		var box:=AABB(Vector3(base)+Vector3(-width/2,shift,-width/2)+data.get("placement_offset",Vector3.ZERO),Vector3(width,world.Catalog.building_height(data.kind),width)).grow(radius)
		if box.has_point(at+Vector3.UP*0.3): return "Keep walls and doors clear"
	for plan in world.plans.values():
		if plan.id!=ignored and plan.kind=="rain_fitting" and plan.rain_spec.kind in CAPACITY and plan.rain_spec.cell==cell: return "Container space reserved"
	return ""
static func configure_navigation(world, surfaces: Dictionary) -> void:
	var nav=world.navigation
	for cell: Vector3i in world.roof_rain.tanks:
		var at:=tank_position(world,cell)
		var radius:=tank_radius(world.roof_rain.tanks[cell].kind)
		var box:=AABB(at-Vector3(radius+0.16,0,radius+0.16),Vector3((radius+0.16)*2,0.7,(radius+0.16)*2))
		for x in range(-2,3):
			for z in range(-2,3):
				var a:=cell+Vector3i(x,0,z)
				if not surfaces.has(a): continue
				if box.has_point(nav.surface_point(a)+Vector3.UP*0.1): nav.blocked[a]=true
				for direction: Vector3i in world.DIRECTIONS:
					var b:=a+direction
					if not surfaces.has(b): continue
					if box.intersects_segment(nav.surface_point(a)+Vector3.UP*0.1,nav.surface_point(b)+Vector3.UP*0.1)!=null:
						if not nav.terrain_barriers.has(a): nav.terrain_barriers[a]=[]
						if b not in nav.terrain_barriers[a]: nav.terrain_barriers[a].append(b)
static func start_point(world, spec: Dictionary) -> Variant:
	if spec.get("source_joint",-1)>=0: return world.roof_rain.get("junctions",{}).get(spec.source_joint,{}).get("position")
	var lane: String=world.roof_rain.gutters.get(spec.get("gutter",-1),{}).get("lane","")
	return roof_lanes(world).get(lane,{}).get("b")
static func end_point(world, spec: Dictionary) -> Variant:
	if spec.get("target_joint",-1)>=0: return world.roof_rain.get("junctions",{}).get(spec.target_joint,{}).get("position")
	if spec.has("outfall"):
		if world.navigation.surfaces.has(spec.outfall): return floor_position(world,spec.outfall)+Vector3.UP*0.95
		return null
	if world.roof_rain.tanks.has(spec.get("target")) or world.wells.has(spec.get("target")): return inlet(world,spec.target)
	return null
static func same_source(a: Dictionary,b: Dictionary) -> bool:
	if a.get("source_joint",-1)>=0: return a.source_joint==b.get("source_joint",-1)
	return a.get("gutter",-1)>=0 and a.get("gutter")==b.get("gutter")
static func downstream(world, joint: int, replacement: Dictionary={}) -> Dictionary:
	if replacement.get("source_joint",-1)==joint: return replacement
	for id in world.roof_rain.pipes:
		if id==replacement.get("replace",-1): continue
		var pipe: Dictionary=world.roof_rain.pipes[id]
		if pipe.get("source_joint",-1)==joint: return pipe
	return {}
static func receiver(world, spec: Dictionary, replacement: Dictionary={}) -> Variant:
	var current:=spec; var visited: Dictionary={}
	while current.get("target_joint",-1)>=0:
		var joint: int=current.target_joint
		if visited.has(joint): return null
		visited[joint]=true; current=downstream(world,joint,replacement)
		if current.is_empty() or not path_error(world,current,false).is_empty(): return null
	if current.has("outfall"):
		var cell: Vector3i=current.outfall
		if world.roof_rain.tanks.has(cell):
			var at:=tank_position(world,cell); var end: Variant=end_point(world,current)
			if end==null: return null
			var opening: float={"vase":0.14,"barrel":0.23,"basin":0.90}[world.roof_rain.tanks[cell].kind]
			if Vector2(at.x-end.x,at.z-end.z).length()<opening-0.035 and inlet(world,cell).y<end.y: return cell
		return null
	return current.get("target")
static func discharge_point(world,spec: Dictionary) -> Vector3:
	var current:=spec; var seen: Dictionary={}
	while current.get("target_joint",-1)>=0 and not seen.has(current.target_joint):
		seen[current.target_joint]=true
		var next:=downstream(world,current.target_joint)
		if next.is_empty() or not path_error(world,next,false).is_empty(): break
		current=next
	return current.path.back()
static func path_error(world, spec: Dictionary, check_cycle := true) -> String:
	var start: Variant=start_point(world,spec); var end: Variant=end_point(world,spec)
	if start==null: return "Choose a gutter or junction"
	if end==null: return "Choose a container or junction"
	var path: Array=spec.path
	if path.size()<2 or path.size()>128: return "Choose a drain route"
	if U.length(path)>256: return "Pipe is too long"
	# Old connections retain a small port tolerance when the eave stock changes.
	if path[0].distance_to(start)>0.18 or path[-1].distance_to(end)>0.18: return "Connect both ends"
	var legacy: bool=spec.get("gutter",-1)>=0 and not world.roof_rain.gutters.get(spec.gutter,{}).get("lane",":s").contains(":s")
	for i in range(1,path.size()):
		if path[i].y>path[i-1].y+0.001: return "Water needs a downhill route"
		if path[i].distance_to(path[i-1])<0.02: return "Pipe is too short"
		for base: Vector3i in world.buildings:
			var data: Dictionary=world.buildings[base]
			if data.kind in ["support","road","well"]: continue
			var width:=2.0 if data.kind=="house" else 1.0
			var box:=AABB(Vector3(base)+data.get("placement_offset",Vector3.ZERO)+Vector3(-width/2,Elevation.base_shift(world,base,data.kind),-width/2),Vector3(width,1.95,width)).grow(0.03 if legacy else 0.10)
			if box.intersects_segment(path[i-1],path[i])!=null: return "Route around the building"
	if check_cycle and spec.get("source_joint",-1)>=0:
		var current:=spec; var seen: Dictionary={spec.source_joint:true}
		while current.get("target_joint",-1)>=0:
			var joint: int=current.target_joint
			if seen.has(joint): return "Pipe route forms a loop"
			seen[joint]=true; current=downstream(world,joint,spec)
			if current.is_empty(): break
	return ""
static func overlaps(a: Dictionary,b: Dictionary) -> bool:
	return a.get("roof")!=null and a.roof==b.get("roof") and minf(a.to,b.to)-maxf(a.from,b.from)>0.001
static func work_cell(world, spec: Dictionary) -> Vector3i:
	if spec.has("cell"): return spec.cell
	if spec.kind=="gutter": return roof_lanes(world)[spec.lane].cell
	if spec.has("outfall"): return spec.outfall
	if spec.get("target_joint",-1)<0: return spec.target
	return world.roof_rain.junctions[spec.target_joint].cell
static func error(world, spec: Dictionary, ignored := -1) -> String:
	if not valid_spec(spec): return "Invalid fitting"
	if spec.kind in CAPACITY: return tank_error(world,spec,ignored)
	if spec.kind=="junction":
		if not world.navigation.surfaces.has(spec.cell): return "Needs an accessible floor"
		if spec.position.y<floor_position(world,spec.cell).y+0.4 or spec.position.y>floor_position(world,spec.cell).y+3: return "Junction is out of reach"
		for base: Vector3i in world.buildings:
			var data: Dictionary=world.buildings[base]
			if data.kind in ["support","road"]: continue
			var width:=2.0 if data.kind=="house" else 1.0
			var box:=AABB(Vector3(base)+data.get("placement_offset",Vector3.ZERO)+Vector3(-width/2,Elevation.base_shift(world,base,data.kind),-width/2),Vector3(width,1.95,width)).grow(0.18)
			if box.has_point(spec.position): return "Keep walls and doors clear"
		for joint in world.roof_rain.get("junctions",{}).values():
			if joint.position.distance_to(spec.position)<0.3: return "Junction space occupied"
		if world.plans.values().any(func(p):return p.id!=ignored and p.kind=="rain_fitting" and p.rain_spec.kind=="junction" and p.rain_spec.position.distance_to(spec.position)<0.3): return "Junction space reserved"
		return ""
	if spec.kind=="gutter":
		var lanes:=roof_lanes(world)
		if not lanes.has(spec.lane): return "Choose a roof edge"
		if world.roof_rain.gutters.values().any(func(g):return overlaps(lanes.get(g.lane,{}),lanes[spec.lane])): return "Gutter already fitted"
		if world.plans.values().any(func(p):return p.id!=ignored and p.kind=="rain_fitting" and p.rain_spec.kind=="gutter" and overlaps(lanes.get(p.rain_spec.lane,{}),lanes[spec.lane])): return "Gutter already planned"
		return ""
	if spec.kind=="pipe":
		if spec.has("replace") and not world.roof_rain.pipes.has(spec.replace): return "Pipe no longer exists"
		for id in world.roof_rain.pipes:
			if id!=spec.get("replace",-1) and same_source(world.roof_rain.pipes[id],spec): return "Outlet already connected"
		if world.plans.values().any(func(p):return p.id!=ignored and p.kind=="rain_fitting" and p.rain_spec.kind=="pipe" and (same_source(p.rain_spec,spec) or (spec.has("replace") and p.rain_spec.get("replace")==spec.replace))): return "Pipe already planned"
		return path_error(world,spec)
	return "Unknown fitting"
static func recipe(spec: Dictionary) -> Dictionary:
	if spec.kind=="pipe": return {"clay":maxi(1,ceili(U.length(spec.path)))}
	return RECIPES.get(spec.kind,{}).duplicate()
static func charged_recipe(data: Dictionary,spec: Dictionary) -> Dictionary:
	var cost:=recipe(spec)
	if spec.has("replace"):
		var paid: Dictionary=data.pipes.get(spec.replace,{}).get("materials",{})
		for resource in cost.keys():
			cost[resource]=maxi(0,cost[resource]-int(paid.get(resource,0)))
			if cost[resource]==0: cost.erase(resource)
	return cost
static func request(world, spec: Dictionary) -> bool:
	var reason:=error(world,spec)
	if not reason.is_empty(): world.last_message=reason; return false
	var materials:=charged_recipe(world.roof_rain,spec)
	if materials.is_empty() and spec.has("replace"):
		complete(world,{"id":-1,"rain_spec":spec,"materials":{}}); return true
	var id: int=world.next_plan_id; world.next_plan_id+=1
	world.plans[id]={"id":id,"kind":"rain_fitting","cell":work_cell(world,spec),"direction":0,"rain_spec":spec.duplicate(true),"materials":materials,"used":{},"claims":{},"required":materials.values().reduce(func(a,b):return a+b,0),"installed":0,"reserved":0}
	world.revision+=1; return true
static func complete(world, plan: Dictionary) -> void:
	var spec: Dictionary=plan.rain_spec.duplicate(true)
	var id: int=spec.get("replace",world.roof_rain.next_id)
	if not spec.has("replace"): world.roof_rain.next_id+=1
	spec.materials=plan.materials.duplicate()
	if spec.has("replace"):
		var paid: Dictionary=world.roof_rain.pipes[id].get("materials",{})
		for resource in paid: spec.materials[resource]=int(spec.materials.get(resource,0))+paid[resource]
		var cost:=recipe(spec); var excess: Dictionary={}
		for resource in spec.materials:
			if spec.materials[resource]>int(cost.get(resource,0)): excess[resource]=spec.materials[resource]-int(cost.get(resource,0))
		if not excess.is_empty(): world.RopeBridges.recover(world,work_cell(world,spec),excess)
		spec.materials=cost; spec.erase("replace")
	if spec.kind in CAPACITY:
		world.roof_rain.tanks[spec.cell]=spec
		var inventory:=Inventory.new(); inventory.capacity=CAPACITY[spec.kind]
		world.water_sources[spec.cell]={"kind":spec.kind,"inventory":inventory}
	elif spec.kind=="gutter": world.roof_rain.gutters[id]=spec
	elif spec.kind=="junction": world.roof_rain.junctions[id]=spec
	else: world.roof_rain.pipes[id]=spec
	world.plans.erase(plan.id); world.rebuild_navigation(); world.revision+=1
static func starter(world) -> void:
	var cell: Vector3i=world.STARTING_HOUSE+Vector3i.LEFT*2
	world.roof_rain.tanks[cell]={"kind":"vase","cell":cell,"offset":Vector3.ZERO,"salvaged":true,"owner":0,"materials":{}}
	var inventory:=Inventory.new(); inventory.capacity=1; inventory.store("water")
	world.water_sources[cell]={"kind":"vase","inventory":inventory}
static func move_tank(world, old: Vector3i, cell: Vector3i, offset: Vector3) -> bool:
	if not world.roof_rain.tanks.has(old): return false
	var spec: Dictionary=world.roof_rain.tanks[old].duplicate(true)
	spec.cell=cell; spec.offset=offset; spec.moving_from=old
	world.last_message=tank_error(world,spec)
	if not world.last_message.is_empty(): return false
	var source: Dictionary=world.water_sources[old]
	if not source.inventory.reservations.is_empty(): world.last_message="Container in use"; return false
	world.roof_rain.tanks.erase(old); world.water_sources.erase(old)
	spec.erase("moving_from"); world.roof_rain.tanks[cell]=spec; world.water_sources[cell]=source
	var fraction: float=world.roof_rain.fractions.get(old,0)
	world.roof_rain.fractions.erase(old); world.roof_rain.fractions[cell]=fraction
	if world.water_orders.has(old): world.water_orders[cell]=world.water_orders[old]; world.water_orders.erase(old)
	# Moving the receiver disconnects the fixed pipe outlet until it is rerouted.
	for pipe in world.roof_rain.pipes.values():
		if pipe.get("target")==old: pipe.target=cell
	world.rebuild_navigation(); world.revision+=1; return true
static func remove(world, target: Dictionary) -> bool:
	if target.kind=="plan": return world.delete_plan(target.id)
	var cell: Vector3i=target.get("cell",Vector3i.ZERO)
	if target.kind=="tank":
		var stock=world.Hydrology.inventory_at(world,cell)
		if stock==null or stock.total()>0 or not stock.reservations.is_empty(): world.last_message="Empty the container first"; return false
	for plan in world.plans.values():
		if plan.kind!="rain_fitting" or plan.rain_spec.kind!="pipe": continue
		var spec: Dictionary=plan.rain_spec
		if (target.kind=="tank" and spec.get("target")==cell) or (target.kind=="gutter" and spec.get("gutter")==target.id) or (target.kind=="junction" and (spec.get("source_joint")==target.id or spec.get("target_joint")==target.id)):
			world.delete_plan(plan.id)
	if target.kind=="tank":
		var inventory=world.Hydrology.inventory_at(world,cell)
		if inventory==null or inventory.total()>0 or not inventory.reservations.is_empty(): world.last_message="Empty the container first"; return false
		for id in world.roof_rain.pipes.keys():
			if world.roof_rain.pipes[id].get("target")==cell: remove(world,{"kind":"pipe","id":id})
		world.RopeBridges.recover(world,cell,world.roof_rain.tanks[cell].get("materials",{}))
		world.roof_rain.tanks.erase(cell); world.water_sources.erase(cell); world.roof_rain.fractions.erase(cell); world.water_orders.erase(cell)
	else:
		var field: String={"gutter":"gutters","junction":"junctions","pipe":"pipes"}.get(target.kind,"")
		if field.is_empty(): return false
		if not world.roof_rain[field].has(target.id): return false
		var record: Dictionary=world.roof_rain[field][target.id]
		if target.kind=="gutter":
			var lanes:=roof_lanes(world); cell=lanes.get(record.lane,{}).get("cell",Vector3i.ZERO)
			for id in world.roof_rain.pipes.keys():
				if world.roof_rain.pipes[id].get("gutter")==target.id: remove(world,{"kind":"pipe","id":id})
		elif target.kind=="junction":
			cell=record.cell
			for id in world.roof_rain.pipes.keys():
				var pipe: Dictionary=world.roof_rain.pipes[id]
				if pipe.get("source_joint")==target.id or pipe.get("target_joint")==target.id: remove(world,{"kind":"pipe","id":id})
		else:
			cell=work_cell(world,record)
			for plan in world.plans.values():
				if plan.kind=="rain_fitting" and plan.rain_spec.get("replace")==target.id: world.delete_plan(plan.id)
		world.RopeBridges.recover(world,cell,record.get("materials",{})); world.roof_rain[field].erase(target.id)
	world.rebuild_navigation(); world.revision+=1; return true
static func outlet_pipe(world,gutter_id: int,lanes: Dictionary={}) -> int:
	if lanes.is_empty(): lanes=roof_lanes(world)
	var visited: Dictionary={}
	while not visited.has(gutter_id) and world.roof_rain.gutters.has(gutter_id):
		visited[gutter_id]=true
		for id in world.roof_rain.pipes:
			var pipe: Dictionary=world.roof_rain.pipes[id]
			if pipe.get("gutter")==gutter_id: return id if path_error(world,pipe).is_empty() else -1
		var lane: Dictionary=lanes.get(world.roof_rain.gutters[gutter_id].lane,{})
		if lane.is_empty(): return -1
		var next: int=-1
		for id in world.roof_rain.gutters:
			var other: Dictionary=lanes.get(world.roof_rain.gutters[id].lane,{})
			if other.get("roof")==lane.roof and is_equal_approx(float(other.get("from",-10)),lane.to): next=id; break
		if next<0: return -1
		gutter_id=next
	return -1
static func rain_second(world) -> void:
	if not world.weather.raining: return
	var lanes:=roof_lanes(world); var incoming := {}; var taken := {}
	var duration: float=world.Hydrology.RAIN_END-world.Hydrology.RAIN_START
	for gutter_id in world.roof_rain.gutters:
		var key: String=world.roof_rain.gutters[gutter_id].lane
		if not lanes.has(key) or taken.has(key): continue
		var outlet:=outlet_pipe(world,gutter_id,lanes)
		if outlet<0: continue
		taken[key]=true
		var target: Variant=receiver(world,world.roof_rain.pipes[outlet])
		if target!=null: incoming[target]=float(incoming.get(target,0))+float(lanes[key].area)/4.0/duration
		else: load("res://scripts/settlement/rain_exposure.gd").spill(world,discharge_point(world,world.roof_rain.pipes[outlet]),0.10)
	# A salvaged open vessel catches one droplet per shower before roofs are fitted.
	for cell: Vector3i in world.roof_rain.tanks:
		if world.roof_rain.tanks[cell].get("salvaged",false) and not incoming.has(cell):
			var top:=inlet(world,cell)
			if not world.buildings.keys().any(func(base):return Vector2(base.x-top.x,base.z-top.z).length()<1.3 and base.y>=cell.y): incoming[cell]=1.0/duration
	for cell: Vector3i in incoming:
		var inventory=world.Hydrology.inventory_at(world,cell)
		if inventory==null: continue
		var amount: float=float(world.roof_rain.fractions.get(cell,0))+incoming[cell]
		var available: float=maxf(0,inventory.capacity-inventory.total())
		if amount>available:
			world.roof_rain.overflow+=amount-available; amount=available
			load("res://scripts/settlement/rain_exposure.gd").spill(world,tank_position(world,cell),0.3)
		var whole:=floori(amount+0.000001)
		world.roof_rain.fractions[cell]=maxf(0,amount-whole)
		if whole>0: inventory.store("water",whole)
	world.revision+=1
static func valid_spec(spec: Variant) -> bool:
	if not spec is Dictionary or spec.get("kind") not in ["vase","barrel","basin","gutter","pipe","junction"]: return false
	if spec.kind in CAPACITY: return spec.get("cell") is Vector3i and spec.get("offset") is Vector3 and spec.offset.is_finite() and absf(spec.offset.x)<=0.5 and absf(spec.offset.z)<=0.5 and is_zero_approx(spec.offset.y)
	if spec.kind=="junction": return spec.get("cell") is Vector3i and spec.get("position") is Vector3 and spec.position.is_finite() and spec.position.length()<30000
	if spec.kind=="gutter": return spec.get("lane") is String and spec.lane.length()<80
	if not (spec.get("gutter") is int or spec.get("source_joint") is int): return false
	var destinations:=int(spec.get("target") is Vector3i)+int(spec.get("target_joint") is int)+int(spec.get("outfall") is Vector3i)
	if destinations!=1: return false
	if spec.has("replace") and (not spec.replace is int or spec.replace<1): return false
	if not spec.get("path") is Array or spec.path.size()<2 or spec.path.size()>128: return false
	for point in spec.path:
		if not point is Vector3 or not point.is_finite() or point.length()>30000: return false
	return true
static func valid(data: Variant, plans: Dictionary, sources: Dictionary) -> bool:
	if not data is Dictionary or not data.get("primary") is bool or not data.get("next_id") is int or data.next_id<1: return false
	if not load("res://scripts/settlement/rain_exposure.gd").valid(data.get("wet",{})): return false
	if not data.get("junctions",{}) is Dictionary: return false
	for field in ["tanks","gutters","pipes","fractions"]:
		if not data.get(field) is Dictionary or data[field].size()>10000: return false
	if not (data.get("overflow") is float or data.get("overflow") is int) or not is_finite(data.overflow) or data.overflow<0: return false
	for cell in data.tanks:
		var tank: Variant=data.tanks[cell]
		if not valid_spec(tank) or tank.kind not in CAPACITY or tank.cell!=cell or not sources.has(cell) or sources[cell].kind!=tank.kind or sources[cell].inventory.capacity!=CAPACITY[tank.kind]: return false
	for field in ["gutters","pipes","junctions"]:
		for id in data.get(field,{}):
			if not id is int or id<1 or id>=data.next_id or not valid_spec(data[field][id]): return false
			if data[field][id].kind!={"gutters":"gutter","pipes":"pipe","junctions":"junction"}[field]: return false
	var outputs: Dictionary={}
	for pipe in data.pipes.values():
		var key: String="j%d" % pipe.source_joint if pipe.get("source_joint",-1)>=0 else "g%d" % pipe.get("gutter",-1)
		if outputs.has(key): return false
		outputs[key]=pipe
		if pipe.get("source_joint",-1)>=0:
			if not data.get("junctions",{}).has(pipe.source_joint): return false
		elif not data.gutters.has(pipe.get("gutter")): return false
		if pipe.get("target_joint",-1)>=0 and not data.get("junctions",{}).has(pipe.target_joint): return false
	for first in data.pipes.values():
		var pipe: Dictionary=first; var visited: Dictionary={}
		while pipe.get("target_joint",-1)>=0:
			var joint: int=pipe.target_joint
			if visited.has(joint): return false
			visited[joint]=true; pipe=outputs.get("j%d" % joint,{})
	for value in data.fractions.values():
		if not (value is float or value is int) or not is_finite(value) or value<0 or value>=1: return false
	for plan in plans.values():
		if plan.kind=="rain_fitting" and (not valid_spec(plan.get("rain_spec")) or plan.materials!=charged_recipe(data,plan.rain_spec) or plan.required!=plan.materials.values().reduce(func(a,b):return a+b,0)): return false
	return true
