extends RefCounted
## Close-fitted stock boards. Bevels and small surface steps are geometry, not textures.
const Timber=preload("res://scripts/settlement/timber_kit.gd")
const Wood=preload("res://scripts/settlement/timber_palette.gd")
const BEVEL:=0.018
const RELIEF:=0.030
const PATCH:=1.0
static var meshes: Dictionary={}
static var material: StandardMaterial3D

static func subtract(rect: Rect2, hole: Rect2) -> Array[Rect2]:
	var overlap:=rect.intersection(hole)
	if not hole.has_area() or not overlap.has_area(): return [rect]
	var result: Array[Rect2]=[]
	for piece in [Rect2(rect.position,Vector2(rect.size.x,overlap.position.y-rect.position.y)),Rect2(Vector2(rect.position.x,overlap.end.y),Vector2(rect.size.x,rect.end.y-overlap.end.y)),Rect2(Vector2(rect.position.x,overlap.position.y),Vector2(overlap.position.x-rect.position.x,overlap.size.y)),Rect2(Vector2(overlap.end.x,overlap.position.y),Vector2(rect.end.x-overlap.end.x,overlap.size.y))]:
		if piece.size.x>0.00001 and piece.size.y>0.00001: result.append(piece)
	return result

static func boards(rect: Rect2, seed_: int, hole:=Rect2()) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for pz in range(floori(rect.position.y),ceili(rect.end.y)):
		for px in range(floori(rect.position.x),ceili(rect.end.x)):
			var patch:=Vector2(px,pz)
			var axis:=posmod(px+pz,2)
			var rng:=RandomNumberGenerator.new(); rng.seed=hash([seed_,px,pz,"plank-patch-v2"])
			# Five parallel strips make a metre-square panel. Stock joints align
			# within each panel; there is no alternating brick-bond arrangement.
			for row in 5:
				var lift:=rng.randf_range(-RELIEF*2.0/3.0,RELIEF/3.0)
				var pitch:=rng.randf_range(-0.008,0.008)
				var shade:=rng.randf_range(0.97,1.025)
				var edge_seed:=rng.randi()
				for span in [Vector2(0,Timber.BOARD.x),Vector2(Timber.BOARD.x,PATCH)]:
					var piece:=Rect2(patch+Vector2(span.x,row*0.2),Vector2(span.y-span.x,0.2)) if axis==0 else Rect2(patch+Vector2(row*0.2,span.x),Vector2(0.2,span.y-span.x))
					piece=piece.intersection(rect)
					if not piece.has_area(): continue
					for cut in subtract(piece,hole): result.append({"rect":cut,"patch":patch,"axis":axis,"lift":lift,"pitch":pitch,"shade":shade,"edge_seed":edge_seed})
	return result

static func triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,colour: Color) -> void:
	st.set_color(colour)
	for point in [a,b,c]: st.add_vertex(point)
static func quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,colour: Color) -> void:
	triangle(st,a,b,c,colour); triangle(st,a,c,d,colour)

static func mesh(rect: Rect2,seed_: int,hole: Rect2,flat:=false) -> ArrayMesh:
	var key:=str([rect,seed_,hole,flat])
	if meshes.has(key): return meshes[key]
	var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=0
	for board in boards(rect,seed_,hole):
		count+=1
		var r: Rect2=board.rect
		var bevel:=minf(BEVEL,minf(r.size.x,r.size.y)*0.18)
		var corners: Array[Vector2]=[r.position,Vector2(r.get_center().x,r.position.y),Vector2(r.end.x,r.position.y),Vector2(r.end.x,r.get_center().y),r.end,Vector2(r.get_center().x,r.end.y),Vector2(r.position.x,r.end.y),Vector2(r.position.x,r.get_center().y)]
		var bottom: Array[Vector3]=[]; var shoulder: Array[Vector3]=[]; var top: Array[Vector3]=[]
		var rng:=RandomNumberGenerator.new(); rng.seed=board.edge_seed
		for p in corners:
			var inset: Vector2=(r.get_center()-p).sign()*bevel*rng.randf_range(0.4,1.4)
			var inner: Vector2=p+inset
			var y: float=0.0 if flat else board.lift+board.pitch*(p[board.axis]-board.patch[board.axis]-0.5)
			bottom.append(Vector3(p.x,y-Timber.BOARD.y,p.y))
			shoulder.append(Vector3(p.x,y-bevel*0.65,p.y))
			top.append(Vector3(inner.x,y,inner.y))
		var shade: float=board.shade
		var face:=Color(shade,shade,shade)
		var center:=Vector3.ZERO
		for p in top: center+=p/top.size()
		center.y+=0.004 if not flat else 0.0
		var under:=center-Vector3.UP*(Timber.BOARD.y+0.004)
		for i in top.size():
			var j: int=(i+1)%top.size()
			triangle(st,center,top[i],top[j],face)
			triangle(st,under,bottom[j],bottom[i],face.darkened(0.24))
			quad(st,bottom[i],bottom[j],shoulder[j],shoulder[i],face.darkened(0.22))
			quad(st,shoulder[i],shoulder[j],top[j],top[i],face.darkened(0.18))
	st.generate_normals()
	if material==null:
		material=StandardMaterial3D.new(); material.albedo_color=Wood.WOOD[0]
		material.roughness=1.0; material.vertex_color_use_as_albedo=true
	st.set_material(material)
	var result:=st.commit(); result.set_meta("plank_count",count)
	if meshes.size()>=128: meshes.clear()
	meshes[key]=result
	return result

static func build(root: Node3D,rect: Rect2,height: float,seed_: int,hole:=AABB()) -> void:
	var opening:=Rect2(Vector2(hole.position.x,hole.position.z),Vector2(hole.size.x,hole.size.z)) if hole.has_volume() else Rect2()
	var node:=MeshInstance3D.new(); node.name="FittedPlankFloor"
	node.mesh=mesh(rect,seed_,opening,root.name=="HomeFloor"); node.position.y=height
	node.set_meta("component_count",node.mesh.get_meta("plank_count"))
	node.set_meta("stock_cut_from","plank")
	root.add_child(node)
