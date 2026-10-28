extends RefCounted
## Pick sparse occupied volumes, never a blueprint's rectangular bounds or ghost.
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")

static func ray_box(ray: Vector3, direction: Vector3, cell: Vector3i) -> Dictionary:
	var low := Vector3(cell) + Vector3(-0.5, 0, -0.5)
	var high := low + Vector3.ONE
	var near := -INF
	var far := INF
	var normal := Vector3i.ZERO
	for axis in 3:
		if absf(direction[axis]) < 0.000001:
			if ray[axis] < low[axis] or ray[axis] > high[axis]:
				return {}
			continue
		var a: float = (low[axis] - ray[axis]) / direction[axis]
		var b: float = (high[axis] - ray[axis]) / direction[axis]
		var entering := minf(a, b)
		if entering > near:
			near = entering
			normal = Vector3i.ZERO
			normal[axis] = -1 if direction[axis] > 0 else 1
		far = minf(far, maxf(a, b))
		if near > far:
			return {}
	if near < 0 or far < 0:
		return {}
	return {"distance": near, "normal": normal, "cell": cell}

static func pick(ray: Vector3, direction: Vector3, cells: Dictionary, level := 0, manual := false, existing := false, cutoff := 99) -> Dictionary:
	if not manual:
		var closest := {}
		var distance := INF
		for cell: Vector3i in cells:
			if cell.y > cutoff:
				continue
			var hit := ray_box(ray, direction, cell)
			if not hit.is_empty() and hit.distance < distance:
				closest = hit
				distance = hit.distance
		if not closest.is_empty():
			var cell: Vector3i = closest.cell if existing else closest.cell + closest.normal
			return {"cell": cell, "hit_cell": closest.cell, "normal": closest.normal} if Shape.in_bounds(cell) else {}
	var floor_y := level if manual else 0
	var point: Variant = Plane(Vector3.UP, float(floor_y)).intersects_ray(ray, direction)
	if point == null:
		return {}
	var target := Vector3i(roundi(point.x), floor_y, roundi(point.z))
	return {"cell": target, "normal": Vector3i.UP} if Shape.in_bounds(target) else {}

static func anchor(draft: Dictionary, turns: int) -> Vector3i:
	# Preserve a ground-level pivot for cellar shapes, but also support drafts
	# authored away from the origin without placing an empty hole on the roof.
	var chosen := Vector3i.ZERO
	var distance := INF
	for cell: Vector3i in draft.cells:
		if Vector3(cell).length_squared() < distance:
			chosen = cell
			distance = Vector3(cell).length_squared()
	return Shape.rotate_cell(chosen, turns)
