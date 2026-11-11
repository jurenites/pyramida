extends RefCounted
## Seeded coastal geology. Only the opening village reserve is authored in place.
const Shape=preload("res://scripts/settlement/island_shape_generator.gd")
const Geo=preload("res://scripts/settlement/island_geology.gd")
const Landform=preload("res://scripts/settlement/landform.gd")
const CLEAR=[Vector2(-12,-2),Vector2(-10,-3),Vector2(-10,-5.5),Vector2(-6.5,-5.5),Vector2(-6,-3),Vector2(-3,-2),Vector2(2,-2),Vector2(4,-6),Vector2(8,-6),Vector2(10,2),Vector2(10,6),Vector2(6,6),Vector2(3,8),Vector2(-3,8),Vector2(-10,10),Vector2(-12,6)]

static func generate(seed_value: int, tapered_shelves := false, shore_slopes := false, sculpted_mountains := false, blended_ridges := false, detail_version := 0) -> Dictionary:
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value^906719
	var coast:=outline(rng,shore_slopes)
	var heading:=rng.randf_range(2.75,4.45)
	var normal:=Vector2.from_angle(heading)
	var crest_height:=float(rng.randi_range(2,4)*2)
	var start:=rng.randf_range(5.0,9.0)
	var patches: Array=[]
	# Independent broken inland margins; the outer edges share the exact coast.
	add_patch(patches,coast,mask(rng,normal.rotated(rng.randf_range(-0.3,0.3)),start-5.0),2.0,0)
	var high_mask:=mask(rng,normal,start)
	# Faulted coastal blocks meet at unequal levels. The split bends independently
	# of the foothill margin, so no single long parallel step crosses the island.
	var fault:=mask(rng,normal.rotated(rng.randf_range(1.0,1.6)),rng.randf_range(-9,6))
	var split_height:=maxf(4,crest_height+(2 if rng.randf()>0.5 else -2))
	if is_equal_approx(split_height,crest_height): split_height+=2
	# Keep the opening foothills' seeded sequence independent of mountain changes.
	var shoulder_at:=normal*rng.randf_range(20,27)+Vector2(-4,0)
	var shoulder_shape:=Geo.outline_at(rng,shoulder_at,Vector2(rng.randf_range(7,13),rng.randf_range(5,9)),rng.randf_range(-PI,PI),9)
	if sculpted_mountains:
		var mountain_rng:=RandomNumberGenerator.new(); mountain_rng.seed=seed_value^73291
		# One broad usable bench, with offset coastal masses rising from selected
		# sides. Upper levels never repeat the whole island's contour.
		add_patch(patches,coast,high_mask,4.0,1)
		var tangent:=Vector2(-normal.y,normal.x)
		for i in 2:
			var at:=Vector2(-4,0)+normal*mountain_rng.randf_range(17,22)+tangent*(-9.0 if i==0 else 10.0)
			var axes:=Vector2(mountain_rng.randf_range(8,12),mountain_rng.randf_range(6,9))
			var mass:=Geo.outline_at(mountain_rng,at,axes,heading+mountain_rng.randf_range(-0.45,0.45),9)
			# Keep high masses on the raised side so the village-facing bench
			# remains broad. Their unequal margins expose different shelf widths.
			for region in Geometry2D.intersect_polygons(mass,high_mask):
				add_patch(patches,coast,region,6.0 if i==0 else maxf(8,crest_height+2),2+i)
	else:
		for region in Geometry2D.intersect_polygons(PackedVector2Array(coast),high_mask):
			for piece in Geometry2D.clip_polygons(region,fault): add_patch(patches,coast,piece,crest_height,1)
			for piece in Geometry2D.intersect_polygons(region,fault): add_patch(patches,coast,piece,split_height,6)
		# A displaced high shoulder, rather than another shrinking copy of the coast.
		add_patch(patches,coast,shoulder_shape,crest_height+2,2)
	# Buildable foothills border the village on different sides in different seeds.
	var local_sites: Array=[Vector2(-3,-6),Vector2(4,9),Vector2(-15,6)]
	for i in local_sites.size():
		var at: Vector2=local_sites[i]+Vector2(rng.randf_range(-1.2,1.2),rng.randf_range(-1,1))
		var size:=Vector2(rng.randf_range(4,6),rng.randf_range(3,5))
		if i==0: at=Vector2(-3,-7)+Vector2(rng.randf_range(-0.5,0.5),rng.randf_range(-0.5,0.5)); size=Vector2(6.5,5)
		add_patch(patches,coast,Geo.outline_at(rng,at,size,rng.randf_range(-0.6,0.6),9),2,3+i)
	patches=Geo.join_shelves(patches)
	var cliffs: Array[bool]=[]
	var beach: Array=[]
	for p: Vector2 in coast:
		var cliff:=false
		for patch in patches:
			if patch.height>=4 and Geo.coast_distance(p,Array(patch.outline))<0.02: cliff=true; break
		cliffs.append(cliff)
		beach.append(p.move_toward(Vector2(-5,1),0.9) if shore_slopes and cliff else (p if cliff else p.move_toward(Vector2(-5,1),rng.randf_range(0.65,1.6))))
	var fringe: Dictionary={}
	if detail_version>=21: fringe=preload("res://scripts/settlement/fringing_reef.gd").make(coast,cliffs,Shape.offshore_outline(coast,1.18),seed_value,detail_version>=22)
	var meshes: Array[ArrayMesh]=[base_mesh(coast,beach,cliffs,seed_value,shore_slopes,fringe)]
	var shelves: Array=[]
	var shoulders: Array=[]
	var mountain_forms: Array=[]
	if detail_version>=24:
		for patch in patches:
			if patch.height<6: continue
			mountain_forms.append(preload("res://scripts/settlement/mountain_shoulders.gd").form(Array(patch.outline),patch.height,heading,seed_value+patch.index*719))
	for patch in patches:
		var foot:=Shape.clean_outline(Array(patch.outline),0.4 if sculpted_mountains else 0.002)
		if Geometry2D.is_polygon_clockwise(PackedVector2Array(foot)): foot.reverse()
		var height: float=patch.height
		# Local inward normals keep concave unions from shrinking across a bay.
		var neck: Array=[]
		for i in foot.size():
			var p: Vector2=foot[i]
			var tangent: Vector2=(foot[(i+1)%foot.size()]-foot[posmod(i-1,foot.size())]).normalized()
			var inset:=Vector2(-tangent.y,tangent.x)*minf(0.55,Geo.coast_distance(p,coast)*0.3)
			var q:=p+inset
			neck.append(q if Geometry2D.is_point_in_polygon(q,PackedVector2Array(foot)) else p)
		if blended_ridges and height>=6:
			var shoulder:=preload("res://scripts/settlement/mountain_shoulders.gd").generate(foot,height,heading,seed_value+patch.index*719,detail_version>=23)
			neck=shoulder.outline
			if detail_version<24: meshes.append(shoulder.mesh)
			shoulders.append({"foot":PackedVector2Array(foot),"crown":shoulder.crown,"height":height})
		elif tapered_shelves:
			var widths: Array=[]
			for p: Vector2 in foot:
				var width:=clampf((height+4.0)*0.18,0.85,2.0) if shore_slopes else minf(minf(0.75,height*0.18),Geo.coast_distance(p,coast)*0.3)
				# The exposed wall remains steep while inland slopes retreat more.
				if sculpted_mountains and Geo.coast_distance(p,coast)<0.5: width=minf(width,1.0)
				widths.append(width)
			neck=Shape.tapered_outline(foot,widths,shore_slopes)
			# Version 17 retreats from a submerged foot to the cap, including
			# sea cliffs. Older saved islands retain their pinned shore vertices.
			var profiles: Array=[Landform.ring(foot,-4.05),Landform.ring(neck,height)] if shore_slopes else [Landform.ring(foot,-4.05),Landform.ring(foot,0),Landform.ring(neck,height)]
			var mesh:=weld_caps(Landform.loft(profiles,seed_value+patch.index,0.16,0))
			if blended_ridges and is_equal_approx(height,4.0):
				mesh=preload("res://scripts/settlement/mountain_shoulders.gd").rising_bench(mesh,normal,start+(9.0 if detail_version>=23 else 13.0),height,detail_version>=21,seed_value,detail_version>=23,mountain_forms,neck,coast)
			else: mesh=Shape.paint(mesh)
			meshes.append(mesh)
		else:
			meshes.append(Shape.paint(weld_caps(Landform.loft([Landform.ring(foot,-4.05),Landform.ring(neck,height-0.8),Landform.ring(foot,height-0.3),Landform.ring(foot,height)],seed_value+patch.index,0.16,0))))
		if detail_version>=24 and height>=6: continue
		shelves.append({"outline":PackedVector2Array(neck if tapered_shelves else foot),"height":height})
	# One to three narrow rock blades, fitted to actual shelf interiors.
	var candidates:=shelves.duplicate()
	candidates.sort_custom(func(a,b): return Shape.polygon_area(a.outline)>Shape.polygon_area(b.outline))
	var peaks:=0; var wanted:=0 if blended_ridges else rng.randi_range(1,3)
	for shelf in candidates:
		if shelf.height<4 or peaks>=wanted: continue
		var triangles:=Geometry2D.triangulate_polygon(shelf.outline)
		var at:=Vector2.ZERO; var largest:=0.0
		for i in range(0,triangles.size(),3):
			var a: Vector2=shelf.outline[triangles[i]]; var b: Vector2=shelf.outline[triangles[i+1]]; var c: Vector2=shelf.outline[triangles[i+2]]
			var area:=absf((b-a).cross(c-a))
			if area>largest: largest=area; at=(a+b+c)/3
		var blade_size:=Vector2(rng.randf_range(1.6,2.6),rng.randf_range(5,8)) if sculpted_mountains else Vector2(rng.randf_range(2,4),rng.randf_range(3,6))
		var blade_angle:=heading+rng.randf_range(-0.5,0.5) if sculpted_mountains else rng.randf_range(-PI,PI)
		var foot:=Geo.outline_at(rng,at,blade_size,blade_angle,7)
		for attempt in 14:
			if Array(foot).all(func(p): return Geometry2D.is_point_in_polygon(p,shelf.outline)): break
			for i in foot.size(): foot[i]=at+(foot[i]-at)*0.8
		var shoulder: Array=[]; var peak:=PackedVector3Array()
		var rise:=rng.randf_range(5.5,8)
		for p: Vector2 in foot:
			shoulder.append(at+(p-at)*0.65)
			var q: Vector2=at+(p-at)*0.16
			var crown_height:=minf(19,shelf.height+rise+rng.randf_range(-1,1))
			if sculpted_mountains:
				var local: Vector2=(p-at).rotated(-blade_angle)
				q=at+(local*Vector2(0.22,0.56)).rotated(blade_angle)
				crown_height=minf(19,shelf.height+rise+local.y/blade_size.y*2.8)
			peak.append(Vector3(q.x,crown_height,q.y))
		var mesh:=Landform.loft([Landform.ring(Array(foot),shelf.height-0.1),Landform.ring(shoulder,shelf.height+rise*0.55),peak],seed_value+peaks,0.16,0)
		for surface in mesh.get_surface_count(): mesh.surface_set_material(surface,Landform.material(Color("667569") if surface==0 else Color("4f625e")))
		meshes.append(mesh); peaks+=1
	var ledge_count:=0
	if detail_version>=21: ledge_count=preload("res://scripts/settlement/mountain_shoulders.gd").ledges(meshes,normal,start+13.0,seed_value)
	return {"coast":PackedVector2Array(coast),"meshes":meshes,"ledge_count":ledge_count,"transform":Transform3D.IDENTITY,"mainland":true,"family":"procedural_mainland","seed":seed_value,"top_height":19.0,"shelves":shelves,"shoulders":shoulders,"mountain_forms":mountain_forms,"fringe":fringe,"cliff_heading":heading,"crest_height":crest_height,"bed_coast":PackedVector2Array(Shape.offshore_outline(coast,1.18) if shore_slopes else coast)}

static func outline(rng: RandomNumberGenerator, shore_slopes := false) -> Array:
	var centre:=Vector2(rng.randf_range(-9,-4),rng.randf_range(-3,1))
	var axes:=Vector2(rng.randf_range(26,36),rng.randf_range(23,32))
	var rotation:=rng.randf_range(-0.65,0.65)
	var phase:=rng.randf_range(-PI,PI)
	var bay_angle:=rng.randf_range(-0.45,0.6)
	var bays: Array=[[bay_angle,rng.randf_range(0.32,0.60),rng.randf_range(0.3,0.6)],
		[bay_angle+rng.randf_range(1.25,2.1),rng.randf_range(0.35,0.65),rng.randf_range(0.27,0.52)]]
	var coast: Array=[]
	for i in 44:
		var angle:=TAU*i/44.0
		var radius:=1.0+0.10*sin(angle*3+phase)+0.045*sin(angle*5-phase)
		for bay in bays: radius-=bay[1]*exp(-pow(angle_difference(angle,bay[0])/bay[2],2))
		var offset: Vector2=(Vector2.from_angle(angle)*axes*radius).rotated(rotation)
		var direction:=offset.normalized()
		# Same safe starting resources, while everything outside can vary.
		var reserve:=Vector2(14.5,12.5) if shore_slopes else Vector2(13,11)
		var relative: Vector2=(centre-Vector2(-3,0))/reserve
		var ray: Vector2=direction/reserve
		var b:=relative.dot(ray)
		var minimum:=(-b+sqrt(b*b-ray.length_squared()*(relative.length_squared()-1.0)))/ray.length_squared()
		coast.append(centre+direction*maxf(offset.length(),minimum))
	return coast

static func mask(rng: RandomNumberGenerator, normal: Vector2, start: float) -> PackedVector2Array:
	var tangent:=Vector2(-normal.y,normal.x)
	var result:=PackedVector2Array()
	for i in 9: result.append(normal*(start+rng.randf_range(-3.5,3.5))+tangent*(-60+i*15))
	result.append(normal*80+tangent*60); result.append(normal*80-tangent*60)
	return result

static func add_patch(patches: Array, coast: Array, mask_polygon: PackedVector2Array, height: float, index: int) -> void:
	# Reserve a broad two-metre foothill as well as the opening ground. Higher
	# blocks stop behind this ledge, leaving real house plots after stair access.
	var reserve:=PackedVector2Array(CLEAR)
	if height>2:
		reserve=PackedVector2Array([Vector2(-12,-2),Vector2(-11,-6),Vector2(-8,-11),Vector2(-1,-12),Vector2(3,-9),Vector2(4,-6),Vector2(8,-6),Vector2(10,2),Vector2(10,6),Vector2(6,6),Vector2(3,8),Vector2(-3,8),Vector2(-10,10),Vector2(-12,6)])
	for inside in Geometry2D.intersect_polygons(PackedVector2Array(coast),mask_polygon):
		for polygon in Geometry2D.clip_polygons(inside,reserve):
			if Shape.polygon_area(polygon)<12: continue
			patches.append({"outline":polygon,"height":height,"at":Vector2.ZERO,"index":index})

static func base_mesh(coast: Array, beach: Array, cliffs: Array[bool], seed_value: int, shore_slopes := false, fringe: Dictionary = {}) -> ArrayMesh:
	var bottom:=coast.duplicate()
	if shore_slopes: bottom=Shape.offshore_outline(coast,1.18)
	var bottom_ring:=Landform.ring(bottom,-4)
	if not fringe.is_empty():
		for i in bottom_ring.size(): bottom_ring[i].y=fringe.toe_heights[i]
	var mesh:=Landform.loft([bottom_ring,Landform.ring(coast,-0.65 if shore_slopes else -0.07),Landform.ring(beach,0)],seed_value,0.16,0)
	var top:=SurfaceTool.new(); top.begin(Mesh.PRIMITIVE_TRIANGLES); top.set_material(Landform.material(Color("a8b966")))
	var sand:=SurfaceTool.new(); sand.begin(Mesh.PRIMITIVE_TRIANGLES); sand.set_material(Landform.material(Color("e5d6aa")))
	var rock:=SurfaceTool.new(); rock.begin(Mesh.PRIMITIVE_TRIANGLES); rock.set_material(Landform.material(Color("596e66")))
	var used_rock:=false
	var faces:=mesh.get_faces()
	for i in range(0,faces.size(),3):
		var normal: Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
		var flat_land:=normal.y>0.99
		if not fringe.is_empty(): flat_land=flat_land and minf(faces[i].y,minf(faces[i+1].y,faces[i+2].y))>=-0.0001
		var surface:=top if flat_land else sand
		if normal.y<=0.99:
			var at: Vector3=(faces[i]+faces[i+1]+faces[i+2])/3
			var near:=INF; var edge:=0
			for j in coast.size():
				var distance:=Vector2(at.x,at.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(at.x,at.z),coast[j],coast[(j+1)%coast.size()]))
				if distance<near: near=distance; edge=j
			if cliffs[edge] and cliffs[(edge+1)%coast.size()]: surface=rock; used_rock=true
		Landform.triangle(surface,faces[i],faces[i+2],faces[i+1])
	var result:=ArrayMesh.new(); top.index(); top.commit(result); sand.index(); sand.commit(result)
	if used_rock: rock.index(); rock.commit(result)
	return result

static func weld_caps(mesh: ArrayMesh) -> ArrayMesh:
	return Shape.weld_caps(mesh)
