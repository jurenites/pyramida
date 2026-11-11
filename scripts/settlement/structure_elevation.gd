extends RefCounted
## Logical storeys retain their identity while an entire pier stack follows its bearing.
const Foundation = preload("res://scripts/settlement/support_foundation.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
static var cache: Dictionary = {}

static func footprint(world, kind: String, cell: Vector3i, direction := 0, offset := Vector3.ZERO, height := 1) -> Array[Vector3i]:
	return world.Planning.support_cells(world, kind, cell, height, direction, offset)

static func inherited(floors: Dictionary, cells: Array[Vector3i]) -> float:
	for cell in cells:
		if not is_zero_approx(float(floors.get(cell, 0.0))): return float(floors[cell])
	return 0.0

static func maps(world, planned := true) -> Dictionary:
	if world.get("generator_version") == null: return {"bases": {}, "floors": {}, "bearings": {}}
	var records: Array = []
	for cell: Vector3i in world.buildings:
		var data: Dictionary = world.buildings[cell]
		if data.kind not in Catalog.ROOFS and data.kind != "stair": continue
		records.append({"cell":cell,"kind":data.kind,"direction":int(data.direction),"placement_offset":data.get("placement_offset",Vector3.ZERO),"support_yaw":float(data.get("support_yaw",0.0)),"house_tier":int(data.get("house_tier",3))})
	for cell: Vector3i in world.platforms:
		records.append({"cell":cell,"kind":"platform","direction":0,"placement_offset":Vector3.ZERO,"platform_tier":world.Platforms.tier(world.platforms[cell])})
	for cell: Vector3i in world.stairs:
		records.append({"cell":cell,"kind":"stairs","direction":int(world.stairs[cell]),"placement_offset":Vector3.ZERO})
	if planned:
		for plan: Dictionary in world.plans.values():
			if not world.Planning.includes(plan) or plan.get("house_upgrade",false) or (world.buildings.has(plan.cell) and not plan.has("relocation")): continue
			if plan.kind not in Catalog.ROOFS and plan.kind not in ["stair","stairs","platform"]: continue
			records.append({"cell":plan.cell,"kind":plan.kind,"direction":int(plan.direction),"placement_offset":plan.get("placement_offset",Vector3.ZERO),"support_yaw":float(plan.get("support_yaw",0.0)),"platform_tier":int(plan.get("platform_tier",1)),"house_tier":int(plan.get("house_tier",1))})
	var key := hash([world.get_instance_id(),world.world_seed,world.generator_version,world.difficulty,world.terrain_revision,world.volume_edits,world.terrain_excavations,records])
	if cache.get(planned,{}).get("key") == key: return cache[planned].maps
	records.sort_custom(func(a,b):return a.cell.y<b.cell.y)
	var bases := {}; var floors := {}; var bearings := {}
	for entry: Dictionary in records:
		var cell: Vector3i = entry.cell
		var cells := footprint(world,entry.kind,cell,entry.direction,entry.placement_offset,int(entry.get("platform_tier",1)))
		var shift := inherited(bearings,cells)
		bases[cell] = shift
		if entry.kind == "platform":
			for at: Vector3i in world.Grid.support_cells(cell):
				floors[at] = shift; bearings[at] = shift
			continue
		for at: Vector3i in cells: floors[at] = shift
		var roof_shift := shift
		if entry.kind == "support" and Foundation.water(world,cell,entry.placement_offset,float(entry.support_yaw)):
			roof_shift = Foundation.water_level(world) + Foundation.DECK_CLEARANCE - float(cell.y + 1)
		for at: Vector3i in world.structural_roof_cells(cell,entry):
			floors[at] = roof_shift; bearings[at] = roof_shift
	var result := {"bases":bases,"floors":floors,"bearings":bearings}
	cache[planned] = {"key":key,"maps":result}
	return result

static func base_shift(world, cell: Vector3i, kind := "support", direction := 0, offset := Vector3.ZERO, planned := true) -> float:
	if world.get("generator_version") == null: return 0.0
	var layout := maps(world,planned)
	if layout.bases.has(cell): return float(layout.bases[cell])
	return inherited(layout.bearings,footprint(world,kind,cell,direction,offset))

static func level_error(world, kind: String, cell: Vector3i, direction := 0, offset := Vector3.ZERO, height := 1) -> String:
	if kind not in Catalog.ROOFS and kind not in ["stair","stairs","platform"]: return ""
	if kind == "support" and Foundation.water(world,cell,offset): return ""
	var floors: Dictionary = maps(world).bearings
	var cells := footprint(world,kind,cell,direction,offset,height)
	var shift := inherited(floors,cells)
	for at in cells:
		if absf(float(floors.get(at,0.0))-shift)>0.001: return "Supports must meet at one height"
	return ""

static func configure_navigation(world, surfaces: Dictionary) -> void:
	var floors: Dictionary = maps(world,false).floors
	var nav = world.navigation
	for cell: Vector3i in surfaces:
		var shift: float = floors.get(cell,0.0)
		if is_zero_approx(shift): continue
		if nav.room_heights.has(cell): nav.room_heights[cell] += shift
		elif not nav.support_poses.has(cell): nav.room_heights[cell] = cell.y + shift
		if not nav.support_poses.has(cell): nav.support_poses[cell] = Transform3D(Basis.IDENTITY,nav.surface_point(cell))
	for a: Vector3i in nav.room_paths:
		for b: Vector3i in nav.room_paths[a].keys():
			var start_shift: float = floors.get(a,0.0)
			var end_shift: float = floors.get(b,0.0)
			if a.y == b.y and absf(start_shift-end_shift)>0.001:
				nav.room_paths[a].erase(b)
				if nav.room_edges.has(a): nav.room_edges[a].erase(b)
				continue
			var path: Array = nav.room_paths[a][b]
			for index in path.size(): path[index].y += lerpf(start_shift,end_shift,float(index)/maxf(1,path.size()-1))
	# Forward and reverse stair contacts share the same dictionary.
	var adjusted := {}
	for a: Vector3i in nav.room_stair_contacts:
		for data: Dictionary in nav.room_stair_contacts[a].values():
			if adjusted.has(data.key): continue
			data.transform.origin.y += float(floors.get(data.key,0.0))
			adjusted[data.key] = true
