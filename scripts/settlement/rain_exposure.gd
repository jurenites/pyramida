extends RefCounted
## Surface dampness affects hauling, never creates a collectible water source.
const SLOWDOWN := 0.35
const RECOVERY := 1.4
static func roof_cover(world) -> Dictionary:
	var covered: Dictionary={}
	var roofs: Dictionary={}
	for lane in load("res://scripts/settlement/roof_rain.gd").roof_lanes(world).values(): roofs[lane.cell]=lane.ridge.y
	for cell: Vector3i in world.buildings:
		var kind: String=world.buildings[cell].kind
		if kind in ["log_shed","small_warehouse","workshop","sawmill","pantry","hay_barn","school","windmill","mill"]:
			roofs[cell]=world.navigation.surface_point(cell).y+world.Catalog.building_height(kind)
	for base: Vector3i in roofs:
		for x in range(-1,2):
			for z in range(-1,2):
				var key:=Vector2i(base.x+x,base.z+z)
				covered[key]=maxf(covered.get(key,-1000.0),roofs[base])
	return covered
static func built_floor(world,cell: Vector3i) -> bool:
	return world.navigation.room_nodes.has(cell) or world.platforms.has(cell) or world.buildings.get(cell,{}).get("kind") in ["road","support"] or world.buildings.get(cell+Vector3i.DOWN,{}).get("kind")=="support"
static func spill(world,point: Vector3,amount: float) -> void:
	if not world.roof_rain.has("wet"): world.roof_rain.wet={}
	var candidates: Dictionary={}; var height := -10000.0
	for cell: Vector3i in world.navigation.surfaces:
		if absf(cell.x-point.x)>1.1 or absf(cell.z-point.z)>1.1: continue
		var y: float=world.navigation.surface_point(cell).y
		if y<=point.y+0.1: candidates[cell]=y; height=maxf(height,y)
	for cell in candidates:
		if height-candidates[cell]<0.12: world.roof_rain.wet[cell]=minf(1,float(world.roof_rain.wet.get(cell,0))+amount)
static func tick(world) -> void:
	if not world.roof_rain.has("wet"): world.roof_rain.wet={}
	var wet: Dictionary=world.roof_rain.wet
	for cell in wet.keys():
		wet[cell]=maxf(0,float(wet[cell])-0.035)
		if wet[cell]<=0 or not world.navigation.surfaces.has(cell): wet.erase(cell)
	if not world.weather.raining: return
	var roofs:=roof_cover(world)
	for cell: Vector3i in world.navigation.surfaces:
		if not built_floor(world,cell): continue
		if roofs.get(Vector2i(cell.x,cell.z),-10000)>world.navigation.surface_point(cell).y+0.5: continue
		wet[cell]=minf(1,float(wet.get(cell,0))+0.12)
	var rain=load("res://scripts/settlement/roof_rain.gd")
	var lanes: Dictionary=rain.roof_lanes(world,true)
	var all_lanes: Dictionary=rain.roof_lanes(world)
	# Uncollected eaves, disconnected pipes and dead-end junctions visibly spill.
	for key in lanes:
		var drained:=false
		for gutter_id in world.roof_rain.gutters:
			if not rain.overlaps(all_lanes.get(world.roof_rain.gutters[gutter_id].lane,{}),lanes[key]): continue
			var outlet: int=rain.outlet_pipe(world,gutter_id,all_lanes)
			# The pipe carries the runoff away, even when its ground outlet is uncaptured.
			if outlet>=0: drained=true; break
		if not drained: spill(world,lanes[key].b,0.13)
static func movement(world,worker: Dictionary,next: Vector3i,delta: float) -> float:
	var wet: Dictionary=world.roof_rain.get("wet",{})
	var amount:=maxf(wet.get(worker.cell,0),wet.get(next,0))
	if amount>0.45:
		worker.wet_steps=float(worker.get("wet_steps",0))+delta*amount
		if worker.wet_steps>=8.0+worker.id%3:
			worker.wet_steps=0.0; worker.slip_remaining=RECOVERY
			return 0.0
	else: worker.wet_steps=maxf(0,float(worker.get("wet_steps",0))-delta)
	return 1.0-SLOWDOWN*amount
static func recover(worker: Dictionary,delta: float) -> bool:
	if float(worker.get("slip_remaining",0))<=0: return false
	worker.slip_remaining=maxf(0,float(worker.slip_remaining)-delta)
	return true
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()>50000: return false
	for cell in data:
		if not cell is Vector3i or not (data[cell] is int or data[cell] is float) or not is_finite(data[cell]) or data[cell]<0 or data[cell]>1: return false
	return true
