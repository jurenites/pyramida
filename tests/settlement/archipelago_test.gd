extends SceneTree
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Islands = preload("res://scripts/settlement/archipelago_landscape.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String]=[]
var checks := 0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for seed_ in [1409,42]:
		var whole := Generator.generate_region(seed_,Generator.INITIAL_BOUNDS,0,"easy",6)
		check(whole.version==6,"New Greece uses versioned islands")
		var islands := 0; var remaining := {}
		for cell: Vector3i in whole.ground: remaining[Vector2i(cell.x,cell.z)]=true
		while not remaining.is_empty():
			islands+=1
			var queue: Array = [remaining.keys()[0]]; remaining.erase(queue[0])
			var cursor := 0
			while cursor<queue.size():
				var current: Vector2i = queue[cursor]; cursor+=1
				for step: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
					if remaining.has(current+step): remaining.erase(current+step); queue.append(current+step)
		check(islands>=4,"Sea separates multiple small islands from the starting island")
		var high := 0
		for cell: Vector3i in whole.ground:
			if cell.y>=5: high+=1
			if maxi(absi(cell.x),absi(cell.z))<=16: check(cell.y==0 and not whole.shapes.has(cell),"Supplied opening stays buildable")
		check(high>20,"Map contains high rocky mountain shelves")
		var merged := {}
		for x in range(2,-4,-1):
			for z in range(2,-4,-1): merged.merge(Generator.generate_chunk(seed_,Vector2i(x,z),"easy",6).ground)
		check(merged==whole.ground,"Reverse chunk order reproduces islands and elevations")
	var world := Model.new(); world.setup(1409,"easy",6)
	var shallow := false; var deep := false
	for x in range(-48,48):
		for z in range(-48,48):
			var cell := Vector3i(x,0,z)
			var depth := Model.Volume.sea_depth(world,cell)
			if depth>0:
				check(not world.ground.has(cell),"Saltwater has no walkable land")
				check(Model.Volume.material_at(world,cell+Vector3i.DOWN)=="water","Water surface has real water volume below")
				check(Model.Volume.material_at(world,cell+Vector3i.DOWN*(depth+1))=="solid","Water has a solid seabed")
				shallow = shallow or Model.Volume.platform_grounded(world,cell)
				deep = deep or not Model.Volume.platform_grounded(world,cell)
	check(shallow and deep,"Short pier posts distinguish shallow from deep sea")
	var restored := Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Island landscape saves and restores")
	check(restored.ground==world.ground and restored.generator_version==6,"Restore preserves island positions and version")
	var legacy := Generator.generate_region(1409,Generator.INITIAL_BOUNDS,0,"easy",4)
	check(legacy.version==4 and legacy.ground.has(Vector3i(-47,0,0)),"Old coastal generator remains available unchanged")
	if failures.is_empty(): print("PASS: %d archipelago, mountain, streaming, water, seabed and save checks"%checks)
	quit(int(not failures.is_empty()))
