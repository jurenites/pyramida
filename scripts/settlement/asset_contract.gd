extends RefCounted
## Authoring volumes use metres: one cell matches WorldGrid.CELL_SIZE.
const Grid = preload("res://scripts/settlement/world_grid.gd")

static func make(size := Vector3(2, 2, 2), offset := Vector3.ZERO, mount := "floor") -> Dictionary:
	return {"size": [size.x, size.y, size.z], "offset": [offset.x, offset.y, offset.z], "margin": 0.05, "mount": mount}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("mount") not in ["floor", "wall", "free"]: return false
	for field in ["size", "offset"]:
		if not value.get(field) is Array or value[field].size() != 3: return false
		for number in value[field]:
			if not (number is float or number is int) or not is_finite(float(number)) or absf(number) > 64: return false
			if field == "size" and number < 0.01: return false
	var margin: Variant = value.get("margin")
	return (margin is float or margin is int) and is_finite(float(margin)) and margin >= 0 and margin <= 0.5

static func box(contract: Dictionary) -> AABB:
	var s: Array = contract.size
	var o: Array = contract.offset
	var size := Vector3(s[0], s[1], s[2])
	return AABB(Vector3(o[0], o[1], o[2]) + Vector3(-size.x / 2, 0, -size.z / 2), size)

static func excess(bounds: AABB, contract: Dictionary) -> bool:
	return not box(contract).grow(float(contract.margin) + 0.00001).encloses(bounds)

static func edges(bounds: AABB, pose := Transform3D.IDENTITY) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	for corner in 8:
		for axis in 3:
			var other: int = corner ^ (1 << axis)
			if other > corner: result.append(PackedVector3Array([pose * bounds.get_endpoint(corner), pose * bounds.get_endpoint(other)]))
	return result
