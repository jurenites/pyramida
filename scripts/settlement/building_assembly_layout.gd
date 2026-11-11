extends RefCounted
## Physical envelopes shared by mixed buildings. Inventories and jobs keep their addresses.
const Catalog=preload("res://data/settlement/catalog.gd")
const Farming=preload("res://scripts/settlement/farming.gd")
const Pose=preload("res://scripts/settlement/home_pose.gd")
const Walk=preload("res://scripts/settlement/building_walk_geometry.gd")
const SIDES=[Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
const ENCLOSED=["house","bakery","kiln","tilery","school","pantry","workshop","mine_camp"]
const OPEN=["sawmill","pottery_workshop","masonry","rope_maker","log_shed","hay_barn","stone_storage","brickyard"]
const SOCKETS=["mill","windmill","mine","quarry","claypit","waterworks","well","small_warehouse","support","stair"]
static var cached_key: String=""
static var cached_entries: Dictionary={}
static func supported(kind: String) -> bool: return kind in ENCLOSED+OPEN+SOCKETS
static func entry(world,cell: Vector3i) -> Dictionary:
	var data: Dictionary=world.buildings[cell]
	var rect:=Farming.footprint(data.kind,cell,data.get("placement_offset",Vector3.ZERO),int(data.direction))
	return {"cell":cell,"kind":data.kind,"elevation":preload("res://scripts/settlement/structure_elevation.gd").base_shift(world,cell,data.kind),"at":Vector3(cell)+data.get("placement_offset",Vector3.ZERO),"rect":rect,"height":Catalog.building_height(data.kind),"direction":int(data.direction),"yaw":Pose.angle(world,cell) if data.kind=="house" else 0.0,"state":{"storage_tier":data.get("storage_tier",1),"mill_tier":data.get("mill_tier",3),"sawmill_tier":data.get("sawmill_tier",2)},"front":[Vector3i.BACK,Vector3i.LEFT,Vector3i.FORWARD,Vector3i.RIGHT][data.direction],"open":data.kind in OPEN,"socket":data.kind in SOCKETS,"joins":[],"above":[],"below":[],"posts":[],"terrace":false,"landings":[]}
static func seam(a: Dictionary,b: Dictionary) -> Dictionary:
	if a.cell.y!=b.cell.y or not is_equal_approx(float(a.get("elevation",0)),float(b.get("elevation",0))) or a.socket or b.socket or minf(a.height,b.height)<Walk.BODY_HEIGHT+0.12: return {}
	for normal: Vector3i in SIDES:
		var x:=normal.x!=0
		var axis:=0 if x else 1
		var along:=1-axis
		var sign_: int=normal.x if x else normal.z
		var boundary: float=a.rect.end[axis] if sign_>0 else a.rect.position[axis]
		var other: float=b.rect.position[axis] if sign_>0 else b.rect.end[axis]
		# Offset homes may meet across a short threshold, never through overlapping walls.
		var gap: float=(other-boundary)*sign_
		if gap < -0.025 or gap > 0.76: continue
		var lo: float=maxf(a.rect.position[along],b.rect.position[along])
		var hi: float=minf(a.rect.end[along],b.rect.end[along])
		if hi-lo<0.96: continue
		if normal!=a.front and -normal!=b.front and not a.open and not b.open: continue
		var at:=Vector3(0,a.cell.y,0)
		var blocks: Array=Walk.rectangles(a)+Walk.rectangles(b)
		var found:=false
		for across in [(lo+hi)/2,(lo+hi)/2+0.35,(lo+hi)/2-0.35,lo+0.49,hi-0.49]:
			if across<lo+0.48 or across>hi-0.48: continue
			at.x=boundary if x else across; at.z=across if x else boundary
			var from:=at-Vector3(normal)*0.30
			var to:=at+Vector3(normal)*(gap+0.30)
			var blocked:=false
			for rect in blocks:
				if AABB(Vector3(rect.position.x,a.cell.y,rect.position.y),Vector3(rect.size.x,2,rect.size.y)).intersects_segment(from+Vector3.UP*0.5,to+Vector3.UP*0.5)!=null: blocked=true; break
			if not blocked: found=true; break
		if not found: continue
		return {"other":b.cell,"normal":normal,"point":at,"far":at+Vector3(normal)*gap,"low":lo,"high":hi,"gap":gap}

	return {}
static func key(point: Vector3) -> Vector3i: return Vector3i((point*1000).round())
static func build(world) -> Dictionary:
	var signature: Array=[world.get_instance_id(),world.world_seed,preload("res://scripts/settlement/structure_elevation.gd").maps(world).bases,load("res://scripts/settlement/building_appearance.gd").revision,world.platforms.keys(),world.stairs,world.bridges,world.plans.values().map(func(plan):return [plan.kind,plan.cell,plan.get("direction",0),plan.get("placement_offset",Vector3.ZERO),plan.get("house_upgrade",false)])]
	for cell in world.buildings:
		var data: Dictionary=world.buildings[cell]
		if supported(data.kind): signature.append([cell,data.kind,data.direction,data.get("placement_offset",Vector3.ZERO),data.get("house_tier",3),data.get("storage_tier",1),data.get("mill_tier",3),data.get("sawmill_tier",2)])
	var cache_key: String=str(signature).sha256_text()
	if cache_key==cached_key: return cached_entries
	var entries: Dictionary={}
	var cells: Array=world.buildings.keys(); cells.sort()
	for cell in cells:
		if supported(world.buildings[cell].kind):
			var data: Dictionary=world.buildings[cell]
			if data.kind!="house" and not data.has("assembly_exemplar"):
				data.assembly_exemplar=preload("res://scripts/settlement/material_exemplars.gd").record(hash([world.world_seed,cell,data.kind]))
			entries[cell]=entry(world,cell)
	for cell in entries:
		var a: Dictionary=entries[cell]
		# Bounded neighbours cover the largest existing building footprint.
		for dx in range(-4,5):
			for dz in range(-4,5):
				for dy in [0,int(a.height)]:
					var next: Vector3i=cell+Vector3i(dx,dy,dz)
					if next==cell or not entries.has(next): continue
					var b: Dictionary=entries[next]
					if dy==0:
						var join:=seam(a,b)
						if not join.is_empty(): a.joins.append(join)
					elif a.rect.intersects(b.rect): a.above.append(next); b.below.append(cell)
		for plan in world.plans.values():
			if plan.get("house_upgrade",false) or plan.kind not in Catalog.ROOFS or plan.cell.y!=cell.y+int(a.height): continue
			if a.rect.intersects(Farming.footprint(plan.kind,plan.cell,plan.get("placement_offset",Vector3.ZERO),int(plan.direction))): a.terrace=true
		# Platforms also replace a pitched roof with an accessible bearing deck.
		for deck in world.platforms:
			if deck.y==cell.y+int(a.height) and a.rect.intersects(Rect2(Vector2(deck.x-1,deck.z-1),Vector2(2,2))): a.terrace=true
		a.landings=landings(world,a)
		if not a.landings.is_empty(): a.terrace=true
	var visited: Dictionary={}
	for cell in entries:
		if visited.has(cell): continue
		var group: Array=[cell]; var cursor:=0
		while cursor<group.size():
			var a: Dictionary=entries[group[cursor]]; cursor+=1; visited[a.cell]=true
			for next in a.above+a.below+a.joins.map(func(j):return j.other):
				if next not in group: group.append(next)
		var owners: Dictionary={}; var inward: Dictionary={}
		for member in group:
			var a: Dictionary=entries[member]
			a.terrace=a.terrace or not a.above.is_empty() or group.any(func(other):return other.y>a.cell.y or (other.y==a.cell.y and entries[other].terrace))
			if a.socket: continue
			for sign_ in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var corner:=Vector3(a.rect.get_center().x+sign_.x*a.rect.size.x/2,a.cell.y,a.rect.get_center().y+sign_.y*a.rect.size.y/2)
				var k: Array=[key(corner),a.height,a.get("elevation",0)]
				if not owners.has(k): owners[k]=member
				inward[k]=inward.get(k,Vector3.ZERO)-Vector3(sign_.x,0,sign_.y)
		for member in group:
			var a: Dictionary=entries[member]
			if a.socket: continue
			for sign_ in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var corner:=Vector3(a.rect.get_center().x+sign_.x*a.rect.size.x/2,a.cell.y,a.rect.get_center().y+sign_.y*a.rect.size.y/2)
				var k: Array=[key(corner),a.height,a.get("elevation",0)]
				if owners[k]==member:
					var post: Vector3=corner+Vector3(inward[k]).sign()*0.08-a.at
					a.posts.append(post if is_zero_approx(inward[k].x) or is_zero_approx(inward[k].z) else Pose.local(a,post))
	cached_key=cache_key; cached_entries=entries
	return entries
static func roof_open(entry_: Dictionary,point: Vector2,entries: Dictionary) -> bool:
	for upper in entry_.above:
		if Pose.contains(entries[upper],point,0.02): return false
	return true
static func stock_kind(kind: String) -> String:
	return "hay" if kind in ["bakery","kiln","school","mine_camp"] else "plank"

static func landings(world,entry_: Dictionary) -> Array:
	var result: Array=[]
	var level: int=entry_.cell.y+int(entry_.height)
	var rect: Rect2=entry_.rect.grow(0.02)
	var stairs: Array=[]
	for cell in world.stairs: stairs.append({"cell":cell,"direction":world.stairs[cell],"run":2})
	for cell in world.buildings:
		if world.buildings[cell].kind=="stair": stairs.append({"cell":cell,"direction":world.buildings[cell].direction,"run":1})
	for stair in stairs:
		if level-stair.cell.y not in ([1,2] if stair.run==2 else [1]): continue
		var direction: Vector3i=world.DIRECTIONS[stair.direction]
		var end: Vector3=Vector3(stair.cell+direction*stair.run); end.y=level
		if rect.has_point(Vector2(end.x,end.z)): result.append([end,Vector3(stair.cell-direction*stair.run)+Vector3.UP*(level-stair.cell.y)])
	var bridges: Array=world.bridges.values()
	for plan in world.plans.values():
		if plan.kind=="rope_bridge": bridges.append(plan.bridge)
	for bridge in bridges:
		for ends in [[bridge.start,bridge.end],[bridge.end,bridge.start]]:
			if absf(ends[0].y-level)<0.1 and rect.has_point(Vector2(ends[0].x,ends[0].z)): result.append(ends)
	return result

static func rails(entry_: Dictionary,entries: Dictionary) -> Array:
	var result: Array=[]
	for normal: Vector3i in SIDES:
		var edge_start:=result.size()
		var half: float=(entry_.rect.size.y if normal.x else entry_.rect.size.x)/2
		var mid: Vector3=entry_.at+Vector3(normal)*(entry_.rect.size.x/2 if normal.x else entry_.rect.size.y/2)+Vector3.UP*(entry_.height+0.06)
		var tangent:=Vector3(-normal.z,0,normal.x)
		var count:=maxi(1,ceili(half*2/0.25))
		for i in count:
			var a: Vector3=Pose.point(entry_,mid+tangent*lerpf(-half,half,float(i)/count))
			var b: Vector3=Pose.point(entry_,mid+tangent*lerpf(-half,half,float(i+1)/count))
			var point: Vector3=(a+b)/2
			var facing:=Pose.local(entry_,Vector3(normal))
			if not roof_open(entry_,Vector2(point.x,point.z)-Vector2(facing.x,facing.z)*0.08,entries): continue
			var outside:=Vector2(point.x,point.z)+Vector2(facing.x,facing.z)*0.1
			var connected:=false
			# The timber seam is part of the shared walking surface, including small
			# gaps between rotated neighbours. Never fence across that connection.
			var unturned:=Pose.unpoint(entry_,point)
			var across: float=unturned.z if normal.x else unturned.x
			for join in entry_.joins:
				if join.normal==normal and entries[join.other].terrace and absf(entries[join.other].height-entry_.height)<0.01 and across>=join.low and across<=join.high: connected=true
			for other in entries.values():
				if other.cell==entry_.cell: continue
				if other.terrace and absf(other.cell.y+other.height+0.06-point.y)<0.01 and Pose.contains(other,outside): connected=true
				if other.cell.y==roundi(point.y) and Pose.contains(other,outside,0.15): connected=true
			for landing in entry_.landings:
				var near:=Geometry2D.get_closest_point_to_segment(Vector2(point.x,point.z),Vector2(landing[0].x,landing[0].z),Vector2(landing[1].x,landing[1].z))
				if near.distance_to(Vector2(point.x,point.z))<0.65: connected=true
			if connected: continue
			# Adjacent sides meet at a corner, but must never become its diagonal chord.
			if result.size()>edge_start and result.back()[1].is_equal_approx(a): result.back()[1]=b
			else: result.append([a,b])
	return result
