extends RefCounted
## Clearance comes from retained equipment and the same structural pieces as rendering.
const Catalog=preload("res://data/settlement/catalog.gd")
const RADIUS:=0.18
const BODY_HEIGHT:=1.50
const WALL_NAMES=["Walls","Frame","ShadeFrame","PlasterWall","PlasterWall2","BackWall","DoorSide","DoorSide2","DoorLintel","JoinedWalls","SharedPosts","ConnectedFrame"]
const ROOF_NAMES=["Roof","Canopy","JoinedRoof","ProceduralRoof","ClothShade","ShedRoof","BarnRoof","StackSupport"]
static var cache: Dictionary={}
static var floors: Dictionary={}
static func floor_height(entry: Dictionary) -> float:
	if entry.kind=="house": return 0.06
	local_boxes(entry)
	return floors.get(str([entry.kind,load("res://scripts/settlement/building_appearance.gd").revision,entry.get("state",{})]),0.0)
static func structural(part: Node3D,size: Vector2) -> bool:
	var label:=str(part.name)
	if label in WALL_NAMES: return true
	for prefix in ["ShedPost","Post","SideRail","EndRail","Upper","RoofBearer","HighRiser","Rail"]:
		if label.begins_with(prefix): return true
	if part is MeshInstance3D and label.begins_with("@MeshInstance"):
		var box: AABB=part.transform*part.mesh.get_aabb()
		var center:=box.get_center()
		if box.size.y>0.6 and box.size.x<0.3 and box.size.z<0.3 and absf(center.x)>size.x/2-0.3 and absf(center.z)>size.y/2-0.3: return true
		if box.size.y<0.3 and ((box.size.x>size.x*0.7 and absf(center.z)>size.y/2-0.3) or (box.size.z>size.y*0.7 and absf(center.x)>size.x/2-0.3)): return true
	return false
static func equipment_offset(kind: String,label: String) -> Vector3:
	# Leave a clear front/side aisle around the working oven, inside its existing room.
	if kind in ["bakery","kiln","tilery"] and label in ["Oven","Opening","Embers","Loaf","Flue"]: return Vector3(0,0,-0.30)
	return Vector3.ZERO
static func equipment_pose(kind: String,part: Node3D,original: Transform3D) -> Transform3D:
	if kind=="tilery" and part is MeshInstance3D:
		var box: AABB=original*part.mesh.get_aabb()
		if box.position.z>0.65 and box.end.y<1.2:
			# Turn the complete moulding bench and its tile samples against the side.
			var basis:=Basis(Vector3.UP,PI/2)
			return Transform3D(basis,Vector3(0.65,0,0.8)-basis*Vector3(0,0,1.03))*original
	var result:=original; result.origin+=equipment_offset(kind,str(part.name)); return result
static func visible(part: Node3D,root: Node3D) -> bool:
	var node: Node3D=part
	while node!=root:
		if not node.visible: return false
		node=node.get_parent()
	return true
static func local_size(kind: String) -> Vector2:
	if Catalog.Reviewed.has(kind):
		var size:=Catalog.Reviewed.size(kind); return Vector2(size.x,size.z)
	return Vector2(2,3) if kind=="rope_maker" else Vector2(2,2)
static func local_boxes(entry: Dictionary) -> Array[AABB]:
	var Appearance=load("res://scripts/settlement/building_appearance.gd")
	var signature: Array=[entry.kind,Appearance.revision,entry.get("state",{})]
	var key:=str(signature)
	if cache.has(key): return cache[key]
	var result: Array[AABB]=[]
	# Home's retained contents are its separately installed utilities, handled below.
	if entry.kind=="house": cache[key]=result; return result
	var root: Node3D=load("res://scripts/settlement/asset_library.gd").create(entry.kind)
	if entry.kind=="windmill": load("res://scripts/settlement/mill_view.gd").sync(root,int(entry.state.get("mill_tier",3)))
	if entry.kind=="sawmill": load("res://scripts/settlement/sawmill_view.gd").sync(root,int(entry.state.get("sawmill_tier",2)))
	if entry.kind=="stone_storage": load("res://scripts/settlement/stone_storage_view.gd").sync(root,int(entry.state.get("storage_tier",1)))
	var size:=local_size(entry.kind)
	var floor_top:=0.0
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null or not visible(mesh,root): continue
		var direct: Node3D=mesh
		while direct.get_parent()!=root: direct=direct.get_parent()
		if not entry.socket and (structural(direct,size) or str(direct.name) in ROOF_NAMES): continue
		var pose:=mesh.transform; var parent: Node3D=mesh.get_parent()
		while parent!=root: pose=parent.transform*pose; parent=parent.get_parent()
		var box: AABB=pose*mesh.mesh.get_aabb()
		box=equipment_pose(entry.kind,direct,direct.transform)*direct.transform.affine_inverse()*box
		if box.end.y<=0.23 and box.size.x>=size.x*0.7 and box.size.z>=size.y*0.7: floor_top=maxf(floor_top,box.end.y)
		if box.end.y<=0.23 or box.position.y>=BODY_HEIGHT+0.20: continue
		result.append(box)
	root.free()
	floors[key]=floor_top
	cache[key]=result
	return result
static func boxes(entry: Dictionary,world=null) -> Array[AABB]:
	var result: Array[AABB]=[]
	var pose:=Transform3D(Basis(Vector3.UP,-int(entry.direction)*PI/2),entry.at)
	for box in local_boxes(entry): result.append(pose*box)
	if not entry.socket:
		for point in entry.posts:
			result.append(AABB(entry.at+point-Vector3(0.115,0,0.115),Vector3(0.23,entry.height,0.23)))
	if world!=null and entry.kind=="house":
		var uid: int=world.buildings[entry.cell].get("home_uid",-1)
		if world.home_utilities.services.get(uid,{}).get("stove",false):
			result.append(Transform3D(Basis(Vector3.UP,float(entry.get("yaw",0))),entry.at)*AABB(Vector3(-0.03,0,-1.03),Vector3(0.76,2.8,0.76)))
	if world!=null:
		result.append_array(stock_boxes(world,entry))
		for cell in world.buildings:
			var data: Dictionary=world.buildings[cell]
			if data.kind!="house" or cell.y<=entry.cell.y or cell.y>entry.cell.y+entry.height: continue
			var offset: Vector3=data.get("placement_offset",Vector3.ZERO)
			for brace in preload("res://scripts/settlement/home_stack.gd").braces(world,cell,offset):
				var a: Vector3=Vector3(cell)+offset+brace[0]; var b: Vector3=Vector3(cell)+offset+brace[1]
				result.append(preload("res://scripts/settlement/structure_frame.gd").log_bounds(a,b))
	return result
static func rectangles(entry: Dictionary,world=null) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	for box in boxes(entry,world):
		if box.end.y<=entry.at.y+0.23 or box.position.y>=entry.at.y+BODY_HEIGHT+maxf(0.06,floor_height(entry)): continue
		var rect:=Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(RADIUS+0.01)
		# Smaller pieces completely inside another solid don't complicate routing.
		if result.any(func(other):return other.encloses(rect)): continue
		result=result.filter(func(other):return not rect.encloses(other))
		result.append(rect)
	return result
static var cargo_bounds: Dictionary={}
static func resource_bounds(resource: String) -> AABB:
	if cargo_bounds.has(resource): return cargo_bounds[resource]
	var asset: String={"food":"bread","stone":"raw_stone","block":"block"}.get(resource,resource)
	var root: Node3D=load("res://scripts/settlement/asset_library.gd").create(asset)
	var result:=AABB(); var first:=true
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		var pose:=mesh.transform; var parent: Node3D=mesh.get_parent()
		while parent!=root: pose=parent.transform*pose; parent=parent.get_parent()
		var box: AABB=pose*mesh.mesh.get_aabb()
		result=box if first else result.merge(box); first=false
	root.free(); cargo_bounds[resource]=result
	return result
static func stock_boxes(world,entry: Dictionary) -> Array[AABB]:
	var result: Array[AABB]=[]
	if not world.stores.has(entry.cell) or entry.kind=="house": return result
	var inventory=world.stores[entry.cell]
	var pose:=Transform3D(Basis(Vector3.UP,-entry.direction*PI/2),entry.at)
	var Stock=preload("res://scripts/settlement/stored_goods_layout.gd")
	if entry.kind=="stone_storage":
		inventory.enable_slots()
		for item in preload("res://scripts/settlement/stone_storage_view.gd").stock_layout(inventory,entry.cell,world.world_seed): result.append(pose*item.pose*item.mesh.get_aabb())
		return result
	if entry.kind not in ["goods_rack","small_warehouse"]:
		for index in mini(12,inventory.count("log")): result.append(pose*Stock.log_pose(entry.kind,index)*resource_bounds("log"))
	var slot:=0
	for resource in Stock.RESOURCES:
		var amount: int=inventory.count(resource)
		if entry.kind in ["goods_rack","small_warehouse"]: amount=mini(amount,maxi(0,8-slot))
		for index in (amount if resource in ["stone","block","pottery"] else mini(amount,4)):
			var bounds:=resource_bounds(resource)
			if resource in ["stone","block"]:
				var Stone=preload("res://scripts/settlement/stone_view.gd")
				var seed_value: int=Stone.Random.world_coordinate_seed(entry.cell.x,entry.cell.z,world.world_seed,610+index)
				bounds=(Stone.block_mesh(seed_value) if resource=="block" else Stone.raw_mesh(seed_value)).get_aabb()
			result.append(pose*Stock.cargo_pose(entry.kind,resource,slot)*bounds); slot+=1
	return result
