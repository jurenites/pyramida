extends RefCounted
## Half-room terrain cells with shared sloped talus and matching collision.
const Greece = preload("res://scripts/settlement/greece_landscape.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
const STONE_TOP := Color("d9b48d")
const STONE_SIDE := Color("c59870")
const STONE_STRATUM := Color("b88965")
const CORNERS := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
const EDGES := [[1, 2, 0, 3], [2, 3, 1, 0], [3, 0, 2, 1], [0, 1, 3, 2]]

static func corner_heights(model, cell: Vector3i) -> Array:
	var h := cell.y * Nav.LEVEL_HEIGHT
	return model.soil_shapes.get(cell, model.terrain_shapes.get(cell, [h, h, h, h]))

static func build(parent: Node3D, model, cells: Dictionary = {}, border: Dictionary = {}, border_shapes: Dictionary = {}) -> void:
	if cells.is_empty(): cells = model.ground
	var chunks := {}
	var edited_edges := PackedVector3Array()
	for cell: Vector3i in cells:
		var key := Vector2i(floori(float(cell.x) / 16), floori(float(cell.z) / 16))
		if not chunks.has(key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			chunks[key] = surface
		var st: SurfaceTool = chunks[key]
		var heights := corner_heights(model, cell)
		var points: Array[Vector3] = []
		for index in 4:
			points.append(Vector3(cell.x * Nav.CELL_SIZE, heights[index], cell.z * Nav.CELL_SIZE) + CORNERS[index] * Nav.CELL_SIZE)
		var talus: bool = model.terrain_shapes.has(cell)
		var color := Color("c6ad88") if talus else (STONE_TOP if cell.y > 0 else Color("fef1cf"))
		if model.difficulty == "easy":
			color = Greece.ground_color(Vector2(cell.x, cell.z), model.world_seed)
		var edited_sand: bool = model.surface_edits.has(Vector2i(cell.x, cell.z))
		if edited_sand: color = Color("fef1cf")
		if talus:
			var normal := (points[2] - points[0]).cross(points[1] - points[0]).normalized()
			color = color.lightened(normal.dot(Vector3(-0.6, 0, -0.8)) * 0.18)
		if heights.size() == 5:
			var centre := Vector3(cell.x * Nav.CELL_SIZE, heights[4], cell.z * Nav.CELL_SIZE)
			for index in 4:
				var next := (index + 1) % 4
				# Relief changes geometry, not the sunlit fill. Per-triangle tint
				# exposes the soil fan as false shadows across otherwise open sand.
				triangle(st, points[index], centre, points[next], color)
		else:
			triangle(st, points[0], points[2], points[1], color)
			triangle(st, points[0], points[3], points[2], color)
		for side in 4:
			var direction: Vector3i = Nav.DIRECTIONS[side]
			var neighbour: Vector3i = model.surface_at(cell.x + direction.x, cell.z + direction.z)
			var column := Vector2i(neighbour.x, neighbour.z)
			var edited_neighbour: bool = model.surface_edits.has(column)
			if edited_neighbour: neighbour.y = int(model.surface_edits[column])
			if not edited_neighbour and not model.ground.has(neighbour) and border.has(column):
				neighbour.y = border[column]
			var bottom: Array = corner_heights(model, neighbour) if model.ground.has(neighbour) else border_shapes.get(neighbour, [neighbour.y * Nav.LEVEL_HEIGHT, neighbour.y * Nav.LEVEL_HEIGHT, neighbour.y * Nav.LEVEL_HEIGHT, neighbour.y * Nav.LEVEL_HEIGHT])
			if model.soil_enabled and not model.ground.has(neighbour) and border.has(column):
				bottom = model.Soil.shape(model, neighbour, bottom)
			if not model.ground.has(neighbour) and not border.has(column):
				bottom = [-1.5, -1.5, -1.5, -1.5]
			if edited_neighbour: bottom = [float(neighbour.y), float(neighbour.y), float(neighbour.y), float(neighbour.y)]
			var edge: Array = EDGES[side]
			var a := points[edge[0]]
			var b := points[edge[1]]
			if (edited_sand or edited_neighbour) and maxf(a.y - bottom[edge[2]], b.y - bottom[edge[3]]) > 0.001:
				# Same-colour sand faces need a contour at the cut, not per-triangle
				# shading. Offset into the air to avoid coplanar line flicker.
				var edge_offset := Vector3(direction) * 0.003 + Vector3.UP * 0.003
				var edge_top_a := a + edge_offset
				var edge_top_b := b + edge_offset
				var edge_low_a := Vector3(a.x, minf(a.y, bottom[edge[2]]), a.z) + edge_offset
				var edge_low_b := Vector3(b.x, minf(b.y, bottom[edge[3]]), b.z) + edge_offset
				edited_edges.append_array(PackedVector3Array([edge_top_a, edge_top_b, edge_top_b, edge_low_b, edge_low_b, edge_low_a, edge_low_a, edge_top_a]))
			# Horizontal strata stay broad; fine gravel lives inside the terrain cell.
			var low := minf(bottom[edge[2]], bottom[edge[3]])
			var high := maxf(a.y, b.y)
			var band := floorf(low / 1.2) * 1.2
			while band < high - 0.001:
				var a_low := Vector3(a.x, maxf(band, bottom[edge[2]]), a.z)
				var b_low := Vector3(b.x, maxf(band, bottom[edge[3]]), b.z)
				var a_high := Vector3(a.x, minf(band + 1.2, a.y), a.z)
				var b_high := Vector3(b.x, minf(band + 1.2, b.y), b.z)
				a_low.y = minf(a_low.y, a_high.y)
				b_low.y = minf(b_low.y, b_high.y)
				var rock := STONE_STRATUM if posmod(roundi(band / 1.2), 3) == 0 else STONE_SIDE
				if edited_sand or edited_neighbour: rock = Color("fef1cf")
				triangle(st, a_low, b_high, b_low, rock)
				triangle(st, a_low, a_high, b_high, rock)
				band += 1.2
		if model.difficulty != "easy" and talus and posmod(cell.x * 17 + cell.z * 31, 4) == 0:
			# Low polygon chips are subcell decoration, never placement coordinates.
			var centre := (points[0] + points[1] + points[2] + points[3]) * 0.25 + Vector3.UP * 0.025
			var tip := centre + Vector3(0.02, 0.14, 0.01)
			var chip := [centre + Vector3(-0.12, 0, -0.1), centre + Vector3(0.13, 0, -0.06), centre + Vector3(0.03, 0, 0.14)]
			for side in 3:
				triangle(st, chip[side], tip, chip[(side + 1) % 3], Color("a38c71"))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for key in chunks:
		var mesh: ArrayMesh = chunks[key].commit()
		var view := MeshInstance3D.new()
		view.name = "RockChunk_%s_%s" % [key.x, key.y]
		view.mesh = mesh
		view.material_override = preload("res://scripts/settlement/illustration_style.gd").terrain_material(material)
		parent.add_child(view)
		var body := StaticBody3D.new()
		body.set_meta("terrain", true)
		var collision := CollisionShape3D.new()
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
		view.add_child(body)
	if not edited_edges.is_empty():
		var outline_mesh := ImmediateMesh.new()
		outline_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for edge_point: Vector3 in edited_edges: outline_mesh.surface_add_vertex(edge_point)
		outline_mesh.surface_end()
		var outline_view := MeshInstance3D.new()
		outline_view.name = "SandCutEdges"
		outline_view.mesh = outline_mesh
		outline_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var outline_material := StandardMaterial3D.new()
		outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline_material.albedo_color = STONE_SIDE
		outline_view.material_override = outline_material
		parent.add_child(outline_view)
	# Small cut-stone treads make the only natural elevation links legible.
	var steps := SurfaceTool.new()
	steps.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lower: Vector3i in model.terrain_ramps:
		if not cells.has(lower): continue
		var upper: Vector3i = model.terrain_ramps[lower]
		var direction := Vector3(upper.x - lower.x, 0, upper.z - lower.z)
		var across := Vector3(-direction.z, 0, direction.x) * 0.35
		var rise := Nav.point(upper).y - Nav.point(lower).y
		for index in 8:
			var p := Nav.point(lower) + direction * (float(index) / 8.0) + Vector3.UP * (float(index + 1) / 8.0 * rise + 0.025)
			quad(steps, p - across, across * 2, direction / 8.0, Vector3.UP, Color("d6c6a2"))
			quad(steps, p - across, across * 2, Vector3.DOWN * rise / 8, -direction, Color("9d896b"))
	if not model.terrain_ramps.is_empty():
		var view := MeshInstance3D.new()
		view.mesh = steps.commit()
		view.material_override = preload("res://scripts/settlement/illustration_style.gd").terrain_material(material)
		parent.add_child(view)

static func quad(st: SurfaceTool, origin: Vector3, u: Vector3, v: Vector3, normal: Vector3, color: Color) -> void:
	st.set_normal(normal)
	st.set_color(color)
	# Tread tops and risers use different axes; both must face their normal.
	var points := [origin, origin + u, origin + u + v, origin, origin + u + v, origin + v]
	if u.cross(v).dot(normal) > 0.0:
		points = [origin, origin + u + v, origin + u, origin, origin + v, origin + u + v]
	for point in points:
		st.add_vertex(point)

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).length_squared() < 0.0000001:
		return
	# Inputs define the outward normal; Godot's clockwise front face needs
	# the opposite vertex order. Back-facing soil flips the shadow normal
	# bias inward and produces striped self-shadowing under a low sun.
	st.set_normal((b - a).cross(c - a).normalized())
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)
