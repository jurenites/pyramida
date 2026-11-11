extends Control
const Stairs=preload("res://scripts/block_city/stair_geometry.gd")
const UI=preload("res://scripts/ui_visual_tokens.gd")
var cells: Array=[]
var tint:=Color.WHITE
var role:="room"
var quarter_stair:=false
var palette:=false
var selected:=false

func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func cell_unit() -> float:
	# One shared metre-to-pixel scale for every shape in equally sized cards.
	# Fit the largest 2×3 footprint; never enlarge a one-cell hall or stair.
	return minf(14*UI.POINT,minf(size.x/5.6,size.y/4.0))
func project(point: Vector3, origin: Vector2, unit: float) -> Vector2:
	return origin+Vector2((point.x-point.z)*unit,(point.x+point.z)*unit*0.5-point.y*unit)
func block(at: Vector3, dimensions: Vector3, origin: Vector2, unit: float, color: Color) -> void:
	var corners:=[]
	for i in 8: corners.append(project(at+Vector3(dimensions.x*(i&1),dimensions.y*((i>>1)&1),dimensions.z*((i>>2)&1)),origin,unit))
	for face in [[1,5,7,3],[4,5,7,6],[2,3,7,6]]:
		var polygon:=PackedVector2Array()
		for index in face: polygon.append(corners[index])
		draw_colored_polygon(polygon,color.darkened(0.16 if face[0]==1 else (0.06 if face[0]==4 else 0)))
func _draw() -> void:
	if palette:
		draw_rect(Rect2(Vector2.ZERO,size),Color("f4f3ed"))
		if selected: draw_rect(Rect2(Vector2.ONE*UI.LINE_WIDTH/2,size-Vector2.ONE*UI.LINE_WIDTH),UI.SELECTION_COLOR,false,UI.LINE_WIDTH)
	if cells.is_empty(): return
	var extent:=Vector3.ZERO
	for cell in cells: extent=extent.max(Vector3(cell)+Vector3.ONE)
	var unit:=cell_unit()
	var origin:=size*0.5-project(extent*0.5,Vector2.ZERO,unit)
	if role=="pole":
		block(Vector3(0.25,0,0.25),Vector3(0.5,0.12,0.5),origin,unit,Color("858b85"))
		block(Vector3(0.43,0.12,0.43),Vector3(0.14,2.13,0.14),origin,unit,Color("a5aaa4"))
		block(Vector3(0.10,2.20,0.43),Vector3(0.80,0.08,0.14),origin,unit,Color("293b42"))
		for x in [0.20,0.45,0.70]: block(Vector3(x,2.25,0.28),Vector3(0.10,0.16,0.10),origin,unit,Color("65cbd0"))
		return
	if role=="elevator":
		block(Vector3.ZERO,Vector3(1,0.07,1),origin,unit,tint)
		block(Vector3.ZERO,Vector3(1,1,0.06),origin,unit,tint)
		block(Vector3.ZERO,Vector3(0.06,1,1),origin,unit,tint)
		for x in [0.20,0.76]: block(Vector3(x,0.07,0.12),Vector3(0.035,0.93,0.035),origin,unit,Color("34454b"))
		block(Vector3(0.19,0.12,0.19),Vector3(0.62,0.08,0.62),origin,unit,tint.lightened(0.35))
		block(Vector3(0.19,0.20,0.19),Vector3(0.62,0.56,0.04),origin,unit,Color("e5e4d8"))
		block(Vector3(0.19,0.20,0.23),Vector3(0.04,0.56,0.58),origin,unit,Color("e5e4d8"))
		for x in [0.03,0.81]: block(Vector3(x,0.08,0.94),Vector3(0.16,0.65,0.04),origin,unit,Color("849593"))
		block(Vector3(0.22,0.20,0.78),Vector3(0.56,0.025,0.035),origin,unit,Color("edbd59"))
		block(Vector3(0.77,0.42,0.96),Vector3(0.06,0.09,0.04),origin,unit,Color("edbd59"))
		return
	if role=="stairs":
		# Same parts as the world mesh, mirrored toward the thumbnail camera.
		block(Vector3.ZERO,Vector3(1,0.04,1),origin,unit,tint)
		var pieces: Array=Stairs.parts(quarter_stair)
		pieces.sort_custom(func(a,b):return float(a.get("height",a.get("position",Vector3.ZERO).y))<float(b.get("height",b.get("position",Vector3.ZERO).y)))
		for part in pieces:
			var color:=Color("edbd59") if part.get("edge",false) else tint.lightened(0.3)
			if part.has("wedge"):
				var polygon:=PackedVector2Array()
				for v in Stairs.wedge_polygon(part.wedge): polygon.append(project(Vector3(v.x+0.5,part.height,0.5-v.y),origin,unit))
				draw_colored_polygon(polygon,color)
				draw_line(polygon[0],polygon[1],Color("edbd59"),1.0,true)
			else:
				var at: Vector3=part.position
				at=Vector3(at.x+0.5,at.y,0.5-at.z)-part.size/2
				block(at,part.size,origin,unit,color)
		return
	if role=="hall":
		block(Vector3.ZERO,Vector3(extent.x,0.08,extent.z),origin,unit,tint)
		var posts:=[]
		for x in [0.03,extent.x-0.15]:
			for z in [0.03,extent.z-0.15]: posts.append(Vector3(x,0.08,z))
		posts.sort_custom(func(a,b):return a.x+a.z<b.x+b.z)
		for post in posts: block(post,Vector3(0.12,0.92,0.12),origin,unit,tint)
		return
	var ordered:=cells.duplicate()
	ordered.sort_custom(func(a,b):return a.x+a.z<b.x+b.z)
	for cell in ordered: block(Vector3(cell)+Vector3.ONE*0.025,Vector3.ONE*0.95,origin,unit,tint)
