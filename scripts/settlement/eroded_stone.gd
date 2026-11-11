extends RefCounted
## Convex fractured boulders, shared by rendering, mining, collision and occupancy.
const Base=preload("res://scripts/settlement/stone_volume.gd")
const Landform=preload("res://scripts/settlement/landform.gd")
static var cache: Dictionary={}

static func capacity(cell: Vector3i, seed_value: int) -> int:
	return Base.capacity(cell,seed_value)

static func logical_amount(cell: Vector3i, seed_value: int, amount: int, saved_capacity := 0) -> int:
	return Base.logical_amount(cell,seed_value,amount,saved_capacity)

static func boulder(rng: RandomNumberGenerator, at: Vector3, size: Vector3) -> Array:
	# Clip a solid with tilted fracture planes, rather than stacking cube columns.
	var vertices: Array[Vector3]=[]
	for y in [0.0,1.0]:
		for p: Vector3 in Base.CORNERS: vertices.append(Vector3(p.x,y,p.z))
	var faces: Array=[]
	for indices in Base.FACES:
		var face: Array[Vector3]=[]
		for i in indices: face.append(vertices[i])
		faces.append(face)
	for normal in [Vector3(1,0.5,1),Vector3(-1,0.3,1),Vector3(1,0.6,-1),Vector3(-1,0.4,-1),Vector3(0.4,1,0.25),Vector3(-0.3,1,-0.4)]:
		faces=Base.clip(faces,normal,0.70+rng.randf_range(-0.08,0.08))
	# Plane clipping can retain redundant points on a straight shared edge.
	# Remove them on every face before triangulation, avoiding T-junctions.
	for face in faces:
		var changed:=true
		while changed and face.size()>3:
			changed=false
			for i in face.size():
				var a: Vector3=face[posmod(i-1,face.size())]; var b: Vector3=face[i]; var c: Vector3=face[(i+1)%face.size()]
				if b.distance_to(Geometry3D.get_closest_point_to_segment(b,a,c))<0.00001:
					face.remove_at(i); changed=true; break
	weld(faces)
	var angle:=rng.randf_range(-PI,PI)
	for face in faces:
		for i in face.size(): face[i]=at+(Vector3(face[i])*size).rotated(Vector3.UP,angle)
	return faces

static func weld(faces: Array) -> void:
	var vertices: Array[Vector3]=[]
	for face in faces:
		for i in face.size():
			var found:=false
			for vertex in vertices:
				if vertex.distance_squared_to(face[i])<0.000000000004:
					face[i]=vertex; found=true; break
			if not found: vertices.append(face[i])

static func sections(cell: Vector3i, seed_value: int) -> Array[Dictionary]:
	var key: Array=[cell,seed_value]
	if cache.has(key): return cache[key]
	var rng:=RandomNumberGenerator.new(); rng.seed=hash(key)
	var result: Array[Dictionary]=[]
	var count:=capacity(cell,seed_value)/9
	for i in count:
		var angle:=TAU*i/count
		# Low rubble fans around two embedded larger fragments; no vertical stacks.
		var radius:=0.55 if i<2 else rng.randf_range(0.75,1.15)
		var at:=Vector3(cos(angle)*radius,-0.025,sin(angle)*radius)
		var size:=Vector3(1.3,1.8,1.1) if i<2 else Vector3(rng.randf_range(0.65,1.0),rng.randf_range(0.5,1.0),rng.randf_range(0.6,0.9))
		result.append({"faces":boulder(rng,at,size),"count":9,"start":i*9})
	if cache.size()>512: cache.erase(cache.keys()[0])
	cache[key]=result
	return result

static func visual_faces(section: Dictionary, remaining: int) -> Array:
	if remaining<=0: return []
	if remaining>=section.count: return section.faces
	if section.get("remaining",-1)==remaining: return section.cut
	var low: float=-0.025; var high:=2.0
	var target: float=Base.polygon_volume(section.faces)*remaining/section.count
	var cut: Array=[]
	for i in 18:
		var middle: float=(low+high)*0.5
		cut=Base.clip(section.faces,Vector3.UP,middle)
		if Base.polygon_volume(cut)<target: low=middle
		else: high=middle
	weld(cut)
	section.remaining=remaining; section.cut=cut
	return cut

static func solid_at(cell: Vector3i, seed_value: int, amount: int, point: Vector3, saved_capacity := 0) -> bool:
	amount=logical_amount(cell,seed_value,amount,saved_capacity)
	for section in sections(cell,seed_value):
		if Base.contains(visual_faces(section,clampi(amount-section.start,0,section.count)),point): return true
	return false

static func occupied_boxes(cell: Vector3i, seed_value: int, amount: int, saved_capacity := 0) -> Array[AABB]:
	amount=logical_amount(cell,seed_value,amount,saved_capacity)
	var result: Array[AABB]=[]
	for section in sections(cell,seed_value):
		var faces:=visual_faces(section,clampi(amount-section.start,0,section.count))
		if faces.is_empty(): continue
		var box:=AABB(faces[0][0],Vector3.ZERO)
		for face in faces:
			for p: Vector3 in face: box=box.expand(p)
		result.append(box)
	return result

static func mesh(faces: Array, colour := Color("738077")) -> ArrayMesh:
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for i in range(1,face.size()-1):
			var normal: Vector3=(face[i]-face[0]).cross(face[i+1]-face[0])
			if normal.length_squared()<0.000000000000000001: continue
			surface.set_normal(normal.normalized())
			for vertex in [face[0],face[i+1],face[i]]: surface.add_vertex(vertex)
	surface.set_material(Landform.material(colour)); surface.index()
	return surface.commit()
