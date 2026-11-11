extends RefCounted
## Deterministic Home offsets on any real roof bearing, retaining paid short braces.
const Pose=preload("res://scripts/settlement/home_pose.gd")
const LIMIT := 0.4
const Catalog=preload("res://data/settlement/catalog.gd")
const Farming=preload("res://scripts/settlement/farming.gd")
static func bearings(world,cell: Vector3i) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	for base in world.buildings:
		var data: Dictionary=world.buildings[base]
		if data.kind not in Catalog.ROOFS or base.y+int(Catalog.building_height(data.kind))!=cell.y: continue
		var rect:=Farming.footprint(data.kind,base,data.get("placement_offset",Vector3.ZERO),int(data.direction))
		if rect.intersects(Rect2(Vector2(cell.x-1,cell.z-1),Vector2(2,2))): result.append(rect.grow(-0.06))
	return result
static func offset(world, cell: Vector3i) -> Vector3:
	for step in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		var neighbor: Dictionary=world.buildings.get(cell+step*2,{})
		if neighbor.get("kind")=="house": return neighbor.get("placement_offset",Vector3.ZERO)
	var supports:=bearings(world,cell)
	if supports.is_empty(): return Vector3.ZERO
	var rng:=RandomNumberGenerator.new(); rng.seed=hash([world.world_seed,cell,"home-stack-v1"])
	var centre: Vector2=supports[0].get_center()-Vector2(cell.x,cell.z)
	return Vector3(clampf(centre.x+rng.randf_range(0.16,0.34)*(-1 if rng.randi()%2 else 1),-LIMIT,LIMIT),0,clampf(centre.y+rng.randf_range(0.16,0.34)*(-1 if rng.randi()%2 else 1),-LIMIT,LIMIT))
static func shifted(world, cell: Vector3i, at: Vector3) -> bool:
	return not braces(world,cell,at).is_empty()
const FREE_OVERHANG := 0.5
const POST_OVERHANG := 1.5
const Frame=preload("res://scripts/settlement/structure_frame.gd")

static func bearing_records(world,cell: Vector3i,offset_: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var footprint:=Rect2(Vector2(cell.x+offset_.x-1,cell.z+offset_.z-1),Vector2(2,2))
	footprint=Pose.bounds({"rect":footprint,"at":Vector3(cell)+offset_,"yaw":Pose.angle(world,cell)})
	for base in world.buildings:
		var data: Dictionary=world.buildings[base]
		if data.kind not in Catalog.ROOFS or base.y+int(Catalog.building_height(data.kind))!=cell.y: continue
		if data.kind=="house" and int(data.get("house_tier",3))<2: continue
		var rect:=Farming.footprint(data.kind,base,data.get("placement_offset",Vector3.ZERO),int(data.direction))
		var bearing: Dictionary={"cell":base,"rect":rect,"at":Vector3(base)+data.get("placement_offset",Vector3.ZERO),"yaw":Pose.angle(world,base) if data.kind=="house" else 0.0}
		if Pose.bounds(bearing).intersects(footprint): result.append(bearing)
	return result

static func opening_boxes(world) -> Array[AABB]:
	var result: Array[AABB]=[]
	var Assembly=load("res://scripts/settlement/building_assembly.gd")
	var Homes=load("res://scripts/settlement/home_assembly.gd")
	Homes.ensure(world)
	var entries: Dictionary=Assembly.Layout.build(world)
	for entry in entries.values():
		if entry.open or entry.socket: continue
		var profile: Dictionary=Homes.profile(world,entry.cell,Homes.members(world,entry.cell)) if entry.kind=="house" else Assembly.V.Generator.generate([{"id":0,"origin":Vector3.ZERO,"entry":Vector3(1,0,2)}],int(world.buildings[entry.cell].get("assembly_exemplar",{}).get("seed",hash([world.world_seed,entry.cell,entry.kind]))),1).rooms[0]
		for wall in Assembly.wall_specs(entry,profile,entries):
			if wall.opening not in ["window","door"]: continue
			var door: bool=wall.opening=="door"
			var size:=Vector3(wall.width+(0.36 if door else 0.08),1.85 if door else 0.90,1.0 if door else 0.32)
			var center:=Vector3(wall.offset,0.925 if door else 1.25,0)
			result.append(Transform3D(Basis(Vector3.UP,wall.yaw),entry.at+Vector3.UP*float(entry.get("elevation",0))+wall.center)*AABB(center-size/2,size))
	return result

static func clear_openings(a: Vector3,b: Vector3,openings: Array[AABB]) -> bool:
	var box:=Frame.log_bounds(a,b)
	for opening in openings:
		if not box.intersects(opening): continue
		# Test each actual stock length, not the large empty corners of a diagonal AABB.
		for pose in Frame.log_poses(a,b):
			var start: Vector3=pose*(Vector3.LEFT*Frame.Timber.LOG_LENGTH/2)
			var end: Vector3=pose*(Vector3.RIGHT*Frame.Timber.LOG_LENGTH/2)
			if opening.grow(Frame.Timber.LOG_DIAMETER/2+0.01).intersects_segment(start,end)!=null: return false
	return true

static func post_foot(world,top: Vector3) -> Variant:
	var best: Variant=null
	for cell in world.ground:
		if cell.x!=roundi(top.x) or cell.z!=roundi(top.z) or cell.y>=top.y: continue
		var y: float=world.navigation.surface_height(cell,top)
		if best==null or y>best: best=y
	for cell in world.platforms:
		if cell.y<top.y and absf(top.x-cell.x)<0.88 and absf(top.z-cell.z)<0.88 and (best==null or cell.y>best): best=float(cell.y)
	for cell in world.buildings:
		var data: Dictionary=world.buildings[cell]
		if data.kind not in Catalog.ROOFS: continue
		if data.kind=="house" and int(data.get("house_tier",3))<2: continue
		var y: float=cell.y+Catalog.building_height(data.kind)
		var rect:=Farming.footprint(data.kind,cell,data.get("placement_offset",Vector3.ZERO),int(data.direction)).grow(-0.12)
		var at: Vector3=Vector3(cell)+data.get("placement_offset",Vector3.ZERO)
		var local_top: Vector3=at+(top-at).rotated(Vector3.UP,-Pose.angle(world,cell)) if data.kind=="house" else top
		if y<top.y-0.1 and rect.has_point(Vector2(local_top.x,local_top.z)) and (best==null or y>best): best=y
	if best==null: return null
	# A post may land on a real roof, but may not pass through another building.
	for cell in world.buildings:
		var data: Dictionary=world.buildings[cell]
		if data.kind not in Catalog.ROOFS: continue
		var rect:=Farming.footprint(data.kind,cell,data.get("placement_offset",Vector3.ZERO),int(data.direction)).grow(0.12)
		var roof: float=cell.y+Catalog.building_height(data.kind)
		if rect.has_point(Vector2(top.x,top.z)) and float(best)<roof-0.1 and top.y>cell.y+0.1: return null
	for collection in [world.trees,world.wells]:
		for cell in collection:
			if Vector2(top.x-cell.x,top.z-cell.z).length()<0.6 and float(best)<cell.y+2 and top.y>cell.y: return null
	return best

static func plan(world,cell: Vector3i,offset_: Vector3) -> Dictionary:
	var bearings_=bearing_records(world,cell,offset_)
	var result: Dictionary={"members":[],"error":"","bearing":not bearings_.is_empty()}
	if bearings_.is_empty(): return result
	var origin:=Vector3(cell)+offset_+Vector3.UP*preload("res://scripts/settlement/structure_elevation.gd").base_shift(world,cell,"house",0,offset_)
	var openings: Array[AABB]=[]; var loaded:=false
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			var corner:=Vector2(origin.x+x,origin.z+z)
			var overhang:=INF
			for bearing in bearings_:
				var delta: Vector2=(corner-corner.clamp(bearing.rect.position,bearing.rect.end)).abs()
				overhang=minf(overhang,maxf(delta.x,delta.y))
			if overhang<=FREE_OVERHANG+0.00001: continue
			if not loaded: openings=opening_boxes(world); loaded=true
			var found:=false
			# Keep the established offset thresholds. Fit the attachment within the
			# corner stock thickness when a small yaw brings it near an aperture.
			for fit in [Vector2(0.92,0.92),Vector2(0.92,1.0),Vector2(1.0,0.92),Vector2(1.0,1.0)]:
				var top:=origin+Vector3(x*fit.x,0,z*fit.y).rotated(Vector3.UP,Pose.angle(world,cell))
				if overhang<POST_OVERHANG-0.00001:
					var anchors: Array[Vector2]=[]
					for bearing in bearings_:
						var rect: Rect2=bearing.rect.grow(-0.08)
						# Prefer the bearing's corners to keep the middle of its facade open.
						for point in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y),Vector2(top.x,top.z).clamp(rect.position,rect.end)]:
							var placed:=Pose.point(bearing,Vector3(point.x,origin.y,point.y))
							var anchor:=Vector2(placed.x,placed.z)
							if anchor not in anchors: anchors.append(anchor)
					anchors.sort_custom(func(a,b):return a.distance_squared_to(Vector2(top.x,top.z))<b.distance_squared_to(Vector2(top.x,top.z)))
					for point in anchors:
						var run: float=point.distance_to(Vector2(top.x,top.z))
						if run>POST_OVERHANG+0.15: continue
						var bottom:=Vector3(point.x,top.y-run,point.y)
						if bottom.y<origin.y-1.85 or not clear_openings(bottom,top,openings): continue
						result.members.append({"kind":"brace","a":bottom-origin,"b":top-origin}); found=true; break
				else:
					var foot: Variant=post_foot(world,top)
					if foot!=null:
						var bottom:=Vector3(top.x,float(foot),top.z)
						if clear_openings(bottom,top,openings): result.members.append({"kind":"post","a":bottom-origin,"b":top-origin}); found=true
				if found: break
			if not found: result.error="Keep support clear of openings"; return result
	return result

static func braces(world, cell: Vector3i, at: Vector3) -> Array:
	return plan(world,cell,at).members.map(func(member):return [member.a,member.b])

static func log_cost(world,cell: Vector3i,at: Vector3) -> int:
	var count:=0
	for member in plan(world,cell,at).members: count+=Frame.log_poses(member.a,member.b).size()
	return count

static func supported(world,cell: Vector3i,offset_: Vector3) -> bool:
	var footprint:=Rect2(Vector2(cell.x+offset_.x-1,cell.z+offset_.z-1),Vector2(2,2))
	var area:=0.0
	for bearing in bearing_records(world,cell,offset_): area+=bearing.rect.intersection(footprint).get_area()
	return area>=0.24999 and plan(world,cell,offset_).error.is_empty()

static func configure_navigation(world,surfaces: Dictionary) -> void:
	var nav=world.navigation
	nav.stack_barriers.clear(); nav.stack_solids.clear()
	for cell in world.buildings:
		var data: Dictionary=world.buildings[cell]
		if data.kind!="house": continue
		var offset_: Vector3=data.get("placement_offset",Vector3.ZERO)
		for member in plan(world,cell,offset_).members:
			var origin:=Vector3(cell)+offset_+Vector3.UP*preload("res://scripts/settlement/structure_elevation.gd").base_shift(world,cell,"house",0,offset_)
			var box:=Frame.log_bounds(origin+member.a,origin+member.b)
			box.position-=Vector3(0.18,1.50,0.18); box.size+=Vector3(0.36,1.50,0.36)
			nav.stack_solids.append(box)
			for y in range(floori(box.position.y),ceili(box.end.y)+1):
				for x in range(floori(box.position.x)-1,ceili(box.end.x)+2):
					for z in range(floori(box.position.z)-1,ceili(box.end.z)+2):
						var at:=Vector3i(x,y,z)
						var point: Vector3=nav.surface_point(at)
						if surfaces.has(at) and box.has_point(point): nav.blocked[at]=true
						for side in nav.DIRECTIONS+nav.DIAGONALS:
							var next: Vector3i=at+side
							if box.intersects_segment(point,nav.surface_point(next))==null: continue
							if not nav.stack_barriers.has(at): nav.stack_barriers[at]=[]
							if next not in nav.stack_barriers[at]: nav.stack_barriers[at].append(next)

static func carries(world,base: Vector3i) -> bool:
	var data: Dictionary=world.buildings.get(base,{})
	if data.get("kind","") not in Catalog.ROOFS: return false
	var records: Array=[]
	for cell in world.buildings:
		if world.buildings[cell].kind=="house": records.append({"cell":cell,"placement_offset":world.buildings[cell].get("placement_offset",Vector3.ZERO)})
	for pending in world.plans.values():
		if pending.kind=="house" and not pending.get("deconstruction",false) and not pending.get("house_upgrade",false): records.append(pending)
	for record in records:
		for bearing in bearing_records(world,record.cell,record.get("placement_offset",Vector3.ZERO)):
			if bearing.cell==base: return true
		var roof: float=base.y+Catalog.building_height(data.kind)+preload("res://scripts/settlement/structure_elevation.gd").base_shift(world,base,data.kind)
		if record.cell.y<=roof: continue
		var offset_: Vector3=record.get("placement_offset",Vector3.ZERO)
		var origin:=Vector3(record.cell)+offset_+Vector3.UP*preload("res://scripts/settlement/structure_elevation.gd").base_shift(world,record.cell,"house",0,offset_)
		var rect:=Farming.footprint(data.kind,base,data.get("placement_offset",Vector3.ZERO),int(data.direction))
		for member in plan(world,record.cell,offset_).members:
			var foot: Vector3=origin+member.a
			if member.kind=="post" and absf(foot.y-roof)<0.02 and rect.has_point(Vector2(foot.x,foot.z)): return true
	return false
