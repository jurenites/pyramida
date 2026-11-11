extends RefCounted
## A continuous submerged coastal shelf, broad on beaches and narrow under cliffs.
const Ocean=preload("res://scripts/settlement/ocean_surface.gd")

static func make(coast: Array, cliffs: Array[bool], toe: Array, seed_value: int, varied := false) -> Dictionary:
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value^83371
	var phase:=rng.randf_range(-PI,PI)
	var widths:=PackedFloat32Array()
	for i in coast.size():
		var exposure:=0.0
		for j in range(-2,3): exposure+=(3-absi(j))*(1.0 if cliffs[posmod(i+j,cliffs.size())] else 0.0)
		exposure/=9.0
		var variation:=1.0+0.14*sin(TAU*i/coast.size()*3+phase)+0.08*cos(TAU*i/coast.size()*5-phase)
		if varied: variation=1.0+0.34*sin(TAU*i/coast.size()*3+phase)+0.15*cos(TAU*i/coast.size()*5-phase)
		widths.append(maxf(1.8,lerpf(18.0,2.8,exposure)*variation) if varied else lerpf(18.0,2.8,exposure)*variation)
	var result: Dictionary={"coast":PackedVector2Array(coast),"toe":PackedVector2Array(toe),"widths":widths,"toe_heights":PackedFloat32Array()}
	if varied:
		result.channels=[]
		var candidates: Array=[]
		for i in coast.size():
			if widths[i]<12 or widths[(i+1)%coast.size()]<12: continue
			var a: Vector2=coast[i]; var b: Vector2=coast[(i+1)%coast.size()]
			var tangent: Vector2=(b-a).normalized()
			candidates.append({"at":(a+b)*0.5,"outward":Vector2(tangent.y,-tangent.x),"width":rng.randf_range(2.3,3.6),"length":maxf(widths[i],widths[(i+1)%coast.size()])*1.6,"depth":rng.randf_range(1.8,2.8),"bend":rng.randf_range(-1.8,1.8),"rank":rng.randf()})
		candidates.sort_custom(func(a,b):return a.rank<b.rank)
		for candidate in candidates:
			if result.channels.any(func(other):return other.at.distance_to(candidate.at)<16): continue
			result.channels.append(candidate)
			if result.channels.size()>=3: break
	for p: Vector2 in toe: result.toe_heights.append(profile(p,result))
	return result

static func profile(point: Vector2, reef: Dictionary) -> float:
	var nearest:=INF; var width:=1.0
	var coast: PackedVector2Array=reef.coast
	for i in coast.size():
		var a:=coast[i]; var b:=coast[(i+1)%coast.size()]
		var at:=Geometry2D.get_closest_point_to_segment(point,a,b)
		var distance:=point.distance_to(at)
		if distance>=nearest: continue
		nearest=distance
		var t:=a.distance_to(at)/maxf(a.distance_to(b),0.001)
		width=lerpf(reef.widths[i],reef.widths[(i+1)%coast.size()],t)
	# The shallow floor continues directly from the beach, then rolls down into
	# deep water. There is no surrounding trench or detached raised oval.
	var depth:=0.5*(1.0-exp(-nearest/0.8))+nearest*0.035
	depth+=4.0*smoothstep(width*0.65,width*1.5,nearest)+maxf(0,nearest-width*1.5)*0.16
	depth+=channel_depth(point,reef)
	return Ocean.LEVEL-depth

static func channel_depth(point: Vector2, reef: Dictionary) -> float:
	var depth:=0.0
	for channel in reef.get("channels",[]):
		var delta: Vector2=point-channel.at
		var along: float=delta.dot(channel.outward)
		var tangent:=Vector2(-channel.outward.y,channel.outward.x)
		var across: float=delta.dot(tangent)-channel.bend*sin(along*0.18)
		var opening:=smoothstep(4.0,7.0,along)*(1.0-smoothstep(channel.length*0.8,channel.length,along))
		depth=maxf(depth,channel.depth*exp(-pow(across/channel.width,2))*opening)
	return depth

static func offshore_height(point: Vector2, reef: Dictionary) -> float:
	var nearest:=INF; var join:=Vector2.ZERO; var join_height:=0.0
	var toe: PackedVector2Array=reef.toe
	for i in toe.size():
		var a:=toe[i]; var b:=toe[(i+1)%toe.size()]
		var at:=Geometry2D.get_closest_point_to_segment(point,a,b)
		var distance:=point.distance_to(at)
		if distance>=nearest: continue
		nearest=distance; join=at
		var t:=a.distance_to(at)/maxf(a.distance_to(b),0.001)
		join_height=lerpf(reef.toe_heights[i],reef.toe_heights[(i+1)%toe.size()],t)
	# Match the actual linear island edge exactly before continuing the profile.
	return join_height+profile(point,reef)-profile(join,reef)
