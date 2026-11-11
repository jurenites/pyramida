extends RefCounted
## A rest-space BVH with conservative posed bounds. Skin only triangles reached
## by the ray; never rebuild a full mesh/BVH or read GPU buffers during hover.
static var prepared: Dictionary = {}
var vertices := PackedVector3Array()
var bones := PackedInt32Array()
var weights := PackedFloat32Array()
var triangles := PackedInt32Array()
var centres := PackedVector3Array()
var tree: Dictionary

static func for_mesh(mesh: Mesh):
	if not prepared.has(mesh):
		var picker = load("res://scripts/settlement/citizen_skin_picker.gd").new()
		picker.prepare(mesh)
		prepared[mesh] = picker
	return prepared[mesh]

func prepare(mesh: Mesh) -> void:
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var offset := vertices.size()
		vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
		bones.append_array(arrays[Mesh.ARRAY_BONES])
		weights.append_array(arrays[Mesh.ARRAY_WEIGHTS])
		for index in arrays[Mesh.ARRAY_INDEX]: triangles.append(offset + index)
	var ids: Array[int] = []
	for face in triangles.size() / 3:
		ids.append(face)
		centres.append((vertices[triangles[face*3]] + vertices[triangles[face*3+1]] + vertices[triangles[face*3+2]]) / 3.0)
	tree = build(ids)

func build(ids: Array[int]) -> Dictionary:
	if ids.size() <= 24:
		var bounds := AABB(vertices[triangles[ids[0]*3]], Vector3.ZERO)
		var influenced := {}
		for face in ids:
			for corner in 3:
				var vertex := triangles[face*3+corner]
				bounds = bounds.expand(vertices[vertex])
				for slot in range(vertex*4, vertex*4+4):
					if weights[slot] > 0: influenced[bones[slot]] = true
		return {"bounds": bounds, "bones": influenced.keys(), "faces": ids}
	var spread := AABB(centres[ids[0]], Vector3.ZERO)
	for id in ids: spread = spread.expand(centres[id])
	var axis := spread.size.max_axis_index()
	ids.sort_custom(func(a, b): return centres[a][axis] < centres[b][axis])
	var middle := ids.size() / 2
	var left := build(ids.slice(0, middle))
	var right := build(ids.slice(middle))
	var influenced := {}
	for bone in left.bones: influenced[bone] = true
	for bone in right.bones: influenced[bone] = true
	return {"bounds": left.bounds.merge(right.bounds), "bones": influenced.keys(), "left": left, "right": right}

func distance(origin: Vector3, direction: Vector3, transforms: Array[Transform3D]) -> float:
	var stack: Array[Dictionary] = [tree]
	var posed := {}
	var nearest := INF
	while not stack.is_empty():
		var node: Dictionary = stack.pop_back()
		var bounds: AABB = transforms[node.bones[0]] * node.bounds
		for index in range(1, node.bones.size()): bounds = bounds.merge(transforms[node.bones[index]] * node.bounds)
		# A positive weighted blend lies inside the union's bounding box.
		# Expand for quantized weights, thin triangles and numerical precision.
		var entry = bounds.grow(0.001).intersects_ray(origin, direction)
		if entry == null: continue
		if not bounds.has_point(origin) and origin.distance_to(entry) > nearest: continue
		if not node.has("faces"):
			stack.append(node.left)
			stack.append(node.right)
			continue
		for face in node.faces:
			for corner in 3:
				var vertex := triangles[face*3+corner]
				if posed.has(vertex): continue
				var point := Vector3.ZERO
				for slot in range(vertex*4, vertex*4+4):
					if weights[slot] > 0: point += (transforms[bones[slot]] * vertices[vertex]) * weights[slot]
				posed[vertex] = point
			var hit = Geometry3D.ray_intersects_triangle(origin, direction, posed[triangles[face*3]], posed[triangles[face*3+1]], posed[triangles[face*3+2]])
			if hit != null: nearest = minf(nearest, origin.distance_to(hit))
	return nearest
