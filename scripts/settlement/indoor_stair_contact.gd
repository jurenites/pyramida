extends RefCounted
## Contact footprints come from the same prefab parts used by RoomView.
const Geometry = preload("res://scripts/block_city/stair_geometry.gd")

static func register(nav, lower: Vector3i, upper: Vector3i, center: Vector3, yaw: float, path: Array) -> void:
	var boxes: Array[AABB] = []
	var trim: Array[AABB] = []
	for part: Dictionary in Geometry.parts():
		var box := AABB(part.position * 2.0 - part.size, part.size * 2.0)
		if part.get("edge", false): trim.append(box)
		else: boxes.append(box)
	var transform_ := Transform3D(Basis(Vector3.UP, yaw), center)
	# Actual adjacent floor tops, including the room's 16 cm floor slab.
	for endpoint: Vector3 in [path.front(), path.back()]:
		var local := transform_.affine_inverse() * endpoint
		boxes.append(AABB(local + Vector3(-0.42,-0.1,-0.5), Vector3(0.84,0.1,1.0)))
	var data := {"transform": transform_, "boxes": boxes, "trim": trim, "key": lower,
		"stride": 0.4}
	if not nav.room_stair_contacts.has(lower): nav.room_stair_contacts[lower] = {}
	if not nav.room_stair_contacts.has(upper): nav.room_stair_contacts[upper] = {}
	nav.room_stair_contacts[lower][upper] = data
	nav.room_stair_contacts[upper][lower] = data

static func active(nav, worker: Dictionary) -> Dictionary:
	var route: Array = worker.get("route", [])
	var index: int = worker.get("route_index", 0)
	if index >= route.size(): return {}
	return nav.room_stair_contacts.get(worker.cell, {}).get(route[index], {})

static func support(stair: Dictionary, point: Vector3) -> Vector3:
	var local: Vector3 = stair.transform.affine_inverse() * point
	var best := INF
	var result := local
	for box: AABB in stair.boxes:
		# Seat the rounded end inside the tread, clear of the raised front trim.
		var inset := Vector3(minf(0.065,box.size.x*0.25), 0, minf(0.065,box.size.z*0.25))
		var candidate := Vector3(clampf(local.x,box.position.x+inset.x,box.end.x-inset.x), box.end.y,
			clampf(local.z,box.position.z+inset.z,box.end.z-inset.z))
		if box.size.z < 0.25:
			candidate.z = box.get_center().z
			for edge: AABB in stair.trim:
				if absf(edge.position.y-box.end.y)<0.005 and absf(edge.get_center().x-box.get_center().x)<0.01:
					candidate.z -= signf(edge.get_center().z-box.get_center().z)*0.025
		var offset := candidate-local
		var distance := Vector2(offset.x,offset.z).length_squared() + offset.y*offset.y*0.015
		if distance < best:
			best = distance
			result = candidate
	return stair.transform * result
