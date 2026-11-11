extends RefCounted
## World-aligned paving: nine real quarry stones per tile, joined across road edges.
const Stone = preload("res://scripts/settlement/stone_view.gd")
const Random = preload("res://scripts/deterministic_random.gd")
const NEIGHBOURS := [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK,
	Vector3i(-1, 0, -1), Vector3i(1, 0, -1), Vector3i(-1, 0, 1), Vector3i(1, 0, 1)]
const STONES_PER_TILE := 9

static func centre(grid: Vector2i, seed_: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = Random.world_coordinate_seed(grid.x, grid.y, seed_, 1810)
	return Vector2(grid) / 3.0 + Vector2(rng.randf_range(-0.075, 0.075), rng.randf_range(-0.075, 0.075))

static func connections(world, cell: Vector3i) -> int:
	var result := 0
	if world == null: return result
	for i in NEIGHBOURS.size():
		if world.buildings.get(cell + NEIGHBOURS[i], {}).get("kind") == "road": result |= 1 << i
	return result

static func inside(point: Vector3, mask: int) -> bool:
	var other := Vector3i(floori(point.x + 0.5), 0, floori(point.z + 0.5))
	if other == Vector3i.ZERO: return true
	var index := NEIGHBOURS.find(other)
	return index >= 0 and (mask & (1 << index)) != 0

static func ground_height(world, cell: Vector3i, local: Vector3) -> float:
	if world == null: return 0.0
	var point := Vector3(cell) + local
	var sample := Vector3i(roundi(point.x), cell.y, roundi(point.z))
	if not world.navigation.surfaces.has(sample): sample = cell
	return world.navigation.surface_height(sample, point) - cell.y

static func mesh(cell: Vector3i, seed_: int, mask := 0, world = null) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-1, 2):
		for z in range(-1, 2):
			var grid := Vector2i(cell.x * 3 + x, cell.z * 3 + z)
			var at := centre(grid, seed_)
			var rng := RandomNumberGenerator.new()
			rng.seed = Random.world_coordinate_seed(grid.x, grid.y, seed_, 1811 + cell.y)
			var source := Stone.raw_mesh(rng.randi()); var bounds := source.get_aabb()
			var arrays := source.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var middle := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(0, TAU), rng.randf_range(-0.03, 0.03))) * Basis.from_scale(Vector3(rng.randf_range(0.31, 0.43), rng.randf_range(0.13, 0.19), rng.randf_range(0.26, 0.36)) / bounds.size)
			# Fit each piece against nearby world-space centres. Unlike rejection
			# packing, this never silently drops stones and has no special tile seam.
			var fit := 1.0
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if dx == 0 and dz == 0: continue
					var delta := centre(grid + Vector2i(dx, dz), seed_) - at
					for vertex: Vector3 in vertices:
						var p := basis * (vertex - middle)
						var projection := Vector2(p.x, p.z).dot(delta)
						if projection > 0: fit = minf(fit, (delta.length_squared() * 0.5 - 0.012 * delta.length()) / projection)
			var origin := Vector3(at.x - cell.x, 0, at.y - cell.z)
			# Outer edges retain whole stones; shared edges allow them to straddle tiles.
			for attempt in 20:
				var valid := true
				for vertex: Vector3 in vertices:
					var p := basis * (vertex - middle); p.x *= fit; p.z *= fit
					if not inside(origin + p, mask): valid = false; break
				if valid: break
				fit *= 0.94
			basis = Basis.from_scale(Vector3(fit, 1, fit)) * basis
			var low := INF; var high := -INF
			for vertex: Vector3 in vertices:
				var y := (basis * (vertex - middle)).y; low = minf(low, y); high = maxf(high, y)
			origin.y = ground_height(world, cell, origin) - low - (high - low) * rng.randf_range(0.50, 0.62)
			var normal_basis := basis.inverse().transposed()
			var shade := rng.randf_range(0.025, 0.085)
			for i in vertices.size():
				st.set_normal((normal_basis * normals[i]).normalized())
				st.set_color(colours[i].darkened(shade))
				st.add_vertex(origin + basis * (vertices[i] - middle))
	var result := st.commit()
	result.set_meta("stone_count", STONES_PER_TILE)
	return result

static func sync(node: Node3D, cell: Vector3i, seed_: int, world = null) -> void:
	var mask := connections(world, cell)
	var terrain: Array = [world.terrain_revision, world.soil_revision] if world != null else []
	var signature := [cell, seed_, node.basis, mask, terrain]
	if node.get_meta("stone_road_seed", []) == signature: return
	node.set_meta("stone_road_seed", signature)
	if node.has_node("Floor"): node.get_node("Floor").hide()
	var stones := node.get_node_or_null("Stones") as MeshInstance3D
	if stones == null:
		stones = MeshInstance3D.new(); stones.name = "Stones"; node.add_child(stones)
		stones.set_meta("variation_exempt", true)
		stones.set_meta("keep_lighting", true)
		stones.set_meta("source_component", "stone_view.raw_mesh")
		stones.material_override = Stone.material()
		stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	stones.mesh = mesh(cell, seed_, mask, world)
	stones.basis = node.basis.inverse()
