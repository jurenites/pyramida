extends RefCounted
## Local coastal masses: no island-wide cutting planes or repeated contour steps.
const Shape=preload("res://scripts/settlement/island_shape_generator.gd")
const Landform=preload("res://scripts/settlement/landform.gd")

static func generate(seed_value: int, village_terraces := false, connected_coast := false) -> Dictionary:
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value^295031
	var coast: Array=[]
	var centre:=Vector2(-7,-1)
	var bays: Array=[]
	for angle in [0.65,1.8,3.2,4.6,5.6]: bays.append([angle+rng.randf_range(-0.1,0.1),rng.randf_range(0.46,0.64)])
	for i in 40:
		var angle:=TAU*(i+rng.randf_range(-0.1,0.1))/40.0
		var radius:=1.0+rng.randf_range(-0.045,0.045)
		for bay in bays:
			var depth: float=bay[1]+(0.22 if village_terraces else 0.0)
			radius-=depth*exp(-pow(angle_difference(angle,bay[0])/0.28,2))
		var offset:=Vector2.from_angle(angle)*Vector2(32,29)*radius
		var direction:=offset.normalized()
		var dot:=centre.dot(direction)
		# A protected clearing, surrounded by deep coves rather than a circular coast.
		var minimum:=-dot+sqrt(dot*dot+15.0*15.0-centre.length_squared())
		if village_terraces:
			# A compact oval protects the family and early timber, rather than an
			# island-wide flat clearing. Bays can now approach from north/east/south.
			var axes:=Vector2(13,11)
			var relative: Vector2=(centre-Vector2(-3,0))/axes
			var ray: Vector2=direction/axes
			var b:=relative.dot(ray)
			minimum=(-b+sqrt(b*b-ray.length_squared()*(relative.length_squared()-1.0)))/ray.length_squared()
		coast.append(centre+direction*maxf(offset.length(),minimum))
	if connected_coast: coast=connected_outline(seed_value)
	var beach: Array=[]
	for p: Vector2 in coast: beach.append(p.move_toward(Vector2.ZERO,0.9))
	var meshes: Array[ArrayMesh]=[Shape.paint(Landform.loft([Landform.ring(coast,-4),Landform.ring(coast,-0.07),Landform.ring(beach,0)],seed_value,0.16,0),true)]
	var shelves: Array=[]
	# Different centres, axes and extents. Only the western mass has a broad high table.
	var specs: Array=[
		[Vector2(-25,-7),Vector2(12,11),2.0,0.15],
		[Vector2(-29,-10),Vector2(13,9),6.0,-0.35],
		[Vector2(-24,17),Vector2(10,7),3.0,0.5],
		[Vector2(-29,19),Vector2(5.0,4),5.0,-0.2],
		[Vector2(-2,-24),Vector2(10,7),4.0,-0.3],
		[Vector2(-5,-27),Vector2(6,4.5),7.0,0.35],
		[Vector2(14,18),Vector2(6,6),2.0,-0.45]]
	if village_terraces:
		# Buildable 2 m shelves near the village lead to a smaller 4 m overlook.
		# Their unequal, offset outlines leave passages, not concentric steps.
		specs.append_array([
			[Vector2(-3,-5),Vector2(4.5,4.5),2.0,-0.25],
			[Vector2(1,-9),Vector2(3.5,3.0),4.0,0.35],
			[Vector2(4,8),Vector2(4.5,3.0),2.0,-0.4],
			[Vector2(-14,6),Vector2(5,4.5),2.0,0.2]])
	if connected_coast:
		# A continuous west/north shoulder, with unequal lower benches reaching
		# into the village. Overlapping benches at one height become one solid.
		specs=[
			[Vector2(-23,-4),Vector2(16,15),2.0,0.15],
			[Vector2(-28,-9),Vector2(12,10),6.0,-0.35],
			[Vector2(-23,12),Vector2(11,7),2.0,0.3],
			[Vector2(-27,12),Vector2(7,5),5.0,-0.2],
			[Vector2(-7,-20),Vector2(15,10),4.0,-0.3],
			[Vector2(-13,-25),Vector2(8,5),7.0,0.35],
			[Vector2(-3,-5),Vector2(5.5,4.5),2.0,-0.25],
			[Vector2(1,-10),Vector2(5,4),4.0,0.35],
			[Vector2(4,8),Vector2(4.5,3.0),2.0,-0.4],
			[Vector2(-14,6),Vector2(6,5),2.0,0.2]]
	var patches: Array=[]
	for index in specs.size():
		var spec: Array=specs[index]
		var at: Vector2=spec[0]+Vector2(rng.randf_range(-0.6,0.6),rng.randf_range(-0.6,0.6))
		var outline:=outline_at(rng,at,spec[1],spec[3],10)
		# Keep actual starting resources/house clear, including the shelf underside.
		var clear:=PackedVector2Array([Vector2(-12,-12),Vector2(12,-12),Vector2(12,12),Vector2(-12,12)])
		if village_terraces:
			clear=PackedVector2Array([Vector2(-12,-2),Vector2(-9,-3),Vector2(-3,-2),Vector2(0,1),Vector2(0,5),Vector2(-3,8),Vector2(-10,10),Vector2(-12,6)])
		if connected_coast:
			clear=PackedVector2Array([Vector2(-12,-2),Vector2(-10,-3),Vector2(-10,-5.5),Vector2(-6.5,-5.5),Vector2(-6,-3),Vector2(-3,-2),Vector2(0,1),Vector2(0,5),Vector2(-3,8),Vector2(-10,10),Vector2(-12,6)])
		for inside in Geometry2D.intersect_polygons(outline,PackedVector2Array(coast)):
			for polygon in Geometry2D.clip_polygons(inside,clear):
				if Shape.polygon_area(polygon)<8: continue
				patches.append({"outline":polygon,"height":spec[2],"at":at,"index":index})
	if connected_coast: patches=join_shelves(patches)
	for patch in patches:
		var polygon: PackedVector2Array=patch.outline
		var at: Vector2=patch.at
		var index: int=patch.index
		var foot:=Shape.clean_outline(Array(polygon))
		if Geometry2D.is_polygon_clockwise(PackedVector2Array(foot)): foot.reverse()
		var height: float=patch.height
		var profiles: Array=[Landform.ring(foot,-0.1)]
		var neck: Array=[]
		for p: Vector2 in foot:
			# The inland flank is undercut; the exposed sea wall stays pinned.
			var distance:=coast_distance(p,coast)
			neck.append(p.move_toward(at,minf(0.9,distance*0.4)))
		profiles.append(Landform.ring(neck,height-0.8))
		profiles.append(Landform.ring(foot,height-0.35))
		profiles.append(Landform.ring(foot,height))
		meshes.append(Shape.paint(Landform.loft(profiles,seed_value+index,0.16,0)))
		shelves.append({"outline":PackedVector2Array(foot),"height":height})
	# Fit each fractured blade to an actual plateau, including deeply cut bay seeds.
	for level in [6.0,4.0]:
		var support:=PackedVector2Array(); var area:=0.0
		for shelf in shelves:
			if shelf.height==level and Shape.polygon_area(shelf.outline)>area:
				support=shelf.outline; area=Shape.polygon_area(support)
		if support.is_empty(): continue
		var triangles:=Geometry2D.triangulate_polygon(support)
		var at:=Vector2.ZERO; var largest:=0.0
		for i in range(0,triangles.size(),3):
			var a: Vector2=support[triangles[i]]; var b: Vector2=support[triangles[i+1]]; var c: Vector2=support[triangles[i+2]]
			var size:=absf((b-a).cross(c-a))
			if size>largest: largest=size; at=(a+b+c)/3
		var foot:=outline_at(rng,at,Vector2(2.8,5.0),rng.randf_range(-0.5,0.5),7)
		for attempt in 10:
			var fits:=true
			for p in foot:
				if not Geometry2D.is_point_in_polygon(p,support): fits=false
			if fits: break
			for i in foot.size(): foot[i]=at+(foot[i]-at)*0.8
		var shoulder: Array=[]; var peak:=PackedVector3Array()
		for p in foot:
			var q: Vector2=at+(p-at)*0.30
			shoulder.append(at+(p-at)*0.76)
			peak.append(Vector3(q.x,level+7.5+rng.randf_range(-1.5,1.0),q.y))
		var mesh:=Landform.loft([Landform.ring(Array(foot),level-0.1),Landform.ring(shoulder,level+4),peak],seed_value,0.16,0)
		for surface in mesh.get_surface_count(): mesh.surface_set_material(surface,Landform.material(Color("667569") if surface==0 else Color("4f625e")))
		meshes.append(mesh)
	return {"coast":PackedVector2Array(coast),"meshes":meshes,"transform":Transform3D.IDENTITY,"mainland":true,"family":"eroded_mainland","seed":seed_value,"top_height":15.0,"shelves":shelves}

static func outline_at(rng: RandomNumberGenerator, at: Vector2, size: Vector2, angle: float, count: int) -> PackedVector2Array:
	var outline:=PackedVector2Array()
	for i in count:
		var direction:=Vector2.from_angle(TAU*(i+rng.randf_range(-0.12,0.12))/count)
		outline.append(at+(direction*size*rng.randf_range(0.88,1.08)).rotated(angle))
	return outline

static func coast_distance(point: Vector2, coast: Array) -> float:
	var distance:=INF
	for i in coast.size(): distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,coast[i],coast[(i+1)%coast.size()])))
	return distance

static func connected_outline(seed_value: int) -> Array:
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value^831719
	var phase:=rng.randf_range(-PI,PI)
	# Two different bays on adjacent flanks leave a broad connected backshore.
	# No evenly spaced cuts: those turn the intervening headlands into star arms.
	var bays: Array=[
		[0.22+rng.randf_range(-0.10,0.10),0.57+rng.randf_range(-0.04,0.04),0.46],
		[1.63+rng.randf_range(-0.12,0.12),0.67+rng.randf_range(-0.03,0.03),0.42],
		[3.65+rng.randf_range(-0.15,0.15),0.12,0.55]]
	var centre:=Vector2(-7,-1)
	var coast: Array=[]
	for i in 48:
		var angle:=TAU*i/48.0
		var radius:=1.0+0.055*sin(angle*3+phase)+0.025*sin(angle*7-phase)
		for bay in bays: radius-=bay[1]*exp(-pow(angle_difference(angle,bay[0])/bay[2],2))
		var offset:=Vector2.from_angle(angle)*Vector2(31,27)*radius
		var direction:=offset.normalized()
		var axes:=Vector2(13,11)
		var relative: Vector2=(centre-Vector2(-3,0))/axes
		var ray: Vector2=direction/axes
		var b:=relative.dot(ray)
		var minimum:=(-b+sqrt(b*b-ray.length_squared()*(relative.length_squared()-1.0)))/ray.length_squared()
		coast.append(centre+direction*maxf(offset.length(),minimum))
	return coast

static func join_shelves(patches: Array) -> Array:
	# Union level neighbours before lofting: no seams, double walls or tiny
	# lowland channels through what should read as one continuous shelf.
	var result: Array=[]
	for original in patches:
		var patch: Dictionary=original.duplicate()
		var index:=0
		while index<result.size():
			var other: Dictionary=result[index]
			if other.height!=patch.height:
				index+=1; continue
			var joined:=Geometry2D.merge_polygons(patch.outline,other.outline)
			if joined.size()!=1:
				index+=1; continue
			patch.outline=joined[0]
			result.remove_at(index); index=0
		result.append(patch)
	return result
