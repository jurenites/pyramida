extends RefCounted
## Creases of the joined occupied volume, with coplanar cube seams removed.
static func edges(cells: Array) -> Array:
	var occupied := {}
	for cell in cells: occupied[Vector3i(cell)]=true
	var candidates := {}
	for cell in occupied:
		for axis in 3:
			for sign_value in [-1,1]:
				var normal := Vector3i.ZERO
				normal[axis]=sign_value
				if occupied.has(cell+normal): continue
				var corners := []
				for uv in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var point: Vector3i=cell
					point[axis]+=1 if sign_value>0 else 0
					point[(axis+1)%3]+=uv.x
					point[(axis+2)%3]+=uv.y
					corners.append(point)
				for index in 4:
					var a: Vector3i=corners[index]
					var b: Vector3i=corners[(index+1)%4]
					var lo:=a.min(b)
					var hi:=a.max(b)
					var key: String="%s:%s" % [lo,hi]
					if not candidates.has(key): candidates[key]={"a":lo,"b":hi,"normals":{}}
					candidates[key].normals[normal]=true
	var lines := {}
	for edge in candidates.values():
		# Two adjacent coplanar faces share one normal: this is a cube seam.
		if edge.normals.size()<2: continue
		var axis: int=(edge.b-edge.a).max_axis_index()
		var fixed: Vector3i=edge.a
		fixed[axis]=0
		var key: String="%s:%s" % [axis,fixed]
		if not lines.has(key): lines[key]={"axis":axis,"segments":[]}
		lines[key].segments.append([edge.a,edge.b])
	var result := []
	for line in lines.values():
		line.segments.sort_custom(func(a,b):return a[0][line.axis]<b[0][line.axis])
		var merged: Array=[]
		for segment in line.segments:
			if not merged.is_empty() and merged[-1][1]==segment[0]: merged[-1][1]=segment[1]
			else: merged.append(segment.duplicate())
		result.append_array(merged)
	return result

static func silhouette(cells: Array, camera: Camera3D) -> Array:
	var outlines := []
	for cell in cells:
		var points := PackedVector2Array()
		for corner in 8:
			points.append(camera.unproject_position(Vector3(cell)+Vector3(corner&1,(corner>>1)&1,(corner>>2)&1)))
		var boundary := Geometry2D.convex_hull(points)
		var index:=0
		while index<outlines.size():
			var joined := Geometry2D.merge_polygons(boundary,outlines[index])
			if joined.size()==1:
				boundary=joined[0]
				outlines.remove_at(index)
				index=0
			else: index+=1
		if boundary.size()>1 and boundary[0].is_equal_approx(boundary[-1]): boundary.resize(boundary.size()-1)
		outlines.append(boundary)
	for boundary in outlines:
		var changed:=true
		while changed and boundary.size()>3:
			changed=false
			for index in boundary.size():
				var a: Vector2=boundary[posmod(index-1,boundary.size())]
				var b: Vector2=boundary[index]
				var c: Vector2=boundary[(index+1)%boundary.size()]
				if (b-a).dot(c-b)>=0 and absf((b-a).cross(c-a))/maxf(0.001,(c-a).length())<0.01:
					boundary.remove_at(index)
					changed=true
					break
	return outlines
