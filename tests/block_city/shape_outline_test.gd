extends SceneTree
const Outline=preload("res://scripts/block_city/shape_outline.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rectangle:=[]
	for x in 2:
		for z in 3: rectangle.append(Vector3i(x,0,z))
	var edges: Array=Outline.edges(rectangle)
	check(edges.size()==12,"A six-cell rectangle has only twelve outer cuboid edges")
	for edge in edges:
		if edge[0].y!=edge[1].y:
			check(edge[0].x in [0,2] and edge[0].z in [0,3],"Only outer corners have vertical lines")
		else:
			check((edge[0].x==edge[1].x and edge[0].x in [0,2]) or (edge[0].z==edge[1].z and edge[0].z in [0,3]),"No internal lines remain on top or bottom")
	var concave: Array=Outline.edges([Vector3i(0,0,0),Vector3i(0,0,1),Vector3i(0,0,2),Vector3i(1,0,2)])
	check(concave.size()==18,"Concave footprint retains its six outer corners instead of a bounding box")
	check(concave.any(func(edge):return edge[0]==Vector3i(1,0,2) and edge[1]==Vector3i(1,1,2)),"The inset corner remains outlined")
	check(Outline.edges([Vector3i.ZERO,Vector3i.UP]).size()==12,"Stacked cells have no horizontal seam between storeys")
	check(Outline.edges([]).is_empty(),"Empty selection produces no lines")
	check(Outline.edges([Vector3i.ZERO]).size()==12,"A single cube keeps its outer shape")
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=8
	camera.position=Vector3(-5,5,-7)
	camera.look_at(Vector3(1,0.5,1.5))
	var contour: Array=Outline.silhouette(rectangle,camera)
	check(contour.size()==1,"The entire room has one merged projected outline")
	check(contour[0].size()==6,"Cuboid selection has only its six silhouette corners, with no back edges")
	check(Outline.silhouette([],camera).is_empty(),"Empty silhouette is safe")
	camera.position=Vector3(0,10,0)
	camera.look_at(Vector3.ZERO,Vector3.FORWARD)
	var cut_shape: Array=Outline.silhouette([Vector3i(0,0,0),Vector3i(0,0,1),Vector3i(0,0,2),Vector3i(1,0,2)],camera)
	check(cut_shape.size()==1 and cut_shape[0].size()==6,"Top-down carved shape keeps its concave contour")
	check(not Geometry2D.is_point_in_polygon(camera.unproject_position(Vector3(1.5,0.5,0.5)),cut_shape[0]),"An empty notch is not enclosed by a bounding-box outline")
	camera.free()
	print("Block City shape outline: ",failures," failures")
	quit(1 if failures else 0)
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
