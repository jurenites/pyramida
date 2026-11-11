extends RefCounted
## Terrain-fitted golden grass and upright pegs; roots stay fixed during growth.
const Farm = preload("res://scripts/settlement/farming.gd")
const Grid = preload("res://scripts/settlement/world_grid.gd")
const Style = preload("res://scripts/settlement/illustration_style.gd")
const Plants = preload("res://scripts/settlement/plant_view.gd")
const Random = preload("res://scripts/deterministic_random.gd")
const BLADES_PER_QUARTER := 256
static var stalk_mesh: ArrayMesh

static func restore_authored(node: Node3D) -> void:
	for part: Node3D in node.get_children():
		if part.has_meta("hay_authored_visible"): part.visible = part.get_meta("hay_authored_visible")

static func height(world, cell: Vector3i, local: Vector3) -> float:
	var layout := Farm.field_layout(world, cell)
	var point := Vector3(cell) * Vector3(Grid.CELL_SIZE, Grid.LEVEL_HEIGHT, Grid.CELL_SIZE)
	point += Vector3(layout.get("placement_offset", Vector3.ZERO)) + local.rotated(Vector3.UP, -int(layout.get("direction", 0)) * PI * 0.5)
	var sample := Vector3i(roundi(point.x / Grid.CELL_SIZE), cell.y, roundi(point.z / Grid.CELL_SIZE))
	# Prepared elevated beds stay on their supported floor; natural ground uses
	# the very same triangle interpolation as citizens and the terrain renderer.
	return world.navigation.surface_height(sample, point) - cell.y * Grid.LEVEL_HEIGHT

static func material(colour: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	result.roughness = 1.0
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if Style.enabled: result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)

static func create_stalk() -> void:
	if stalk_mesh != null: return
	# The same single-triangle blade and wind material as natural Grass.
	stalk_mesh = Plants._blade_mesh(0.05, 0, Color.WHITE)

static func sync(world, cell: Vector3i, node: Node3D) -> void:
	var state := [world.get_instance_id(), world.terrain_revision, world.navigation.revision, node.get_meta("hay_border_seams", []), Farm.field_layout(world, cell)]
	var fitted := node.get_node_or_null("TerrainField") as Node3D
	if fitted == null or node.get_meta("hay_surface_state", []) != state:
		if fitted != null: fitted.free()
		fitted = Node3D.new()
		fitted.name = "TerrainField"
		node.add_child(fitted)
		node.set_meta("hay_surface_state", state.duplicate(true))
		build_soil(world, cell, node, fitted)
		build_borders(world, cell, node, fitted)
		build_stalks(world, cell, fitted)
	for part: Node3D in node.get_children():
		if part is MeshInstance3D or part.name in ["Plants", "JoinedBorderPieces"]:
			part.set_meta("hay_authored_visible", part.visible)
			part.visible = false
	animate(world, cell, node)

static func build_soil(world, cell: Vector3i, node: Node3D, fitted: Node3D) -> void:
	var original := node.get_node("Soil") as MeshInstance3D
	var bounds := original.transform * original.mesh.get_aabb()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Quarter-metre samples include soil corners and centres. Four triangles per
	# square also follow the terrain's centre fan without bridging a hollow.
	for x in 16:
		for z in 16:
			var corners: Array[Vector3] = []
			for uv: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0.5, 0.5)]:
				var point := Vector3(lerpf(bounds.position.x, bounds.end.x, (x + uv.x) / 16.0), 0, lerpf(bounds.position.z, bounds.end.z, (z + uv.y) / 16.0))
				point.y = height(world, cell, point) + 0.018
				corners.append(point)
			for side in 4: triangle(surface, corners[side], corners[4], corners[(side + 1) % 4])
	surface.generate_normals()
	var soil := MeshInstance3D.new()
	soil.name = "Soil"
	soil.mesh = surface.commit()
	soil.material_override = material(Color("e8d5a4"))
	soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fitted.add_child(soil)

static func build_borders(world, cell: Vector3i, node: Node3D, fitted: Node3D) -> void:
	var parts: Array = node.get_children()
	var joined := node.get_node_or_null("JoinedBorderPieces")
	if joined != null: parts.append_array(joined.get_children())
	for original in parts:
		if not original is MeshInstance3D or not original.visible or original.name == "Soil": continue
		if str(original.name).begins_with("EdgePeg"):
			var peg := original.duplicate() as MeshInstance3D
			peg.position.y += height(world, cell, peg.position)
			peg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fitted.add_child(peg)

static func build_stalks(world, cell: Vector3i, fitted: Node3D) -> void:
	create_stalk()
	for quarter in 4:
		var crop := MultiMeshInstance3D.new()
		crop.name = "Quarter%d" % quarter
		crop.set_meta("hay_quarter", quarter)
		crop.multimesh = MultiMesh.new()
		crop.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		crop.multimesh.use_colors = true
		crop.multimesh.use_custom_data = true
		crop.multimesh.mesh = stalk_mesh
		crop.multimesh.instance_count = BLADES_PER_QUARTER
		crop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crop.extra_cull_margin = 0.35
		var seed_: int = world.world_seed if world != null else 0
		var rng := RandomNumberGenerator.new()
		rng.seed = Random.world_coordinate_seed(cell.x, cell.z, seed_, 1500 + cell.y * 4 + quarter)
		var origin := Vector3(cell)
		if world != null: origin += Vector3(Farm.field_layout(world, cell).get("placement_offset", Vector3.ZERO))
		crop.set_instance_shader_parameter("wind_origin", Vector2(origin.x, origin.z))
		var roots: Array[Transform3D] = []
		for index in BLADES_PER_QUARTER:
			var point := Vector3.ZERO
			for attempt in 24:
				point = Vector3((-1.96 if quarter % 2 == 0 else 0.04) + rng.randf() * 1.92, 0,
					(-1.96 if quarter < 2 else 0.04) + rng.randf() * 1.92)
				if roots.all(func(other): return Vector2(point.x - other.origin.x, point.z - other.origin.z).length_squared() >= 0.0064): break
			point.y = (height(world, cell, point) if world != null else 0.0) + 0.02
			var width := rng.randf_range(1.4, 2.4)
			var pose := Transform3D(Basis.from_scale(Vector3(width, rng.randf_range(0.55, 0.95), width)), point)
			roots.append(pose)
			crop.multimesh.set_instance_transform(index, pose)
			crop.multimesh.set_instance_color(index, Color("ddb65d").lerp(Color("f1ce79"), rng.randf()))
			crop.multimesh.set_instance_custom_data(index, Color(rng.randf_range(-0.06, 0.06), 0, 0, 0))
		crop.set_meta("roots", roots)
		fitted.add_child(crop)

static func animate(world, cell: Vector3i, node: Node3D) -> void:
	var fitted := node.get_node_or_null("TerrainField")
	if fitted == null: return
	var garden: Dictionary = world.gardens[cell]
	for quarter in 4:
		var crop := fitted.get_node("Quarter%d" % quarter) as MultiMeshInstance3D
		var progress: float = garden.get("quarter_growth", [garden.growth, garden.growth, garden.growth, garden.growth])[quarter]
		var ripe := (Farm.standing_quarters(garden) & (1 << quarter)) != 0
		crop.visible = Farm.quarter_open(world, cell, quarter) and (ripe or progress > 0.0)
		var growth := 1.0 if ripe else snappedf(clampf(progress / Farm.GROW_SECONDS, 0.04, 1.0), 0.025)
		if crop.get_meta("growth", -1.0) == growth: continue
		crop.set_meta("growth", growth)
		var roots: Array = crop.get_meta("roots")
		for index in roots.size():
			var pose: Transform3D = roots[index]
			pose.basis = pose.basis.scaled_local(Vector3(1, growth, 1))
			crop.multimesh.set_instance_transform(index, pose)
