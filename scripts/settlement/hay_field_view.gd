extends RefCounted
## Shared crop borders are disposable presentation; each field keeps its own harvest.
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Random = preload("res://scripts/deterministic_random.gd")
const HALF_WIDTH := Grid.ROOM_SIZE
const EPSILON := 0.0001

static func arrange_pegs(node: Node3D, cell: Vector3i, world_seed: int) -> bool:
	# Saved map coordinates and seed reconstruct the same border after reload.
	# This never consumes simulation RNG or changes the logical field footprint.
	var identity := Random.world_coordinate_seed(cell.x, cell.z, world_seed, 1200 + cell.y)
	if node.get_meta("hay_peg_identity", -1) == identity: return false
	node.set_meta("hay_peg_identity", identity)
	for peg in node.get_children():
		if not peg is MeshInstance3D or not peg.has_meta("hay_peg_slot"): continue
		var side: int = peg.get_meta("hay_peg_side")
		var slot: int = peg.get_meta("hay_peg_slot")
		var corner: int = peg.get_meta("hay_peg_corner", -1)
		var detail := 16 + corner if corner >= 0 else side * 4 + slot
		var along := -1.26 + slot * 0.84 + lerpf(-0.12, 0.12, Random.detail_fraction(identity, detail, 1))
		var outside := HALF_WIDTH + lerpf(0.10, 0.15, Random.detail_fraction(identity, detail, 2))
		var height := lerpf(0.83, 1.18, Random.detail_fraction(identity, detail, 3))
		peg.rotation = Vector3(lerpf(-0.14, 0.14, Random.detail_fraction(identity, detail, 4)),
			lerpf(-0.45, 0.45, Random.detail_fraction(identity, detail, 5)),
			lerpf(-0.14, 0.14, Random.detail_fraction(identity, detail, 6)))
		peg.scale = Vector3(1, height, 1)
		peg.position = Vector3((-outside if side == 0 else outside), 0, along) if side < 2 else Vector3(along, 0, (-outside if side == 2 else outside))
		if corner >= 0:
			peg.position = Vector3(-outside if corner % 2 == 0 else outside, 0, -outside if corner < 2 else outside)
		var bounds: AABB = peg.transform * peg.mesh.get_aabb()
		peg.position.y = 0.025 - bounds.position.y
	return true

static func sync(world, cell: Vector3i, node: Node3D, excluded: Dictionary = {}) -> void:
	var changed := arrange_pegs(node, cell, world.world_seed)
	var building: Dictionary = world.buildings[cell]
	var offset: Vector3 = building.get("placement_offset", Vector3.ZERO)
	var angle := int(building.get("direction", 0)) * PI * 0.5
	var seams: Array = [[], [], [], []] # Local -X, +X, -Z, +Z.
	# Four-metre fields, including legacy centres one metre from current centres.
	var reach := ceili(HALF_WIDTH * 2.0 / Grid.CELL_SIZE) + 1
	for x in range(-reach, reach + 1):
		for z in range(-reach, reach + 1):
			var other := cell + Vector3i(x, 0, z)
			if other == cell or excluded.has(other): continue
			var neighbour: Dictionary = world.buildings.get(other, {})
			if neighbour.get("kind") != "hay_field": continue
			var delta := Vector3(x * Grid.CELL_SIZE, 0, z * Grid.CELL_SIZE)
			delta += Vector3(neighbour.get("placement_offset", Vector3.ZERO)) - offset
			if absf(delta.y) > EPSILON: continue
			delta = delta.rotated(Vector3.UP, angle)
			for axis in 2:
				var across := delta.x if axis == 0 else delta.z
				var along := delta.z if axis == 0 else delta.x
				if absf(absf(across) - HALF_WIDTH * 2.0) > EPSILON: continue
				var interval := Vector2(maxf(-HALF_WIDTH, along - HALF_WIDTH), minf(HALF_WIDTH, along + HALF_WIDTH))
				if interval.y - interval.x > EPSILON:
					seams[axis * 2 + int(across > 0)].append(interval)
	if not changed and node.get_meta("hay_border_seams", []) == seams: return
	node.set_meta("hay_border_seams", seams)
	var pieces := node.get_node_or_null("JoinedBorderPieces")
	if pieces != null: pieces.free()
	pieces = Node3D.new()
	pieces.name = "JoinedBorderPieces"
	node.add_child(pieces)
	for child in node.get_children():
		if not child is MeshInstance3D: continue
		var plank: bool = child.name.begins_with("EdgePlank")
		if not plank and not child.name.begins_with("EdgePeg"): continue
		if child.has_meta("hay_peg_corner"):
			# Each corner belongs to both incident edges, even though its mesh
			# sits outside their nominal intervals. Shared seams remove it once.
			var corner: int = child.get_meta("hay_peg_corner")
			var x_side := corner % 2
			var z_side := 2 + int(corner >= 2)
			var x_end := -HALF_WIDTH if x_side == 0 else HALF_WIDTH
			var z_end := -HALF_WIDTH if z_side == 2 else HALF_WIDTH
			child.visible = not (covers_endpoint(seams[x_side], z_end) or covers_endpoint(seams[z_side], x_end))
			continue
		var axis := 0 if absf(child.position.x) > absf(child.position.z) else 2
		var side := axis + int((child.position.x if axis == 0 else child.position.z) > 0)
		var cuts: Array = seams[side]
		child.visible = cuts.is_empty()
		if cuts.is_empty(): continue
		var along_axis := 2 if axis == 0 else 0
		var bounds: AABB = child.transform * child.mesh.get_aabb()
		if not plank:
			# Tilted sticks remain whole; hide any touching the joined interval.
			child.visible = not cuts.any(func(cut): return cut.y > bounds.position[along_axis] and cut.x < bounds.end[along_axis])
			continue
		var remaining: Array[Vector2] = [Vector2(bounds.position[along_axis], bounds.end[along_axis])]
		for cut: Vector2 in cuts:
			var next: Array[Vector2] = []
			for span in remaining:
				if cut.y <= span.x or cut.x >= span.y:
					next.append(span)
					continue
				if cut.x > span.x + EPSILON: next.append(Vector2(span.x, cut.x))
				if cut.y < span.y - EPSILON: next.append(Vector2(cut.y, span.y))
			remaining = next
		for span in remaining:
			var piece := child.duplicate() as MeshInstance3D
			pieces.add_child(piece)
			piece.visible = true
			piece.scale[along_axis] *= (span.y - span.x) / bounds.size[along_axis]
			piece.position[along_axis] += (span.x + span.y - bounds.position[along_axis] - bounds.end[along_axis]) * 0.5
	# Extend soil up to shared footprint edges so removing timber exposes no sand slit.
	var soil := node.get_node("Soil") as MeshInstance3D
	var size := soil.mesh.get_aabb().size
	for axis in 2:
		var low := -HALF_WIDTH if not seams[axis * 2].is_empty() else -size[axis * 2] * 0.5
		var high := HALF_WIDTH if not seams[axis * 2 + 1].is_empty() else size[axis * 2] * 0.5
		soil.scale[axis * 2] = (high - low) / size[axis * 2]
		soil.position[axis * 2] = (high + low) * 0.5

		# The continuous crop canopy meets across the same shared boundary.
		var plants := node.get_node("Plants") as Node3D
		plants.scale[axis * 2] = soil.scale[axis * 2]
		plants.position[axis * 2] = soil.position[axis * 2]

static func covers_endpoint(intervals: Array, point: float) -> bool:
	return intervals.any(func(span): return point >= span.x - EPSILON and point <= span.y + EPSILON)
