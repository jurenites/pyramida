extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Islands=preload("res://scripts/settlement/solid_islands.gd")
const Edge=preload("res://scripts/settlement/terrain_vegetation_edge.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world:=Model.new(); world.setup(1409,"easy")
	var slopes:=0; var joined:=0
	for cell: Vector3i in world.terrain_shapes:
		var shape: Array=world.terrain_shapes[cell]
		if shape.size()!=5: continue
		slopes+=1
		var point:=Vector3(cell.x,shape[4],cell.z)
		check(Islands.solid(world,point-Vector3.UP*0.01) and not Islands.solid(world,point+Vector3.UP*0.01),"Curved walking ground matches the solid at its centre")
		check(absf(world.navigation.surface_point(cell).y-shape[4])<0.001,"Citizens use the sampled curve, not a flat logical level")
		check(not world.build_error("support",cell).is_empty(),"Uneven natural ground does not silently grant a level building footing")
		for direction in [Vector3i.RIGHT,Vector3i.BACK]:
			if world.terrain_shapes.has(cell+direction) and world.navigation._touching(cell,cell+direction): joined+=1
	check(slopes>5 and joined>2,"Gently folded land retains connected walkable patches")
	var restored:=Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Five-sample terrain survives a real save roundtrip")
	check(restored.terrain_shapes.size()==world.terrain_shapes.size(),"Restored curvature retains all cells")
	var maximum_error:=0.0
	for cell: Vector3i in world.terrain_shapes:
		var original: Array=world.terrain_shapes[cell]; var saved: Array=restored.terrain_shapes.get(cell,[])
		check(original.size()==saved.size(),"Restored terrain keeps its centre sample")
		for i in mini(original.size(),saved.size()): maximum_error=maxf(maximum_error,absf(original[i]-saved[i]))
	check(maximum_error<0.000001,"JSON roundtrip retains sub-millimetre curvature accuracy")
	var main: Dictionary=Islands.definitions(1409,world.generator_version)[0]
	var thin:=0; var broad:=0
	for x in range(-40,30):
		for z in range(-35,35):
			var cover:=Edge.coverage(Vector2(x,z),2,main.shelves)
			if cover<0.01: thin+=1
			if cover>0.99: broad+=1
	check(thin>50 and broad>50,"Rock margins coexist with broad grassy soil")
	var legacy: Dictionary=Islands.definitions(1409,22)[0]
	check(main.coast==legacy.coast,"Folding does not move the accepted shoreline")
	var old_top:=-INF; var new_top:=-INF
	for shoulder in legacy.shoulders:
		for p: Vector3 in shoulder.crown: old_top=maxf(old_top,p.y)
	for shoulder in main.shoulders:
		for p: Vector3 in shoulder.crown: new_top=maxf(new_top,p.y)
	check(new_top>old_top+1,"Mountain crowns grow upwards without adding isolated peak props")
	if failures.is_empty(): print("PASS: physical curved walking ground, connected slopes, safe building footing, soil margins and saved curvature")
	quit(int(not failures.is_empty()))
