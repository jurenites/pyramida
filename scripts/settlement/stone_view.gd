extends RefCounted
## Three-tier natural outcrops, rough quarried cargo and shaped masonry blocks.
const Terrain = preload("res://scripts/settlement/terrain_mesh.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const Random = preload("res://scripts/deterministic_random.gd")
const Volume = preload("res://scripts/settlement/stone_volume.gd")
const BLOCK_SIZE := Terrain.Nav.CELL_SIZE

static func block_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var width := rng.randf_range(0.85, 0.98) * BLOCK_SIZE
	var depth := rng.randf_range(0.85, 0.98) * BLOCK_SIZE
	var height := rng.randf_range(0.78, 0.91) * BLOCK_SIZE
	var taper_x := rng.randf_range(0.76, 0.94)
	var taper_z := rng.randf_range(0.76, 0.94)
	var shear := Vector2(rng.randf_range(-0.09, 0.09), rng.randf_range(-0.09, 0.09)) * BLOCK_SIZE
	var tilt_x := rng.randf_range(0.07, 0.16) * (-1 if rng.randf() < 0.5 else 1)
	var tilt_z := rng.randf_range(0.04, 0.13) * (-1 if rng.randf() < 0.5 else 1)
	var vertices: Array[Vector3] = []
	for corner: Vector3 in Terrain.CORNERS:
		vertices.append(Vector3(corner.x * width, 0, corner.z * depth))
	for corner: Vector3 in Terrain.CORNERS:
		var x := corner.x * width * taper_x + shear.x
		var z := corner.z * depth * taper_z + shear.y
		vertices.append(Vector3(x, height + x * tilt_x + z * tilt_z, z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shade := rng.randf_range(-0.035, 0.035)
	var faces := [[4, 7, 6, 5], [0, 1, 2, 3], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]
	for index in faces.size():
		var face: Array = faces[index]
		var colour := Terrain.STONE_TOP if index == 0 else (Terrain.STONE_STRATUM if index % 3 == 0 else Terrain.STONE_SIDE)
		colour = colour.lightened(shade)
		Terrain.triangle(st, vertices[face[0]], vertices[face[1]], vertices[face[2]], colour)
		Terrain.triangle(st, vertices[face[0]], vertices[face[2]], vertices[face[3]], colour)
	return st.commit()

static func material() -> Material:
	var source := StandardMaterial3D.new()
	source.vertex_color_use_as_albedo = true
	source.vertex_color_is_srgb = true
	source.roughness = 1.0
	return Illustration.terrain_material(source)

static func raw_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Broad quarry fractures: a long block with chipped corners, not a round boulder.
	var width := rng.randf_range(0.94, 1.10) * BLOCK_SIZE
	var depth := rng.randf_range(0.63, 0.76) * BLOCK_SIZE
	var height := rng.randf_range(0.56, 0.68) * BLOCK_SIZE
	var outline := [Vector2(-0.36, -0.5), Vector2(0.35, -0.5), Vector2(0.5, -0.32), Vector2(0.5, 0.34), Vector2(0.33, 0.5), Vector2(-0.35, 0.5), Vector2(-0.5, 0.31), Vector2(-0.5, -0.33)]
	var vertices: Array[Vector3] = []
	var shear := Vector2(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04))
	for layer in 2:
		for corner: Vector2 in outline:
			var taper := 1.0 if layer == 0 else rng.randf_range(0.88, 0.98)
			vertices.append(Vector3(corner.x * width * taper + shear.x * layer, height * layer + (corner.x * 0.06 + corner.y * 0.04) * layer, corner.y * depth * taper + shear.y * layer))
	var centre := Vector3(0, height * 0.5, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 8:
		var next := (index + 1) % 8
		var colour := Terrain.STONE_SIDE.lightened(rng.randf_range(-0.05, 0.04))
		_raw_face(st, vertices[index], vertices[next], vertices[next + 8], centre, colour)
		_raw_face(st, vertices[index], vertices[next + 8], vertices[index + 8], centre, colour)
	for index in range(1, 7):
		_raw_face(st, vertices[0], vertices[index], vertices[index + 1], centre, Terrain.STONE_STRATUM)
		_raw_face(st, vertices[8], vertices[index + 8], vertices[index + 9], centre, Terrain.STONE_TOP)
	return st.commit()

static func _raw_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3, colour: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c) / 3.0 - centre) < 0: normal = -normal
	# Clockwise vertices face out in Godot; the shading normal still points out.
	if (b - a).cross(c - a).dot(normal) > 0:
		var swap := b
		b = c
		c = swap
	st.set_normal(normal)
	st.set_color(colour)
	for vertex in [a, b, c]: st.add_vertex(vertex)

static func populate(node: Node3D, cell: Vector3i, world_seed: int, capacity: int, dressed := false) -> void:
	if not dressed:
		populate_outcrop(node, cell, world_seed, capacity)
		return
	var stone_material := material()
	# Older inventories can hold thirty stones. Give those a broader stepped base
	# instead of turning preserved stock into a fourteen-storey column.
	var base_width := 2
	var pyramid_capacity := 5
	while pyramid_capacity < capacity and capacity > 6:
		base_width += 1
		pyramid_capacity += base_width * base_width
	for index in capacity:
		var stone := MeshInstance3D.new()
		stone.name = "Stone%d" % index
		var shape_seed := Random.world_coordinate_seed(cell.x, cell.z, world_seed, 610 + index)
		stone.mesh = block_mesh(shape_seed) if dressed else raw_mesh(shape_seed)
		stone.material_override = stone_material
		stone.set_meta("keep_lighting", true)
		# Four grounded blocks, then pairs resting across their shared seams.
		@warning_ignore("integer_division")
		var layer := 0 if index < 4 else 1 + (index - 4) / 2
		var x := float(index % 2) - 0.5
		@warning_ignore("integer_division")
		var z := float(index / 2) - 0.5 if index < 4 else 0.0
		if layer > 0 and layer % 2 == 0:
			z = x
			x = 0.0
		if capacity > 6:
			var slot := index
			var width := base_width
			layer = 0
			while slot >= width * width and width > 1:
				slot -= width * width
				width -= 1
				layer += 1
			x = float(slot % width) - float(width - 1) * 0.5
			# Each complete row occupies one grid slot in depth.
			@warning_ignore("integer_division")
			z = float(slot / width) - float(width - 1) * 0.5
		stone.position = Vector3(x * 0.93, layer * 0.77, z * 0.93) * BLOCK_SIZE
		stone.rotation.y = (Random.world_fraction(cell.x, cell.z, world_seed, 810 + index) - 0.5) * 0.16
		node.add_child(stone)
		stone.owner = node

static func outcrop_slice(seed_value: int, layer: int, column_height: int) -> ArrayMesh:
	# Every slice samples the same column, so consecutive pieces meet exactly.
	# Mining exposes a new slanted cap without shrinking the rest of the rock.
	var vertices := Volume.vertices(seed_value, layer, column_height)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var shade := rng.randf_range(-0.025, 0.025)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [[4, 7, 6, 5], [0, 1, 2, 3], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]
	for index in faces.size():
		var face: Array = faces[index]
		var colour := Terrain.STONE_TOP if index == 0 else Terrain.STONE_SIDE
		# Broad painted faces preserve the reference's quiet pillar silhouettes.
		colour = colour.lightened(shade + (0.035 if index in [2, 4] else 0.0))
		Terrain.triangle(st, vertices[face[0]], vertices[face[1]], vertices[face[2]], colour)
		Terrain.triangle(st, vertices[face[0]], vertices[face[2]], vertices[face[3]], colour)
	return st.commit()

static func populate_outcrop(node: Node3D, cell: Vector3i, world_seed: int, capacity: int) -> void:
	var roll := Random.world_roll(cell.x, cell.z, world_seed, 940)
	var profiles := [[3, 2, 1], [3, 1, 1, 1], [3, 3]]
	var heights: Array = profiles[roll % profiles.size()].duplicate() if capacity == 6 else []
	var remaining := capacity
	while heights.is_empty() or (capacity != 6 and remaining > 0):
		heights.append(mini(3, remaining))
		remaining -= mini(3, remaining)
		if remaining == 0: break
	var width := maxi(1, ceili(sqrt(heights.size())))
	var rows := ceili(float(heights.size()) / width)
	var turn := float(roll % 4) * PI * 0.5
	var stone_material := material()
	var index := 0
	# Bottom-up indexing means pickup always clears a supported upper piece first.
	for layer in 3:
		for column in heights.size():
			if layer >= heights[column]: continue
			var seed_value := Random.world_coordinate_seed(cell.x, cell.z, world_seed, 950 + column)
			var stone := MeshInstance3D.new()
			stone.name = "Stone%d" % index
			stone.mesh = outcrop_slice(seed_value, layer, heights[column])
			stone.material_override = stone_material
			stone.set_meta("keep_lighting", true)
			stone.set_meta("stone_layer", layer)
			stone.set_meta("stone_column", column)
			@warning_ignore("integer_division")
			stone.position = Vector3(column % width - float(width - 1) * 0.5, 0, column / width - float(rows - 1) * 0.5) * BLOCK_SIZE * 0.86
			stone.position = stone.position.rotated(Vector3.UP, turn)
			stone.rotation.y = turn
			node.add_child(stone)
			stone.owner = node
			index += 1

static func sync(node: Node3D, cell: Vector3i, world_seed: int, inventory, dressed := false) -> void:
	if not dressed and inventory.capacity > 30:
		sync_volume(node, cell, world_seed, inventory)
		return
	var signature := [cell, world_seed, inventory.capacity, dressed]
	if node.get_meta("stone_signature", []) != signature:
		for child in node.get_children():
			if child is MeshInstance3D: child.free()
		populate(node, cell, world_seed, inventory.capacity, dressed)
		node.set_meta("stone_signature", signature)
	var bounds := AABB()
	var first := true
	for child in node.get_children():
		if not child is MeshInstance3D: continue
		child.visible = int(str(child.name).trim_prefix("Stone")) < inventory.count("stone")
		if child.visible:
			var box: AABB = child.transform * child.mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
	if node.has_meta("collider"):
		var shape: CollisionShape3D = node.get_meta("collider").get_child(0)
		shape.disabled = first
		if not first:
			shape.shape.size = bounds.size
			shape.position = bounds.get_center()

static func sync_volume(node: Node3D, cell: Vector3i, world_seed: int, inventory) -> void:
	var signature := [cell, world_seed, inventory.capacity, inventory.count("stone")]
	if node.get_meta("stone_signature", []) == signature: return
	for child in node.get_children():
		if child is MeshInstance3D: child.free()
	var collision_faces := PackedVector3Array()
	var bounds := AABB()
	var first := true
	for section in Volume.sections(cell, world_seed):
		var remaining := clampi(Volume.logical_amount(cell, world_seed, inventory.count("stone"), inventory.capacity) - int(section.start), 0, section.count)
		if remaining == 0: continue
		var faces := Volume.visual_faces(section, remaining)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in faces:
			var normal: Vector3 = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
			var colour := Terrain.STONE_TOP if normal.y > 0.5 else Terrain.STONE_SIDE
			for index in range(1, face.size() - 1):
				# Logical polygons wind outward mathematically; Godot draws
				# clockwise exteriors. Keep the outward normal for shadow bias.
				st.set_normal(normal)
				st.set_color(colour)
				for vertex in [face[0], face[index + 1], face[index]]: st.add_vertex(vertex)
		var part := MeshInstance3D.new()
		part.name = "Section%d" % section.start
		# Share triangle corners within each flat face (24 render vertices per cuboid).
		st.index()
		part.mesh = st.commit()
		part.material_override = material()
		part.set_meta("keep_lighting", true)
		node.add_child(part)
		collision_faces.append_array(part.transform * part.mesh.get_faces())
		var box: AABB = part.transform * part.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if node.has_meta("collider"):
		var shape: CollisionShape3D = node.get_meta("collider").get_child(0)
		shape.disabled = first
		if not first:
			var collision := ConcavePolygonShape3D.new()
			collision.backface_collision = true
			collision.set_faces(collision_faces)
			shape.shape = collision
			shape.position = Vector3.ZERO
	node.set_meta("stone_signature", signature)
