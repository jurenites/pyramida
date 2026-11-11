extends RefCounted
## Coordinate-derived yaw is stable for existing saves and prospective placements.
const MAX_DEGREES := 5.0
static func angle(world, cell: Vector3i) -> float:
	var seed_: int=hash([world.world_seed,cell,"home-yaw-v1"])
	return deg_to_rad(float(posmod(seed_,10001))/10000.0*MAX_DEGREES)
static func local(entry: Dictionary, point: Vector3) -> Vector3:
	return point.rotated(Vector3.UP,float(entry.get("yaw",0)))
static func point(entry: Dictionary, at: Vector3) -> Vector3:
	return entry.at+local(entry,at-entry.at)
static func unpoint(entry: Dictionary, at: Vector3) -> Vector3:
	return entry.at+(at-entry.at).rotated(Vector3.UP,-float(entry.get("yaw",0)))
static func bounds(entry: Dictionary) -> Rect2:
	var rect: Rect2=entry.rect
	var result:=Rect2(); var first:=true
	for corner in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var p:=point(entry,Vector3(corner.x,entry.at.y,corner.y))
		var q:=Vector2(p.x,p.z)
		if first: result=Rect2(q,Vector2.ZERO); first=false
		else: result=result.expand(q)
	return result
static func contains(entry: Dictionary, at: Vector2, margin:=0.0) -> bool:
	var p:=unpoint(entry,Vector3(at.x,entry.at.y,at.y))
	return entry.rect.grow(margin).has_point(Vector2(p.x,p.z))
