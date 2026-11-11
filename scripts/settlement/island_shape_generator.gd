extends RefCounted
## Seeded contour construction, not a heightmap: the sea-facing rim can stay
## vertical while independent lee-side shelves and undercuts move inward/outward.
const Landform = preload("res://scripts/settlement/landform.gd")
const FAMILIES := ["headland", "cove", "saddle", "bluff"]

static func generate(seed_value: int, family: String, centre: Vector2, size_factor := 1.0, tapered_shelves := false, shore_slopes := false, narrow_shallows := false, folded_layers := false) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed=seed_value
	var size := Vector2(10,4.6)
	match family:
		"cove": size=Vector2(9,8)
		"saddle": size=Vector2(10.5,6)
		"bluff": size=Vector2(6,7.5)
	size *= size_factor*rng.randf_range(0.88,1.06)
	var rotation := rng.randf_range(-PI,PI)
	var wind_angle := rng.randf_range(-1.2,1.2)
	var wind := Vector2.from_angle(wind_angle)
	var count := rng.randi_range(12,16)
	var phase := rng.randf_range(-PI,PI)
	var coast: Array = []; var shelter: Array[float] = []
	var shelf_width := rng.randf_range(2.2,3.8)
	var beach_width := rng.randf_range(0.8,1.7)
	for i in count:
		var angle := TAU*(float(i)+rng.randf_range(-0.18,0.18))/count
		var direction := Vector2.from_angle(angle)
		var radius := 1.0+0.13*sin(angle*3+phase)+rng.randf_range(-0.07,0.07)
		if family=="cove":
			# A deep bay cuts into one side; it is not just a stretched oval.
			var bay := maxf(0,direction.dot(-wind))
			radius *= 1.0-0.60*pow(bay,6)
		if family=="saddle": radius *= 1.0-0.16*pow(absf(direction.y),4)
		coast.append(direction*size*radius)
		var exposure := 1.0-smoothstep(-0.45,0.25,direction.dot(wind))
		shelter.append(0.0 if exposure<0.025 else (1.0 if exposure>0.975 else exposure))
	var beach := inset(coast,shelter,beach_width)
	var low_rim := inset(coast,shelter,beach_width+0.25)
	var shelf := inset(coast,shelter,beach_width+shelf_width)
	if tapered_shelves:
		beach=tapered_outline(coast,shelter.map(func(value): return value*beach_width))
		low_rim=tapered_outline(beach,shelter.map(func(value): return value*0.25))
		shelf=tapered_outline(low_rim,shelter.map(func(value): return value*(shelf_width-0.25)))
	if shore_slopes:
		beach=tapered_outline(coast,shelter.map(func(value): return maxf(0.6,value*beach_width)),true)
		low_rim=tapered_outline(beach,shelter.map(func(value): return maxf(0.2,value*0.25)),true)
		shelf=tapered_outline(low_rim,shelter.map(func(value): return maxf(0.25,value*(shelf_width-0.25))),true)
	var low_height := float(rng.randi_range(1,3))
	var top_height := low_height+float(rng.randi_range(3,5))
	if family=="cove": top_height=low_height+2.0
	var bottom:=coast.duplicate()
	if shore_slopes:
		for i in bottom.size(): bottom[i]=Vector2(bottom[i])*(1.12 if narrow_shallows else 1.4)
	var profiles := [Landform.ring(bottom,-4),Landform.ring(coast,-0.65 if shore_slopes else -0.07),Landform.ring(beach,0),Landform.ring(low_rim,low_height)]
	var meshes: Array[ArrayMesh] = []
	# Keep tiny joining facets at pinned coast corners instead of opening holes.
	var area_epsilon:=0.000000000001 if tapered_shelves else 0.00000001
	if family=="saddle":
		# Two separate heights across a broad saddle, with a real gap between summits.
		meshes.append(paint(Landform.loft(profiles,seed_value,0.16,0,area_epsilon),false,tapered_shelves))
		for side in [-1.0,1.0]:
			var foot := clip_half(shelf,side,1.2)
			var hull := Geometry2D.convex_hull(PackedVector2Array(foot))
			foot=Array(hull); foot.pop_back(); foot=clean_outline(foot)
			if foot.size()<3: continue
			var summit: Array = []; var peak_centre:=Vector2.ZERO
			for p: Vector2 in foot: peak_centre+=p
			peak_centre/=foot.size()
			for p: Vector2 in foot: summit.append(peak_centre+(p-peak_centre)*0.90)
			var height := top_height+(2.0 if side>0 else 0.0)
			var peak_profiles: Array=[Landform.ring(foot,low_height-0.1),Landform.ring(summit,height)] if shore_slopes else [Landform.ring(foot,low_height-0.1),Landform.ring(foot,height-0.5),Landform.ring(summit,height)]
			meshes.append(paint(Landform.loft(peak_profiles,seed_value,0.16,0,area_epsilon),false,tapered_shelves))
	else:
		profiles.append(Landform.ring(shelf,low_height))
		# Retain the legacy lip and its RNG draws for saved island geometry.
		var neck: Array = []
		var overhang_angle := wind_angle+1.0
		for p: Vector2 in shelf:
			var sector := pow(maxf(0,p.normalized().dot(Vector2.from_angle(overhang_angle))),8)
			if sector<0.02: sector=0.0
			neck.append(p-p.normalized()*sector*rng.randf_range(0.55,0.9))
		var summit: Array=[]
		if tapered_shelves:
			summit=tapered_outline(shelf,shelter.map(func(value): return maxf(0.4,value*0.7) if shore_slopes else value*0.7),shore_slopes)
			profiles.append(Landform.ring(summit,top_height))
		else:
			profiles.append(Landform.ring(neck,top_height-1.2))
			profiles.append(Landform.ring(shelf,top_height-0.7))
			profiles.append(Landform.ring(shelf,top_height))
		if family=="headland" and not shore_slopes:
			var crown_width:=rng.randf_range(1.2,2.0)
			var crown := tapered_outline(summit,shelter.map(func(value): return value*(crown_width-0.7))) if tapered_shelves else inset(coast,shelter,beach_width+shelf_width+crown_width)
			profiles.append(Landform.ring(crown,top_height))
			profiles.append(Landform.ring(tapered_outline(crown,crown.map(func(_p): return 0.3),true) if shore_slopes else crown,top_height+2))
			top_height+=2
		if folded_layers:
			# On the exposed side, intermediate contours lie on the same sloping
			# cliff from beach to crown. There is no narrow horizontal ring left.
			for layer in range(3,profiles.size()-1):
				for i in coast.size():
					var span: Vector2=Vector2(summit[i])-Vector2(beach[i])
					var p: Vector3=profiles[layer][i]
					var fraction:=clampf((Vector2(p.x,p.z)-Vector2(beach[i])).dot(span)/maxf(0.0001,span.length_squared()),0,1)
					p.y=lerpf(p.y,top_height*fraction,pow(1.0-shelter[i],0.6))
					profiles[layer][i]=p
		meshes.append(paint(Landform.loft(profiles,seed_value,0.16,0,area_epsilon),false,tapered_shelves))
	if folded_layers:
		# A thin windward shelf inclines into the wall. Broad lee shelves retain
		# grass, but their strata dip and rise rather than tracing the waterline.
		for i in meshes.size(): meshes[i]=fold_layers(meshes[i],wind,phase,low_height)
	var transform := Transform3D(Basis(Vector3.UP,-rotation),Vector3(centre.x,0,centre.y))
	var world_coast := PackedVector2Array()
	for p: Vector2 in coast: world_coast.append(p.rotated(rotation)+centre)
	var soil_outline:=PackedVector2Array()
	for p: Vector2 in shelf: soil_outline.append(p.rotated(rotation)+centre)
	return {"soil_shelves":[{"outline":soil_outline,"height":top_height}],"soil_levels":Vector3(0,low_height,top_height),"coast":world_coast,"meshes":meshes,"transform":transform,"mainland":false,
		"bed_coast":PackedVector2Array(bottom.map(func(p): return p.rotated(rotation)+centre)),"family":family,"cliff_direction":wind.rotated(rotation),"shelf_width":shelf_width,"top_height":top_height,"seed":seed_value}

static func fold_layers(mesh: ArrayMesh, wind: Vector2, phase: float, low_height: float) -> ArrayMesh:
	var result:=ArrayMesh.new()
	var bottom:=INF
	for p: Vector3 in mesh.get_faces(): bottom=minf(bottom,p.y)
	for index in mesh.get_surface_count():
		var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(mesh.surface_get_material(index))
		var source:=ArrayMesh.new(); source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(index))
		var faces:=source.get_faces()
		for i in range(0,faces.size(),3):
			var triangle: Array=[]
			for j in 3:
				var p: Vector3=faces[i+j]; var at:=Vector2(p.x,p.z)
				var dip:=at.dot(wind.rotated(0.65))*0.10+0.25*sin(at.dot(wind.rotated(-0.8))*0.35+phase)
				p.y+=dip*smoothstep(maxf(0.0,bottom),maxf(low_height,bottom+0.5),p.y)
				triangle.append(p)
			Landform.triangle(surface,triangle[0],triangle[2],triangle[1],1e-18)
		surface.index(); surface.commit(result)
	return result

## The settlement sits in a lowland between independently terraced coastal arms.
## Clipping every raised shelf against the SAME coast pins sea cliffs to the water;
## only the inland edge retreats. This avoids a mountain on a circular foundation.
static func generate_main(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed=seed_value^19349663
	var coast: Array = []
	var bay_angles := [0.65,1.95,3.55,5.35]
	var bay_depths: Array[float]=[]
	for i in bay_angles.size():
		bay_angles[i]+=rng.randf_range(-0.16,0.16)
		bay_depths.append(rng.randf_range(0.30,0.48))
	for i in 32:
		var angle := TAU*(i+rng.randf_range(-0.12,0.12))/32.0
		var direction := Vector2.from_angle(angle)
		var extent := Vector2(23 if direction.x>0 else 41,29)
		var radius := 1.0+rng.randf_range(-0.055,0.055)
		for j in bay_angles.size():
			var distance := angle_difference(angle,bay_angles[j])
			radius-=bay_depths[j]*exp(-pow(distance/0.25,2))
		var p := direction*extent*radius
		# Reserve the house, workers and initial resources without a round coast.
		if p.length()<15.5: p=p.normalized()*15.5
		coast.append(p)
	var meshes: Array[ArrayMesh]=[]
	var beach: Array=[]
	for p: Vector2 in coast: beach.append(p*0.94)
	var base := paint(Landform.loft([Landform.ring(coast,-4),Landform.ring(coast,-0.07),Landform.ring(beach,0)],seed_value,0.16,0),true)
	meshes.append(base)
	# Different widths, heights and directions produce unequal coastal headlands.
	var regions := [
		{"normal":Vector2(-1,-0.10).normalized(),"start":13.0,"width":5.5,"height":3.0,"top":9.0},
		{"normal":Vector2(0.08,-1).normalized(),"start":13.0,"width":4.2,"height":2.0,"top":6.0},
		{"normal":Vector2(0.45,1).normalized(),"start":14.0,"width":3.2,"height":2.0,"top":5.0}]
	for region in regions:
		var normal: Vector2=region.normal
		var start: float=region.start+rng.randf_range(-0.5,0.5)
		var width: float=region.width+rng.randf_range(-0.8,0.8)
		var bends: Array[float]=[]
		for i in 11: bends.append(rng.randf_range(-2.8,2.8))
		var feet := add_coastal_shelf(meshes,coast,normal,start,bends,-0.1,region.height,seed_value)
		# The neck ends before the upper shelf, leaving a genuine inward-facing lip.
		var upper_bends: Array[float]=[]
		for bend in bends: upper_bends.append(bend+rng.randf_range(-1.8,1.8))
		var necks := add_coastal_shelf(meshes,coast,normal,start+width+0.8,upper_bends,region.height-0.1,region.top-1.0,seed_value,feet)
		var tops := add_coastal_shelf(meshes,coast,normal,start+width,upper_bends,region.top-1.0,region.top,seed_value,necks)
		if region.top>8:
			add_coastal_shelf(meshes,coast,normal,start+width+6,upper_bends,region.top-0.1,region.top+3,seed_value,tops)
	return {"coast":PackedVector2Array(coast),"meshes":meshes,"transform":Transform3D.IDENTITY,
		"mainland":true,"family":"mainland","seed":seed_value,"top_height":12.0}

static func add_coastal_shelf(meshes: Array[ArrayMesh], coast: Array, normal: Vector2, distance: float, bends: Array[float], bottom: float, top: float, seed_value: int, supporting: Array = []) -> Array:
	var footprints: Array=[]
	var tangent := Vector2(-normal.y,normal.x)
	var mask := PackedVector2Array()
	for i in bends.size():
		var along := -50.0+i*10.0
		var edge := distance+bends[i]
		# Keep the whole protected starting circle clear, including between vertices.
		if absf(along)<=20: edge=maxf(distance,14.5)+bends[i]+2.8
		mask.append(normal*edge+tangent*along)
	mask.append(normal*80+tangent*50); mask.append(normal*80-tangent*50)
	for polygon in Geometry2D.intersect_polygons(PackedVector2Array(coast),mask):
		if polygon_area(polygon)<2.0: continue
		if bottom>0:
			var bearing := 0.0
			for support: PackedVector2Array in supporting:
				for overlap in Geometry2D.intersect_polygons(polygon,support): bearing+=polygon_area(overlap)
			# A bay can split the mask into separate tips. Never leave a floating tip.
			if bearing<0.5: continue
		var outline := clean_outline(Array(polygon))
		if outline.size()<3: continue
		if Geometry2D.is_polygon_clockwise(PackedVector2Array(outline)): outline.reverse()
		meshes.append(paint(Landform.loft([Landform.ring(outline,bottom),Landform.ring(outline,top)],seed_value,0.16,0)))
		footprints.append(PackedVector2Array(outline))
	return footprints

static func polygon_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for i in polygon.size(): area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
	return absf(area)*0.5

static func inset(outline: Array, shelter: Array[float], amount: float) -> Array:
	var result: Array = []
	for index in outline.size():
		var p: Vector2=outline[index]
		if shelter[index]==0: result.append(p); continue
		# Pinned windward vertices carry the same wall all the way into the sea.
		# A positive radius prevents thin coves from folding over themselves.
		result.append(p.normalized()*maxf(p.length()*0.32,p.length()-amount*shelter[index]))
	return result

static func clip_half(outline: Array, side: float, gap: float) -> Array:
	var result: Array = []
	for index in outline.size():
		var a: Vector2=outline[index]; var b: Vector2=outline[(index+1)%outline.size()]
		var da := a.x*side-gap; var db := b.x*side-gap
		if da>=0: result.append(a)
		if (da>=0)!=(db>=0): result.append(a.lerp(b,da/(da-db)))
	return result

static func clean_outline(outline: Array, tolerance := 0.002) -> Array:
	var result := outline.duplicate()
	var changed := true
	while changed and result.size()>3:
		changed=false
		for index in result.size():
			var a: Vector2=result[posmod(index-1,result.size())]
			var b: Vector2=result[index]; var c: Vector2=result[(index+1)%result.size()]
			if b.distance_to(Geometry2D.get_closest_point_to_segment(b,a,c))<tolerance:
				result.remove_at(index); changed=true; break
	return result

static func paint(mesh: ArrayMesh, lowland := false, precise_facets := false) -> ArrayMesh:
	var area_epsilon:=0.000000000001 if precise_facets else 0.00000001
	var surfaces: Array[SurfaceTool]=[]
	for colour: Color in [Color("a8b966"),Color("596e66"),Color("405950"),Color("e5d6aa")]:
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(Landform.material(colour)); surfaces.append(surface)
	var used := [false,false,false,false]
	var faces := mesh.get_faces()
	for i in range(0,faces.size(),3):
		var normal := (faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
		var highest := maxf(faces[i].y,maxf(faces[i+1].y,faces[i+2].y))
		var surface := (3 if highest<=0.001 else 0) if normal.y>0.99 else (2 if normal.y < -0.1 else 1)
		if lowland: surface=0 if normal.y>0.99 else (2 if normal.y < -0.1 else 3)
		Landform.triangle(surfaces[surface],faces[i],faces[i+2],faces[i+1],area_epsilon); used[surface]=true
	var result := ArrayMesh.new()
	for i in surfaces.size():
		if used[i]: surfaces[i].index(); surfaces[i].commit(result)
	return result

static func tapered_outline(foot: Array, widths: Array, strict := false) -> Array:
	# Offset along the adjacent edge normals, not the chord through neighbours:
	# uneven concave corners must stay inward of BOTH incident walls.
	var scale_factor:=1.0
	for attempt in range(14 if strict else 10):
		var cap: Array=[]
		var inside:=true
		for i in foot.size():
			var p: Vector2=foot[i]
			var incoming: Vector2=(p-foot[posmod(i-1,foot.size())]).normalized()
			var outgoing: Vector2=(foot[(i+1)%foot.size()]-p).normalized()
			var a:=Vector2(-incoming.y,incoming.x)
			var b:=Vector2(-outgoing.y,outgoing.x)
			var direction: Vector2=(a+b).normalized()
			var distance:=float(widths[i])*scale_factor
			var offset:=direction*minf(distance/maxf(direction.dot(a),0.1),distance*2.0)
			var q:=p+offset
			var contains:=Geometry2D.is_point_in_polygon(q,PackedVector2Array(foot))
			if strict and not contains and distance>0.000001: inside=false
			cap.append(q if strict or contains else p)
		var valid:=inside and not Geometry2D.triangulate_polygon(PackedVector2Array(cap)).is_empty()
		for i in cap.size():
			var next: int=(i+1)%cap.size()
			# Also reject a folded side quad at a short concave corner, even if
			# the upper polygon itself still triangulates successfully.
			if (Vector2(cap[i])-Vector2(foot[i])).cross(Vector2(cap[next])-Vector2(foot[i]))>0.000001: valid=false
			if (Vector2(cap[next])-Vector2(foot[i])).cross(Vector2(foot[next])-Vector2(foot[i]))>0.000001: valid=false
			if strict:
				var margin:=minf(float(widths[i]),float(widths[next]))*scale_factor*Vector2(foot[i]).distance_to(foot[next])*0.15
				if (Vector2(cap[i])-Vector2(foot[i])).cross(Vector2(cap[next])-Vector2(foot[i]))> -margin: valid=false
				if (Vector2(cap[next])-Vector2(foot[i])).cross(Vector2(foot[next])-Vector2(foot[i]))> -margin: valid=false
			for j in range(i+2,cap.size()):
				if i==0 and j==cap.size()-1: continue
				if Geometry2D.segment_intersects_segment(cap[i],cap[(i+1)%cap.size()],cap[j],cap[(j+1)%cap.size()])!=null: valid=false
		if valid: return cap
		scale_factor*=0.5
	return foot.duplicate()


static func weld_caps(mesh: ArrayMesh, area_epsilon := 0.00000001) -> ArrayMesh:
	# Polygon clipping can align three non-neighbouring vertices. Ear clipping
	# then leaves a long cap edge opposite two shorter edges. Split those edges
	# explicitly, preserving exact wall vertices and watertight excavation solids.
	var faces:=mesh.get_faces()
	var vertices: Dictionary={}
	for point: Vector3 in faces: vertices[point]=true
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,faces.size(),3):
		var pending: Array=[[faces[i],faces[i+1],faces[i+2]]]
		while not pending.is_empty():
			var triangle: Array=pending.pop_back()
			var split:=false
			if absf(triangle[0].y-triangle[1].y)<0.00001 and absf(triangle[0].y-triangle[2].y)<0.00001:
				for edge in 3:
					var a: Vector3=triangle[edge]; var b: Vector3=triangle[(edge+1)%3]; var c: Vector3=triangle[(edge+2)%3]
					for point: Vector3 in vertices:
						if absf(point.y-a.y)>0.00001 or point.distance_to(a)<0.0001 or point.distance_to(b)<0.0001 or point.distance_to(c)<0.0001: continue
						if point.distance_to(Geometry3D.get_closest_point_to_segment(point,a,b))>0.0002: continue
						pending.append([a,point,c]); pending.append([point,b,c]); split=true; break
					if split: break
			if not split: Landform.triangle(surface,triangle[0],triangle[2],triangle[1],area_epsilon)
	surface.index(); return surface.commit()


static func offshore_outline(coast: Array, scale_value: float) -> Array:
	var centre:=Vector2.ZERO
	for p: Vector2 in coast: centre+=p
	centre/=coast.size()
	var result: Array=[]
	for p: Vector2 in coast: result.append(centre+(p-centre)*scale_value)
	return result
