extends RefCounted
## IDs 0–8 remain stable for existing saves; additional 3×3 sections cover paving.
const START := 4
static var cache: Dictionary={}
static var cache_mutex:=Mutex.new()
static func bounds(config: Dictionary) -> Rect2i:
	return Rect2i(-7,-6-int(config.street.front_road_width),int(config.plot.width)+14,int(config.plot.depth)+13+int(config.street.front_road_width))

static func roads(config: Dictionary) -> Array:
	var area:=bounds(config); var w:=int(config.plot.width); var d:=int(config.plot.depth)
	var f:=int(config.street.front_road_width)
	var result: Array=[Rect2i(area.position.x,-1-f,area.size.x,f),Rect2i(area.position.x,d+1,area.size.x,1)]
	for x in [-2,w+1]:
		result.append(Rect2i(x,area.position.y,1,-1-f-area.position.y))
		result.append(Rect2i(x,d+2,1,area.end.y-d-2))
	return result

static func plots(config: Dictionary) -> Array:
	var w:=int(config.plot.width); var d:=int(config.plot.depth)
	var front:=int(config.street.front_road_width)
	var id: String="%d:%d:%d" % [w,d,front]
	cache_mutex.lock()
	if cache.has(id):
		var found: Array=cache[id]; cache_mutex.unlock(); return found
	var result: Array=[]
	for z in [-5-front,0,d+3]:
		for x in [-6,0,w+3]: result.append(Rect2i(x,z,w,d))
	var area:=bounds(config); var streets:=roads(config)
	for z in range(area.position.y,area.end.y-2):
		for x in range(area.position.x,area.end.x-2):
			var rect:=Rect2i(x,z,3,3)
			if not result.has(rect) and not streets.any(func(road):return road.intersects(rect)): result.append(rect)
	cache[id]=result
	cache_mutex.unlock()
	return result

static func contains(config: Dictionary, owned: Array, cell: Vector3i, margin := 0) -> bool:
	var parcels:=plots(config)
	for id in owned:
		if parcels[int(id)].grow(margin).has_point(Vector2i(cell.x,cell.z)): return true
	return false

static func covered(config: Dictionary,owned: Array,id: int) -> bool:
	var rect: Rect2i=plots(config)[id]
	for x in range(rect.position.x,rect.end.x):
		for z in range(rect.position.y,rect.end.y):
			if not contains(config,owned,Vector3i(x,0,z)): return false
	return true

static func at(config: Dictionary, point: Vector2, owned: Array=[]) -> int:
	if contains(config,owned,Vector3i(floori(point.x),0,floori(point.y))): return -1
	var parcels:=plots(config)
	# Original building footprints keep their familiar purchase target.
	for id in 9:
		if Rect2(parcels[id]).has_point(point): return id
	var best:=-1; var distance:=INF
	for id in range(9,parcels.size()):
		var rect:=Rect2(parcels[id])
		if not rect.has_point(point): continue
		var score:=rect.get_center().distance_squared_to(Vector2(floori(point.x)+0.5,floori(point.y)+0.5))
		if score<distance: best=id; distance=score
	return best
