extends RefCounted
## Flat painted materials plus a world-only edge pass; GUI and picking stay untouched.
const EDGE_SHADER = preload("res://shaders/settlement_illustration.gdshader")
const UNGRADED_SHADER = preload("res://shaders/settlement_ungraded.gdshader")
const Settings = preload("res://scripts/gameplay_settings.gd")
const Palette = preload("res://scripts/game_palette.gd")
const DayCycle = preload("res://scripts/settlement/day_cycle.gd")
static var enabled := true
static var ground_material: ShaderMaterial
static var flat_materials: Dictionary = {}
static var shadow_materials: Dictionary = {}
static var ungraded_materials: Dictionary = {}

static func configure_sun(light: DirectionalLight3D, distance := 200.0) -> void:
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light.directional_shadow_max_distance = distance
	light.directional_shadow_split_1 = 0.1
	light.directional_shadow_split_2 = 0.25
	light.directional_shadow_split_3 = 0.5
	# Filtered shadows avoid contact-hardening sample noise on small timber faces.
	light.shadow_blur = 0.6
	light.shadow_bias = 0.1
	light.shadow_normal_bias = 2.0
	light.light_angular_distance = 0.0

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
		var ratio := Palette.PEACH_SHADOW.srgb_to_linear() / Palette.SAND_SURFACE.srgb_to_linear()
		ground_material.set_shader_parameter("shadow_ratio", Vector3(ratio.r,ratio.g,ratio.b))
	return ground_material

static func shadowed(source: Material, shaped_surface:=false) -> Material:
	if not enabled or not source is StandardMaterial3D: return source
	if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or source.emission_enabled: return flat(source)
	var key := str(source.albedo_color) + ":" + str(source.vertex_color_use_as_albedo) + ":" + str(shaped_surface)
	if not shadow_materials.has(key):
		var result := ShaderMaterial.new()
		result.shader = preload("res://shaders/settlement_painted_shadow.gdshader")
		result.set_shader_parameter("fill_colour", source.albedo_color)
		result.set_shader_parameter("use_vertex_colour", source.vertex_color_use_as_albedo)
		result.set_shader_parameter("shaped_surface", shaped_surface)
		shadow_materials[key] = result
	return shadow_materials[key]

static func apply(node: Node, ignore_day_tint := false, receive_shadows := false) -> void:
	for part in node.find_children("*", "MeshInstance3D", true, false):
		var visual := part as MeshInstance3D
		if visual.mesh == null or visual.get_meta("keep_lighting", false):
			continue
		var shaped: bool=visual.get_meta("timber_stock","")=="plank" or visual.get_meta("stock_cut_from","")=="plank" or visual.get_meta("shaped_surface",false)
		if visual.material_override != null:
			visual.material_override = ungraded(visual.material_override) if ignore_day_tint else (shadowed(visual.material_override,shaped) if receive_shadows else flat(visual.material_override))
		else:
			for surface in visual.mesh.get_surface_count():
				visual.set_surface_override_material(surface, shadowed(visual.get_active_material(surface),shaped) if receive_shadows else flat(visual.get_active_material(surface)))

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
	# Grade against the reference paper: midday keeps the exact authored swatches;
	# night maps that paper to the slate-blue swatch, without a second blue wash.
	var morning := Palette.SAND_SURFACE.lerp(Palette.LIMESTONE_SIDE,0.12) / Palette.SAND_SURFACE
	var evening := Palette.PEACH_SHADOW / Palette.SAND_SURFACE
	var night := Palette.NIGHT_SURFACE / Palette.SAND_SURFACE
	var tint := DayCycle.cycle_color(phase, morning, Color.WHITE, evening, night)
	material.set_shader_parameter("day_tint", Vector3(tint.r, tint.g, tint.b))
	RenderingServer.global_shader_parameter_set("settlement_day_tint", Vector3(tint.r, tint.g, tint.b))
