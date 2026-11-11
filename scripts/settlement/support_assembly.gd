extends RefCounted
## Pure world-space Support fitting, shared by the prototype and settlement.
const CORNERS := [Vector3(-0.5,0,-0.5),Vector3(0.5,0,-0.5),Vector3(0.5,0,0.5),Vector3(-0.5,0,0.5)]
const SIDES := [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]
const POST_FIT := 0.15
var supports: Array[Vector3] = []
var groups: Array[int] = []
var yaws: Array[float] = []
var open_tops: Array[bool] = []

func basis(index: int) -> Basis:
	return Basis(Vector3.UP,yaws[index])

func add(position: Vector3,yaw: float,group := -1) -> void:
	var chosen := group_for(position,yaw) if group < 0 else group
	supports.append(position); yaws.append(yaw); groups.append(chosen)

func group_for(origin: Vector3,yaw: float) -> int:
	var visited := {}
	for index in supports.size():
		var group := groups[index]
		if visited.has(group): continue
		visited[group] = true
		if absf(wrapf(yaws[index]-yaw,-PI,PI))>0.001: continue
		var inverse := basis(index).inverse()
		var bounds := AABB(inverse*origin,Vector3.ZERO)
		var adjacent := false
		for other in supports.size():
			if groups[other] != group: continue
			bounds = bounds.expand(inverse*supports[other])
			var delta := (inverse*(supports[other]-origin)).abs()
			if delta.is_equal_approx(Vector3.RIGHT) or delta.is_equal_approx(Vector3.UP) or delta.is_equal_approx(Vector3.BACK): adjacent = true
		if adjacent and bounds.size.x<=1.001 and bounds.size.y<=1.001 and bounds.size.z<=1.001: return group
	return maxi(groups.max()+1,supports.size()) if not groups.is_empty() else 0

func grouped_neighbor(index: int,direction: Vector3) -> bool:
	for other in supports.size():
		if groups[other]==groups[index] and supports[other].is_equal_approx(supports[index]+basis(index)*direction): return true
	return false

func layouts() -> Array[Dictionary]:
	var owners := {}; var inward := {}; var touches := {}
	for index in supports.size():
		for corner: Vector3 in CORNERS:
			var key := [groups[index],(supports[index] + basis(index)*corner).snapped(Vector3.ONE * 0.001)]
			if not owners.has(key): owners[key] = index
			inward[key] = inward.get(key,Vector3.ZERO) - corner
			touches[key] = touches.get(key,0) + 1
	var layouts: Array[Dictionary] = []
	for index in supports.size():
		var origin := supports[index]
		var posts: Array = []; var beams: Array = []; var corners: Array = []
		var open_top := open_tops[index] if open_tops.size()==supports.size() else grouped_neighbor(index,Vector3.UP)
		for i in 4:
			var corner: Vector3 = CORNERS[i]
			var key := [groups[index],(origin + basis(index)*corner).snapped(Vector3.ONE * 0.001)]
			var count: int = touches[key]
			var diagonal: bool = count == 2 and inward[key].is_zero_approx()
			var straight: bool = count == 2 and not diagonal
			posts.append(diagonal or (owners[key] == index and count < 4 and not straight))
			corners.append(corner * 0.76 if diagonal else corner + inward[key].sign() * 0.12)
			beams.append(not open_top and not grouped_neighbor(index,SIDES[i]))
		layouts.append({"posts":posts,"beams":beams,"corners":corners,"open_top":open_top,"borrowed":[-1,-1,-1,-1]})
	fit_shared_posts(layouts)
	return layouts

func facing_modules(a: int, b: int) -> bool:
	# Face contact only: a diagonal corner or a different floor is not a bearing.
	var delta := (basis(b).inverse()*(supports[a]-supports[b])).abs()
	if delta.y > 0.001: return false
	return (delta.x >= 0.85 and delta.x <= 1.0+POST_FIT and delta.z < 0.999) or (delta.z >= 0.85 and delta.z <= 1.0+POST_FIT and delta.x < 0.999)

func fit_shared_posts(layouts: Array[Dictionary]) -> void:
	var order: Array[int] = []
	for index in supports.size(): order.append(index)
	order.sort_custom(func(a: int,b: int): return groups[a] < groups[b] if groups[a] != groups[b] else a < b)
	var bearings: Array[Dictionary] = []
	var fitted := {}
	var beams: Array[Dictionary] = []
	for index in order:
		var layout := layouts[index]
		for corner_index in 4:
			if not layout.posts[corner_index]: continue
			var nominal: Vector3 = supports[index]+basis(index)*CORNERS[corner_index]
			var shared := false
			for bearing in bearings:
				if groups[bearing.index] == groups[index] or not facing_modules(index,bearing.index): continue
				if nominal.distance_to(bearing.nominal) > POST_FIT+0.0001: continue
				# Never change the existing pile or either building transform. Only
				# the new frame's bearing endpoints fit to the existing log centre.
				layout.posts[corner_index] = false
				layout.borrowed[corner_index] = bearing.index
				layout.corners[corner_index] = basis(index).inverse()*(bearing.position-supports[index])
				fitted[[groups[index],nominal.snapped(Vector3.ONE*0.001)]] = bearing.position
				shared = true
				break
			if not shared:
				bearings.append({"index":index,"nominal":nominal,"position":supports[index]+basis(index)*layout.corners[corner_index]})
	# All members meeting the same group corner must use its fitted bearing,
	# including members whose duplicate local post was already suppressed.
	for index in order:
		for corner_index in 4:
			var key := [groups[index],(supports[index]+basis(index)*CORNERS[corner_index]).snapped(Vector3.ONE*0.001)]
			if fitted.has(key): layouts[index].corners[corner_index] = basis(index).inverse()*(fitted[key]-supports[index])
	for index in order:
		var layout := layouts[index]
		# Fitted endpoints can make a duplicate boundary beam coincide exactly.
		# Keep its earlier owner too; never remove a merely nearby bearing.
		for edge in 4:
			if not layout.beams[edge]: continue
			var a: Vector3 = supports[index]+basis(index)*layout.corners[edge]+Vector3.UP*0.84
			var b: Vector3 = supports[index]+basis(index)*layout.corners[(edge+1)%4]+Vector3.UP*0.84
			var shared := false
			for beam in beams:
				if groups[beam.index] == groups[index]: continue
				if (a.is_equal_approx(beam.a) and b.is_equal_approx(beam.b)) or (a.is_equal_approx(beam.b) and b.is_equal_approx(beam.a)):
					layout.beams[edge] = false; shared = true; break
			if not shared: beams.append({"index":index,"a":a,"b":b})


static func overlaps(a: Vector3, yaw_a: float, b: Vector3, yaw_b: float) -> bool:
	if absf(a.y-b.y)>=0.999: return false
	var aa := Basis(Vector3.UP,yaw_a); var bb := Basis(Vector3.UP,yaw_b)
	for axis: Vector3 in [aa.x,aa.z,bb.x,bb.z]:
		var radius := 0.5*(absf(axis.dot(aa.x))+absf(axis.dot(aa.z))+absf(axis.dot(bb.x))+absf(axis.dot(bb.z)))
		if absf((b-a).dot(axis))>=radius-0.001: return false
	return true
