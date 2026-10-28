extends SceneTree
const Model = preload("res://scripts/block_city/model.gd")
const Cable = preload("res://scripts/block_city/cable.gd")
const Neighbourhood = preload("res://scripts/block_city/neighbourhood.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var m = Model.new()
	check(m.validate_config().is_empty(),"Valid shape configuration")
	check(m.config.shapes.filter(func(shape):return not shape.get("palette_hidden",false)).size()==9,"Nine visible shapes include the placeable small pole")
	for shape in m.config.shapes:
		check(shape.get("role","")=="pole" or shape.cells.all(func(p): return p[1]==0),"Room shapes remain flat; poles reserve their vertical clearance")
		for yaw in 4:
			var f: Dictionary = m.oriented({"shape":shape.id},yaw)
			check(f.cells.size()==shape.cells.size() and f.cells.has(f.door),"Yaw preserves room and door")
			var before: Array = shape.cells.map(func(p): return int(p[1]))
			var after: Array = f.cells.map(func(p): return p.y)
			before.sort(); after.sort()
			check(before==after,"Rotation never tips a room")
	var card := {"shape":"rectangle","color":0}
	check(m.landing(card,0,0).ok,"Initial room lands")
	check(not m.landing(card,-1,0).ok,"Ground-level construction stays inside the lot")
	m.queue[0] = card
	check(m.drop(0,0),"Drop initial room")
	check(m.landing(card,-1,0).ok,"One-cell upper overhang is allowed beyond the lot")
	check(m.landing(card,-1,0).origin.y==1,"Overhang leaves the passage at ground level")
	check(not m.landing(card,-2,0).ok,"Two-cell external overhang is rejected")
	check(not m.fits([Vector3i(0,9,0)],{},{},false),"Ceiling enforced")
	check(not m.fits([Vector3i(0,-4,0)],{},{},true),"Bedrock enforced")
	check(m.support([Vector3i(0,1,0),Vector3i(1,1,0)],{Vector3i(0,0,0):0},false).ok,"One-cell brace")
	check(not m.support([Vector3i(0,1,0),Vector3i(1,1,0),Vector3i(2,1,0)],{Vector3i(0,0,0):0},false).ok,"Braces cannot chain")
	var overhang := {Vector3i(0,0,0):0,Vector3i(0,1,0):1,Vector3i(1,1,0):1}
	check(not m.support([Vector3i(1,2,0)],overhang,false).ok,"A cantilever cannot become a load-bearing column")
	check(not m.support([Vector3i(0,2,0),Vector3i(1,2,0)],overhang,false).ok,"Stacking a whole floor over a cantilever is rejected")
	check(not m.support([Vector3i(0,2,0),Vector3i(1,2,0),Vector3i(2,2,0)],overhang,false).ok,"Cantilevers cannot staircase outward")
	check(m.support([Vector3i(0,2,0)],overhang,false).ok,"Grounded columns can still grow")
	check(m.powered_cells().is_empty(),"New rooms have no implicit electricity")
	check(m.connect_power(Vector3i(0,0,0),Vector3i.FORWARD),"Visible front edge accepts cable")
	check(m.powered_cells().size()==6,"One cable powers touching cells on the same floor")
	check(not m.connect_power(Vector3i(0,0,0),Vector3i.FORWARD),"Duplicate cable is rejected")
	check(m.connection(Vector3i(1,0,2),Vector3i.BACK).ok,"Cable intersections no longer reject a far-wall connection")
	check(not m.connection(Vector3i(0,0,0),Vector3i.RIGHT).ok,"Internal shared face has no socket")
	m.queue[0] = {"shape":"rectangle","color":1}
	check(m.drop(0,0),"Stack another floor")
	check(m.powered_cells().size()==6 and not m.powered_cells().has(Vector3i(0,1,0)),"Power never spreads vertically")
	check(m.connect_power(Vector3i(0,1,0),Vector3i.FORWARD),"Second floor needs its own cable")
	check(m.powered_cells().size()==12,"Both directly wired floors are powered")
	var points := Cable.curve(Cable.socket(Vector3i(0,1,0),Vector3i.FORWARD))
	check(points[0]==Cable.POLE,"Cable starts at pole")
	check(points[-1].is_equal_approx(Cable.socket(Vector3i(0,1,0),Vector3i.FORWARD)),"Cable ends at chosen wall")
	check(points[12].y < points[0].lerp(points[-1],0.5).y,"Cable visibly sags")
	check(m.has_access(m.rooms[0]),"Ground door reaches pedestrian passage")
	check(not m.has_access(m.rooms[1]),"Cable does not create stairs")
	check(m.connect_room(1),"Door action builds real access")
	check(m.has_access(m.rooms[1]),"Explicit pedestrian route connects upper door")
	var state: Dictionary = m.snapshot()
	check(not state.has("credits") and not state.has("forecast") and not m.rooms[0].has("enabled") and not m.rooms[0].has("kind"),"Removed mechanics are absent from state")
	check(m.save_game("/tmp/block-city-v2-test.json"),"Atomic save")
	var loaded = Model.new()
	check(loaded.load_game("/tmp/block-city-v2-test.json"),"Load version 2")
	check(loaded.snapshot()==state,"Round trip preserves grid, cable endpoints and queue")
	check(m.undo() and not m.has_access(m.rooms[1]),"Undo access independently of cable")
	check(m.undo() and m.powered_cells().size()==6,"Undo second cable independently of room")
	m = Model.new()
	check(m.drop(0,0,0,true),"Basement placement remains supported")
	check(not m.connection(Vector3i(0,-1,0),Vector3i.FORWARD).ok,"Underground rooms cannot be wired through soil")
	m = Model.new()
	m.queue[0] = card
	check(m.drop(1,0),"Place room away from pole")
	check(m.connect_power(Vector3i(2,0,0),Vector3i.FORWARD),"Longer visible cable")
	check(m.fits([Vector3i(0,3,-1)],{},{},false),"Existing cables do not block future construction")
	var plan := Neighbourhood.layout(m.config)
	check(plan.plot==Rect2(0,0,3,3),"Exact 3x3 foundation")
	check(plan.roads[0].size.y==3,"Front road is wider than two tiles")
	check(plan.roads.slice(1).all(func(road):return road.size.x==1 or road.size.y==1),"Other streets are one-tile alleys")
	for passage in plan.passages:
		check(not passage.intersects(plan.plot),"Passage surrounds rather than consumes plot")
		for road in plan.roads: check(not passage.intersects(road),"Road starts outside passage")
	var silhouettes := {}
	for building in plan.neighbours:
		silhouettes[building.cells.size()] = true
		for cell in building.cells:
			check(cell.y==0 or building.cells.has(cell+Vector3i.DOWN),"Neighbour has direct support, never an overhang")
			for road in plan.roads: check(not road.has_point(Vector2(cell.x+0.5,cell.z+0.5)),"Neighbour leaves roads clear")
	check(silhouettes.size()>1,"Neighbouring masses vary")
	var retired := loaded.snapshot()
	retired.queue[0].shape="elbow"
	retired.basement_queue[0].shape="square"
	var converted = Model.new()
	check(converted.load_state(retired),"Previous queues migrate")
	check(converted.queue[0].shape=="small_square" and converted.basement_queue[0].shape=="rectangle","Retired cards become flat shapes")
	check(converted.rooms==loaded.rooms,"Queue migration preserves existing construction")
	var invalid := FileAccess.open("/tmp/block-city-v2-invalid.json",FileAccess.WRITE)
	state.rooms[0].cells[0] = [100,0,0]
	invalid.store_string(JSON.stringify(state)); invalid.close()
	var untouched: Dictionary = loaded.snapshot()
	check(not loaded.load_game("/tmp/block-city-v2-invalid.json") and loaded.snapshot()==untouched,"Malformed save cannot partially replace live state")
	var legacy := untouched.duplicate(true)
	legacy.version = 1
	var names := ["home","shop","laundry","school","storage"]
	for r in legacy.rooms: r.kind = names[int(r.color)]; r.enabled = false
	for key in ["queue","basement_queue"]:
		for c in legacy[key]: c.kind = names[int(c.color)]
	var old_file := FileAccess.open("/tmp/block-city-v1-migrate.json",FileAccess.WRITE)
	old_file.store_string(JSON.stringify(legacy)); old_file.close()
	var migrated = Model.new()
	check(migrated.load_legacy("/tmp/block-city-v1-migrate.json"),"Compatible earlier layouts migrate")
	check(migrated.rooms.size()==untouched.rooms.size() and migrated.rooms[0].cells==untouched.rooms[0].cells,"Migration preserves placed geometry")
	check(migrated.cables.is_empty() and not migrated.rooms[0].has("enabled") and not migrated.rooms[0].has("kind"),"Migration removes old switches, types and wall-pipe electricity")
	for id in ["cube","domino","bar"]:
		var small = Model.new()
		small.queue[0] = {"shape":id,"color":0}
		check(small.drop(0,0),"Small shape places")
		var copy = Model.new()
		check(copy.load_state(small.snapshot()) and copy.rooms==small.rooms,"Small shape survives save-state loading")
	var distribution := {}
	for draw in 10000:
		var id: String = m.weighted_shape(m.config.shapes,hash("draw:%d" % draw))
		distribution[id] = int(distribution.get(id,0))+1
	var total_weight: float=m.config.shapes.reduce(func(total,shape):return total+float(shape.weight),0.0)
	check(absf(float(distribution.get("domino",0))/10000.0-float(m.shape_for("domino").weight)/total_weight)<0.025,"Domino draw frequency follows its configured weight")
	check(float(distribution.get("flat_l",0)+distribution.get("flat_l_mirror",0))/10000.0<0.035,"L shapes remain rare")
	var single = Model.new()
	for shape in single.config.shapes: shape.weight = 1 if shape.id=="cube" else 0
	check(single.choose_card().shape=="cube","Zero weights exclude shapes")
	for x in 3:
		for z in 3:
			if x==1 and z==1: continue
			single.rooms.append({"id":single.rooms.size(),"shape":"bar","color":0,"cells":[[x,8,z]],"access_path":[]})
	for shape in single.config.shapes: shape.weight = 1 if shape.id in ["cube","rectangle"] else 0
	# The one-cell shaft is reachable, with its floor at ground level.
	check(single.choose_card().shape=="cube","Supply excludes shapes that cannot fit")
	print("Block City v2: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
