extends RefCounted
## A shared roof is split by room only for visibility; all pieces use one profile.
const Houses = preload("res://scripts/settlement/house_groups.gd")
const Kit = preload("res://scripts/settlement/roof_kit.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const Frame = preload("res://scripts/settlement/connected_frames.gd")
const Boards = preload("res://scripts/settlement/roof_boards.gd")
const EAVE := 1.85
const PITCH := 1.0

static func pose_in(root: Node3D, mesh: Node3D) -> Transform3D:
	var pose := mesh.transform
	var parent := mesh.get_parent() as Node3D
	while parent != root:
		pose = parent.transform * pose; parent = parent.get_parent() as Node3D
	return pose

static func authored_parts(node: Node3D) -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	var roof := node.get_node_or_null("Roof")
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or node.get_node_or_null("JoinedRoof") != null and node.get_node("JoinedRoof").is_ancestor_of(mesh): continue
		var source: String = mesh.get_meta("source_component", "")
		var bounds: AABB = pose_in(node, mesh) * mesh.mesh.get_aabb()
		if (roof != null and roof.is_ancestor_of(mesh)) or source.begins_with("Roof/") or mesh.get_meta("roof_component", "") in Kit.SIZES or (mesh.has_meta("timber_stock") and bounds.get_center().y > 1.95): parts.append(mesh)
	return parts

static func profile(tiles: Dictionary, rooms: Array = []) -> Dictionary:
	var edges: Array = []
	for tile: Vector2i in tiles:
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not tiles.has(tile + side): edges.append([tile, side])
	var runs: Array = []
	for room: Dictionary in rooms:
		var axis: int = room.axis
		var low: float = room.at[axis] - 1; var high: float = room.at[axis] + 1
		for neighbour: Dictionary in rooms:
			var delta: Vector2 = neighbour.at - room.at
			if neighbour.axis == axis or not is_zero_approx(delta[1 - axis]) or not is_equal_approx(absf(delta[axis]), 2): continue
			# A wing's ridge reaches the perpendicular main ridge, not just its wall.
			low = minf(low, neighbour.at[axis]); high = maxf(high, neighbour.at[axis])
		runs.append({"axis": axis, "across": room.at[1 - axis], "low": low, "high": high})
	return {"tiles": tiles, "rooms": rooms, "edges": edges, "runs": runs}

static func height_at(point: Vector2, shape: Dictionary) -> float:
	var rise := 0.0
	for run: Dictionary in shape.runs:
		if point[run.axis] < run.low - 0.001 or point[run.axis] > run.high + 0.001: continue
		# The outer envelope of the intersecting slopes forms a continuous roof.
		# Using the minimum here would cut the branch down to the eaves.
		rise = maxf(rise, 1.0 - absf(point[1 - run.axis] - run.across))
	return EAVE + rise * PITCH

static func heights(tile: Vector2i, shape: Dictionary) -> Array[float]:
	var result: Array[float] = []
	for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		result.append(height_at(Vector2(tile) + corner, shape) - EAVE)
	return result

static func component(values: Array[float]) -> Dictionary:
	var high: Array[int] = []
	for i in 4:
		if values[i] > 0.5: high.append(i)
	if high.size() == 1: return {"kind": "roof_corner", "angle": -high[0] * PI / 2}
	if high.size() == 2:
		for turn in 4:
			if posmod(-turn, 4) in high and posmod(3 - turn, 4) in high:
				return {"kind": "roof_wedge", "angle": turn * PI / 2}
	return {"kind": "roof_junction", "angle": 0.0}

static func tile_mesh(tile: Vector2i, shape: Dictionary) -> ArrayMesh:
	var values := heights(tile, shape)
	var part := component(values)
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array = []
	for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		points.append(Vector3(tile.x + corner.x, EAVE + values[points.size()], tile.y + corner.y))
	if part.kind != "roof_junction":
		# Use the exact unit wedge/corner slopes, without the hidden solid faces
		# between modules. Recompute painted shading after rotating the part.
		var pose := Transform3D(Basis(Vector3.UP, part.angle), Vector3(tile.x + 0.5, EAVE, tile.y + 0.5))
		var arrays := Kit.mesh(part.kind).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0, vertices.size(), 3):
			if normals[i].y < 0.01: continue
			var a := pose * vertices[i]; var b := pose * vertices[i + 1]; var c := pose * vertices[i + 2]
			Kit.polygon(tool, [a, b, c], (a + b + c) / 3 - Vector3.UP)
	else:
		# Concave corners are the inverse of the outer corner pyramid. Their
		# diagonal valley joins two roof planes without a hole or a vertical wall.
		var middle := Vector2(tile) + Vector2(0.5, 0.5)
		var centre := Vector3(middle.x, height_at(middle, shape), middle.y)
		for i in 4:
			var a: Vector3 = points[i]; var b: Vector3 = points[(i + 1) % 4]
			if not (b - a).cross(centre - a).is_zero_approx(): Kit.polygon(tool, [a, b, centre], centre - Vector3.UP)
	return tool.commit()

static func ridge_segments(tile: Vector2i, shape: Dictionary) -> Array:
	var result: Array = []
	var found := {}
	for run: Dictionary in shape.runs:
		var axis: int = run.axis; var across := 1 - axis
		if tile[across] != int(run.across) or tile[axis] < run.low or tile[axis] + 1 > run.high: continue
		if found.has(axis): continue
		found[axis] = true
		var a := Vector2(tile); var b := a; b[axis] += 1
		if height_at(a, shape) > EAVE + 0.99 and height_at(b, shape) > EAVE + 0.99: result.append([a, b])
	return result

static func sync(model, views: Dictionary, planning := false) -> void:
	var nodes := {}
	for node: Node3D in views.values():
		var cell: Vector3i = node.get_meta("cell", Vector3i.ZERO)
		if node.get_meta("asset", "") == "house" and not node.get_meta("planned", false) and not node.has_meta("construction_parts") and Houses.is_house(model, cell): nodes[cell] = node
	var visited := {}
	for cell: Vector3i in nodes:
		if visited.has(cell): continue
		var rooms := Houses.members(model, cell)
		var tiles := {}; var room_tiles := {}; var covered_tiles := {}
		for room: Vector3i in rooms:
			visited[room] = true
			if not nodes.has(room): continue
			room_tiles[room] = []
			for x in 2:
				for z in 2:
					var offset := Vector3(x - 0.5, 0, z - 0.5)
					var covered: bool = model.Planning.upper_used(model, room, "house", offset) if planning else model.roof_panel_covered(room, offset)
					if covered:
						covered_tiles[Vector2i(room.x + x - 1, room.z + z - 1)] = true
						continue
					var tile := Vector2i(room.x + x - 1, room.z + z - 1)
					tiles[tile] = true; room_tiles[room].append(tile)
		var ridge_rooms: Array = []
		for room: Vector3i in rooms:
			if nodes.has(room): ridge_rooms.append({"at": Vector2(room.x, room.z), "axis": 1 if int(model.buildings[room].direction) % 2 == 0 else 0})
		var shape := profile(tiles, ridge_rooms) if not tiles.is_empty() else {}
		shape["covered"] = covered_tiles
		for room: Vector3i in rooms:
			if not nodes.has(room): continue
			var node: Node3D = nodes[room]
			var level := preload("res://scripts/settlement/house_tiers.gd").tier(model.buildings[room])
			preload("res://scripts/settlement/house_tiers.gd").frame(node, level)
			var signature := [rooms, tiles.keys(), ridge_rooms, node.rotation.y, model.world_seed, level]
			var parts := authored_parts(node)
			if node.get_meta("joined_roof_signature", []) != signature:
				node.set_meta("joined_roof_signature", signature.duplicate(true))
				if node.has_node("JoinedRoof"): node.get_node("JoinedRoof").free()
				if not room_tiles[room].is_empty():
					var roof := Node3D.new(); roof.name = "JoinedRoof"; roof.set_meta("variation_exempt", true); node.add_child(roof)
					# Meshes use world-grid coordinates but remain owned by their room.
					roof.transform = Transform3D(node.basis.inverse(), node.basis.inverse() * -Vector3(room.x, 0, room.z))
					var material := StandardMaterial3D.new(); material.albedo_color = [Color("d9b464"), Color("c19361"), Color("ba674d")][level - 1]; material.roughness = 1; material.vertex_color_use_as_albedo = true; material.cull_mode = BaseMaterial3D.CULL_DISABLED
					var cap := node.get_node_or_null("Roof/Cap") as MeshInstance3D
					if level == 3 and cap != null and cap.get_active_material(0) is StandardMaterial3D: material.albedo_color = cap.get_active_material(0).albedo_color
					for tile: Vector2i in room_tiles[room]:
						var mesh := MeshInstance3D.new(); mesh.name = "Slope_%d_%d" % [tile.x, tile.y]; mesh.mesh = Boards.mesh(tile_mesh(tile, shape), tile, shape, hash([model.world_seed, room.y]), ["hay", "house", "imbrex"][level - 1]); mesh.material_override = material; roof.add_child(mesh)
						mesh.set_meta("roof_component", component(heights(tile, shape)).kind)
						mesh.set_meta("source_component", ["ThatchSheaf", "Roof/Cap2", "Imbrex"][level - 1])
						mesh.set_meta("construction_role", "roof_cover")
						mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
						var ridges := ridge_segments(tile, shape)
						for index in ridges.size():
							var a: Vector2 = ridges[index][0]; var b: Vector2 = ridges[index][1]
							if level != 2:
								preload("res://scripts/settlement/roof_covering.gd").ridge(roof, a, b, EAVE + 1, "hay" if level == 1 else "imbrex", material)
							else: Frame.member(roof, "RidgePlank_%d_%d_%d" % [tile.x, tile.y, index], Vector3(a.x, EAVE + 1.08, a.y), Vector3(b.x, EAVE + 1.08, b.y))
					Frame.Timber.rebuild(roof)
					Illustration.apply(roof, false, true)
				# Clearance includes the physical panel thickness and its small tilt.
				preload("res://scripts/settlement/roof_timber.gd").fit(node, func(at: Vector3):
					var point := node.basis * at + Vector3(room.x, 0, room.z)
					if not tiles.has(Vector2i(floori(point.x), floori(point.z))):
						if covered_tiles.has(Vector2i(floori(point.x), floori(point.z))): return INF
					return height_at(Vector2(point.x, point.z), shape) - 0.18 if not shape.is_empty() and shape.has("runs") else INF)
			for part: MeshInstance3D in parts:
				part.visible = false
