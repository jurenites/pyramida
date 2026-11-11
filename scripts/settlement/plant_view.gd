extends RefCounted
## Small seed markers and rooted grass share the world's illustrated palette.
static func seed() -> Node3D:
	var root := Node3D.new()
	root.name = "Seed"
	var earth := MeshInstance3D.new()
	var mound := SphereMesh.new()
	mound.radius = 0.24
	mound.height = 0.12
	earth.mesh = mound
	earth.position.y = 0.035
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color("a57c53")
	earth.material_override = soil
	root.add_child(earth)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("6d9753")
	for side in [-1, 1]:
		var leaf := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.12
		shape.height = 0.10
		leaf.mesh = shape
		leaf.scale = Vector3(1, 1, 0.55)
		leaf.position = Vector3(side * 0.08, 0.17, 0)
		leaf.rotation.z = side * 0.55
		leaf.material_override = green
		root.add_child(leaf)
	return root

# Every leaf is its own triangle. No multi-leaf stamp or fixed root layout.
const Random = preload("res://scripts/deterministic_random.gd")
const GRASS_SCALE := 2.0
static var grass_material: ShaderMaterial

static func grass() -> Node3D:
	var root := Node3D.new()
	root.name = "GrassPatch"
	var plants := Node3D.new()
	plants.name = "Plants"
	root.add_child(plants)
	_grass_layout(root, 0, Vector3i.ZERO)
	return root

static func _grass_layout(root: Node3D, world_seed: int, cell: Vector3i) -> void:
	var identity := [world_seed, cell, GRASS_SCALE]
	if root.get_meta("grass_identity", []) == identity: return
	root.set_meta("grass_identity", identity)
	if root.has_meta("grass_surface"): root.remove_meta("grass_surface")
	var plants := root.get_node("Plants")
	for blade in plants.get_children(): blade.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = Random.world_coordinate_seed(cell.x, cell.z, world_seed, 320)
	var count := 15
	var angle := rng.randf_range(0, TAU)
	var spread := Vector2(rng.randf_range(0.34, 0.43), rng.randf_range(0.28, 0.38))
	var roots: Array[Vector2] = []
	for index in count:
		var offset := Vector2.ZERO
		for attempt in 64:
			offset = (Vector2.from_angle(rng.randf_range(0, TAU)) * sqrt(rng.randf()) * spread).rotated(angle)
			if roots.all(func(other): return offset.distance_to(other) >= 0.075): break
		roots.append(offset)
	# Keep the seeded scatter order so each harvest thins the whole patch.
	for index in count:
		var blade := MeshInstance3D.new()
		blade.name = "Blade%d" % index
		var height := rng.randf_range(0.19, 0.49) * GRASS_SCALE
		blade.mesh = _blade_mesh(rng.randf_range(0.025, 0.065), rng.randf_range(-0.10, 0.10),
			preload("res://scripts/game_palette.gd").GRASS.lerp(preload("res://scripts/game_palette.gd").HAY_FIELD, rng.randf()))
		blade.position = Vector3(roots[index].x * GRASS_SCALE, 0.012, roots[index].y * GRASS_SCALE)
		blade.set_meta("grown_height", height)
		blade.scale = Vector3(GRASS_SCALE, height, GRASS_SCALE)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blade.extra_cull_margin = 0.15 * GRASS_SCALE
		plants.add_child(blade)

static func sync_grass(root: Node3D, world, cell: Vector3i) -> void:
	_grass_layout(root, world.world_seed, cell)
	var plants := root.get_node("Plants")
	var state := [world.terrain_revision, world.soil_revision, root.position]
	if root.get_meta("grass_surface", []) != state:
		root.set_meta("grass_surface", state)
		for blade: MeshInstance3D in plants.get_children():
			blade.set_instance_shader_parameter("wind_origin", Vector2(root.position.x, root.position.z))
			var point := root.position + blade.position
			var ground := Vector3i(roundi(point.x / world.Grid.CELL_SIZE), cell.y, roundi(point.z / world.Grid.CELL_SIZE))
			# Follow neighbouring soil only on this shelf. At a cliff, extend the
			# owning surface under the leaf instead of snapping to another level.
			# A wall may naturally hide the overlapping part of the patch.
			if not world.navigation.surfaces.has(ground): ground = cell
			blade.position.y = world.navigation.surface_height(ground, point) - root.position.y + 0.012
		# Keep picking bounds stable while individual leaves are harvested.
		if root.has_meta("collider"):
			var bounds := AABB(plants.get_child(0).position, Vector3.ZERO)
			for blade: Node3D in plants.get_children():
				bounds = bounds.expand(blade.position - Vector3(0.18 * GRASS_SCALE, 0.012, 0.18 * GRASS_SCALE))
				bounds = bounds.expand(blade.position + Vector3(0.18 * GRASS_SCALE, float(blade.get_meta("grown_height")), 0.18 * GRASS_SCALE))
			var collision: CollisionShape3D = root.get_meta("collider").get_child(0)
			collision.shape.size = bounds.size
			collision.position = bounds.get_center()
	var crop: Dictionary = world.gardens[cell]
	var remaining := clampi(int(crop.food), 0, 3) * 5
	root.set_meta("resource_empty", remaining == 0)
	for index in plants.get_child_count():
		# Each harvest removes five entire leaves. Remaining leaves never shrink.
		plants.get_child(index).visible = index < remaining
	if root.has_meta("collider"):
		root.get_meta("collider").collision_layer = (2 if root.get_meta("planned", false) else 1) if remaining > 0 and root.is_visible_in_tree() and not root.get_meta("relocation_piece", false) else 0

static func _blade_mesh(width: float, lean: float, color: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex: Vector3 in [Vector3(-width * 0.5, 0, 0), Vector3(width * 0.5, 0, 0), Vector3(lean, 1, 0)]:
		surface.set_color(color)
		surface.set_normal(Vector3.FORWARD)
		surface.set_uv(Vector2(0.5, vertex.y))
		surface.add_vertex(vertex)
	if grass_material == null:
		grass_material = ShaderMaterial.new()
		grass_material.shader = preload("res://shaders/settlement_grass.gdshader")
		grass_material.set_shader_parameter("wind_strength", 0.065)
		grass_material.set_shader_parameter("wind_speed", 1.2)
	surface.set_material(grass_material)
	return surface.commit()
