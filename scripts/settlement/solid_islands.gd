extends RefCounted
## The same closed faceted solids drive drawing, foundations and excavation.
const Landform = preload("res://scripts/settlement/landform.gd")
const Vegetation = preload("res://scripts/settlement/vegetation_patches.gd")
const Grid = preload("res://scripts/settlement/world_grid.gd")
static var cache: Dictionary = {}
static var cache_lock := Mutex.new()
static var samples_lock := Mutex.new()

static func enabled(world) -> bool:
	return (world.difficulty == "easy" and world.generator_version >= 7) or (world.difficulty == "normal" and world.generator_version >= 14)

static func definitions(seed_value: int, version := 10) -> Array[Dictionary]:
	cache_lock.lock()
	var key := [seed_value,version]
	if not cache.has(key): cache[key] = make_islands(seed_value,version)
	var result: Array[Dictionary] = cache[key]
	cache_lock.unlock()
	return result

static func make_islands(seed_value: int, version := 10) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var coast := [Vector2(22,-5),Vector2(21,10),Vector2(15,20),Vector2(3,24),Vector2(-12,22),Vector2(-26,18),Vector2(-39,6),Vector2(-43,-8),Vector2(-38,-23),Vector2(-23,-31),Vector2(-8,-29),Vector2(5,-23),Vector2(18,-17)]
	if version>=9:
		var island: Dictionary
		if version>=15: island=preload("res://scripts/settlement/procedural_main_island.gd").generate(seed_value,version>=16,version>=17,version>=19,version>=20,version)
		elif version>=10: island=preload("res://scripts/settlement/island_geology.gd").generate(seed_value,version>=12,version>=13)
		else: island=preload("res://scripts/settlement/island_shape_generator.gd").generate_main(seed_value)
		island.parts=[]
		for mesh: ArrayMesh in island.meshes: island.parts.append(part(mesh,island.transform))
		island.erase("meshes"); result.append(island)
	else:
		result.append(make_island(coast,Vector3(-22,0,-15),1.0,0.0,seed_value,true))
	if version>=8:
		var generator=preload("res://scripts/settlement/island_shape_generator.gd")
		var rng := RandomNumberGenerator.new(); rng.seed=seed_value^7319
		var families: Array=generator.FAMILIES.duplicate()
		# Local RNG: world generation never consumes a global random sequence.
		for i in range(families.size()-1,0,-1):
			var other:=rng.randi_range(0,i); var swap: String=families[i]
			families[i]=families[other]; families[other]=swap
		var centres := [Vector2(35,8),Vector2(20,-39),Vector2(-28,42),Vector2(44,39)]
		for i in centres.size():
			var centre: Vector2=centres[i]
			var scale_value:=0.8 if i==3 else 1.0
			if version>=15:
				centre+=Vector2(rng.randf_range(-6,6),rng.randf_range(-6,6))
				scale_value=rng.randf_range(0.7,1.15)
			var island: Dictionary=generator.generate(seed_value+i*7919+1009,families[i],centre,scale_value,version>=16,version>=17,version>=21,version>=23)
			if version>=15:
				# Leave navigable water between independently shaped islands even
				# when the new main coastline extends farther on this seed.
				for attempt in 16:
					var overlaps:=false
					for existing in result:
						for padded in Geometry2D.offset_polygon(existing.coast,12.0 if version>=21 else 3.0):
							if not Geometry2D.intersect_polygons(island.coast,padded).is_empty(): overlaps=true
					if not overlaps: break
					centre+=centre.normalized()*4
					island=generator.generate(seed_value+i*7919+1009,families[i],centre,scale_value,version>=16,version>=17,version>=21,version>=23)
			island.parts=[]
			for mesh: ArrayMesh in island.meshes: island.parts.append(part(mesh,island.transform))
			island.erase("meshes"); result.append(island)
		if version>=10: add_coastal_rocks(result,seed_value,version)
		if version>=18 and version<21: preload("res://scripts/settlement/reef_shelves.gd").generate(result,seed_value)
		return result
	for spec in [[Vector3(35,0,8),0.65,0.6],[Vector3(20,0,-39),0.8,-0.7],[Vector3(-28,0,42),0.65,2.1],[Vector3(44,0,39),0.42,-1.1]]:
		var at: Vector3 = spec[0]; var scale_value: float = spec[1]; var angle: float = spec[2]
		var outline: Array = []
		for p: Vector2 in [Vector2(14,-1),Vector2(14,8),Vector2(6,15),Vector2(-7,15),Vector2(-16,7),Vector2(-17,-4),Vector2(-9,-12),Vector2(4,-12),Vector2(12,-7)]:
			outline.append(Vector2(at.x,at.z)+p.rotated(angle)*scale_value)
		result.append(make_island(outline,at,scale_value,angle,seed_value+result.size()*31,false))
	return result

static func add_coastal_rocks(islands: Array[Dictionary], seed_value: int, version := 10) -> void:
	if version>=19:
		preload("res://scripts/settlement/coastal_outcrops.gd").generate(islands,seed_value)
		return
	var rock=preload("res://scripts/settlement/eroded_stone.gd")
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value^13931
	for island in islands:
		island.shoals=[]
		var groups:=0
		for i in island.coast.size():
			if (i+seed_value)%3!=0: continue
			var a: Vector2=island.coast[i]; var b: Vector2=island.coast[(i+1)%island.coast.size()]
			var tangent: Vector2=(b-a).normalized(); var inland:=Vector2(-tangent.y,tangent.x)
			var foot: Vector2=(a+b)*0.5+inland*0.15
			var height:=0.0
			for item in island.parts:
				var levels:=hits(item,foot)
				if not levels.is_empty(): height=maxf(height,levels.back())
			if height<2.0: continue
			for j in (2 if version>=11 else 3):
				var at: Vector2=(a+b)*0.5-inland*(1.6+j*0.75)+tangent*rng.randf_range(-1.8,1.8)
				if islands.any(func(other): return Geometry2D.is_point_in_polygon(at,other.coast)): continue
				var faces: Array=rock.boulder(rng,Vector3(at.x,-4,at.y),Vector3(rng.randf_range(1.6,2.6),rng.randf_range(6.8,8.0),rng.randf_range(1.4,2.2)))
				island.parts.append(part(rock.mesh(faces,Color("6e8077")),Transform3D.IDENTITY))
				var waterline:=preload("res://scripts/settlement/ocean_surface.gd").waterline(island.parts.back().faces)
				if waterline.size()>2: island.shoals.append(waterline)
			groups+=1
			if groups>=(2 if island.mainland and version<11 else 1): break

static func make_island(coast: Array, mountain: Vector3, scale_value: float, angle: float, seed_value: int, mainland: bool) -> Dictionary:
	var inner: Array = []; var centre := Vector2.ZERO
	for p: Vector2 in coast: centre += p
	centre /= coast.size()
	for p: Vector2 in coast:
		# Beach only broadens along the sheltered southern/eastern flank.
		var width := 0.99 if p.y < centre.y else 0.90
		inner.append(centre+(p-centre)*width)
	var base := Landform.loft([Landform.ring(coast,-4),Landform.ring(coast,-0.07),Landform.ring(inner,0)],seed_value,0.16,0.0)
	# CSG keeps materials, but not input vertex colours. Give the grassy cap
	# and the sloped beach their own surfaces instead of a colour attribute.
	var grass := SurfaceTool.new(); grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sand := SurfaceTool.new(); sand.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := base.get_faces()
	for i in range(0,faces.size(),3):
		var normal := (faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
		Landform.triangle(grass if normal.y>0.999999 else sand,faces[i],faces[i+2],faces[i+1])
	grass.set_material(Landform.material(Color("a8b966"))); sand.set_material(Landform.material(Color("e5d6aa")))
	grass.index(); sand.index(); base=grass.commit(); sand.commit(base)
	var parts: Array[Dictionary] = [part(base,Transform3D.IDENTITY)]
	var transform := Transform3D(Basis(Vector3.UP,angle).scaled(Vector3(scale_value,1,scale_value)),mountain)
	var meshes := [Landform.terraces(seed_value),Landform.ridge(seed_value),Landform.fin(seed_value)]
	for index in meshes.size():
		var mesh: ArrayMesh = meshes[index]
		# Integer flat walking elevations; the angled overhang undersides stay freeform.
		var remapped := ArrayMesh.new()
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				if is_equal_approx(vertices[i].y,6.6): vertices[i].y=6
				if is_equal_approx(vertices[i].y,8.5): vertices[i].y=8
				if is_equal_approx(vertices[i].y,11.7): vertices[i].y=12
			arrays[Mesh.ARRAY_VERTEX]=vertices
			remapped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			remapped.surface_set_material(surface,Landform.material(Color("a8b966") if surface==0 and index!=2 else (Color("596e66") if surface==1 else Color("405950"))))
		parts.append(part(remapped,transform))
	return {"coast":PackedVector2Array(coast),"parts":parts,"mainland":mainland}

static func part(mesh: ArrayMesh, transform: Transform3D) -> Dictionary:
	var faces := mesh.get_faces()
	for index in faces.size(): faces[index]=transform*faces[index]
	var bounds := AABB(faces[0],Vector3.ZERO)
	for p in faces: bounds=bounds.expand(p)
	return {"mesh":mesh,"transform":transform,"faces":faces,"bounds":bounds,"columns":{}}

static func hits(part_data: Dictionary, point: Vector2) -> Array[float]:
	var bounds: AABB = part_data.bounds
	if point.x<bounds.position.x or point.x>bounds.end.x or point.y<bounds.position.z or point.y>bounds.end.z: return []
	samples_lock.lock()
	if part_data.columns.has(point):
		var cached: Array[float]=part_data.columns[point]
		samples_lock.unlock(); return cached
	samples_lock.unlock()
	var result: Array[float] = []
	var faces: PackedVector3Array = part_data.faces
	for index in range(0,faces.size(),3):
		var a := faces[index]; var b := faces[index+1]; var c := faces[index+2]
		var ab := Vector2(b.x-a.x,b.z-a.z); var ac := Vector2(c.x-a.x,c.z-a.z)
		var determinant := ab.cross(ac)
		if absf(determinant)<0.000001: continue
		var ap := point-Vector2(a.x,a.z)
		var u := ap.cross(ac)/determinant; var v := ab.cross(ap)/determinant
		if u < -0.000001 or v < -0.000001 or u+v > 1.000001: continue
		var y := a.y+u*(b.y-a.y)+v*(c.y-a.y)
		var duplicate := false
		for previous in result:
			if absf(previous-y)<0.00001: duplicate=true; break
		if not duplicate: result.append(y)
	result.sort()
	samples_lock.lock()
	if part_data.columns.size()>100000: part_data.columns.clear()
	part_data.columns[point]=result
	samples_lock.unlock()
	return result

static func native_solid(seed_value: int, point: Vector3, version := 10) -> bool:
	if version>=17 and point.y< -0.35 and point.y<seabed_height(Vector2(point.x,point.z),seed_value,version): return true
	if point.y < -4 and shore_distance(Vector2(point.x,point.z),seed_value,version)<=0: return true
	for island in definitions(seed_value,version):
		for item in island.parts:
			if not item.bounds.has_point(point): continue
			var levels := hits(item,Vector2(point.x,point.z))
			for index in range(0,levels.size()-1,2):
				if point.y>=levels[index] and point.y<levels[index+1]: return true
	return false

static func solid(world, point: Vector3) -> bool:
	var basin=preload("res://scripts/settlement/puddle_basin.gd")
	var cell:=Vector3i(roundi(point.x),roundi(point.y),roundi(point.z))
	if point.y<cell.y+0.001 and basin.active(world,cell) and point.y>basin.height(cell,world.world_seed,point): return false
	for cut: Dictionary in world.terrain_excavations:
		var local: Vector3 = Basis(Vector3.UP,cut.yaw).inverse()*(point-cut.origin)
		if absf(local.x)<0.5001 and absf(local.z)<0.5001 and local.y>=-0.0001 and local.y<1.0001: return false
	return native_solid(world.world_seed,point,world.generator_version)

static func shore_distance(point: Vector2, seed_value: int, version := 10) -> float:
	var nearest := INF
	for island in definitions(seed_value,version):
		var polygon: PackedVector2Array = island.coast
		var distance := INF
		for index in polygon.size(): distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[index],polygon[(index+1)%polygon.size()])))
		if Geometry2D.is_point_in_polygon(point,polygon): return -distance
		nearest=minf(nearest,distance)
	return nearest

static func generate(seed_value: int,bounds: Rect2i, version := 10, dry := false) -> Dictionary:
	var result := {"seed":seed_value,"version":version,"heights":{},"ground":{},"shapes":{},"ramps":{},"water":{},"nature":{},"grass":{},"border":{},"border_shapes":{}}
	var trees := Vegetation.trees_in(bounds,seed_value,not dry)
	var bushes := Vegetation.bushes_in(bounds,seed_value)
	for x in range(bounds.position.x-1,bounds.end.x+1):
		for z in range(bounds.position.y-1,bounds.end.y+1):
			var column := Vector2i(x,z); var point := Vector2(x,z)
			var candidates: Array[float] = []
			for island in definitions(seed_value,version):
				for item in island.parts:
					if not item.get("decorative",false): candidates.append_array(hits(item,point))
			for height in candidates:
				var level := roundi(height)
				var beach := height>=(-0.35 if version>=17 else -0.071) and height< -0.00001
				var gentle:=version>=23 and height>=0 and absf(height-level)<=0.44
				if not beach and not gentle and (height < -0.001 or absf(height-level)>0.001): continue
				var at := Vector3(x,height,z)
				if not native_solid(seed_value,at-Vector3.UP*0.01,version) or native_solid(seed_value,at+Vector3.UP*0.01,version): continue
				var beach_shape: Array[float]=[]
				if beach and version>=17:
					for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]: beach_shape.append(beach_height(seed_value,point+offset,version))
					# A shoreline cell is walkable only when the entire metre patch
					# is a gentle dry beach, never a cliff sampled across its edge.
					if beach_shape.min()< -0.65 or beach_shape.max()>0.1 or beach_shape.max()-beach_shape.min()>0.65: continue
				var slope_shape: Array[float]=[]
				if gentle:
					for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
						slope_shape.append(surface_near(seed_value,point+offset,height,version))
					# Gentle relief shares a logical floor; sheer cliffs never become
					# walking shortcuts, and uneven cells cannot host flat buildings.
					if slope_shape.min()<level-0.44 or slope_shape.max()>level+0.44 or slope_shape.max()-slope_shape.min()>0.45:
						if absf(height-level)>0.001: continue
						slope_shape.clear()
					elif slope_shape.any(func(value):return absf(value-level)>0.001): slope_shape.append(height)
					else: slope_shape.clear()
				var cell := Vector3i(x,level,z)
				result.border[column]=maxi(level,int(result.border.get(column,-10)))
				if not bounds.has_point(column): continue
				result.heights[column]=maxi(level,int(result.heights.get(column,-10))); result.ground[cell]=true
				if beach:
					var shape: Array[float]=[]
					for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]: shape.append(beach_height(seed_value,point+offset,version))
					result.shapes[cell]=beach_shape if version>=17 else shape; result.border_shapes[cell]=result.shapes[cell]
				if not slope_shape.is_empty():
					result.shapes[cell]=slope_shape; result.border_shapes[cell]=slope_shape
				if cell in [Vector3i(-8,0,0),Vector3i(8,0,-8),Vector3i(-10,0,8)]: result.water[cell]="puddle"; continue
				if beach: continue
				if not dry and (version<14 or level<6) and shore_distance(point,seed_value,version)<-2: result.grass[cell]=true
				if maxi(absi(x),absi(z))<=14 or level!=0: continue
				if bushes.has(column): result.nature[cell]="berry"
				elif trees.has(column): result.nature[cell]=trees[column]
				if result.nature.has(cell): result.grass.erase(cell)
	return result

static func surface_near(seed_value: int, point: Vector2, height: float, version: int) -> float:
	var nearest: float=-INF; var distance:=INF
	for island in definitions(seed_value,version):
		for item in island.parts:
			if item.get("decorative",false): continue
			for candidate: float in hits(item,point):
				if absf(candidate-height)<distance:
					distance=absf(candidate-height); nearest=candidate
	return nearest

static func beach_height(seed_value: int, point: Vector2, version := 10) -> float:
	for island in definitions(seed_value,version):
		var levels := hits(island.parts[0],point)
		if not levels.is_empty(): return levels.back()
	return -0.07

static func excavate(world, plan: Dictionary) -> void:
	if not enabled(world) or plan.kind!="support": return
	var origin: Vector3 = Vector3(plan.cell)+plan.get("placement_offset",Vector3.ZERO)
	var yaw := float(plan.get("support_yaw",0.0))
	var intersects := false
	var bounds := Transform3D(Basis(Vector3.UP,yaw),origin)*AABB(Vector3(-0.5,0,-0.5),Vector3.ONE)
	for island in definitions(world.world_seed,world.generator_version):
		for item in island.parts:
			if item.bounds.intersects(bounds): intersects=true; break
	if not intersects: return
	world.terrain_excavations.append({"origin":origin,"yaw":yaw})
	world.terrain_revision+=1

static func configure_navigation(world, surfaces: Dictionary) -> void:
	world.navigation.terrain_barriers.clear()
	if not enabled(world): return
	var entries := {}
	for cut: Dictionary in world.terrain_excavations:
		var cell := Vector3i(roundi(cut.origin.x),roundi(cut.origin.y),roundi(cut.origin.z))
		if world.loaded_chunks.has(Vector2i(floori(cell.x/16.0),floori(cell.z/16.0))) and solid(world,cut.origin-Vector3.UP*0.02):
			surfaces[cell]=true
			world.navigation.support_poses[cell]=Transform3D(Basis(Vector3.UP,cut.yaw),cut.origin)
			entries[cell]=true
	for cell: Vector3i in surfaces.keys():
		var clear := true
		var centre: Vector3=world.navigation.support_poses.get(cell,Transform3D(Basis.IDENTITY,Vector3(cell))).origin
		for offset in [Vector3.ZERO,Vector3(0.18,0,0),Vector3(-0.18,0,0),Vector3(0,0,0.18),Vector3(0,0,-0.18)]:
			for height in [0.05,0.7,1.4]:
				if solid(world,centre+offset+Vector3.UP*height): clear=false; break
			if not clear: break
		if not clear: surfaces.erase(cell)
	# Check actual body clearance across each tunnel mouth, including small
	# surviving rock slivers between an off-grid frame and the outside floor.
	for cell: Vector3i in entries:
		if not surfaces.has(cell): continue
		for direction: Vector3i in world.DIRECTIONS:
			var other := cell+direction
			if not surfaces.has(other): continue
			var a: Vector3=world.navigation.support_poses.get(cell,Transform3D(Basis.IDENTITY,Vector3(cell))).origin
			var b: Vector3=world.navigation.support_poses.get(other,Transform3D(Basis.IDENTITY,Vector3(other))).origin
			if passage_clear(world,a,b): continue
			for pair in [[cell,other],[other,cell]]:
				if not world.navigation.terrain_barriers.has(pair[0]): world.navigation.terrain_barriers[pair[0]]=[]
				if pair[1] not in world.navigation.terrain_barriers[pair[0]]: world.navigation.terrain_barriers[pair[0]].append(pair[1])

static func passage_clear(world, a: Vector3, b: Vector3) -> bool:
	var axis := (b-a).normalized(); var tangent:=Vector3(-axis.z,0,axis.x)
	for step in 17:
		for side in [-0.18,0.0,0.18]:
			for height in [0.05,0.7,1.4]:
				if solid(world,a.lerp(b,float(step)/16.0)+tangent*side+Vector3.UP*height): return false
	return true

static func valid(cuts: Variant) -> bool:
	if not cuts is Array or cuts.size()>100000: return false
	for cut: Variant in cuts:
		if not cut is Dictionary or not cut.get("origin") is Vector3 or not (cut.get("yaw") is float or cut.get("yaw") is int): return false
		if not cut.origin.is_finite() or not is_finite(cut.yaw) or absf(cut.yaw)>PI/12+0.00001: return false
		if absf(cut.origin.x)>16382 or absf(cut.origin.z)>16382 or cut.origin.y<0 or cut.origin.y>36 or not is_equal_approx(cut.origin.y,roundf(cut.origin.y)): return false
	return true

static func seabed_height(point: Vector2, seed_value: int, version: int) -> float:
	return bed_height_in(point,definitions(seed_value,version))

static func bed_height_in(point: Vector2, islands: Array) -> float:
	# The island's real submerged base is the near-shore bed. Beyond its toe,
	# continue into a sloping offshore floor instead of terminating the terrain.
	var height: float=-INF
	var distance: float=INF
	for island in islands:
		var levels:=hits(island.parts[0],point)
		if not levels.is_empty(): height=maxf(height,levels.back())
		var outline: PackedVector2Array=island.get("bed_coast",island.coast)
		for i in outline.size(): distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,outline[i],outline[(i+1)%outline.size()])))
	if height> -INF: return height
	if not islands[0].get("fringe",{}).is_empty():
		var reef: Dictionary=islands[0].fringe
		var main_bed: float=preload("res://scripts/settlement/fringing_reef.gd").offshore_height(point,reef)
		var main_near:=INF; var other_near:=INF
		for j in reef.toe.size(): main_near=minf(main_near,point.distance_to(Geometry2D.get_closest_point_to_segment(point,reef.toe[j],reef.toe[(j+1)%reef.toe.size()])))
		# Small islands have only their narrow submerged feet. The main reef
		# fades away before meeting those deeper beds, without a light halo.
		for i in range(1,islands.size()):
			var outline: PackedVector2Array=islands[i].get("bed_coast",islands[i].coast)
			for j in outline.size(): other_near=minf(other_near,point.distance_to(Geometry2D.get_closest_point_to_segment(point,outline[j],outline[(j+1)%outline.size()])))
		var other_bed:=-4.0-other_near/6.0
		var main_weight:=pow(1.0-smoothstep(0,3,main_near),2)/maxf(main_near,0.00001)
		var other_weight:=pow(1.0-smoothstep(0,3,other_near),2)/maxf(other_near,0.00001)
		var total:=main_weight+other_weight
		var bed:=maxf(main_bed,other_bed)
		if total>0: bed=lerpf(bed,(main_bed*main_weight+other_bed*other_weight)/total,minf(1,total))
		return bed
	var offshore := -4.0-distance/6.0
	return preload("res://scripts/settlement/reef_shelves.gd").height_in(point,islands,offshore,distance)
