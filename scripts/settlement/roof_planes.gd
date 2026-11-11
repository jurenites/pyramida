extends RefCounted
## Thin overlapping boards cut against the shared roof planes. No closed solids.
const WIDTH := 1.0 / 3.0
const OVERLAP := 0.035
const SKEW := 0.028
const EAVE := 1.85

static func variation(seed_: int, axis: int, side: int, ridge: float, column: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_, axis, side, roundi(ridge * 1000), column])
	return {"skew": rng.randf_range(-SKEW, SKEW), "end": rng.randf_range(0.065, 0.13),
		"tilt": rng.randf_range(-0.008, 0.008), "shade": rng.randf_range(0.91, 1.04),
		"lift": 0.012 + 0.026 * posmod(column, 2)}

static func clip(poly: Array, axis: int, side: int, ridge: float, skew: float, limit: float, greater: bool) -> Array:
	var result: Array = []
	if poly.is_empty(): return result
	var previous: Vector3 = poly.back()
	var pv: float = previous[axis] - skew * side * (previous[2 - axis] - ridge) - limit
	for point: Vector3 in poly:
		var value: float = point[axis] - skew * side * (point[2 - axis] - ridge) - limit
		var inside := value >= -0.00001 if greater else value <= 0.00001
		var previous_inside := pv >= -0.00001 if greater else pv <= 0.00001
		if inside != previous_inside: result.append(previous.lerp(point, pv / (pv - value)))
		if inside: result.append(point)
		previous = point; pv = value
	return result

static func seam_fade(point: Vector3, shape: Dictionary, axis: int, ridge: float) -> float:
	var distance := absf(point[2 - axis] - ridge)
	# Both roof planes land on the same height at ridge/valley seams.
	var fade := clampf(distance / 0.09, 0, 1)
	for run: Dictionary in shape.runs:
		var other_axis: int = run.axis * 2
		if other_axis == axis: continue
		if point[other_axis] < run.low - 0.001 or point[other_axis] > run.high + 0.001: continue
		var other_height: float = EAVE + 1 - absf(point[2 - other_axis] - run.across)
		fade = minf(fade, clampf(absf(point.y - other_height) / 0.09, 0, 1))
	return fade

static func vertex(point: Vector3, tile: Vector2i, shape: Dictionary, axis: int, side: int, ridge: float, style: Dictionary) -> Vector3:
	var across := 2 - axis
	var fade := seam_fade(point, shape, axis, ridge)
	var original := point
	# Only exposed outline edges get a ragged overhang; shared tile seams stay put.
	for i in [0, 2]:
		var tile_axis := 0 if i == 0 else 1
		for sign_ in [-1, 1]:
			var edge := float(tile[tile_axis]) + (1 if sign_ > 0 else 0)
			var neighbour := tile; neighbour[tile_axis] += sign_
			if absf(original[i] - edge) > 0.0001 or shape.tiles.has(neighbour) or shape.get("covered", {}).has(neighbour): continue
			var extension: float = style.end if i == across else 0.045
			point[i] += sign_ * extension
			if i == across: point.y -= side * sign_ * extension
	var down := side * (original[across] - ridge)
	point.y += fade * (style.lift + style.tilt * (down - 0.5))
	return point

static func polygon(tool: SurfaceTool, points: Array, shade: float) -> void:
	for i in range(1, points.size() - 1):
		var a: Vector3 = points[0]; var b: Vector3 = points[i]; var c: Vector3 = points[i + 1]
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < 0.00000001: continue
		if normal.y < 0: normal = -normal
		normal = normal.normalized()
		var triangle := [a, b, c]
		if (b - a).cross(c - a).dot(normal) > 0: triangle.reverse()
		var light := 0.86 + 0.14 * maxf(0, normal.dot(Vector3(-0.4, 0.8, 0.6).normalized()))
		for point: Vector3 in triangle:
			tool.set_normal(normal); tool.set_color(Color(shade * light, shade * light, shade * light)); tool.add_vertex(point)

static func mesh(source: ArrayMesh, tile: Vector2i, shape: Dictionary, seed_: int) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, vertices.size(), 3):
		var a := vertices[i]; var b := vertices[i + 1]; var c := vertices[i + 2]
		var normal := (b - a).cross(c - a).normalized()
		if normal.y < 0: normal = -normal
		if normal.y < 0.1: continue
		var axis := 2 if absf(normal.x) > absf(normal.z) else 0
		var across := 2 - axis
		var side := 1 if normal[across] >= 0 else -1
		var middle := (a + b + c) / 3
		var ridge: float = snappedf(middle[across] + side * (middle.y - EAVE - 1), 0.001)
		for column in range(floori(minf(a[axis], minf(b[axis], c[axis])) / WIDTH) - 1, ceili(maxf(a[axis], maxf(b[axis], c[axis])) / WIDTH) + 1):
			var style := variation(seed_, axis, side, ridge, column)
			var poly := clip([a, b, c], axis, side, ridge, style.skew, column * WIDTH - OVERLAP, true)
			poly = clip(poly, axis, side, ridge, style.skew, (column + 1) * WIDTH + OVERLAP, false)
			if poly.size() < 3: continue
			for j in poly.size(): poly[j] = vertex(poly[j], tile, shape, axis, side, ridge, style)
			polygon(tool, poly, style.shade)
	return tool.commit()

static func ridge_mesh(segments: Array) -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: Array in segments:
		var a: Vector2 = segment[0]; var b: Vector2 = segment[1]
		var normal := Vector2(-(b - a).y, (b - a).x) * 0.075
		for side in [-1, 1]:
			var start := Vector3(a.x, EAVE + 1.045, a.y); var end := Vector3(b.x, EAVE + 1.045, b.y)
			var offset := Vector3(normal.x * side, -0.055, normal.y * side)
			polygon(tool, [start, end, end + offset, start + offset], 1.0)
	return tool.commit()
