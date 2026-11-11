extends RefCounted
## Filled logical quarry cells with connected, faceted terrace silhouettes.
const Random = preload("res://scripts/deterministic_random.gd")
const BLOCK_SIZE := 1.0
const COLUMN_SIZE := 1.0
const SECTION_HEIGHT := 1.0
const STOREY_HEIGHT := 2.0
const MAX_HEIGHT := 3 * STOREY_HEIGHT
const RADIUS := 2
const STONES_PER_CUBIC_METRE := 9
const LEGACY_STONES_PER_CUBIC_METRE := 64
const CORNERS := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
const FACES := [[4, 7, 6, 5], [0, 1, 2, 3], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]

# Retained only for legacy inventory validation and small legacy pile rendering.
static func vertices(seed_value: int, layer: int, column_height: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var height := rng.randf_range(0.91, 1.02) * BLOCK_SIZE
	var width := rng.randf_range(0.86, 0.96) * BLOCK_SIZE
	var depth := rng.randf_range(0.86, 0.96) * BLOCK_SIZE
	var taper := rng.randf_range(0.91, 1.04)
	var lean := Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08)) * BLOCK_SIZE
	var slope := Vector2(rng.randf_range(0.07, 0.15), rng.randf_range(-0.11, 0.11))
	var base: Array[Vector3] = []
	for corner: Vector3 in CORNERS:
		base.append(Vector3(corner.x * width + rng.randf_range(-0.025, 0.025), 0, corner.z * depth + rng.randf_range(-0.025, 0.025)))
	# Reproduce the previous geometry exactly when recognizing saved capacities.
	var foot_rng := RandomNumberGenerator.new()
	foot_rng.seed = seed_value + 1957
	var foot_scale := Vector3(foot_rng.randf_range(0.70, 1.32), 1, foot_rng.randf_range(0.70, 1.32))
	var direction := foot_rng.randf_range(0, TAU)
	var foot_shift := Vector3(cos(direction), 0, sin(direction)) * foot_rng.randf_range(0.24, 0.43) * BLOCK_SIZE
	var feet: Array[Vector3] = []
	for corner: Vector3 in base:
		feet.append(corner * foot_scale + foot_shift + Vector3(foot_rng.randf_range(-0.05, 0.05), 0, foot_rng.randf_range(-0.05, 0.05)) * BLOCK_SIZE)
	var vertices: Array[Vector3] = []
	for level in [layer, layer + 1]:
		var fraction := float(level) / column_height
		for index in base.size():
			var corner := base[index]
			var p := corner * lerpf(1.0, taper, fraction) + lean * fraction
			p += (feet[index] - corner) * (1.0 - fraction)
			p.y = level * height + (corner.x * slope.x + corner.z * slope.y) * fraction
			vertices.append(p)
	return vertices

static func volume(points: Array[Vector3]) -> float:
	var total := 0.0
	for face in FACES:
		var a: Vector3 = points[face[0]]
		for i in range(1, face.size() - 1):
			total += a.dot(points[face[i]].cross(points[face[i + 1]])) / 6.0
	return absf(total)

static var _sections: Dictionary = {}

static func sections(cell: Vector3i, world_seed: int) -> Array[Dictionary]:
	var cache_key := Vector3i(cell.x, world_seed, cell.z)
	if _sections.has(cache_key): return _sections[cache_key]
	var roll := Random.world_roll(cell.x, cell.z, world_seed, 940)
	var profiles := [[3, 2, 1, 1], [3, 1, 1, 1], [3, 3, 1, 1]]
	var heights: Array = profiles[roll % profiles.size()]
	var turn := float(roll % 4) * PI * 0.5
	var result: Array[Dictionary] = []
	var previous := 0
	for layer in 3:
		for column in heights.size():
			if layer >= heights[column]: continue
			var points: Array[Vector3] = []
			for level in [layer, layer + 1]:
				for corner: Vector3 in CORNERS:
					points.append(Vector3(corner.x * COLUMN_SIZE, level * SECTION_HEIGHT, corner.z * COLUMN_SIZE))
			var count := roundi(COLUMN_SIZE * COLUMN_SIZE * SECTION_HEIGHT * STONES_PER_CUBIC_METRE)
			@warning_ignore("integer_division")
			var offset := Vector3(column % 2 - 0.5, 0, column / 2 - 0.5) * COLUMN_SIZE
			result.append({"vertices": points, "count": count, "start": previous, "offset": offset.rotated(Vector3.UP, turn), "turn": turn, "layer": layer, "column": column, "heights": heights, "seed": roll})
			previous += count
	if _sections.size() >= 256: _sections.erase(_sections.keys()[0])
	_sections[cache_key] = result
	return result

static func capacity(cell: Vector3i, world_seed: int) -> int:
	var parts := sections(cell, world_seed)
	return parts[-1].start + parts[-1].count

static func valid_saved_capacity(cell: Vector3i, world_seed: int, saved_capacity: int) -> bool:
	var old_capacity := sections(cell, world_seed).size() * LEGACY_STONES_PER_CUBIC_METRE
	return saved_capacity in [6, 30, capacity(cell, world_seed), old_capacity, old_capacity * 2, old_capacity * 8, legacy_capacity(cell, world_seed)]

static func legacy_capacity(cell: Vector3i, world_seed: int) -> int:
	var roll := Random.world_roll(cell.x, cell.z, world_seed, 940)
	var heights: Array = [[3, 2, 1], [3, 1, 1, 1], [3, 3]][roll % 3]
	var total := 0.0
	for layer in 3:
		for column in heights.size():
			if layer < heights[column]:
				total += volume(vertices(Random.world_coordinate_seed(cell.x, cell.z, world_seed, 950 + column), layer, heights[column]))
	return roundi(total * LEGACY_STONES_PER_CUBIC_METRE)

static func logical_amount(cell: Vector3i, world_seed: int, amount: int, saved_capacity: int = 0) -> int:
	var full := capacity(cell, world_seed)
	if saved_capacity <= 0 or saved_capacity == full: return amount
	# Older quarries retain their exact goods and reservations, and their mined fraction.
	return clampi(roundi(float(amount) * full / saved_capacity), 1 if amount > 0 else 0, full)

static func visual_faces(section: Dictionary, remaining: int) -> Array:
	# Consolidate mining subdivisions before shaping the connected shelves.
	var boxes: Array[AABB] = []
	for chunk in remaining_chunks(section, remaining):
		var box := AABB(chunk[0][0], Vector3.ZERO)
		for face in chunk:
			for point: Vector3 in face: box = box.expand(point)
		boxes.append(box)
	var merged := true
	while merged:
		merged = false
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				if not _can_merge_boxes(boxes[i], boxes[j]): continue
				boxes[i] = boxes[i].merge(boxes[j])
				boxes.remove_at(j)
				merged = true
				break
			if merged: break
	var result: Array = []
	for box in boxes:
		var points: Array[Vector3] = []
		for height in [box.position.y, box.end.y]:
			for corner: Vector3 in CORNERS:
				points.append(Vector3(box.get_center().x + corner.x * box.size.x, height, box.get_center().z + corner.z * box.size.z))
		var faces: Array = []
		for face in FACES:
			var polygon: Array[Vector3] = []
			for index in face: polygon.append(points[index])
			faces.append(polygon)
		# Cut only convex OUTER corners of the connected shelf. Neighbouring
		# columns keep their shared planes; this never bevels every mining cube.
		for corner: Vector3 in CORNERS:
			var sx := int(signf(corner.x))
			var sz := int(signf(corner.z))
			if _shelf_neighbour(section, sx, 0) or _shelf_neighbour(section, 0, sz): continue
			var bevel := 0.22 + Random.world_fraction(sx, sz, int(section.seed), 962) * 0.10
			# Slightly battered facets, with flat, exact-height terrace tops.
			var normal := Vector3(sx, 0.045, sz)
			faces = clip(faces, normal, 1.0 - bevel)
		for face in faces:
			var polygon: Array[Vector3] = []
			for point: Vector3 in face:
				polygon.append(point.rotated(Vector3.UP, section.turn) + Vector3(section.offset))
			result.append(polygon)
	return result

static func _shelf_neighbour(section: Dictionary, dx: int, dz: int) -> bool:
	var x := int(section.column) % 2 + dx
	@warning_ignore("integer_division")
	var z := int(section.column) / 2 + dz
	return x >= 0 and x < 2 and z >= 0 and z < 2 and int(section.heights[z * 2 + x]) > int(section.layer)

static func _can_merge_boxes(a: AABB, b: AABB) -> bool:
	for axis in 3:
		if not (is_equal_approx(a.end[axis], b.position[axis]) or is_equal_approx(b.end[axis], a.position[axis])): continue
		var aligned := true
		for other in 3:
			if other == axis: continue
			if not is_equal_approx(a.position[other], b.position[other]) or not is_equal_approx(a.end[other], b.end[other]): aligned = false
		if aligned: return true
	return false

static func polygons(points: Array[Vector3]) -> Array:
	var result: Array = []
	for face in FACES:
		var polygon: Array[Vector3] = []
		for index in face: polygon.append(points[index])
		result.append([polygon[0], polygon[1], polygon[2]])
		result.append([polygon[0], polygon[2], polygon[3]])
	return result

static func clip(faces: Array, normal: Vector3, distance: float) -> Array:
	var result: Array = []
	var cap: Array[Vector3] = []
	var cut := false
	for face in faces:
		var polygon: Array[Vector3] = []
		for index in face.size():
			var a: Vector3 = face[index]
			var b: Vector3 = face[(index + 1) % face.size()]
			var da := a.dot(normal) - distance
			var db := b.dot(normal) - distance
			if da > 0.000001: cut = true
			if da <= 0.000001: polygon.append(a)
			if absf(da) <= 0.000001 and not cap.any(func(point): return point.is_equal_approx(a)): cap.append(a)
			if (da < -0.000001 and db > 0.000001) or (da > 0.000001 and db < -0.000001):
				var intersection := a.lerp(b, da / (da - db))
				polygon.append(intersection)
				if not cap.any(func(point): return point.is_equal_approx(intersection)): cap.append(intersection)
		if polygon.size() >= 3: result.append(polygon)
	if cut and cap.size() >= 3:
		var centre := Vector3.ZERO
		for point in cap: centre += point
		centre /= cap.size()
		var u := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := normal.cross(u)
		cap.sort_custom(func(a, b): return atan2((a - centre).dot(v), (a - centre).dot(u)) < atan2((b - centre).dot(v), (b - centre).dot(u)))
		result.append(cap)
	return result

static func polygon_volume(faces: Array) -> float:
	var total := 0.0
	for face in faces:
		for index in range(1, face.size() - 1):
			total += face[0].dot(face[index].cross(face[index + 1])) / 6.0
	return absf(total)

static func fragments(section: Dictionary) -> Array:
	if section.has("fragments"): return section.fragments
	# Half-metre cells subdivide the mining shape independently of resource yield.
	# Edge cells retain clipped faces and contribute only their occupied volume.
	var faces := polygons(section.vertices)
	var bounds := AABB(section.vertices[0], Vector3.ZERO)
	for point in section.vertices: bounds = bounds.expand(point)
	var result: Array = []
	var total := 0.0
	for y in range(floori(bounds.position.y * 2), ceili(bounds.end.y * 2)):
		for x in range(floori(bounds.position.x * 2), ceili(bounds.end.x * 2)):
			for z in range(floori(bounds.position.z * 2), ceili(bounds.end.z * 2)):
				var clipped := faces
				for axis in 3:
					var normal := Vector3.ZERO
					normal[axis] = 1.0
					var coordinate: float = [x, y, z][axis] * 0.5
					clipped = clip(clip(clipped, normal, coordinate + 0.5), -normal, -coordinate)
				var size := polygon_volume(clipped)
				if size < 0.000001: continue
				result.append({"faces": clipped, "start": total, "volume": size, "bottom": y * 0.5, "top": (y + 1) * 0.5})
				total += size
	section.fragments = result
	return result

static func remaining_chunks(section: Dictionary, remaining: int) -> Array:
	if remaining <= 0: return []
	if section.get("remaining_amount", -1) == remaining: return section.remaining_chunks
	if remaining >= int(section.count):
		section.remaining_amount = remaining
		section.remaining_chunks = [polygons(section.vertices)]
		return section.remaining_chunks
	var result: Array = []
	var available: float = volume(section.vertices) * float(remaining) / section.count
	for fragment in fragments(section):
		var amount := clampf(available - float(fragment.start), 0.0, fragment.volume)
		if amount < 0.000001: continue
		var visible: Array = fragment.faces
		if amount < float(fragment.volume) - 0.000001:
			var low: float = fragment.bottom
			var high: float = fragment.top
			for iteration in 18:
				var middle := (low + high) * 0.5
				visible = clip(fragment.faces, Vector3.UP, middle)
				if polygon_volume(visible) < amount: low = middle
				else: high = middle
		result.append(visible)
	section.remaining_amount = remaining
	section.remaining_chunks = result
	return result

static func contains(faces: Array, point: Vector3) -> bool:
	for face in faces:
		var normal: Vector3 = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
		if normal.dot(point - face[0]) > 0.00001: return false
	return not faces.is_empty()

static func solid_at(cell: Vector3i, world_seed: int, amount: int, local_point: Vector3, saved_capacity: int = 0) -> bool:
	amount = logical_amount(cell, world_seed, amount, saved_capacity)
	for section in sections(cell, world_seed):
		var remaining := clampi(amount - int(section.start), 0, section.count)
		if remaining == 0: continue
		var point: Vector3 = (local_point - section.offset).rotated(Vector3.UP, -section.turn)
		for chunk in remaining_chunks(section, remaining):
			if contains(chunk, point): return true
	return false

static func occupied_boxes(cell: Vector3i, world_seed: int, amount: int, saved_capacity: int = 0) -> Array[AABB]:
	amount = logical_amount(cell, world_seed, amount, saved_capacity)
	var result: Array[AABB] = []
	for section in sections(cell, world_seed):
		var remaining := clampi(amount - int(section.start), 0, section.count)
		if remaining <= 0: continue
		if section.get("boxes_amount", -1) != remaining:
			var boxes: Array[AABB] = []
			for chunk in remaining_chunks(section, remaining):
				var box := AABB(Vector3(chunk[0][0]).rotated(Vector3.UP, section.turn) + Vector3(section.offset), Vector3.ZERO)
				for face in chunk:
					for point: Vector3 in face: box = box.expand(point.rotated(Vector3.UP, section.turn) + Vector3(section.offset))
				boxes.append(box)
			section.boxes_amount = remaining
			section.boxes = boxes
		result.append_array(section.boxes)
	return result
