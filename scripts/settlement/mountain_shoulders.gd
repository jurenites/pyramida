extends RefCounted
## A mountain is one continuous rock mass, from submerged cliff foot to broad crown.
const Shape=preload("res://scripts/settlement/island_shape_generator.gd")
const Landform=preload("res://scripts/settlement/landform.gd")

static func generate(foot: Array, height: float, heading: float, seed_value: int, folded_layers := false) -> Dictionary:
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value^29173
	var normal:=Vector2.from_angle(heading)
	var centre:=Vector2.ZERO
	for p: Vector2 in foot: centre+=p
	centre/=foot.size()
	var phase:=rng.randf_range(-PI,PI)
	var apron_widths: Array=[]; var crown_widths: Array=[]
	for p: Vector2 in foot:
		var exposed:=smoothstep(-0.65,0.65,(p-centre).normalized().dot(normal))
		# On the exposed flank the mountain falls into a steep sea cliff. The
		# opposite flank retreats into a much wider shoulder above the terrace.
		apron_widths.append(lerpf(2.8,0.6,exposed))
		crown_widths.append(lerpf(1.4,0.75,exposed))
	var apron: Array=[]; var crown: Array=[]; var taper:=1.0
	for attempt in 6:
		apron=Shape.tapered_outline(foot,apron_widths.map(func(width): return width*taper),true)
		crown=Shape.tapered_outline(apron,crown_widths.map(func(width): return width*taper),true)
		# Clipped coastal fragments need proportionately smaller setbacks, or
		# a broad shoulder on a large island becomes a thin tooth on a small one.
		if Shape.polygon_area(PackedVector2Array(crown))>=Shape.polygon_area(PackedVector2Array(foot))*0.30: break
		taper*=0.72
	var shoulder_ring:=PackedVector3Array(); var crown_ring:=PackedVector3Array()
	for i in foot.size():
		var direction: Vector2=(Vector2(foot[i])-centre).normalized()
		var exposed:=smoothstep(-0.45,0.75,direction.dot(normal))
		var fracture:=sin(direction.angle()*2.0+phase)*0.55
		# The change of slope travels up and down the flank, rather than making
		# another level ring. A broad broken crown replaces an added pointed fin.
		var shoulder_y:=height-2.1+fracture+exposed*0.7
		var crown_y:=height+exposed*(1.6+fracture)
		if folded_layers:
			shoulder_y-=0.6*(1.0-exposed)
			crown_y+=0.8+exposed*1.6+fracture*0.7
		shoulder_ring.append(Vector3(apron[i].x,shoulder_y,apron[i].y))
		crown_ring.append(Vector3(crown[i].x,crown_y,crown[i].y))
	var mesh:=Landform.loft([Landform.ring(foot,-4.05),shoulder_ring,crown_ring],seed_value,0.16,0)
	mesh=paint(Shape.weld_caps(mesh))
	return {"mesh":mesh,"outline":crown,"crown":crown_ring}

static func form(foot: Array, height: float, heading: float, seed_value: int) -> Dictionary:
	var centre:=Vector2.ZERO
	for p: Vector2 in foot: centre+=p
	centre/=foot.size()
	var axes:=Vector2.ONE*3
	for p: Vector2 in foot:
		var delta: Vector2=(p-centre).rotated(-heading)
		axes.x=maxf(axes.x,absf(delta.x)); axes.y=maxf(axes.y,absf(delta.y))
	return {"centre":centre,"axes":axes,"heading":heading,"height":height+2.8,"phase":float(posmod(seed_value,971))*0.017}

static func mountain_lift(at: Vector2, forms: Array) -> float:
	var lift:=0.0
	for form in forms:
		var delta: Vector2=(at-Vector2(form.centre)).rotated(-form.heading)
		# Long uneven foothills face the village; the sea flank stays compact.
		var axes: Vector2=form.axes+Vector2(7.5 if delta.x<0 else 1.5,3.5)
		var angle:=delta.angle()
		var radius: float=(delta/axes).length()/(1.0+0.12*sin(angle*3.0+form.phase)+0.06*cos(angle*5.0-form.phase))
		var influence:=1.0-smoothstep(0.30,1.0,radius)
		lift=maxf(lift,(form.height-4.0)*influence)
	return lift

static func inland_edges(outline: Array, coast: Array) -> Array:
	var result: Array=[]
	for i in outline.size():
		var a: Vector2=outline[i]; var b: Vector2=outline[(i+1)%outline.size()]
		var middle: Vector2=(a+b)*0.5
		var sea_distance:=INF
		for j in coast.size(): sea_distance=minf(sea_distance,middle.distance_to(Geometry2D.get_closest_point_to_segment(middle,coast[j],coast[(j+1)%coast.size()])))
		if sea_distance>2.0: result.append([a,b])
	return result

static func inland_margin(at: Vector2, edges: Array) -> float:
	var distance:=INF
	for edge in edges: distance=minf(distance,at.distance_to(Geometry2D.get_closest_point_to_segment(at,edge[0],edge[1])))
	return smoothstep(1.5,6.5,distance)

static func rising_bench(mesh: ArrayMesh, normal: Vector2, start: float, height: float, broken_faces := false, seed_value := 0, folded_layers := false, mountain_forms: Array = [], bench_outline: Array = [], coast: Array = []) -> ArrayMesh:
	# Broad lee shelves stay flat. Three intersecting geological folds make an
	# uneven rocky back, rather than a single diagonal ramp or a mounted peak.
	var folds: Array=[[normal,start,0.20],[normal.rotated(0.5),start+1.0,0.12],[normal.rotated(-0.55),start+4.0,0.10]]
	var breaks:=folds.duplicate()
	var phase:=float(posmod(seed_value,971))*0.017
	if broken_faces:
		var tangent:=Vector2(-normal.y,normal.x)
		breaks.append_array([[normal.rotated(0.2),start+3.0],[normal.rotated(-0.15),start+7.0],[normal.rotated(0.3),start+12.0],[normal.rotated(-0.2),start+17.0],
			[tangent.rotated(0.2),-12.0],[tangent.rotated(-0.2),-3.0],[tangent.rotated(0.1),7.0],[tangent,17.0]])
	if not mountain_forms.is_empty():
		# Shared oblique cuts supply large low-poly facets throughout the connected
		# bench, including its walls. No separate mountain pedestal is added.
		for value in range(10,41,4): breaks.append([normal,float(value)+0.37])
		for value in range(-30,31,5): breaks.append([normal.rotated(PI/2),float(value)+0.61])
	var margin_edges:=inland_edges(bench_outline,coast) if not mountain_forms.is_empty() else []
	var mountain_heights: Dictionary={}
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces:=mesh.get_faces()
	for i in range(0,faces.size(),3):
		var pieces: Array=[[faces[i],faces[i+1],faces[i+2]]]
		for fold in breaks:
			var next: Array=[]
			for piece in pieces:
				for side in [-1.0,1.0]:
					var polygon:=clip(piece,fold[0],fold[1],side)
					if polygon.size()>=3: next.append(polygon)
			pieces=next
		for polygon in pieces:
			for j in polygon.size():
				var p: Vector3=polygon[j]; var lift:=0.0
				for fold in folds: lift+=maxf(0,Vector2(p.x,p.z).dot(fold[0])-fold[1])*fold[2]
				if broken_faces:
					# Broad fracture cells vary by less than a metre. Half-metre
					# benches give some adjacent faces a shared small ledge while
					# their neighbours remain inclined. No narrow or tall peaks.
					var weathering:=0.70*sin(p.x*0.35+phase)*sin(p.z*0.45-phase)*minf(1,lift/0.8)
					lift=maxf(0,lift+weathering) if folded_layers else maxf(0,roundf((lift+weathering)*2.0)*0.5)
				if not mountain_forms.is_empty():
					var at:=Vector2(p.x,p.z)
					if not mountain_heights.has(at): mountain_heights[at]=mountain_lift(at,mountain_forms)*inland_margin(at,margin_edges)
					lift=maxf(lift,mountain_heights[at])
				p.y+=lift*clampf((p.y+4.05)/(height+4.05),0,1)
				polygon[j]=p
			for j in range(1,polygon.size()-1): Landform.triangle(surface,polygon[0],polygon[j+1],polygon[j],1e-18 if broken_faces else 1e-12)
	return paint(surface.commit(),broken_faces,folded_layers,not mountain_forms.is_empty())

static func clip(points: Array, normal: Vector2, start: float, side: float) -> Array:
	var result: Array=[]
	for i in points.size():
		var a: Vector3=points[i]; var b: Vector3=points[(i+1)%points.size()]
		var da:=Vector2(a.x,a.z).dot(normal)-start
		var db:=Vector2(b.x,b.z).dot(normal)-start
		if da*side>=0: result.append(a)
		if da*db<0:
			# Both faces of a shared edge calculate the exact same cut vertex.
			if b<a:
				var swap:=a; a=b; b=swap
				var distance:=da; da=db; db=distance
			result.append(a.lerp(b,da/(da-db)))
	return result

static func paint(mesh: ArrayMesh, tiny_facets := false, folded_layers := false, continuous_foothills := false) -> ArrayMesh:
	var surfaces: Array[SurfaceTool]=[]; var used: Array[bool]=[false,false,false,false,false]
	for colour: Color in [Color("a8b966"),Color("748276"),Color("596e66"),Color("839081"),Color("67796e")]:
		var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(Landform.material(colour)); surfaces.append(surface)
	var faces:=mesh.get_faces()
	for i in range(0,faces.size(),3):
		var normal: Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
		var index:=0 if normal.y>0.99 else (1 if normal.y>0.65 else 2)
		if tiny_facets and normal.y>0.65 and maxf(faces[i].y,maxf(faces[i+1].y,faces[i+2].y))>4.001:
			index=3 if normal.x>0.20 else (4 if normal.z< -0.20 else 1)
		if folded_layers and normal.y>0.75 and minf(faces[i].y,minf(faces[i+1].y,faces[i+2].y))<5.8: index=0
		# One soil/rock transition across the whole folded upper surface prevents
		# narrow triangulation facets becoming dark isolated wedges at the toe.
		if continuous_foothills and normal.y>0.15 and minf(faces[i].y,minf(faces[i+1].y,faces[i+2].y))>=3.99: index=0
		Landform.triangle(surfaces[index],faces[i],faces[i+2],faces[i+1],1e-18 if tiny_facets else 1e-12); used[index]=true
	var result:=ArrayMesh.new()
	for i in surfaces.size():
		if used[i]: surfaces[i].index(); surfaces[i].commit(result)
	return result

static func ledges(meshes: Array[ArrayMesh], normal: Vector2, start: float, seed_value: int) -> int:
	var terrain=load("res://scripts/settlement/solid_islands.gd")
	var geo=preload("res://scripts/settlement/island_geology.gd")
	var parts: Array=[]
	for mesh in meshes: parts.append(terrain.part(mesh,Transform3D.IDENTITY))
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value^93719
	var candidates: Array=[]
	for x in range(-40,25,3):
		for z in range(-36,35,3):
			var at:=Vector2(x,z)+Vector2(rng.randf_range(-0.7,0.7),rng.randf_range(-0.7,0.7))
			if at.dot(normal)<start-2: continue
			var h:=surface_height(parts,at,terrain)
			if h<4.6 or h>11: continue
			var foot:=Array(geo.outline_at(rng,at,Vector2(rng.randf_range(2.0,3.0),rng.randf_range(1.2,2.0)),normal.angle()+PI/2+rng.randf_range(-0.25,0.25),6))
			var low:=INF; var high:=-INF
			var top:=floorf(h*2)/2
			for attempt in 3:
				low=INF; high=-INF
				for p: Vector2 in foot:
					var y:=surface_height(parts,p,terrain); low=minf(low,y); high=maxf(high,y)
				if low>=4.05 and top-low<=1.6 and high-low<=3.5: break
				for i in foot.size(): foot[i]=at+(foot[i]-at)*0.8
			# Follow existing inclined rock. Only a low broken lip projects from
			# it; the uphill side stays buried in the parent mountain.
			if low<4.05 or top-low<0.25 or top-low>1.6 or high-low<0.4 or high-low>3.5: continue
			candidates.append({"at":at,"foot":foot,"top":top,"rank":rng.randf()})
	candidates.sort_custom(func(a,b): return a.rank<b.rank)
	var chosen: Array[Vector2]=[]
	for candidate in candidates:
		if chosen.any(func(at): return at.distance_to(candidate.at)<6.5): continue
		var foot: Array=candidate.foot
		var neck:=Shape.tapered_outline(foot,foot.map(func(_p):return 0.45),true)
		var cap:=Shape.tapered_outline(neck,foot.map(func(_p):return 0.20),true)
		var mesh:=Landform.loft([Landform.ring(foot,-4.05),Landform.ring(neck,candidate.top-0.35),Landform.ring(cap,candidate.top)],seed_value,0.16,0)
		meshes.append(paint(Shape.weld_caps(mesh),true)); chosen.append(candidate.at)
		if chosen.size()>=5: break
	return chosen.size()

static func surface_height(parts: Array, point: Vector2, terrain) -> float:
	var result: float=-INF
	for part in parts:
		var levels: Array=terrain.hits(part,point)
		if not levels.is_empty(): result=maxf(result,levels.back())
	return result
