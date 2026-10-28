extends RefCounted
## Seeded, bounded room packing around a connected circulation core.
const Model=preload("res://scripts/block_city/model.gd")
const Navigation=preload("res://scripts/block_city/room_navigation.gd")
var model
var rng:=RandomNumberGenerator.new()
var conditions: Dictionary
var attempts:=0

func generate(config: Dictionary, requested: Dictionary) -> Dictionary:
	conditions={"width":3,"depth":3,"floors":3,"seed":2026,"top_setback":false,"max_room_cells":6,"min_rooms":1,"allowed_shapes":["room_domino","bar","small_square","rectangle"]}
	conditions.merge(requested,true)
	var w:=int(conditions.width); var d:=int(conditions.depth); var h:=int(conditions.floors)
	if w<2 or w>6 or d<2 or d>6 or h<1 or h>9: return failure("Footprint must be 2–6 cells per side; floors must be 1–9")
	if int(conditions.min_rooms)<0: return failure("Minimum room count cannot be negative")
	if int(conditions.max_room_cells)<2 or int(conditions.max_room_cells)>6: return failure("Room size must be 2–6 cells")
	var tuned:=config.duplicate(true)
	tuned.plot.width=w; tuned.plot.depth=d; tuned.plot.ceiling=h; tuned.plot.overhang=0
	model=Model.new("",tuned)
	for id in conditions.allowed_shapes:
		var shape: Dictionary=model.shape_for(str(id))
		if shape.is_empty() or shape.get("role","room")!="room" or shape.get("palette_hidden",false): return failure("Unknown or unavailable room shape: %s" % id)
	if conditions.allowed_shapes.is_empty(): return failure("Choose at least one room shape")
	rng.seed=int(conditions.seed); attempts=0
	for y in h:
		var width:=w-1 if bool(conditions.top_setback) and y==h-1 and h>1 and w>2 else w
		# Street entrance, cross-corridor, then a stair at the end of the spine.
		for x in width:
			if not add_piece({"shape":"cube","color":0},x,0,y,0): return failure("Invalid entrance corridor")
		for z in range(1,d):
			var shape: String="stairs" if z==d-1 and y<h-1 else "cube"
			if not add_piece({"shape":shape,"color":0},0,z,y,0): return failure("Invalid stair spine")
		if not pack_floor(width,d,y): return failure("No connected packing fits these conditions within the search limit")
	var ordinary_rooms: int=model.rooms.filter(func(room):return model.room_role(room)=="room").size()
	if ordinary_rooms<int(conditions.min_rooms): return failure("Generated layout cannot meet the requested minimum room count")
	model.apply_connection_colors()
	var validation:=validate(model)
	if not validation.ok: return failure(validation.error)
	validation.ordinary_rooms=ordinary_rooms
	var cells:=[]
	for room in model.rooms:
		for raw in room.cells: cells.append(Model.vec(raw))
	return {"ok":true,"conditions":conditions.duplicate(true),"rooms":model.rooms.duplicate(true),"cells":cells,"config":tuned,"validation":validation}

func failure(message: String) -> Dictionary: return {"ok":false,"error":message}

func add_piece(card: Dictionary,x: int,z: int,y: int,yaw: int) -> bool:
	var plan: Dictionary=model.landing(card,x,z,yaw,false,y)
	if not plan.ok: return false
	model.rooms.append({"id":model.rooms.size(),"shape":card.shape,"color":card.color,"cells":plan.cells.map(func(cell):return Model.arr(cell)),"door":Model.arr(plan.door),"normal":Model.arr(plan.normal),"braces":[],"access_path":[]})
	return true

func pack_floor(width: int,depth: int,y: int) -> bool:
	attempts+=1
	if attempts>3000: return false
	var occupied: Dictionary=model.occupied()
	var target:=Vector3i(-1,y,-1)
	for z in range(1,depth):
		for x in range(1,width):
			if target.x<0 and not occupied.has(Vector3i(x,y,z)): target=Vector3i(x,y,z)
	if target.x<0: return true
	var options:=[]
	for id in conditions.allowed_shapes:
		if model.shape_for(id).cells.size()>int(conditions.max_room_cells): continue
		for yaw in 4:
			for door in model.entrance_options(id):
				var card: Dictionary={"shape":id,"color":y%model.config.colors.size(),"door":door.door,"normal":door.normal}
				var oriented: Dictionary=model.oriented(card,yaw)
				var cells: Array=oriented.cells.map(func(cell):return cell+target)
				if cells.any(func(cell):return cell.x<1 or cell.x>=width or cell.z<1 or cell.z>=depth or occupied.has(cell)): continue
				var entry: Vector3i=oriented.door+target
				var outside: Vector3i=entry+oriented.normal
				if not occupied.has(outside): continue
				var parent: Dictionary=model.rooms[occupied[outside]]
				if model.room_role(parent)!="room" and not model.port_matches(parent,outside,-oriented.normal): continue
				options.append({"card":card,"yaw":yaw,"order":rng.randf()})
	options.sort_custom(func(a,b):return a.order<b.order)
	# A leftover unit may become a hall only where it actually joins circulation.
	for direction in Model.DIRECTIONS:
		var adjacent: Vector3i=target+direction
		if occupied.has(adjacent) and model.port_matches(model.rooms[occupied[adjacent]],adjacent,-direction):
			options.append({"card":{"shape":"cube","color":0},"yaw":0}); break
	for option in options:
		if not add_piece(option.card,target.x,target.z,y,option.yaw): continue
		if pack_floor(width,depth,y): return true
		model.rooms.pop_back()
	return false

static func validate(candidate) -> Dictionary:
	var occupied: Dictionary=candidate.occupied()
	var count:=0
	for room in candidate.rooms:
		count+=room.cells.size()
		if not room.cells.has(room.door) or room.cells.has(Model.arr(Model.vec(room.door)+Model.vec(room.normal))): return {"ok":false,"error":"Invalid doorway"}
		for raw in room.cells:
			var cell:=Model.vec(raw)
			if cell.y>0 and not occupied.has(cell+Vector3i.DOWN): return {"ok":false,"error":"Unsupported cell"}
	if occupied.size()!=count: return {"ok":false,"error":"Overlapping rooms"}
	var network:=Navigation.build(candidate,candidate.rooms)
	if network.entry.is_empty(): return {"ok":false,"error":"No street entrance"}
	var seen: Dictionary={network.entry.cell:true}
	var pending: Array=seen.keys()
	while not pending.is_empty():
		var at: Vector3i=pending.pop_back()
		for next in network.graph.get(at,{}):
			if not seen.has(next): seen[next]=true; pending.append(next)
	for cell in occupied:
		if not seen.has(cell): return {"ok":false,"error":"Unreachable room cell"}
	return {"ok":true,"room_count":candidate.rooms.size(),"reachable_cells":count,"entry":Model.arr(network.entry.cell)}
