extends RefCounted
## Shared walls, bearings and roof decks; each workplace retains its real equipment.
const Layout=preload("res://scripts/settlement/building_assembly_layout.gd")
const Pose=preload("res://scripts/settlement/home_pose.gd")
const V=preload("res://scripts/settlement/modular_house_view.gd")
const Frame=preload("res://scripts/settlement/structure_frame.gd")
const Cover=preload("res://scripts/settlement/roof_covering.gd")
const Walk=preload("res://scripts/settlement/building_walk_geometry.gd")
const WALL_NAMES=Walk.WALL_NAMES
const ROOF_NAMES=Walk.ROOF_NAMES
static func structural(part: Node3D,entry: Dictionary) -> bool:
	return Walk.structural(part,entry.local_size)
static func hide_source(asset: Node3D,entry: Dictionary,root: Node3D) -> void:
	for child in asset.get_children():
		if child==root or not child is Node3D or child is CollisionObject3D: continue
		if entry.kind=="house": child.visible=false; continue
		if not child.has_meta("assembly_equipment_pose"): child.set_meta("assembly_equipment_pose",child.transform)
		child.transform=Walk.equipment_pose(entry.kind,child,child.get_meta("assembly_equipment_pose"))
		if entry.socket:
			if child.name=="StackSupport": child.visible=not entry.above.is_empty()
			continue
		if structural(child,entry) or str(child.name) in ROOF_NAMES:
			# Keep the approved cloth shade over an unloaded Masonry.
			if child.name=="ClothShade" and not entry.terrace: continue
			child.visible=false
static func sync(world,views: Dictionary) -> void:
	var Homes=load("res://scripts/settlement/home_assembly.gd")
	Homes.ensure(world)
	var entries:=Layout.build(world)
	for asset: Node3D in views.values():
		var cell: Vector3i=asset.get_meta("cell",Vector3i.ZERO)
		if not entries.has(cell) or asset.get_meta("planned",false) or asset.has_meta("construction_parts"): continue
		var entry: Dictionary=entries[cell].duplicate(true)
		if asset.get_meta("asset","")!=entry.kind or entry.kind in ["support","stair"]: continue
		var data: Dictionary=world.buildings[cell]
		entry.local_size=Vector2(Layout.Catalog.Reviewed.size(entry.kind).x,Layout.Catalog.Reviewed.size(entry.kind).z) if Layout.Catalog.Reviewed.has(entry.kind) else Vector2(2,3) if entry.kind=="rope_maker" else Vector2(2,2)
		var uid: int=data.get("home_uid",0)
		var shaft: bool=world.home_utilities.services.get(uid,{}).get("stove",false)
		var seed_: int=hash([world.world_seed,cell,entry.kind])
		var exemplar: Dictionary=data.get("home_exemplar",data.get("assembly_exemplar",V.Exemplars.record(seed_)))
		seed_=int(exemplar.seed)
		var chimney_stack: Array=entries.values().filter(func(other):return other.cell.y>cell.y and other.rect.intersects(entry.rect.grow(0.4))).map(func(other):return [other.cell,other.rect,other.height]) if entry.kind in ["bakery","kiln","tilery"] else []
		var stack_supports: Dictionary=preload("res://scripts/settlement/home_stack.gd").plan(world,cell,data.get("placement_offset",Vector3.ZERO)) if entry.kind=="house" else {"members":[]}
		var stamp: Array=[entry,chimney_stack,entry.above.map(func(at):return entries[at].rect),entry.below.map(func(at):return entries[at].rect),data.get("house_tier",3),shaft,world.stairs,exemplar,stack_supports]
		var name_: String="AssembledHome" if entry.kind=="house" else "AssembledBuilding"
		var root: Node3D=asset.get_node_or_null(name_)
		if root==null or root.get_meta("assembly_stamp",[])!=stamp:
			if root!=null: root.free()
			root=Node3D.new(); root.name=name_; asset.add_child(root); root.rotation.y=-asset.rotation.y
			root.set_meta("assembly_stamp",stamp.duplicate(true)); root.set_meta("exemplar_state",exemplar)
			var profile: Dictionary
			if entry.kind=="house": profile=Homes.profile(world,cell,Homes.members(world,cell))
			else:
				profile=V.Generator.generate([{"id":0,"origin":Vector3.ZERO,"entry":Vector3(1,0,2)}],seed_,1).rooms[0]
				profile.covering=Layout.stock_kind(entry.kind); profile.roof_color=V.P.HAY_FIELD if profile.covering=="hay" else V.Wood.WOOD[0]
			profile.color=V.Generator.wall_colour(cell.y)
			if not entry.socket:
				walls(root,entry,profile,entries)
				for at in entry.posts: Frame.log_member(root,"SharedPost",at,at+Vector3.UP*(entry.height-0.04))
				var rect: Rect2=entry.rect
				for normal: Vector3i in Layout.SIDES:
					var tangent:=Vector3(-normal.z,0,normal.x)
					var half: float=(rect.size.y if normal.x else rect.size.x)/2-0.08
					var mid: Vector3=Vector3(normal)*(rect.size.x/2-0.08 if normal.x else rect.size.y/2-0.08)+Vector3.UP*(entry.height-0.10)
					var shared: Array=entry.joins.filter(func(j):return j.normal==normal and is_zero_approx(j.gap) and is_equal_approx(j.high-j.low,half*2+0.16))
					if shared.is_empty(): Frame.log_member(root,"SharedBearing",Pose.local(entry,mid-tangent*half),Pose.local(entry,mid+tangent*half))
					elif cell<shared[0].other: Frame.log_member(root,"SharedBearing",mid-tangent*half,mid+tangent*half)
				if entry.kind=="house":
					var floor_root:=Node3D.new(); floor_root.name="HomeFloor"; root.add_child(floor_root); floor_root.rotation.y=entry.yaw
					V.deck(floor_root,Rect2(-1,-1,2,2),0.06)
			if entry.terrace:
				terrace(root,entry,entries,world)
			elif not entry.socket and entry.kind not in ["masonry","stone_storage","brickyard"]:
				if entry.kind=="house":
					var roof_root:=Node3D.new(); roof_root.name="Covering"; root.add_child(roof_root); roof_root.rotation.y=entry.yaw; roof_root.position=Pose.local(entry,Vector3(-1,0,-1))
					if shaft: profile.shaft=Vector3(1.35,0,0.35)
					V.roof(roof_root,profile,1)
				else:
					var cover:=Node3D.new(); cover.name="Covering"; root.add_child(cover); cover.set_meta("exemplar_state",exemplar)
					roof(cover,entry,profile,seed_)
			for join in entry.joins:
				if join.gap>0.025 or not is_zero_approx(entry.yaw):
					var size:=Vector3(join.gap+0.30,0.055,0.84) if join.normal.x else Vector3(0.84,0.055,join.gap+0.30)
					V.box(root,size,(join.point+join.far)/2-entry.at+Vector3.UP*0.032,V.Wood.WOOD[0])
			for member in stack_supports.members:
				Frame.log_member(root,"StackPost" if member.kind=="post" else "StackBrace",member.a,member.b)
			if entry.kind in ["bakery","kiln","tilery"]: chimney(root,entry,entries,data)
			V.Exemplars.consolidate(root); V.paint(root)
		hide_source(asset,entry,root)
static func wall_specs(entry: Dictionary,profile: Dictionary,entries: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if entry.open: return result
	for index in 4:
		var normal: Vector3i=Layout.SIDES[index]
		var joins: Array=entry.joins.filter(func(j):return j.normal==normal)
		var length_: float=entry.rect.size.y if normal.x else entry.rect.size.x
		var center: Vector3=Vector3(normal)*(entry.rect.size.x/2-0.05 if normal.x else entry.rect.size.y/2-0.05)
		var spec: Dictionary=profile.walls[index].duplicate(true) if profile.walls.size()==4 else {"opening":"window","offset":0.0,"width":V.Generator.WINDOW_WIDTH}
		spec.side=index; spec.center=center; spec.yaw=PI/2 if normal.x else 0.0; spec.length=length_; spec.height=entry.height-0.15
		if normal==entry.front: spec.opening="door"; spec.offset=0.0; spec.width=0.84
		elif spec.opening=="door": spec.opening="window"; spec.width=V.Generator.WINDOW_WIDTH
		if not joins.is_empty():
			var join: Dictionary=joins[0]
			# A fully shared wall belongs to one room; the other side sees the same portal.
			if is_zero_approx(join.gap) and is_equal_approx(join.high-join.low,length_) and entry.cell>join.other and not entries[join.other].open: continue
			spec.opening="door"; spec.width=0.84
			var local: Vector3=join.point-entry.at
			spec.offset=-local.z if normal.x else local.x
		if joins.is_empty():
			spec.center=Pose.local(entry,spec.center); spec.yaw+=entry.yaw
		result.append(spec)
	return result
static func walls(root: Node3D,entry: Dictionary,profile: Dictionary,entries: Dictionary) -> void:
	for spec in wall_specs(entry,profile,entries): V.wall(root,spec,profile.color)
static func terrace(root: Node3D,entry: Dictionary,entries: Dictionary,world) -> void:
	if entry.kind=="house":
		# A continuous deck under the upper floor closes the small rotated seam.
		var deck_root:=Node3D.new(); deck_root.name="TerraceFloor"; root.add_child(deck_root); deck_root.rotation.y=entry.yaw
		# Keep the relieved deck below the upper room's floor, even where they overlap.
		V.deck(deck_root,Rect2(-1,-1,2,2),entry.height+0.04)
		for join in entry.joins:
			var size:=Vector3(join.gap+0.30,0.055,join.high-join.low) if join.normal.x else Vector3(join.high-join.low,0.055,join.gap+0.30)
			V.box(root,size,(join.point+join.far)/2-entry.at+Vector3.UP*entry.height,V.Wood.WOOD[0])
		for rail in Layout.rails(entry,entries): V.rail(root,rail[0]-entry.at,rail[1]-entry.at,hash([world.world_seed,entry.cell]))
		return
	# Split around upper footprints. Roof planks never cut through an occupied room.
	var xs: Array=[entry.rect.position.x,entry.rect.end.x]; var zs: Array=[entry.rect.position.y,entry.rect.end.y]
	for upper in entry.above:
		var overlap: Rect2=entry.rect.intersection(entries[upper].rect)
		for x in [overlap.position.x,overlap.end.x]: if x not in xs: xs.append(x)
		for z in [overlap.position.y,overlap.end.y]: if z not in zs: zs.append(z)
	xs.sort(); zs.sort()
	for x in xs.size()-1:
		for z in zs.size()-1:
			var rect:=Rect2(xs[x],zs[z],xs[x+1]-xs[x],zs[z+1]-zs[z])
			if not Layout.roof_open(entry,rect.get_center(),entries): continue
			rect.position-=Vector2(entry.at.x,entry.at.z)
			V.deck(root,rect,entry.height+0.06)
	for rail in Layout.rails(entry,entries): V.rail(root,rail[0]-entry.at,rail[1]-entry.at,hash([world.world_seed,entry.cell]))
static func roof(root: Node3D,entry: Dictionary,profile: Dictionary,seed_: int) -> void:
	var width: float=entry.rect.size.x; var depth: float=entry.rect.size.y
	var slope: float=profile.roof_slope; var base: float=entry.height+0.1
	var covering: String=profile.covering
	if not entry.open:
		for z in [-depth/2,depth/2]:
			# The tiny wedge is a closed wall, not a light leak under the covering.
			for i in ceili(width/0.1):
				var x: float=-width/2+(i+0.5)*width/ceili(width/0.1)
				var height: float=0.25+slope*x
				V.box(root,Vector3(width/ceili(width/0.1)+0.002,height,0.1),Vector3(x,entry.height-0.15+height/2,z),profile.color)
	var poses: Array[Transform3D]=[]
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_
	if covering=="hay":
		preload("res://scripts/settlement/thatch_roof.gd").build(root,Rect2(-width/2-0.14,-depth/2-0.14,width+0.28,depth+0.28),base,slope,seed_)
	else:
		for x in V.Timber.centres(width+0.28,V.Timber.BOARD.x):
			for z in V.Timber.centres(depth+0.28,V.Timber.BOARD.z): poses.append(Transform3D(Basis(Vector3.FORWARD,-atan(slope)),Vector3(x,base+slope*x,z)))
		V.Exemplars.batch(root,"plank",poses,root.get_meta("exemplar_state"),"workplace-roof")
static func chimney(root: Node3D,entry: Dictionary,entries: Dictionary,data: Dictionary) -> void:
	var basis:=Basis(Vector3.UP,-int(data.direction)*PI/2)
	var start:=basis*Vector3(0.48,1.85,-1.05)
	# Keep the flue outside all rooms above, with a short shoulder from the oven.
	var top: float=entry.height+0.65
	var at:=start
	if not entry.above.is_empty():
		at=basis*Vector3(entry.local_size.x/2+0.43,1.85,-1.05)
		var outward: Vector3=basis*Vector3.RIGHT
		for upper in entries.values():
			if upper.cell.y<entry.cell.y+entry.height or not upper.rect.intersects(entry.rect.grow(0.4)): continue
			top=maxf(top,upper.cell.y-entry.cell.y+upper.height+0.65)
			if outward.x>0.5: at.x=maxf(at.x,upper.rect.end.x-entry.at.x+0.43)
			elif outward.x < -0.5: at.x=minf(at.x,upper.rect.position.x-entry.at.x-0.43)
			elif outward.z>0.5: at.z=maxf(at.z,upper.rect.end.y-entry.at.z+0.43)
			else: at.z=minf(at.z,upper.rect.position.y-entry.at.z-0.43)
		V.box(root,Vector3(absf(at.x-start.x)+0.28,0.28,absf(at.z-start.z)+0.28),(start+at)/2,V.Resources.colour("brick"))
	V.brick_stack(root,at,ceili((top-at.y)/0.2),"workplace-flue")
