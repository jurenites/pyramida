extends RefCounted
## One deterministic bowl drives terrain subtraction, walking height and waterline.
const DEPTH := 0.18
const RADII := [0.0,0.35,0.7,1.0]
static var outlines := {}
static func outline(cell: Vector3i, seed_value: int) -> PackedVector2Array:
	var key := [cell,seed_value]
	if outlines.has(key): return outlines[key]
	var phase := float(posmod(hash(key),10000))/10000.0*TAU
	var result := PackedVector2Array()
	for i in 32:
		var angle := TAU*float(i)/32.0
		var radius := 1.0+0.09*sin(angle*3.0+phase)+0.05*cos(angle*5.0-phase)
		result.append((Vector2(cos(angle)*0.43,sin(angle)*0.34)*radius).rotated(phase))
	if outlines.size()>=512: outlines.clear()
	outlines[key]=result
	return result
static func active(world, cell: Vector3i) -> bool:
	return world.water_sources.get(cell,{}).get("kind")=="puddle" and not world.wells.has(cell) and not world.buildings.has(cell) and world.ground.has(cell)
static func cells(world) -> Array:
	return world.water_sources.keys().filter(func(cell):return active(world,cell))
static func radial_height(radius: float) -> float:
	for i in range(1,RADII.size()):
		if radius<=RADII[i]: return lerpf(-DEPTH*(1.0-RADII[i-1]*RADII[i-1]),-DEPTH*(1.0-RADII[i]*RADII[i]),inverse_lerp(RADII[i-1],RADII[i],radius))
	return 0.0
static func height(cell: Vector3i, seed_value: int, point: Vector3) -> float:
	var local := Vector2(point.x-cell.x,point.z-cell.z)
	if local.length_squared()<0.0000001: return cell.y-DEPTH
	var edge := outline(cell,seed_value)
	for i in edge.size():
		var hit=Geometry2D.segment_intersects_segment(Vector2.ZERO,local.normalized()*2.0,edge[i],edge[(i+1)%edge.size()])
		if hit!=null: return cell.y+radial_height(local.length()/maxf(hit.length(),0.0001))
	return float(cell.y)
static func triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	if (b-a).cross(c-a).length_squared()<0.000000001: return
	for point in [a,b,c]: st.add_vertex(point)
static func cutter(cell: Vector3i, seed_value: int) -> ArrayMesh:
	var edge := outline(cell,seed_value)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := RADII.duplicate(); rings.append(1.0)
	for layer in range(1,rings.size()):
		var low: float=rings[layer-1]; var high: float=rings[layer]
		var y0 := radial_height(low); var y1 := 0.1 if layer==rings.size()-1 else radial_height(high)
		for i in edge.size():
			var a := edge[i]; var b := edge[(i+1)%edge.size()]
			var p := Vector3(a.x*low,y0,a.y*low); var q := Vector3(b.x*low,y0,b.y*low)
			var r := Vector3(a.x*high,y1,a.y*high); var s := Vector3(b.x*high,y1,b.y*high)
			triangle(st,p,s,r); triangle(st,p,q,s)
	for i in edge.size():
		var a := edge[i]; var b := edge[(i+1)%edge.size()]
		triangle(st,Vector3(0,0.1,0),Vector3(a.x,0.1,a.y),Vector3(b.x,0.1,b.y))
	st.generate_normals(); st.index(); return st.commit()
static func water(cell: Vector3i, seed_value: int, fraction: float) -> ArrayMesh:
	if fraction<=0: return null
	var level := lerpf(-DEPTH,-0.025,sqrt(clampf(fraction,0,1)))
	var scale_value := 0.0
	for i in range(1,RADII.size()):
		if level<=radial_height(RADII[i]):
			scale_value=lerpf(RADII[i-1],RADII[i],inverse_lerp(radial_height(RADII[i-1]),radial_height(RADII[i]),level)); break
	var edge := outline(cell,seed_value)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in edge.size():
		var a := edge[i]*scale_value; var b := edge[(i+1)%edge.size()]*scale_value
		triangle(st,Vector3(0,level,0),Vector3(a.x,level,a.y),Vector3(b.x,level,b.y))
	st.generate_normals(); return st.commit()
