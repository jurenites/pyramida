extends RefCounted
## Sea stays below the metre-addressed walking floor; no settlement migration.
const LEVEL := -0.65
const CONTACT_LEVEL := LEVEL + 0.025
const WIND_DIRECTION := Vector2(0.85,0.52)
const WIND_SPEED := 1.25 # Metres per second along WIND_DIRECTION.

static func waterline(faces: PackedVector3Array) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for i in range(0,faces.size(),3):
		for j in 3:
			var a:=faces[i+j]; var b:=faces[i+(j+1)%3]
			if (a.y<CONTACT_LEVEL)!=(b.y<CONTACT_LEVEL):
				var hit:=a.lerp(b,(CONTACT_LEVEL-a.y)/(b.y-a.y))
				points.append(Vector2(hit.x,hit.z))
	if points.size()<3: return PackedVector2Array()
	var hull:=Geometry2D.convex_hull(points)
	if hull.size()>1: hull.remove_at(hull.size()-1)
	return hull
