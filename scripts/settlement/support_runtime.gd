extends RefCounted
const Assembly = preload("res://scripts/settlement/support_assembly.gd")
const Foundation = preload("res://scripts/settlement/support_foundation.gd")
const MAX_YAW := PI / 12.0

static func ordered(world) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for cell: Vector3i in world.buildings:
		if world.buildings[cell].kind == "support": result.append(cell)
	result.sort_custom(func(a: Vector3i,b: Vector3i):
		var aa: int = world.buildings[a].get("support_order",-1)
		var bb: int = world.buildings[b].get("support_order",-1)
		return a < b if aa==bb else aa<bb)
	return result

static func assembly(world, cells: Array[Vector3i]):
	var result := Assembly.new()
	for cell in cells:
		var data: Dictionary = world.buildings[cell]
		result.add(Vector3(cell)+data.get("placement_offset",Vector3.ZERO)+Vector3.UP*(Foundation.deck_drop(world,cell,data.get("placement_offset",Vector3.ZERO),float(data.get("support_yaw",0.0)))+preload("res://scripts/settlement/structure_elevation.gd").base_shift(world,cell)),float(data.get("support_yaw",0.0)),int(data.get("support_group",-1)))
	return result

static func complete(world, cell: Vector3i, yaw: float) -> void:
	# Persist ownership before another building can claim a nearby bearing.
	var cells := ordered(world); cells.erase(cell)
	var layout = assembly(world,cells)
	var order := 0
	for index in cells.size():
		var data: Dictionary = world.buildings[cells[index]]
		if not data.has("support_group"): data.support_group = layout.groups[index]
		if not data.has("support_order"): data.support_order = order
		order = maxi(order,int(data.support_order)+1)
	var data: Dictionary = world.buildings[cell]
	data.support_yaw = yaw; data.support_order = order
	data.support_group = layout.group_for(Vector3(cell)+data.get("placement_offset",Vector3.ZERO)+Vector3.UP*(Foundation.deck_drop(world,cell,data.get("placement_offset",Vector3.ZERO),yaw)+preload("res://scripts/settlement/structure_elevation.gd").base_shift(world,cell)),yaw)

static func valid(data: Dictionary) -> bool:
	var yaw: Variant = data.get("support_yaw",0.0)
	if not (yaw is int or yaw is float) or not is_finite(float(yaw)) or absf(yaw)>MAX_YAW+0.00001: return false
	for key in ["support_group","support_order"]:
		if data.has(key) and (not data[key] is int or data[key]<0): return false
	return true

static func foundation_error(world, cell: Vector3i, offset: Vector3, yaw: float, ignored_plan_id := -1, ignored_cell: Variant = null, allow_planned := true) -> String:
	if not is_finite(yaw) or absf(yaw)>MAX_YAW+0.00001: return "Support angle is too large"
	for other: Vector3i in world.buildings:
		var data: Dictionary = world.buildings[other]
		if other==ignored_cell: continue
		if data.kind=="support" and Assembly.overlaps(Vector3(cell)+offset,yaw,Vector3(other)+data.get("placement_offset",Vector3.ZERO),float(data.get("support_yaw",0.0))): return "Support frames overlap"
	for plan: Dictionary in world.plans.values():
		if int(plan.id)!=ignored_plan_id and plan.kind=="support" and not world.Deconstruction.is_salvage(plan) and Assembly.overlaps(Vector3(cell)+offset,yaw,Vector3(plan.cell)+plan.get("placement_offset",Vector3.ZERO),float(plan.get("support_yaw",0.0))): return "Support frames overlap"
	var basis := Basis(Vector3.UP,yaw)
	for corner: Vector3 in Assembly.CORNERS:
		var point := Vector3(cell)+offset+basis*(corner*0.76)
		var carried := false
		for below: Vector3i in world.buildings:
			var data: Dictionary = world.buildings[below]
			if data.kind!="support" or below.y+1!=cell.y: continue
			var local: Vector3 = Basis(Vector3.UP,float(data.get("support_yaw",0.0))).inverse()*(point-Vector3(below)-data.get("placement_offset",Vector3.ZERO))
			if absf(local.x)<=0.501 and absf(local.z)<=0.501: carried=true; break
		if allow_planned and not carried:
			for plan: Dictionary in world.plans.values():
				if plan.kind!="support" or int(plan.id)==ignored_plan_id or plan.cell.y+1!=cell.y or world.Deconstruction.is_salvage(plan): continue
				var local: Vector3 = Basis(Vector3.UP,float(plan.get("support_yaw",0.0))).inverse()*(point-Vector3(plan.cell)-plan.get("placement_offset",Vector3.ZERO))
				if absf(local.x)<=0.501 and absf(local.z)<=0.501: carried=true; break
		if carried: continue
		var depth := Foundation.depth(world, point)
		if depth < 0: return "Posts must reach the seabed"
		if depth > 0:
			var top := Foundation.deck_height(world,cell,offset,yaw)
			if Foundation.earth(world, Vector3(point.x, top + 0.04, point.z)): return "Keep the deck clear of the shore"
			continue
		if world.SolidIslands.enabled(world) and world.SolidIslands.solid(world,point-Vector3.UP*0.02): continue
		var floor_cell := Vector3i(roundi(point.x),cell.y,roundi(point.z))
		if world.buildings.get(floor_cell+Vector3i.DOWN,{}).get("kind","")=="support": return "Support every post"
		if not world.supports_build_cell(floor_cell):
			if not allow_planned or not world.Planning.supports(world,floor_cell,world.Planning.platforms(world,ignored_plan_id),ignored_plan_id): return "Support every post"
		if world.terrain_shapes.has(floor_cell): return "Choose level ground"
	return ""

static func carries_neighbor(world,cell: Vector3i) -> bool:
	if not world.buildings.get(cell,{}).has("support_group"): return false
	var cells := ordered(world)
	var owner := cells.find(cell)
	if owner<0: return false
	var fitted = assembly(world,cells)
	for layout in fitted.layouts():
		if owner in layout.borrowed: return true
	return false
