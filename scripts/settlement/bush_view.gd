extends RefCounted
## Rounded bushes with a low flattened base and individually varied flat green fills.
const Random = preload("res://scripts/deterministic_random.gd")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const SIZE_SCALE := 0.5
const COLOURS := [Color("7c956c"), Color("708961"), Color("849d73"), Color("768f67")]
const SHADE_STEPS := 256
const MESH_CACHE_LIMIT := 128
static var meshes: Dictionary = {}
static var materials: Dictionary = {}

static func foliage_mesh(variant: int) -> ArrayMesh:
	if meshes.has(variant):
		return meshes[variant]
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in vertices.size():
		vertices[index] = bun_point(vertices[index], variant)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var source := ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(source, 0)
	surface.generate_normals()
	var result := surface.commit()
	if meshes.size() >= MESH_CACHE_LIMIT: meshes.erase(meshes.keys()[0])
	meshes[variant] = result
	return result

static func bun_point(point: Vector3, variant: int) -> Vector3:
	var phase := float(variant % 1000003) * 0.00137
	var angle := atan2(point.z, point.x)
	var radial := Vector2(point.x, point.z).length()
	var outline := 1.0 + radial * (0.045 * sin(angle * 3.0 + phase) + 0.025 * cos(angle * 5.0 - phase))
	# A domed crown above broad shoulders; the underside curves into a flat base.
	var height := 0.28 + point.y * 1.14 if point.y >= 0 else 0.28 * pow(1.0 + point.y, 3.0)
	return Vector3(
		point.x * (1.19 + 0.035 * sin(phase)) * outline + 0.075 * point.y * sin(phase + 0.7),
		height,
		point.z * (1.14 + 0.04 * cos(phase)) * outline + 0.06 * point.y * cos(phase)) * SIZE_SCALE

static func berry_position(index: int, variant: int) -> Vector3:
	var spots := [Vector2(0, 0.27), Vector2(-0.43, -0.24), Vector2(0.43, -0.1)]
	var spot: Vector2 = spots[index] if index < 3 else Vector2(sin(index * 2.4), cos(index * 2.4)) * 0.65
	var surface := Vector3(spot.x, sqrt(1.0 - spot.length_squared()), spot.y)
	return bun_point(surface, variant) + Vector3.UP * 0.045

static func foliage_material(colour_index: int) -> StandardMaterial3D:
	if not materials.has(colour_index):
		var material := StandardMaterial3D.new()
		var base: Color = COLOURS[colour_index % COLOURS.size()]
		# Decode the discrete shade band packed above the base colour index.
		@warning_ignore("integer_division")
		var shade := float(colour_index / COLOURS.size()) / float(SHADE_STEPS - 1)
		material.albedo_color = base.darkened(0.06).lerp(base.lightened(0.06), shade)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.roughness = 1.0
		material.metallic_specular = 0.0
		materials[colour_index] = material
	return materials[colour_index]

static func sync(node: Node3D, cell: Vector3i, seed_: int, identity := -1) -> void:
	var appearance := Vector3i(cell.x, cell.z, seed_) if identity < 0 else Vector3i(identity, 0, 0)
	if node.has_meta("bush_appearance") and node.get_meta("bush_appearance") == appearance:
		return
	var roll: int = Random.world_roll(cell.x, cell.z, seed_, 416) if identity < 0 else identity
	var leaves := node.get_node("Leaves0") as MeshInstance3D
	var variant := roll
	leaves.mesh = foliage_mesh(variant)
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for index in 9:
		if node.has_node("Berry%d" % index):
			node.get_node("Berry%d" % index).position = berry_position(index, variant)
	# Keep the established shade pattern stable for saved bushes.
	var colour_index := posmod(floori(cell.x / 2.0) + 2 * floori(cell.z / 2.0) + seed_, COLOURS.size())
	# Stable per-bush variation, with a bounded shared material palette.
	colour_index += COLOURS.size() * (Random.world_roll(cell.x, cell.z, seed_, 417) % SHADE_STEPS)
	if identity >= 0: colour_index = identity % (COLOURS.size() * SHADE_STEPS)
	leaves.material_override = Illustration.ungraded(foliage_material(colour_index))
	node.set_meta("bush_appearance", appearance)

static func transplant(node: Node3D, payload: Dictionary) -> void:
	node.scale = Vector3.ONE * lerpf(0.18, 1.0, float(payload.seed_growth))
	for child in node.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("Berry"):
			child.visible = int(str(child.name).trim_prefix("Berry")) < int(payload.berries)
