extends RefCounted
## Broad, fully submerged shelves. Their real bed also drives water colour and costs.
const Ocean = preload("res://scripts/settlement/ocean_surface.gd")

static func generate(islands: Array, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value ^ 481903
	var chosen: Array[Vector2] = []
	for island in islands:
		island.reefs = []
		var coast: PackedVector2Array = island.get("bed_coast",island.coast)
		var candidates: Array = []
		for i in coast.size():
			var a := coast[i]; var b := coast[(i+1)%coast.size()]
			if a.distance_to(b)<3: continue
			var tangent := (b-a).normalized()
			var outward := Vector2(tangent.y,-tangent.x)
			var edge := (a+b)*0.5
			if Geometry2D.is_point_in_polygon(edge+outward,coast): outward = -outward
			var centre := edge+outward*10.0
			var clear := true
			for other in islands:
				var outlines: Array = [other.get("bed_coast",other.coast)]
				outlines.append_array(other.get("shoals",[]))
				for bed: PackedVector2Array in outlines:
					for x in [-4,0,4]:
						for z in [-4,0,4]:
							var sample := centre+Vector2(x,z)
							if Geometry2D.is_point_in_polygon(sample,bed): clear = false
							for j in bed.size():
								if sample.distance_to(Geometry2D.get_closest_point_to_segment(sample,bed[j],bed[(j+1)%bed.size()]))<2.5: clear = false
			if clear: candidates.append({"centre":centre,"tangent":tangent,"radius":Vector2(rng.randf_range(11,14),rng.randf_range(8,10)),"depth":rng.randf_range(0.55,0.8),"phase":rng.randf_range(-PI,PI),"rank":rng.randf()})
		candidates.sort_custom(func(a,b): return a.rank<b.rank)
		for candidate in candidates:
			if chosen.any(func(at): return at.distance_to(candidate.centre)<26): continue
			island.reefs.append(candidate); chosen.append(candidate.centre)
			if island.reefs.size()>=(2 if island.mainland else 1): break

static func height_in(point: Vector2, islands: Array, offshore: float, toe_distance: float) -> float:
	var result := offshore
	for island in islands:
		for reef in island.get("reefs",[]):
			var delta: Vector2 = point-reef.centre
			var tangent: Vector2 = reef.tangent
			var local: Vector2 = Vector2(delta.dot(tangent),delta.dot(Vector2(-tangent.y,tangent.x)))/reef.radius
			var radius := local.length()
			if radius>1.15: continue
			# A wide shallow interior with an irregular, gradually falling rim.
			radius *= 1.0+0.07*sin(atan2(local.y,local.x)*3.0+reef.phase)
			var coverage := (1.0-smoothstep(0.62,1.08,radius))*smoothstep(0.0,2.5,toe_distance)
			var top: float = Ocean.LEVEL-reef.depth-0.04*sin(point.x*0.45+reef.phase)*sin(point.y*0.4)
			result = maxf(result,lerpf(offshore,top,coverage))
	return result
