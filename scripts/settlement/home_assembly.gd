extends RefCounted
## Ordinary Home addresses remain authoritative; shared room geometry follows their assembly.
const Houses = preload("res://scripts/settlement/house_groups.gd")
const V = preload("res://scripts/settlement/modular_house_view.gd")
const U = preload("res://scripts/settlement/room_utilities.gd")
const Tiers = preload("res://scripts/settlement/house_tiers.gd")
const UID_BASE := 1000000000
const FLOOR_HEIGHT := 0.06
static var cached_key := ""
static var cached_contexts: Array=[]

class Context extends RefCounted:
	var source
	var room_site: Dictionary
	func _get(property: StringName) -> Variant: return source.get(property)
	func _set(property: StringName, value: Variant) -> bool: source.set(property,value); return true
	func utility_kind() -> String: return "home_utility"
	func utility_states() -> Dictionary:
		var result := {}
		for owner in room_site.utilities:
			if room_site.design.any(func(entry):return entry.uid==owner): result[owner]=room_site.utilities[owner]
		return result
	func rebuild_navigation() -> void: source.rebuild_navigation()
	func request_collect_water(cell: Vector3i) -> bool: return source.request_collect_water(cell)
	func get_instance_id_for_source() -> int: return source.get_instance_id()

static func ensure(world) -> void:
	for cell in world.buildings:
		var home: Dictionary=world.buildings[cell]
		if home.kind!="house": continue
		if not home.has("home_uid"):
			home.home_uid=UID_BASE+int(world.home_utilities.next_id); world.home_utilities.next_id+=1
		if not home.has("home_exemplar"): home.home_exemplar=V.Exemplars.record(int(world.world_seed)^int(home.home_uid))
static func members(world, start: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i]=[start]; var cursor := 0
	while cursor<result.size():
		var at: Vector3i=result[cursor]; cursor+=1
		for direction in Houses.SIDES+[Vector3i.UP,Vector3i.DOWN]:
			var next: Vector3i=at+direction*2
			if next in result or not Houses.is_house(world,next): continue
			if not is_equal_approx(preload("res://scripts/settlement/structure_elevation.gd").base_shift(world,at,"house"),preload("res://scripts/settlement/structure_elevation.gd").base_shift(world,next,"house")): continue
			if direction.y==0 and world.buildings[at].get("placement_offset",Vector3.ZERO)!=world.buildings[next].get("placement_offset",Vector3.ZERO): continue
			if direction.y==0 and not Houses.linked(at,world.buildings[at].direction,next,world.buildings[next].direction): continue
			result.append(next)
	result.sort_custom(func(a,b):return a.y<b.y if a.y!=b.y else (a.x<b.x if a.x!=b.x else a.z<b.z))
	return result
static func terrace(world, cell: Vector3i, group: Array) -> bool:
	var mixed: Dictionary=preload("res://scripts/settlement/building_assembly_layout.gd").build(world).get(cell,{})
	if not mixed.is_empty(): return mixed.above.is_empty() and mixed.terrace
	return false
static func profile(world, cell: Vector3i, group: Array) -> Dictionary:
	var home: Dictionary=world.buildings[cell]
	var record := {"id":0,"origin":Vector3.ZERO,"entry":Vector3(1,0,2)}
	var result: Dictionary=V.Generator.generate([record],int(home.home_exemplar.seed),1).rooms[0]
	for wall in result.walls:
		var direction: Vector3i=[Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK][wall.side]
		if cell+direction*2 in group or direction==Houses.SIDES[home.direction]: wall.opening="door"; wall.offset=0; wall.width=0.84
		elif wall.opening=="door": wall.opening="window"; wall.width=V.Generator.WINDOW_WIDTH
	for wall in result.walls:
		if wall.opening=="window" and V.Generator.aperture(wall).grow(0.12).intersects(AABB(Vector3(0.97,0,-0.03),Vector3(0.76,2.8,0.76))):
			wall.offset=-V.Generator.WINDOW_OFFSET
			if V.Generator.aperture(wall).grow(0.12).intersects(AABB(Vector3(0.97,0,-0.03),Vector3(0.76,2.8,0.76))): wall.opening=""
	result.covering=["hay","plank","imbrex"][Tiers.tier(home)-1]
	result.gutter=false
	# Match the existing walking surface instead of burying boards below land.
	result.color=V.Generator.wall_colour(cell.y)
	result.floor_height=FLOOR_HEIGHT
	result.roof_color=[V.P.HAY_FIELD,V.Wood.WOOD[0],V.Resources.colour("imbrex")][Tiers.tier(home)-1]
	return result
static func contexts(world) -> Array:
	ensure(world)
	var signature: Array=[world.get_instance_id(),preload("res://scripts/settlement/structure_elevation.gd").maps(world).bases,world.buildings.keys().map(func(at):return [at,world.buildings[at].kind,world.buildings[at].get("placement_offset",Vector3.ZERO)]),world.plans.values().filter(func(p):return p.kind=="house").map(func(p):return p.cell)]
	for at in world.buildings:
		var home: Dictionary=world.buildings[at]
		if home.kind=="house": signature.append([at,home.home_uid,home.direction,Tiers.tier(home),home.get("placement_offset",Vector3.ZERO),home.home_exemplar])
	var key := str(signature).sha256_text()
	if key==cached_key: return cached_contexts
	var result: Array=[]; var visited := {}
	for cell in world.buildings:
		if not Houses.is_house(world,cell) or visited.has(cell): continue
		var group := members(world,cell)
		var context := Context.new(); context.source=world
		var records: Array=[]
		var origin: Vector3i=group[0]
		var source_cell: Vector3i=origin
		for candidate in group:
			if candidate.y==origin.y and candidate+Vector3i.UP*2 not in group: source_cell=candidate; break
		for candidate in group:
			if world.home_utilities.services.has(world.buildings[candidate].home_uid): source_cell=candidate; break
		for at in group:
			visited[at]=true
			var home: Dictionary=world.buildings[at]
			var local: Vector3i=(at-origin)/2
			var normal: Vector3i=Houses.SIDES[home.direction]
			records.append({"id":records.size(),"uid":home.home_uid,"building_id":world.buildings[origin].home_uid,"shape":"room_domino","cells":[U.Rooms.Layout.arr(local)],"normal":U.Rooms.Layout.arr(normal),"door":U.Rooms.Layout.arr(local),"braces":[],"access_path":[],"color":0,
				"home_cell":at,"home_offset":home.get("placement_offset",Vector3.ZERO),"home_roof":not terrace(world,at,group),"home_profile":profile(world,at,group),
				"generated":{"v":1,"seed":0,"source":0 if at==source_cell else 1,"yaw":0,"exemplar":home.home_exemplar}})
		context.room_site={"origin":origin,"design":records,"built":records,"beds":[],"next_id":UID_BASE+int(world.home_utilities.next_id),"utilities":world.home_utilities.services}
		result.append(context)
	cached_key=key; cached_contexts=result
	return result
static func reset_cache() -> void:
	cached_key=""; cached_contexts=[]
	preload("res://scripts/settlement/building_assembly_layout.gd").cached_key=""
static func context_for(world, owner: int):
	for context in contexts(world):
		if context.room_site.design.any(func(entry):return entry.uid==owner): return context
	return null
static func tick(world, delta: float) -> void:
	if world.home_utilities.services.is_empty(): return
	for context in contexts(world): U.tick(context,delta)
static func rain_second(world) -> void:
	if world.home_utilities.services.is_empty(): return
	for context in contexts(world): U.rain_second(context)
static func sync(world, views: Dictionary) -> void:
	preload("res://scripts/settlement/building_assembly.gd").sync(world,views)
class ValidationWorld extends RefCounted:
	var buildings: Dictionary
	var plans: Dictionary={}

static func valid(data: Variant, buildings: Dictionary, plans: Dictionary={}) -> bool:
	if not data is Dictionary or not data.get("next_id") is int or data.next_id<1 or not data.get("services") is Dictionary: return false
	var ids := {}
	for home in buildings.values():
		if not home is Dictionary: return false
		if not home.has("home_uid"): continue
		if not home.get("direction") is int or home.direction<0 or home.direction>3 or not home.get("placement_offset",Vector3.ZERO) is Vector3: return false
		if home.kind!="house" or not home.home_uid is int or home.home_uid<UID_BASE or home.home_uid>=UID_BASE+data.next_id or ids.has(home.home_uid): return false
		if not V.Exemplars.valid(home.get("home_exemplar")): return false
		ids[home.home_uid]=true
	for owner in data.services:
		if not ids.has(owner): return false
	var records: Array=[]
	var test_world := ValidationWorld.new(); test_world.buildings=buildings
	for cell in buildings:
		var home: Dictionary=buildings[cell]
		if home.has("home_uid"):
			var group := members(test_world,cell)
			records.append({"uid":home.home_uid,"building_id":buildings[group[0]].home_uid,"home_cell":cell,"generated":{"source":0}})
	for service in data.services.values():
		if not service.get("barrel_cell") is Vector3i: return false
	return U.valid({"utilities":data.services,"design":records},plans,true)

static func has_utilities(world, cell: Vector3i) -> bool:
	if not Houses.is_house(world,cell): return false
	for member in members(world,cell):
		if world.home_utilities.services.has(world.buildings[member].get("home_uid",-1)): return true
	return false

static func configure_navigation(world, surfaces: Dictionary) -> void:
	ensure(world)
	var nav=world.navigation
	var envelopes: Dictionary=preload("res://scripts/settlement/building_assembly_layout.gd").build(world)
	var linker=preload("res://scripts/settlement/room_navigation.gd")
	for cell in world.buildings:
		if not Houses.is_house(world,cell): continue
		var home: Dictionary=world.buildings[cell]
		var group := members(world,cell)
		var offset: Vector3=home.get("placement_offset",Vector3.ZERO)
		# Home centres and actual doorway thresholds become walkable room nodes.
		nav.room_offsets[cell]=offset
		surfaces[cell]=true; nav.blocked.erase(cell); nav.room_nodes[cell]=home.home_uid; nav.room_heights[cell]=cell.y+FLOOR_HEIGHT
		for direction in Houses.SIDES:
			var joined: bool=cell+direction*2 in group
			var portals: Array=envelopes[cell].joins.filter(func(join):return join.normal==direction)
			if not joined and direction!=Houses.SIDES[home.direction] and portals.is_empty(): continue
			var door: Vector3i=cell+direction
			var outside: Vector3i=cell+direction*2
			var threshold: Vector3=preload("res://scripts/settlement/home_pose.gd").point(envelopes[cell],Vector3(door)+offset) if portals.is_empty() else portals[0].point
			var occupied_outside: bool=envelopes.values().any(func(other):return other.cell!=cell and other.cell.y==cell.y and other.rect.grow(-0.01).has_point(Vector2(outside.x,outside.z)))
			if portals.is_empty() and not joined and occupied_outside: continue
			nav.room_offsets[door]=threshold-Vector3(door)
			surfaces[door]=true; nav.blocked.erase(door); nav.room_nodes[door]=home.home_uid; nav.room_heights[door]=door.y+FLOOR_HEIGHT
			linker.link(nav.room_edges,cell,door)
			linker.add_path(nav,cell,door,[Vector3(cell)+offset+Vector3.UP*FLOOR_HEIGHT,threshold-Vector3(direction)*0.30+Vector3.UP*FLOOR_HEIGHT,threshold+Vector3.UP*FLOOR_HEIGHT])
			# Mixed rooms use their equipment-safe interior path, not a centre shortcut.
			var mixed: bool=not portals.is_empty() and envelopes[portals[0].other].kind!="house"
			var obstructed: bool=envelopes.values().any(func(other):return other.cell!=cell and other.cell.y==cell.y and other.rect.grow(-0.01).has_point(Vector2(outside.x,outside.z)))
			if mixed or (obstructed and not joined): continue
			linker.link(nav.room_edges,door,outside)
			linker.add_path(nav,door,outside,[threshold+Vector3.UP*FLOOR_HEIGHT,Vector3(outside)+(offset if joined else Vector3.ZERO)+Vector3.UP*FLOOR_HEIGHT])
	for context in contexts(world):
		for owner in U.states(context):
			if U.state(context,owner).rain: nav.blocked[U.barrel_cell(context,owner)]=true
	# Resolve shared thresholds after every room/terrace has supplied its physical pose.
	for a in nav.room_edges:
		for b in nav.room_edges[a]:
			if int(nav.room_nodes.get(a,-1))>=UID_BASE or int(nav.room_nodes.get(b,-1))>=UID_BASE:
				if not nav.room_paths.get(a,{}).has(b): linker.add_path(nav,a,b,[nav.surface_point(a),nav.surface_point(b)])
				else:
					nav.room_paths[a][b][0]=nav.surface_point(a)
					nav.room_paths[a][b][-1]=nav.surface_point(b)
