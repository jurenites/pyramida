extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Neighbourhood=preload("res://scripts/block_city/neighbourhood.gd")
const Generator=preload("res://scripts/block_city/building_generator.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var model=Model.new()
	var plan:=Neighbourhood.layout(model.config)
	var walkable: Dictionary={}
	for rect in plan.passages: walkable[Vector2i(rect.position)]=true
	check(plan.neighbours.size()==8,"Buildings surround all eight adjacent blocks")
	for building in plan.neighbours:
		var config: Dictionary=model.config.duplicate(true)
		config.plot.width=building.conditions.width; config.plot.depth=building.conditions.depth
		var candidate=Model.new("",config); candidate.rooms=building.rooms
		check(Generator.validate(candidate).ok,"Each grey neighbor has connected, supported rooms")
		var entry: Vector3i=building.origin+Model.vec(building.validation.entry)+Vector3i.FORWARD
		check(walkable.has(Vector2i(entry.x,entry.z)),"Each neighbor entrance reaches pavement")
		for cell in building.cells:
			check(not walkable.has(Vector2i(cell.x,cell.z)),"Sidewalk does not run inside a building")
	for crossing in plan.crossings:
		check(not crossing.rect.intersects(plan.roads[0]),"No crossing traverses the wide main road")
		check(walkable.has(crossing.from) and walkable.has(crossing.to),"Both ends of each crossing meet a sidewalk")
		check(plan.roads.any(func(road):return road.encloses(crossing.rect)),"Crosswalk fits inside a narrow street")
	# Only the wide main road separates the front row; the other six blocks link.
	var seen: Dictionary={Vector2i(-1,0):true}; var pending: Array=seen.keys()
	while not pending.is_empty():
		var at: Vector2i=pending.pop_back()
		var nexts: Array=[]
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if walkable.has(at+direction): nexts.append(at+direction)
		for crossing in plan.crossings:
			if at==crossing.from: nexts.append(crossing.to)
			if at==crossing.to: nexts.append(crossing.from)
		for next in nexts:
			if not seen.has(next): seen[next]=true; pending.append(next)
	for building in plan.neighbours:
		var entry: Vector3i=building.origin+Model.vec(building.validation.entry)+Vector3i.FORWARD
		check(seen.has(Vector2i(entry.x,entry.z))==(building.origin.z>=0),"Pedestrian routes connect side/rear blocks without crossing the main road")
	print("Block City neighborhood: ",failures," failures")
	quit(1 if failures else 0)
