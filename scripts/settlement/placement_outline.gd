extends RefCounted
## Full-volume placement edges, kept separate from flat inspection markers.

static func box_edges(centre: Vector3, size: Vector3) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for su in [-1, 1]:
			for sv in [-1, 1]:
				var a := centre
				a[axis] -= size[axis] * 0.5
				a[u] += su * size[u] * 0.5
				a[v] += sv * size[v] * 0.5
				var b := a
				b[axis] += size[axis]
				result.append(PackedVector3Array([a, b]))
	return result

static func cell_edges(cells: Dictionary, cutoff := 99) -> Array[PackedVector3Array]:
	# Exposed faces contribute edges. Coplanar seams disappear; convex and
	# concave turns remain, so an L/T shape never becomes its bounding box.
	var visible := {}
	for cell: Vector3i in cells:
		if cell.y <= cutoff: visible[cell] = true
	var edges := {}
	for cell: Vector3i in visible:
		for axis in 3:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			for sign_value in [-1, 1]:
				var normal := Vector3i.ZERO
				normal[axis] = sign_value
				if visible.has(cell + normal): continue
				var corners: Array[Vector3i] = []
				for signs: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
					var corner := cell * 2 + Vector3i.UP + normal
					corner[u] += signs.x
					corner[v] += signs.y
					corners.append(corner)
				for i in 4:
					var a := corners[i]
					var b := corners[(i + 1) % 4]
					var key := [a.min(b), a.max(b)]
					if not edges.has(key): edges[key] = {}
					edges[key][normal] = true
	var result: Array[PackedVector3Array] = []
	for edge: Array in edges:
		if edges[edge].size() > 1:
			result.append(PackedVector3Array([Vector3(edge[0]) * 0.5, Vector3(edge[1]) * 0.5]))
	return result
