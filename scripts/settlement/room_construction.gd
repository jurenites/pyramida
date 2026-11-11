extends RefCounted
## Adapter from shared room editing to the settlement's material-and-labour jobs.
const Layout=preload("res://scripts/settlement/room_layout.gd")
const Editor=preload("res://scripts/block_city/editor_selection.gd")
const Stair=preload("res://scripts/block_city/stair_geometry.gd")
const COSTS={"room_frame":4,"room_shell":2,"room_stair":3,"room_bed":2,"room_utility":1,"home_utility":1,"rain_fitting":1}
const SHAPES=["cube","domino","room_domino","bar","small_square","rectangle","stairs"]
static var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/block_city/balance.json"))
static func fresh(origin: Vector3i) -> Dictionary:
	return {"origin":origin,"design":[],"built":[],"beds":[],"next_id":1}
static func layout(world, built:=false):
	var result=Layout.new("",config)
	# The settlement adapter has no demo transformer occupying a hidden room cell.
	result.transformer_cell=Vector3i(-100,0,-100)
	result.defer_analysis=true
	result.queue=[{"shape":"cube","color":0},{"shape":"cube","color":0}]
	result.basement_queue=result.queue.duplicate(true)
	result.rooms=world.room_site.get("built" if built else "design",[]).duplicate(true)
	for id in result.rooms.size(): result.rooms[id].id=id
	return result
static func base(world,cell: Vector3i) -> Vector3i:
	return world.room_site.origin+cell*2
static func tile_nodes(world,cell: Vector3i) -> Array:
	var p:=base(world,cell)
	return [p,p+Vector3i.RIGHT,p+Vector3i.BACK,p+Vector3i(1,0,1)]
static func signature(room: Dictionary) -> Array:
	return [room.shape,room.cells,room.door,room.normal,room.building_id]
static func kind(room: Dictionary) -> String:
	return "room_frame" if room.shape in ["cube","domino"] else ("room_stair" if room.shape=="stairs" else "room_shell")
static func constructed(world,room: Dictionary) -> bool:
	var actual=layout(world,true)
	var occ: Dictionary=actual.occupied()
	for raw in room.cells:
		var cell:=Layout.vec(raw)
		if not occ.has(cell): return false
		var existing: Dictionary=actual.rooms[occ[cell]]
		if kind(existing)!=kind(room): return false
		if kind(room)!="room_frame" and signature(existing).slice(0,4)!=signature(room).slice(0,4): return false
	return true
static func placement_error(world, design) -> String:
	if design.rooms.size()>128: return "Room limit"
	if not Layout.Frame.structure_issues(design).is_empty(): return "Support or clearance"
	for room in design.rooms:
		if room.shape not in SHAPES: return "Unsupported room"
		for raw in room.cells:
			for cell: Vector3i in tile_nodes(world,Layout.vec(raw)):
				if not world.Catalog.in_bounds(cell): return "Outside world"
				if raw[1]==0 and (not world.ground.has(cell) or (not world.navigation.room_nodes.has(cell) and not is_equal_approx(world.navigation.surface_height(cell,Vector3(cell)),float(cell.y)))): return "Needs level ground"
				for collection in [world.buildings,world.stores,world.wells,world.trees,world.deposits,world.platforms,world.stairs,world.gardens,world.soil_beds,world.vines,world.water_sources]:
					for other: Vector3i in collection:
						if collection==world.water_sources and collection[other].get("kind")=="cistern":
							if cell==other: return "Container space occupied"
							continue
						if abs(other.x-cell.x)<=1 and abs(other.z-cell.z)<=1 and abs(other.y-cell.y)<2: return "Space occupied"
				for plan in world.plans.values():
					if plan.kind in COSTS: continue
					var other: Vector3i=plan.cell
					if abs(other.x-cell.x)<=1 and abs(other.z-cell.z)<=1 and abs(other.y-cell.y)<2: return "Space reserved"
	for plan in world.plans.values():
		if not plan.has("room_uid") or (plan.installed==0 and plan.reserved==0): continue
		var original:=room_for(world,plan)
		if not design.rooms.any(func(room):return signature(room)==signature(original)): return "Construction underway"
	# Completed construction stays physical until its replacement is built.
	var desired: Dictionary=design.occupied()
	for room in world.room_site.built:
		for raw in room.cells:
			var cell:=Layout.vec(raw)
			if not desired.has(cell): return "Built frame must stay supported"
			var target: Dictionary=design.rooms[desired[cell]]
			if kind(room)!="room_frame" and signature(room).slice(0,4)!=signature(target).slice(0,4): return "Keep completed room"
	for bed in world.room_site.beds+world.plans.values().filter(func(plan):return plan.kind=="room_bed"):
		var cell: Array=bed.get("bed_cell",bed.get("cell",[]))
		if not design.rooms.any(func(room):return kind(room)=="room_shell" and room.cells.has(cell)): return "Keep the room supporting its bed"
	return ""
static func legacy_overlap(world,cell: Vector3i) -> bool:
	for room in world.room_site.get("design",[]):
		for raw in room.cells:
			for p: Vector3i in tile_nodes(world,Layout.vec(raw)):
				if abs(cell.x-p.x)<=1 and abs(cell.z-p.z)<=1 and abs(cell.y-p.y)<2: return true
	return false
static func commit(world, design) -> bool:
	world.last_message=placement_error(world,design)
	if not world.last_message.is_empty(): return false
	var target: Array=design.rooms.duplicate(true)
	var next: int=world.room_site.next_id
	for room in target:
		var found: Array=world.room_site.design.filter(func(old):return signature(old)==signature(room))
		if not found.is_empty(): room.uid=found[0].uid
		else: room.uid=next; next+=1
	# Do not discard delivered work or a builder's current reservation during editing.
	for plan in world.plans.values():
		if not plan.has("room_uid"): continue
		if target.any(func(room):return room.uid==plan.room_uid): continue
		if plan.installed>0 or plan.reserved>0:
			world.last_message="Room already under construction"; return false
	for id in world.plans.keys():
		var plan: Dictionary=world.plans[id]
		if plan.has("room_uid") and not target.any(func(room):return room.uid==plan.room_uid): world.plans.erase(id)
	world.room_site.design=target; world.room_site.next_id=next
	for room in target:
		if constructed(world,room) or world.plans.values().any(func(plan):return plan.get("room_uid",-1)==room.uid): continue
		var type:=kind(room)
		var cost: int=COSTS[type]*room.cells.size()
		var id: int=world.next_plan_id; world.next_plan_id+=1
		world.plans[id]={"id":id,"kind":type,"cell":base(world,Layout.vec(room.cells[0])),"direction":0,
			"room_uid":room.uid,"required":cost,"installed":0,"reserved":0,"materials":{"log":cost},"used":{},"claims":{}}
	world.revision+=1; world.last_message="Construction queued"
	return true
static func room_for(world,plan: Dictionary) -> Dictionary:
	for room in world.room_site.get("design",[]):
		if room.uid==plan.get("room_uid",-1): return room
	return {}
static func ready(world,plan: Dictionary) -> bool:
	if plan.kind=="rain_fitting": return load("res://scripts/settlement/roof_rain.gd").error(world,plan.rain_spec,plan.id).is_empty()
	if plan.kind=="home_utility":
		var context=load("res://scripts/settlement/home_assembly.gd").context_for(world,plan.utility_owner)
		return context!=null and load("res://scripts/settlement/room_utilities.gd").ready(context,plan)
	if plan.kind=="room_utility": return load("res://scripts/settlement/room_utilities.gd").ready(world,plan)
	if plan.kind=="room_bed":
		return world.room_site.get("built",[]).any(func(room):return kind(room)=="room_shell" and room.cells.has(plan.bed_cell))
	var room:=room_for(world,plan)
	if room.is_empty(): return false
	var built=layout(world,true); var occ: Dictionary=built.occupied()
	var cells: Array=room.cells.map(func(raw):return Layout.vec(raw))
	for cell in cells: occ.erase(cell)
	return built.support(cells,occ,false,built.room_role(room),room.get("frame_cells",[])).ok
static func work_cells(world,plan: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i]=[]
	if not ready(world,plan): return result
	if plan.kind=="rain_fitting":
		if plan.rain_spec.kind in ["vase","barrel","basin"]:
			var radius:=2 if plan.rain_spec.kind=="basin" else 1
			for direction: Vector3i in world.DIRECTIONS:
				var at: Vector3i=plan.cell+direction*radius
				if world.navigation.walkable(at): result.append(at)
			return result
		for at: Vector3i in world.navigation.access_cells(plan.cell):
			if world.navigation.walkable(at): result.append(at)
		return result
	if plan.kind=="home_utility":
		for at: Vector3i in world.navigation.access_cells(plan.cell):
			if world.navigation.walkable(at): result.append(at)
		return result
	if plan.kind=="room_bed":
		var access:=bed_access(world,{"cell":plan.bed_cell})
		for p: Vector3i in [access,access+Vector3i.BACK]:
			if world.navigation.walkable(p): result.append(p)
		return result
	var room:=room_for(world,plan)
	if plan.kind=="room_utility": room=load("res://scripts/settlement/room_utilities.gd").room(world,plan.utility_target)
	if plan.kind=="room_stair":
		var yaw:=0
		while Layout.rotate_point(Vector3i.FORWARD,yaw)!=Layout.vec(room.normal): yaw+=1
		var center:=Vector3(base(world,Layout.vec(room.cells[0])))+Vector3(0.5,0,0.5)
		var entry:=Vector3i((center+Vector3(-0.5,0,-1.5).rotated(Vector3.UP,-yaw*PI/2)).round())
		if world.navigation.walkable(entry): result.append(entry)
		return result
	for raw in room.cells:
		for p: Vector3i in tile_nodes(world,Layout.vec(raw)):
			for d in [Vector3i.ZERO]+world.DIRECTIONS:
				if world.navigation.walkable(p+d) and not result.has(p+d): result.append(p+d)
			# Workers on a completed lower floor can raise the frame above them.
			if plan.kind=="room_frame" and world.navigation.walkable(p+Vector3i.DOWN*2): result.append(p+Vector3i.DOWN*2)
	return result
static func complete(world,plan: Dictionary) -> void:
	if plan.kind=="rain_fitting":
		load("res://scripts/settlement/roof_rain.gd").complete(world,plan); return
	if plan.kind=="home_utility":
		var context=load("res://scripts/settlement/home_assembly.gd").context_for(world,plan.utility_owner)
		if context!=null: load("res://scripts/settlement/room_utilities.gd").complete(context,plan)
		return
	if plan.kind=="room_utility":
		load("res://scripts/settlement/room_utilities.gd").complete(world,plan); return
	if plan.kind=="room_bed":
		world.room_site.beds.append({"cell":plan.bed_cell.duplicate(),"direction":plan.direction,"id":plan.id})
	else:
		var room:=room_for(world,plan).duplicate(true)
		if room.is_empty(): return
		var built=layout(world,true)
		room.id=built.rooms.size(); built.rooms.append(room)
		Layout.Frame.replace(built,[room])
		world.room_site.built=built.rooms.duplicate(true)
	world.plans.erase(plan.id)
	for worker in world.workers:
		if worker.get("assigned_plan_id",-1)==plan.id: worker.assigned_plan_id=-1
	world.rebuild_navigation()
static func can_add_bed(world,cell: Vector3i) -> bool:
	if world.room_site.is_empty(): return false
	if not world.room_site.design.any(func(room):return kind(room)=="room_shell" and room.cells.has(Layout.arr(cell))): return false
	if world.room_site.beds.any(func(bed):return bed.cell==Layout.arr(cell)) or world.plans.values().any(func(plan):return plan.get("bed_cell",[])==Layout.arr(cell)): return false
	return true
static func add_bed(world,cell: Vector3i) -> bool:
	if not can_add_bed(world,cell): return false
	var id: int=world.next_plan_id; world.next_plan_id+=1
	world.plans[id]={"id":id,"kind":"room_bed","cell":base(world,cell),"bed_cell":Layout.arr(cell),"direction":0,
		"required":2,"installed":0,"reserved":0,"materials":{"log":2},"used":{},"claims":{}}
	world.revision+=1; return true
static func visit_bed(world,worker: Dictionary) -> bool:
	if world.room_site.is_empty() or worker.get("bed_visit_after",0.0)>world.time: return false
	for bed in world.room_site.beds:
		var target:=bed_access(world,bed)
		if world.workers.any(func(other):return other.id!=worker.id and (other.cell==target or other.job.get("target")==target)): continue
		if world.order_move(worker.id,target):
			worker.bed_visit_after=world.time+world.Jobs.Balance.number("day_seconds")
			worker.status="Walking to bed"; return true
	return false

static func bed_access(world,bed: Dictionary) -> Vector3i:
	var p:=base(world,Layout.vec(bed.cell))
	for room in world.room_site.built:
		if room.cells.has(bed.cell) and int(room.normal[0])<0: return p
	return p+Vector3i.RIGHT

static func valid(site,plans: Dictionary) -> bool:
	if not site is Dictionary: return false
	if site.is_empty(): return not plans.values().any(func(plan):return plan is Dictionary and plan.get("kind","") in COSTS and plan.kind not in ["home_utility","rain_fitting"])
	if not site.get("origin") is Vector3i or not site.get("next_id") is int or site.next_id<1: return false
	for field in ["design","built"]:
		if not site.get(field) is Array or site[field].size()>256: return false
		var occupied: Dictionary={}; var uids: Dictionary={}
		for room in site[field]:
			if room is Dictionary and room.has("generated") and not load("res://scripts/settlement/generated_building_plan.gd").valid(room.generated): return false
			if not room is Dictionary or room.get("shape","") not in SHAPES or not room.get("cells") is Array or room.cells.is_empty() or room.cells.size()>6: return false
			if not room.get("uid") is int or room.uid<1 or room.uid>=site.next_id or not room.get("building_id") is int or room.building_id<1: return false
			if not room.has_all(["id","color","door","normal","braces","access_path"]) or not Layout.valid_point(room.door) or not Layout.valid_point(room.normal): return false
			if not Layout.DIRECTIONS.has(Layout.vec(room.normal)) or not room.cells.has(room.door): return false
			if not room.id is int or not room.color is int or room.color<0 or room.color>=config.colors.size(): return false
			if field=="design" and uids.has(room.uid): return false
			uids[room.uid]=true
			if not room.braces is Array or not room.access_path is Array or not room.get("groups",[]) is Array or not room.get("frame_cells",[]) is Array: return false
			for brace in room.braces:
				if not brace is Array or brace.size()!=2 or not Layout.valid_point(brace[0]) or not Layout.valid_point(brace[1]): return false
			for step in room.access_path:
				if not Layout.valid_point(step): return false
			for group in room.get("groups",[]):
				if not group is int or group<1: return false
			for frame in room.get("frame_cells",[]):
				if not Layout.valid_point(frame) or not room.cells.has(frame): return false
			for raw in room.cells:
				if not Layout.valid_point(raw): return false
				var cell:=Layout.vec(raw)
				if abs(cell.x)>64 or abs(cell.z)>64 or cell.y<0 or cell.y>=9 or occupied.has(cell): return false
				occupied[cell]=true
	if not site.get("beds") is Array or site.beds.size()>128: return false
	var beds: Array=[]
	for bed in site.beds:
		if not bed is Dictionary or not Layout.valid_point(bed.get("cell",[])) or not bed.get("id") is int or not bed.get("direction") is int: return false
		if beds.has(bed.cell) or not site.built.any(func(room):return kind(room)=="room_shell" and room.cells.has(bed.cell)): return false
		beds.append(bed.cell)
	var planned: Array=[]
	for plan in plans.values():
		if not plan is Dictionary: return false
		if plan.get("kind","") not in COSTS: continue
		if not plan.get("required") is int or not plan.get("cell") is Vector3i: return false
		if plan.kind in ["room_utility","home_utility","rain_fitting"]: continue
		if plan.get("materials")!={"log":plan.required}: return false
		if plan.kind=="room_bed":
			if not Layout.valid_point(plan.get("bed_cell",[])) or plan.required!=2: return false
			if beds.has(plan.bed_cell) or not site.design.any(func(room):return kind(room)=="room_shell" and room.cells.has(plan.bed_cell)): return false
			beds.append(plan.bed_cell)
			if plan.cell!=site.origin+Layout.vec(plan.bed_cell)*2: return false
		else:
			var found: Array=site.design.filter(func(room):return room.uid==plan.get("room_uid",-1))
			if found.size()!=1 or kind(found[0])!=plan.kind or plan.required!=COSTS[plan.kind]*found[0].cells.size(): return false
			if planned.has(plan.room_uid) or plan.cell!=site.origin+Layout.vec(found[0].cells[0])*2: return false
			planned.append(plan.room_uid)
	return load("res://scripts/settlement/room_utilities.gd").valid(site,plans)
