extends RefCounted
## Sparse cliff-fall scenery, never a finite Stone deposit or gathering target.
const Rock=preload("res://scripts/settlement/eroded_stone.gd")
const Ocean=preload("res://scripts/settlement/ocean_surface.gd")

static func generate(islands: Array, seed_value: int) -> void:
	var terrain=load("res://scripts/settlement/solid_islands.gd")
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value^13931
	for island in islands:
		island.shoals=[]
		var candidates: Array=[]
		for i in island.coast.size():
			var a: Vector2=island.coast[i]; var b: Vector2=island.coast[(i+1)%island.coast.size()]
			var tangent: Vector2=(b-a).normalized(); var inland:=Vector2(-tangent.y,tangent.x)
			var edge: Vector2=(a+b)*0.5
			var height:=0.0
			# Inclined cliffs retreat from their toe. Sample the exposed face
			# inland instead of requiring a vertical wall at the waterline.
			for distance in [0.5,1.0,1.5,2.0]:
				for item in island.parts:
					var levels: Array=terrain.hits(item,edge+inland*distance)
					if not levels.is_empty(): height=maxf(height,levels.back())
			if height>=2: candidates.append({"edge":edge,"inland":inland,"tangent":tangent,"rank":rng.randf()})
		candidates.sort_custom(func(a,b): return a.rank<b.rank)
		var selected: Array[Vector2]=[]
		for candidate in candidates:
			if selected.any(func(p): return p.distance_to(candidate.edge)<13): continue
			var added:=0
			for j in 3:
				var at: Vector2=candidate.edge-candidate.inland*(4.0+j*1.1+rng.randf_range(-0.25,0.25))+candidate.tangent*((j-1)*2.1+rng.randf_range(-0.6,0.6))
				var clearance:=INF
				for other in islands:
					if Geometry2D.is_point_in_polygon(at,other.coast): clearance=0; break
					for k in other.coast.size():
						clearance=minf(clearance,at.distance_to(Geometry2D.get_closest_point_to_segment(at,other.coast[k],other.coast[(k+1)%other.coast.size()])))
				if clearance<2: continue
				var bed: float=terrain.bed_height_in(at,islands)
				# A dominant fallen slab, a smaller exposed fragment and a low
				# submerged stone. Each begins below the physical bed, not floating.
				var crown: float=Ocean.LEVEL+([rng.randf_range(0.8,1.5),rng.randf_range(0.2,0.65),-0.2][j])
				if bed>crown-0.4: continue
				var width:=rng.randf_range(3.0,4.2)*(1.0-j*0.20)
				var faces:=Rock.boulder(rng,Vector3.ZERO,Vector3(width,1.0,width*0.8))
				var top: float=-INF; var bottom: float=INF
				for face in faces:
					for vertex: Vector3 in face: top=maxf(top,vertex.y); bottom=minf(bottom,vertex.y)
				for face in faces:
					for k in face.size():
						var p: Vector3=face[k]
						var fraction: float=(p.y-bottom)/(top-bottom)
						# Wide buried feet and compressed broken crowns read as
						# weathered rock, rather than tall rectangular water posts.
						var spread:=lerpf(1.35,0.85,fraction)
						face[k]=Vector3(at.x+p.x*spread,lerpf(bed-0.6,crown,pow(fraction,0.6)),at.y+p.z*spread)
				var item: Dictionary=terrain.part(Rock.mesh(faces,Color("718078")),Transform3D.IDENTITY)
				item.decorative=true
				island.parts.append(item)
				var waterline:=Ocean.waterline(item.faces)
				if waterline.size()>2: island.shoals.append(waterline)
				added+=1
			if added>0: selected.append(candidate.edge)
			if selected.size()>=(2 if island.mainland else 1): break
