extends RefCounted
## Additive adapter: generated room plans use existing delivery, labour and save records.
const Rules = preload("res://scripts/settlement/modular_house_rules.gd")
const Rooms = preload("res://scripts/settlement/room_construction.gd")
const Exemplars = preload("res://scripts/settlement/material_exemplars.gd")
const Utilities = preload("res://scripts/settlement/room_utilities.gd")
const VERSION := 1

class Candidate extends RefCounted:
	const Catalog = preload("res://data/settlement/catalog.gd")
	var source
	var room_site: Dictionary
	func _get(property: StringName) -> Variant: return source.get(property)

static func prepare(world, anchor: Vector3i, seed_: int, yaw := 0) -> Dictionary:
	var proxy := Candidate.new(); proxy.source = world
	proxy.room_site = Rooms.fresh(anchor) if world.room_site.is_empty() else world.room_site.duplicate(true)
	var delta: Vector3i = anchor - proxy.room_site.origin
	if posmod(delta.x, 2) != 0 or posmod(delta.z, 2) != 0 or delta.y != 0: return {"error":"Align with existing room grid"}
	var offset := Vector3i(delta.x / 2, 0, delta.z / 2)
	var design = Rooms.layout(proxy)
	var owner := 1
	for room in design.rooms: owner = maxi(owner, int(room.building_id) + 1)
	var records := Rules.layout(seed_)
	var modules: Array[Dictionary] = []
	for record in records:
		var local := Vector3i((record.origin + Vector3(2, 0, 1)) / 2)
		modules.append({"local":local,"shape":"room_domino","source":int(record.id)})
	# Each uncovered lower roof is an accessible open terrace at the same storey.
	for record in records:
		if record.origin.y != 0 or records.any(func(other):return other.origin == record.origin + Vector3.UP * 2): continue
		modules.append({"local":Vector3i((record.origin + Vector3(2, 2, 1)) / 2),"shape":"cube","source":-1})
	modules.append({"local":Vector3i(-1,0,0),"shape":"stairs","source":-1})
	# Doors form a spanning access graph on each floor, rooted in the entrance
	# and terrace. No room receives a door into an absent neighbour.
	var parents := {}; var reached: Array[Vector3i] = [Vector3i.ZERO]
	for spec in modules:
		if spec.shape == "cube": reached.append(spec.local)
	var cursor := 0
	while cursor < reached.size():
		var parent: Vector3i = reached[cursor]; cursor += 1
		for spec in modules:
			var d: Vector3i = parent - spec.local
			if spec.local in reached or d.y != 0 or absi(d.x) + absi(d.z) != 1: continue
			parents[spec.local] = d; reached.append(spec.local)
	var added: Array = []
	for spec in modules:
		var cell: Vector3i = Rooms.Layout.rotate_point(spec.local,yaw) + offset
		var normal := Vector3i.RIGHT if spec.shape == "stairs" else (Vector3i.BACK if spec.local.x == 0 else Vector3i.LEFT)
		if spec.local.z < 0: normal = Vector3i.BACK
		if parents.has(spec.local) and spec.shape != "stairs": normal = parents[spec.local]
		normal = Rooms.Layout.rotate_point(normal,yaw)
		var room := {"id":design.rooms.size(),"shape":spec.shape,"color":0,"cells":[Rooms.Layout.arr(cell)],"door":Rooms.Layout.arr(cell),"normal":Rooms.Layout.arr(normal),"braces":[],"access_path":[],"building_id":owner,"groups":[],"frame_cells":[],
			"generated":{"v":VERSION,"seed":seed_,"source":spec.source,"yaw":yaw,"exemplar":Exemplars.record(int(world.world_seed) ^ (owner * 104729) ^ seed_)}}
		design.rooms.append(room); added.append(room)
	var error := Rooms.placement_error(proxy,design)
	# Preview utility recipes against prospective room IDs, without mutating the live site.
	var estimate := Candidate.new(); estimate.source=world; estimate.room_site=proxy.room_site.duplicate(true)
	for i in added.size(): added[i].uid=int(proxy.room_site.next_id)+i
	estimate.room_site.design=design.rooms
	var utility_materials := Utilities.installation_cost(estimate,added[0].uid)
	var barrel := Utilities.barrel_cell(estimate,added[0].uid)
	if not world.ground.has(barrel) or world.water_sources.has(barrel): error="Container needs clear ground"
	for collection in [world.buildings,world.stores,world.trees,world.wells]:
		if collection.has(barrel): error="Container space occupied"
	var bed_cells: Array = []
	for room in added:
		if room.shape == "room_domino" and design.room_ports(room,design.rooms).size()==1: bed_cells.append(Rooms.Layout.vec(room.cells[0]))
	var materials := utility_materials.duplicate()
	materials.log=int(materials.get("log",0))+bed_cells.size()*2+modules.reduce(func(total,spec):return total + Rooms.COSTS["room_stair" if spec.shape == "stairs" else ("room_frame" if spec.shape == "cube" else "room_shell")],0)
	return {"error":error,"design":design,"site":proxy.room_site,"added":added,"seed":seed_,"anchor":anchor,"beds":bed_cells,"materials":materials,"cost":materials.values().reduce(func(a,b):return a+b,0)}

static func commit(world, proposal: Dictionary) -> bool:
	if not proposal.get("error", "Invalid plan").is_empty(): return false
	var previous: Dictionary = world.room_site
	if world.room_site.is_empty(): world.room_site = proposal.site
	if not Rooms.commit(world,proposal.design): world.room_site = previous; return false
	# Beds are real construction jobs and remain unavailable until their room exists.
	for cell: Vector3i in proposal.beds: Rooms.add_bed(world,cell)
	var source: Dictionary=world.room_site.design.filter(func(entry):return entry.building_id==proposal.added[0].building_id and entry.get("generated",{}).get("source",-1)==0)[0]
	Utilities.install(world,source.uid)
	return true

static func valid(data: Variant) -> bool:
	return data is Dictionary and data.get("v") == VERSION and data.get("seed") is int and data.get("source") is int and data.source >= -1 and data.source < Rules.layout(data.seed).size() and data.get("yaw") is int and data.yaw in [0,1,2,3] and Exemplars.valid(data.get("exemplar"))
