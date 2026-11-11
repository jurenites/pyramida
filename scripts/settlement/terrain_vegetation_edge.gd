extends RefCounted
## World-space soil clearance survives CSG excavation without extra mesh seams.
static var cache: Dictionary={}

static func field(island: Dictionary) -> Dictionary:
	var shelves: Array=island.get("soil_shelves",island.get("shelves",[]))
	if shelves.is_empty(): return {}
	var key:=hash([island.seed,island.coast,shelves,island.get("soil_levels",Vector3(0,2,4))])
	if cache.has(key): return cache[key]
	var bounds:=Rect2(island.coast[0],Vector2.ZERO)
	for p: Vector2 in island.coast: bounds=bounds.expand(p)
	bounds=bounds.grow(3)
	var levels: Vector3=island.get("soil_levels",Vector3(0,2,4))
	var size:=192
	var image:=Image.create(size,size,false,Image.FORMAT_RGB8)
	for z in size:
		for x in size:
			var at:=bounds.position+Vector2(x+0.5,z+0.5)/size*bounds.size
			image.set_pixel(x,z,Color(coverage(at,levels.x,shelves),coverage(at,levels.y,shelves),coverage(at,levels.z,shelves)))
	cache[key]={"texture":ImageTexture.create_from_image(image),"bounds":Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y),"levels":levels}
	return cache[key]

static func coverage(at: Vector2, height: float, shelves: Array) -> float:
	var distance:=10.0
	for shelf in shelves:
		if shelf.height<height+0.5: continue
		var outline: PackedVector2Array=shelf.outline
		if Geometry2D.is_point_in_polygon(at,outline): return 0.0
		for i in outline.size(): distance=minf(distance,at.distance_to(Geometry2D.get_closest_point_to_segment(at,outline[i],outline[(i+1)%outline.size()])))
	return smoothstep(0.8,2.4,distance)
