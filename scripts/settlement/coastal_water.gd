extends RefCounted
## A world-space coast field, baked once per island layout/wind, not per frame.
## R: signed metres to land/rocks, G: wave exposure, B: metres to island coast.
const Ocean = preload("res://scripts/settlement/ocean_surface.gd")
const CELL := 0.65
const REACH := 24.0

static func distance_to(point: Vector2, outlines: Array) -> float:
	var distance := 10000.0
	var inside := false
	for polygon: PackedVector2Array in outlines:
		inside = inside or Geometry2D.is_point_in_polygon(point, polygon)
		for i in polygon.size():
			var nearest := Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])
			distance=minf(distance,point.distance_to(nearest))
	return -distance if inside else distance

static func fetch_distance(point: Vector2, direction: Vector2, occupancy: Image, bounds: Rect2) -> float:
	# Sampling baked occupancy avoids testing every polygon for every ray.
	for step in range(1,25):
		var distance := float(step)
		var pixel := Vector2i((point+direction*distance-bounds.position)/CELL)
		if pixel.x<0 or pixel.y<0 or pixel.x>=occupancy.get_width() or pixel.y>=occupancy.get_height(): return REACH
		if occupancy.get_pixelv(pixel).r<0: return distance
	return REACH

static func bake(islands: Array, wind := Ocean.WIND_DIRECTION, physical_bed := false) -> Dictionary:
	var coasts: Array=[]; var outlines: Array=[]; var rocks: Array=[]
	var bounds := Rect2(islands[0].coast[0],Vector2.ZERO)
	for island in islands:
		coasts.append(island.coast); outlines.append(island.coast)
		for shoal in island.get("shoals",[]): outlines.append(shoal); rocks.append(shoal)
	for polygon in outlines:
		for point in polygon: bounds=bounds.expand(point)
	bounds=bounds.grow(REACH+4)
	var size:=Vector2i(ceil(bounds.size.x/CELL),ceil(bounds.size.y/CELL))
	bounds.size=Vector2(size)*CELL
	var occupancy:=Image.create(size.x,size.y,false,Image.FORMAT_RGBAF)
	for y in size.y:
		for x in size.x:
			var point:=bounds.position+(Vector2(x,y)+Vector2.ONE*0.5)*CELL
			var land:=distance_to(point,coasts)
			var shore:=minf(land,distance_to(point,rocks))
			var bed:=-1.0-maxf(0,land)/6.0
			occupancy.set_pixel(x,y,Color(shore,1,land,bed))
	var field:=occupancy.duplicate() as Image
	var upwind: Vector2=-wind.normalized()
	# Shelter varies over metres; only contact distances need sub-metre resolution.
	var exposure_size:=Vector2i(ceil(size.x/3.0),ceil(size.y/3.0))
	var exposure:=Image.create(exposure_size.x,exposure_size.y,false,Image.FORMAT_RF)
	for y in exposure_size.y:
		for x in exposure_size.x:
			var point:=bounds.position+(Vector2(x,y)+Vector2.ONE*0.5)*bounds.size/Vector2(exposure_size)
			var value:=occupancy.get_pixelv(Vector2i((point-bounds.position)/CELL))
			if value.r<-CELL*2 or value.r>REACH:
				exposure.set_pixel(x,y,Color(0.12 if value.r<0 else 1.0,0,0)); continue
			var fetch:=0.0
			for angle in [-0.65,-0.32,0.0,0.32,0.65]:
				fetch+=fetch_distance(point,upwind.rotated(angle),occupancy,bounds)/REACH
			var enclosure:=0.0
			for i in 8:
				enclosure+=1.0-fetch_distance(point,Vector2.RIGHT.rotated(i*TAU/8),occupancy,bounds)/REACH
			var energy:=clampf(0.12+0.88*(fetch/5.0)*(1.0-0.8*enclosure/8.0),0.12,1.0)
			exposure.set_pixel(x,y,Color(energy,0,0))
	exposure.resize(size.x,size.y,Image.INTERPOLATE_BILINEAR)
	for y in size.y:
		for x in size.x:
			var value:=field.get_pixel(x,y); value.g=exposure.get_pixel(x,y).r; field.set_pixel(x,y,value)
	return {"image":field,"bounds":bounds,"physical_bed":physical_bed,"islands":islands if physical_bed else []}

static func seabed(field: Dictionary) -> ArrayMesh:
	if field.get("physical_bed",false): return physical_seabed(field)
	# A smooth visual skin for the existing one-metre + distance/6 foundation bed.
	# It has no collider and does not change water volumes or Support rules.
	var image: Image=field.image; var bounds: Rect2=field.bounds
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stride:=3
	for y in range(0,image.get_height()-stride,stride):
		for x in range(0,image.get_width()-stride,stride):
			for corner: Vector2i in [Vector2i(0,0),Vector2i(stride,0),Vector2i(0,stride),Vector2i(stride,0),Vector2i(stride,stride),Vector2i(0,stride)]:
				var pixel:=Vector2i(x,y)+corner; var value:=image.get_pixelv(pixel)
				var point:=bounds.position+(Vector2(pixel)+Vector2.ONE*0.5)*CELL
				var height:=-1.0-maxf(0,value.b)/6.0
				surface.set_normal(Vector3.UP); surface.add_vertex(Vector3(point.x,height,point.y))
	surface.index()
	return surface.commit()

static func physical_seabed(field: Dictionary) -> ArrayMesh:
	# Near-shore rock and sand already belong to the island solids. Clip the
	# offshore floor to their submerged toes, avoiding overlapping surfaces and
	# jagged depth seams from a coarse height grid laid across the beach.
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var islands: Array=field.islands
	var bounds: Rect2=field.bounds
	var spacing:=CELL*3.0
	var height_cache: Dictionary={}
	var beds: Array=[]
	for island in islands:
		var outline: PackedVector2Array=island.get("bed_coast",island.coast)
		var area:=Rect2(outline[0],Vector2.ZERO)
		for p in outline: area=area.expand(p)
		beds.append({"outline":outline,"bounds":area})
	for x in range(ceili(bounds.size.x/spacing)):
		for z in range(ceili(bounds.size.y/spacing)):
			var at:=bounds.position+Vector2(x,z)*spacing
			var cell:=Rect2(at,Vector2.ONE*spacing)
			var pieces: Array=[PackedVector2Array([at,at+Vector2(spacing,0),at+Vector2.ONE*spacing,at+Vector2(0,spacing)])]
			for bed in beds:
				if not cell.intersects(bed.bounds): continue
				var next: Array=[]
				for polygon in pieces: next.append_array(Geometry2D.clip_polygons(polygon,bed.outline))
				pieces=next
			for polygon: PackedVector2Array in pieces:
				if Geometry2D.is_polygon_clockwise(polygon): continue
				var indices:=Geometry2D.triangulate_polygon(polygon)
				for index in indices:
					var p: Vector2=polygon[index]
					if not height_cache.has(p): height_cache[p]=preload("res://scripts/settlement/solid_islands.gd").bed_height_in(p,islands)
					surface.set_normal(Vector3.UP); surface.add_vertex(Vector3(p.x,height_cache[p],p.y))
	surface.index(); return surface.commit()
