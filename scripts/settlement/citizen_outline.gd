extends Control
## Occlusion masks plus a selection-only pass follow actual animated bodies.
## No GPU readback, physics boxes, or changes to world materials.
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const OUTLINE_SHADER = preload("res://shaders/citizen_occlusion_outline.gdshader")
const OCCLUDED_COLOR := Color("c5bca8f2")
var silhouette: SubViewport
var exposed: SubViewport
var selection: SubViewport
var mask_camera: Camera3D
var exposed_camera: Camera3D
var selection_camera: Camera3D
var proxies: Dictionary = {}
var roots: Dictionary = {}
var revision := -1
var white: StandardMaterial3D
var black: StandardMaterial3D
var regions: Array[Rect2] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	white = _mask_material(Color.WHITE)
	black = _mask_material(Color.BLACK)
	silhouette = _viewport(World3D.new())
	exposed = _viewport(silhouette.world_3d)
	selection = _viewport(silhouette.world_3d)
	mask_camera = _camera(silhouette, 1)
	exposed_camera = _camera(exposed, 3)
	selection_camera = _camera(selection, 4)
	var effect := ShaderMaterial.new()
	effect.shader = OUTLINE_SHADER
	effect.set_shader_parameter("visible_mask", exposed.get_texture())
	effect.set_shader_parameter("silhouette_mask", silhouette.get_texture())
	effect.set_shader_parameter("selection_mask", selection.get_texture())
	var colour := Tokens.SELECTION_COLOR
	colour.a = 0.8
	effect.set_shader_parameter("selection_color", colour)
	effect.set_shader_parameter("outline_color", OCCLUDED_COLOR)
	material = effect
	hide()

func _mask_material(colour: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = colour
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _viewport(space: World3D) -> SubViewport:
	var result := SubViewport.new()
	result.world_3d = space
	result.transparent_bg = true
	result.msaa_3d = Viewport.MSAA_2X
	result.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(result)
	return result

func _camera(target: SubViewport, layers: int) -> Camera3D:
	var result := Camera3D.new()
	result.cull_mask = layers
	result.environment = Environment.new()
	result.environment.background_mode = Environment.BG_COLOR
	result.environment.background_color = Color.BLACK
	target.add_child(result)
	return result

func sync(world, camera: Camera3D, model, active := true) -> void:
	visible = active and not world.actors.is_empty()
	for target in [silhouette, exposed, selection]:
		target.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if not visible: return
	# Render at logical UI resolution in both illustrated and reduced-resolution mode.
	var dimensions := Vector2i(size).max(Vector2i(2, 2))
	for target in [silhouette, exposed, selection]: target.size = dimensions
	material.set_shader_parameter("stroke_uv", Vector2.ONE * Tokens.LINE_WIDTH / size.max(Vector2.ONE))
	for target in [mask_camera, exposed_camera, selection_camera]:
		target.global_transform = camera.global_transform
		target.projection = camera.projection
		target.keep_aspect = camera.keep_aspect
		target.size = camera.size
		target.fov = camera.fov
		target.near = camera.near
		target.far = camera.far
	var wanted := {}
	var has_selection := false
	regions.clear()
	for actor in world.actors:
		if not actor.is_visible_in_tree() or (world.fog_enabled and not model.exploration.contains(actor.global_position)): continue
		if camera.is_position_behind(actor.global_position): continue
		var bounds := _screen_bounds(actor, camera)
		if not bounds.has_area(): continue
		_add_region(bounds)
		var selected: bool = actor.ring.visible
		has_selection = has_selection or selected
		for part in actor.silhouette_parts: _sync_part(part, 5 if selected else 1, wanted)
	# Refresh lists when construction/appearance changes. Mesh instances retain
	# their real transforms, cutaway state and individually revealed work stages.
	if revision != world.last_revision:
		roots.clear()
		revision = world.last_revision
	for key: String in world.entity_views:
		if not (key.begins_with("building:") or key.begins_with("stockpile:") or key.begins_with("well:") or key.begins_with("platform:") or key.begins_with("stairs:") or key.begins_with("plan:")): continue
		var node: Node3D = world.entity_views[key]
		if not node.is_visible_in_tree(): continue
		if not roots.has(node): roots[node] = node.find_children("*", "MeshInstance3D", true, false)
		for part in roots[node]:
			if is_instance_valid(part): _sync_part(part, 2, wanted)
	for source in proxies.keys():
		if not wanted.has(source):
			proxies[source].free()
			proxies.erase(source)
	for source in roots.keys():
		if not is_instance_valid(source): roots.erase(source)
	visible = not regions.is_empty()
	for target in [silhouette, exposed]:
		target.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	selection.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible and has_selection else SubViewport.UPDATE_DISABLED
	material.set_shader_parameter("has_selection", has_selection)
	queue_redraw()

func _screen_bounds(actor, camera: Camera3D) -> Rect2:
	var box := AABB()
	var initialized := false
	for part in actor.silhouette_parts:
		if not part.is_visible_in_tree() or part.mesh == null: continue
		var bounds: AABB = part.global_transform * part.mesh.get_aabb()
		box = box.merge(bounds) if initialized else bounds
		initialized = true
	if not initialized: return Rect2()
	var viewport_scale := size / Vector2(camera.get_viewport().get_visible_rect().size)
	var rect := Rect2(camera.unproject_position(box.get_endpoint(0)) * viewport_scale, Vector2.ZERO)
	for index in range(1, 8): rect = rect.expand(camera.unproject_position(box.get_endpoint(index)) * viewport_scale)
	return rect.grow(Tokens.LINE_WIDTH + 2).intersection(Rect2(Vector2.ZERO, size))

func _add_region(rect: Rect2) -> void:
	# Shade only small areas around people. Merge overlaps so alpha never doubles.
	var index := 0
	while index < regions.size():
		if rect.intersects(regions[index]):
			rect = rect.merge(regions[index])
			regions.remove_at(index)
			index = 0
		else: index += 1
	regions.append(rect)

func _draw() -> void:
	for rect in regions: draw_rect(rect, Color.WHITE)

func _sync_part(source: MeshInstance3D, layer: int, wanted: Dictionary) -> void:
	if not source.is_visible_in_tree() or source.mesh == null: return
	wanted[source] = true
	if not proxies.has(source):
		var proxy := MeshInstance3D.new()
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		silhouette.add_child(proxy)
		proxies[source] = proxy
	var proxy: MeshInstance3D = proxies[source]
	proxy.layers = layer
	proxy.material_override = white if layer & 1 else black
	proxy.mesh = source.mesh
	proxy.global_transform = source.global_transform
