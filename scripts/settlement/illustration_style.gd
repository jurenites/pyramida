extends RefCounted
## Flat painted materials plus a world-only edge pass; GUI and picking stay untouched.
const EDGE_SHADER = preload("res://shaders/settlement_illustration.gdshader")
const UNGRADED_SHADER = preload("res://shaders/settlement_ungraded.gdshader")
const Settings = preload("res://scripts/gameplay_settings.gd")
const DayCycle = preload("res://scripts/settlement/day_cycle.gd")
static var enabled := true
static var ground_material: ShaderMaterial
static var flat_materials: Dictionary = {}
static var ungraded_materials: Dictionary = {}

static func ungraded(source: Material) -> Material:
	if not enabled or not source is StandardMaterial3D:
		return source
	if not ungraded_materials.has(source):
		var result := ShaderMaterial.new()
		result.shader = UNGRADED_SHADER
		var colour: Color = source.albedo_color
		result.set_shader_parameter("fill_colour", Vector4(colour.r, colour.g, colour.b, colour.a))
		ungraded_materials[source] = result
	return ungraded_materials[source]

static func flat(source: Material) -> Material:
	if not enabled or not source is StandardMaterial3D:
		return source
	if not flat_materials.has(source):
		var result := source.duplicate() as StandardMaterial3D
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		result.roughness = 1.0
		flat_materials[source] = result
	return flat_materials[source]

# The paper terrain keeps its painted colours but receives real shadow maps.
static func terrain_material(source: StandardMaterial3D) -> Material:
	if not enabled:
		return source
	if ground_material == null:
		ground_material = ShaderMaterial.new()
		ground_material.shader = preload("res://shaders/settlement_paper_ground.gdshader")
	return ground_material

static func apply(node: Node, ignore_day_tint := false) -> void:
	for part in node.find_children("*", "MeshInstance3D", true, false):
		var visual := part as MeshInstance3D
		if visual.mesh == null or visual.get_meta("keep_lighting", false):
			continue
		if visual.material_override != null:
			visual.material_override = ungraded(visual.material_override) if ignore_day_tint else flat(visual.material_override)
		else:
			for surface in visual.mesh.get_surface_count():
				visual.set_surface_override_material(surface, flat(visual.get_active_material(surface)))

static func configure(container: SubViewportContainer, viewport: SubViewport) -> void:
	# Preserve compensation values above white until the final colour grading pass.
	viewport.use_hdr_2d = enabled
	container.stretch_shrink = 1 if enabled else 2
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if enabled else CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.msaa_3d = Viewport.MSAA_4X if enabled else Viewport.MSAA_DISABLED
	if enabled:
		var material := ShaderMaterial.new()
		material.shader = EDGE_SHADER
		material.set_shader_parameter("linear_source", true)
		container.material = material
	else:
		container.material = null

static func update(material: Material, elapsed: float) -> void:
	if not material is ShaderMaterial:
		return
	var phase := fposmod(elapsed, Settings.SIMULATION_DAY_SECONDS) / Settings.SIMULATION_DAY_SECONDS
	var tint := DayCycle.cycle_color(phase, Color("f7e7d0"), Color.WHITE, Color("edc6ab"), Color("7aa3f5"))
	tint = tint.lerp(Color("7aa3f5"), DayCycle.night_amount(phase))
	material.set_shader_parameter("day_tint", Vector3(tint.r, tint.g, tint.b))
	RenderingServer.global_shader_parameter_set("settlement_day_tint", Vector3(tint.r, tint.g, tint.b))
