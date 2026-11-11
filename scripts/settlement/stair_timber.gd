extends RefCounted
## Split ordinary Log stock lengthwise. Stock length and diameter stay canonical.
const Timber=preload("res://scripts/settlement/timber_kit.gd")
const Palette=preload("res://scripts/settlement/timber_palette.gd")
static var half_log: ArrayMesh
static func triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	for p in [a,b,c]: st.add_vertex(p)
static func stock_mesh() -> ArrayMesh:
	if half_log!=null: return half_log
	var bark:=SurfaceTool.new(); bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood:=SurfaceTool.new(); wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius:=Timber.LOG_DIAMETER/2; var end:=Timber.LOG_LENGTH/2
	for i in 6:
		var a:=Vector3(0,cos(PI*i/6.0)*radius,sin(PI*i/6.0)*radius)
		var b:=Vector3(0,cos(PI*(i+1)/6.0)*radius,sin(PI*(i+1)/6.0)*radius)
		triangle(bark,a+Vector3.LEFT*end,a+Vector3.RIGHT*end,b+Vector3.RIGHT*end)
		triangle(bark,a+Vector3.LEFT*end,b+Vector3.RIGHT*end,b+Vector3.LEFT*end)
		triangle(wood,Vector3.LEFT*end,a+Vector3.LEFT*end,b+Vector3.LEFT*end)
		triangle(wood,Vector3.RIGHT*end,b+Vector3.RIGHT*end,a+Vector3.RIGHT*end)
	var a:=Vector3(-end,-radius,0); var b:=Vector3(end,-radius,0); var c:=Vector3(end,radius,0); var d:=Vector3(-end,radius,0)
	triangle(wood,a,b,c); triangle(wood,a,c,d)
	bark.generate_normals(); bark.set_material(Palette.material("tree","log",0))
	wood.generate_normals(); wood.set_material(Palette.material("tree","log",1))
	half_log=bark.commit(); wood.commit(half_log); return half_log
static func member(root: Node3D,label: String,a: Vector3,b: Vector3,side:=1) -> void:
	var direction: Vector3=(b-a).normalized()
	var basis:=Basis(Quaternion(Vector3.RIGHT,direction))
	if side<0: basis=basis.rotated(direction,PI)
	var mesh:=ArrayMesh.new()
	for surface in 2:
		var st:=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for offset in Timber.centres(a.distance_to(b),Timber.LOG_LENGTH):
			st.append_from(stock_mesh(),surface,Transform3D(basis,(a+b)/2+direction*offset))
		st.set_material(Palette.material("tree","log",surface)); st.commit(mesh)
	var part:=MeshInstance3D.new(); part.name=label; part.mesh=mesh
	part.set_meta("timber_count",Timber.centres(a.distance_to(b),Timber.LOG_LENGTH).size())
	part.set_meta("timber_stock","log"); part.set_meta("timber_cut_profile","split_half")
	root.add_child(part)
static func populate(root: Node3D,rise: int) -> void:
	for child in root.get_children():
		if child is MeshInstance3D: child.free()
	var bounds: AABB=Timber.sources("plank")[0].pose*Timber.sources("plank")[0].mesh.get_aabb()
	var basis:=Basis(Vector3.UP,PI/2)
	# Keep both variants' node names identical for the existing mesh-swap path.
	for i in 10:
		var step:=mini(i,rise*5-1)
		var at:=Vector3(lerpf(-0.86,0.86,float(step)/maxi(1,rise*5-1)),(step+1)*0.2-bounds.size.y/2,0)
		var poses: Array[Transform3D]=[]
		for offset in [-0.1,0.1]: poses.append(Transform3D(basis,at+Vector3(0,0,offset)-basis*bounds.get_center()))
		var tread:=MeshInstance3D.new(); tread.name="LadderRung_%02d" % i; tread.mesh=Timber.batch("plank",poses)
		tread.set_meta("timber_stock","plank"); tread.set_meta("timber_count",poses.size()); root.add_child(tread)
		tread.visible=i<rise*5
	for side in [-1,1]:
		member(root,"LadderRail%d" % side,Vector3(-0.86,0.08,side*0.45),Vector3(0.86,rise-0.12,side*0.45),side)
		member(root,"LadderSupport%d" % side,Vector3(0.80,0.08,side*0.45),Vector3(0.80,rise-0.16,side*0.45),side)
	for label in ["LowerEntrance","UpperEntrance"]:
		if not root.has_node(label):
			var marker:=Marker3D.new(); marker.name=label; root.add_child(marker)
	root.get_node("LowerEntrance").position=Vector3(-1,0,0)
	root.get_node("UpperEntrance").position=Vector3(1,rise,0)
