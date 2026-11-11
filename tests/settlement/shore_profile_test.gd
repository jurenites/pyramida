extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Islands=preload("res://scripts/settlement/solid_islands.gd")
const Coast=preload("res://scripts/settlement/coastal_water.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func surface_height(island: Dictionary, point: Vector2) -> float:
	var height: float=-INF
	for part in island.parts:
		var levels:=Islands.hits(part,point)
		if not levels.is_empty(): height=maxf(height,levels.back())
	return height
func run() -> void:
	for seed_value in [1409,42,9182,101]:
		var world:=Model.new(); world.setup(seed_value,"normal")
		var definitions:=Islands.definitions(seed_value,world.generator_version)
		var main: Dictionary=definitions[0]
		var beaches:=0
		for i in main.coast.size():
			var a: Vector2=main.coast[i]; var b: Vector2=main.coast[(i+1)%main.coast.size()]
			var inward:=Vector2(-(b-a).y,(b-a).x).normalized(); var at: Vector2=(a+b)*0.5
			if surface_height(main,at+inward*2)>0.1: continue
			# A beach section must stay clear of rock throughout the transect.
			# A single inland probe can miss a narrow headland crossing the shore.
			var profile: Array[float]=[]
			for step in range(-12,13):
				var p:=at+inward*step*0.2
				var h:=surface_height(main,p)
				profile.append(Islands.seabed_height(p,seed_value,world.generator_version) if h== -INF else h)
			if profile.any(func(h): return h>0.1): continue
			var previous: float=-INF; var crossings: Dictionary={}
			for step in range(-12,13):
				var distance:=step*0.2
				var h: float=profile[step+12]
				if previous> -INF: check(absf(h-previous)<0.7,"Beach has a continuous slope through the waterline seed=%s edge=%s distance=%s heights=%s,%s"%[seed_value,i,distance,previous,h])
				for water in [-0.8,-0.65,-0.5]:
					if not crossings.has(water) and h>=water: crossings[water]=distance
				previous=h
			check(crossings.size()==3,"Low, normal and high water each intersect the same sloped beach")
			if crossings.size()==3: check(crossings[-0.5]-crossings[-0.8]<=1.6,"A small tide shifts the shore gradually")
			beaches+=1
		check(beaches>=3,"Sheltered beach space survives beside the cliffs")
		for point in [Vector2(-55,-45),Vector2(55,-50),Vector2(0,65)]:
			var bed:=Islands.seabed_height(point,seed_value,world.generator_version)
			check(bed< -4,"Offshore terrain continues below island bases")
			check(Islands.native_solid(seed_value,Vector3(point.x,bed-0.02,point.y),world.generator_version),"Underwater terrain is solid below its actual surface")
			check(not Islands.native_solid(seed_value,Vector3(point.x,bed+0.02,point.y),world.generator_version),"Water space remains above the seabed")
			var cell:=Vector3i(int(point.x),floori(bed)-1,int(point.y))
			check(world.Volume.material_at(world,cell)=="solid","Construction queries agree with the submerged terrain")
		for cell: Vector3i in world.ground:
			if cell.y==0 and world.terrain_shapes.has(cell): check(world.soil_shapes[cell][4]> -0.5,"Walkable shore stays dry at the tested high water")
		check(Model.new().restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Sloped beaches and offshore ground survive save/load")
		if seed_value==1409:
			var bed_mesh:=Coast.physical_seabed({"islands":definitions,"bounds":Rect2(-55,-45,110,100)})
			for vertex in bed_mesh.get_faces(): check(absf(vertex.y-Islands.seabed_height(Vector2(vertex.x,vertex.z),seed_value,world.generator_version))<0.002,"Rendered offshore vertices use the physical bed heights")
		print("Seed ",seed_value," continuous beach sections=",beaches)
	if failures.is_empty(): print("PASS: sloped beaches, tide range, real seabed, dry walking ground and saves")
	quit(int(not failures.is_empty()))
