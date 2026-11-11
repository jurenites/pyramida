extends SceneTree
const Islands=preload("res://scripts/settlement/solid_islands.gd")
const Generator=preload("res://scripts/settlement/world_generator.gd")
var failures: Array[String]=[]
var checks := 0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var previous := []
	for seed_value in [1409,42,9182,101,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31]:
		check_mainland(seed_value)
		var islands := Islands.definitions(seed_value,8)
		var families := {}; var signatures := []; var heights := {}
		for index in range(1,islands.size()):
			var island: Dictionary=islands[index]
			families[island.family]=true; heights[island.top_height]=true
			var mesh_signature := []
			for item in island.parts:
				mesh_signature.append(hash(item.faces))
				for point: Vector3 in item.faces: check(point.is_finite(),"Finite generated solid")
				# A closed solid's undirected edges occur in pairs, including caps.
				var edges := {}
				for i in range(0,item.faces.size(),3):
					for j in 3:
						var a: Vector3=item.faces[i+j].snapped(Vector3.ONE*0.0001)
						var b: Vector3=item.faces[i+(j+1)%3].snapped(Vector3.ONE*0.0001)
						var edge := [a,b] if a<b else [b,a]
						edges[edge]=int(edges.get(edge,0))+1
				for edge in edges:
					if edges[edge]!=2: print("Open edge ",edge," count ",edges[edge])
					check(edges[edge]==2,"Watertight %s mesh, seed %d"%[island.family,seed_value])
			signatures.append(hash(mesh_signature))
			var sea_cliff := false; var shelf_area := 0.0
			for item in island.parts:
				for i in range(0,item.faces.size(),3):
					var a: Vector3=item.faces[i]; var b: Vector3=item.faces[i+1]; var c: Vector3=item.faces[i+2]
					var cross: Vector3=(c-a).cross(b-a)
					if cross.normalized().y>0.99 and a.y>0: shelf_area+=cross.length()*0.5
			for i in island.coast.size():
				var a: Vector2=island.coast[i]; var b: Vector2=island.coast[(i+1)%island.coast.size()]
				var edge := b-a; var inward:=Vector2(-edge.y,edge.x).normalized()
				var point := (a+b)*0.5+inward*0.035
				var outside := point-inward*0.1
				if Islands.native_solid(seed_value,Vector3(point.x,0.1,point.y),8) and Islands.native_solid(seed_value,Vector3(point.x,minf(3.5,island.top_height-0.2),point.y),8) and not Islands.native_solid(seed_value,Vector3(outside.x,0.1,outside.y),8): sea_cliff=true
			check(sea_cliff,"%s has a continuous cliff at the water, seed %d"%[island.family,seed_value])
			check(shelf_area>20,"%s retains broad flat building terraces"%island.family)
		check(families.size()==4,"Every map has four different island forms")
		check(heights.size()>=2,"Summits do not all share one height")
		check(previous!=signatures,"Changing seed changes generated geometry")
		previous=signatures
		var repeat := Islands.make_islands(seed_value,8)
		for i in range(1,repeat.size()):
			check(repeat[i].coast==islands[i].coast,"Coast regeneration is deterministic")
			for j in repeat[i].parts.size(): check(repeat[i].parts[j].faces==islands[i].parts[j].faces,"Solid regeneration is deterministic")
	var legacy:=Islands.definitions(1409,7)
	check(legacy[1].parts.size()==4 and not legacy[1].has("family"),"Version 7 keeps its original landforms")
	check(legacy[1].coast!=Islands.definitions(1409,8)[1].coast,"Generator versions cannot share the wrong cache")
	var region:=Generator.generate_region(42,Rect2i(16,-48,32,32),0,"easy",8)
	var merged := {}
	for x in [2,1]:
		for z in [-2,-3]: merged.merge(Generator.generate_chunk(42,Vector2i(x,z),"easy",8).ground)
	check(region.ground==merged,"New island surfaces agree across reverse chunk order")
	if failures.is_empty(): print("PASS: %d seeded shape, watertight solid, sea cliff, terrace and compatibility checks"%checks)
	quit(int(not failures.is_empty()))

func check_mainland(seed_value: int) -> void:
	var island: Dictionary=Islands.definitions(seed_value,9)[0]
	var concave := 0; var cliff_length := 0.0
	var shelves := {}; var overhang := false
	for i in island.coast.size():
		var a: Vector2=island.coast[i]; var b: Vector2=island.coast[(i+1)%island.coast.size()]
		var c: Vector2=island.coast[(i+2)%island.coast.size()]
		if (b-a).cross(c-b)<-0.1: concave+=1
		var inward:=Vector2(-(b-a).y,(b-a).x).normalized()
		var at: Vector2=(a+b)*0.5+inward*0.05
		if Islands.native_solid(seed_value,Vector3(at.x,1.5,at.y),9): cliff_length+=(b-a).length()
	check(concave>=4,"Main island has several indented bays")
	check(cliff_length>25,"Main island has extensive cliffs directly at the sea")
	for item in island.parts:
		var edges := {}
		for i in range(0,item.faces.size(),3):
			var a: Vector3=item.faces[i]; var b: Vector3=item.faces[i+1]; var c: Vector3=item.faces[i+2]
			var cross := (c-a).cross(b-a)
			if cross.normalized().y>0.99 and a.y>0: shelves[a.y]=float(shelves.get(a.y,0))+cross.length()*0.5
			if cross.normalized().y< -0.99 and a.y>3:
				var centre: Vector3=(a+b+c)/3
				for point in [centre,a.lerp(b,0.5).lerp(centre,0.02),b.lerp(c,0.5).lerp(centre,0.02),c.lerp(a,0.5).lerp(centre,0.02)]:
					if not Islands.native_solid(seed_value,point-Vector3.UP*0.05,9) and Islands.native_solid(seed_value,point+Vector3.UP*0.05,9): overhang=true
			for j in 3:
				var start: Vector3=item.faces[i+j].snapped(Vector3.ONE*0.0001)
				var end: Vector3=item.faces[i+(j+1)%3].snapped(Vector3.ONE*0.0001)
				var edge := [start,end] if start<end else [end,start]
				edges[edge]=int(edges.get(edge,0))+1
		for edge in edges: check(edges[edge]==2,"Mainland closed solid, seed %d"%seed_value)
	check(shelves.size()>=5,"Mainland has different terrace elevations")
	check(overhang,"Mainland retains real air beneath projecting shelves")
	for x in range(-10,11,2):
		for z in range(-10,11,2):
			check(Islands.native_solid(seed_value,Vector3(x,-0.1,z),9) and not Islands.native_solid(seed_value,Vector3(x,0.1,z),9),"Starting settlement remains on usable lowland")
	var repeat:=Islands.make_islands(seed_value,9)[0]
	check(repeat.coast==island.coast,"Mainland coastline is deterministic")
	for i in island.parts.size(): check(repeat.parts[i].faces==island.parts[i].faces,"Mainland geometry is deterministic")
	check(Islands.definitions(seed_value,8)[0].coast!=island.coast,"Existing version 8 main island is preserved")
