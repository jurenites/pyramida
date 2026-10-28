class_name CompassWidget
extends RefCounted

const Palette = preload("res://scripts/game_palette.gd")
const UIText = preload("res://scripts/ui_text_catalog.gd")
const PixelUITheme = preload("res://scripts/pixel_ui.gd")
const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")
const COMPASS_OUTLINE_SHADER := preload("res://shaders/compass_outline.gdshader")

const BODY_RADIUS := 0.9
const FACE_RADIUS := 0.74
const BODY_HEIGHT := 0.54
const FACE_HEIGHT := 0.42
const SIDE_COUNT := 32
const CAMERA_DISTANCE := 4.0
const CAMERA_SIZE := 2.35
const BUTTON_OFFSET := -Vector2.ONE * (VisualTokens.COMPASS_DIAMETER_PIXELS + 12 * VisualTokens.POINT)

var _viewport: SubViewport
var _camera: Camera3D
var _hover_outline: MeshInstance3D


func mount(host: Node, parent: Node, reset_camera: Callable) -> void:
	_viewport = SubViewport.new()
	_viewport.name = "CompassViewport"
	_viewport.size = Vector2i(
		VisualTokens.COMPASS_DIAMETER_PIXELS,
		VisualTokens.COMPASS_DIAMETER_PIXELS
	)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(_viewport)

	var compass_root := Node3D.new()
	compass_root.name = "GroundParallelCompass"
	_viewport.add_child(compass_root)
	_hover_outline = _create_hover_silhouette()
	compass_root.add_child(_hover_outline)
	compass_root.add_child(_create_side_wall(
		BODY_RADIUS, 0.0, BODY_HEIGHT, SIDE_COUNT, Palette.TOOL_METAL.darkened(0.28)
	))
	compass_root.add_child(_create_ring(
		BODY_RADIUS, FACE_RADIUS, SIDE_COUNT, Palette.TOOL_METAL, BODY_HEIGHT
	))
	compass_root.add_child(_create_disc(
		FACE_RADIUS, SIDE_COUNT, Palette.FOG_AND_SHADOW.lightened(0.28), FACE_HEIGHT
	))
	compass_root.add_child(_create_triangle(true))
	compass_root.add_child(_create_triangle(false))
	_create_camera()
	_create_button(parent, reset_camera)


func update_camera(viewing_direction: Vector3) -> void:
	if not is_instance_valid(_camera):
		return
	_camera.position = viewing_direction.normalized() * CAMERA_DISTANCE
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _create_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "CompassCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_SIZE
	_camera.near = 0.05
	_camera.far = 20.0
	_camera.current = true
	_viewport.add_child(_camera)


func _create_button(parent: Node, reset_camera: Callable) -> void:
	var compass_button := TextureButton.new()
	compass_button.name = "ResetCameraCompass"
	compass_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	compass_button.position = BUTTON_OFFSET
	compass_button.size = Vector2(
		VisualTokens.COMPASS_DIAMETER_PIXELS,
		VisualTokens.COMPASS_DIAMETER_PIXELS
	)
	compass_button.ignore_texture_size = true
	compass_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	compass_button.texture_normal = _viewport.get_texture()
	compass_button.tooltip_text = UIText.text(UIText.COMPASS_BUTTON_TOOLTIP_TEXT)
	compass_button.theme = PixelUITheme.tooltip_theme()
	compass_button.pressed.connect(reset_camera)
	compass_button.mouse_entered.connect(_set_hover.bind(true))
	compass_button.mouse_exited.connect(_set_hover.bind(false))
	compass_button.focus_entered.connect(_set_hover.bind(true))
	compass_button.focus_exited.connect(_set_hover.bind(false))
	parent.add_child(compass_button)


func _create_hover_silhouette() -> MeshInstance3D:
	var outline_mesh := CylinderMesh.new()
	outline_mesh.top_radius = BODY_RADIUS
	outline_mesh.bottom_radius = BODY_RADIUS
	outline_mesh.height = BODY_HEIGHT
	outline_mesh.radial_segments = SIDE_COUNT
	outline_mesh.rings = 1
	var outline := MeshInstance3D.new()
	outline.name = "ViewDependentCompassHoverOutline"
	outline.mesh = outline_mesh
	outline.position.y = BODY_HEIGHT * 0.5
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var outline_material := ShaderMaterial.new()
	outline_material.shader = COMPASS_OUTLINE_SHADER
	outline_material.set_shader_parameter("outline_pixels", VisualTokens.OUTLINE_PIXELS)
	outline_material.set_shader_parameter(
		"viewport_size",
		Vector2(VisualTokens.COMPASS_DIAMETER_PIXELS, VisualTokens.COMPASS_DIAMETER_PIXELS)
	)
	outline.material_override = outline_material
	outline.visible = false
	return outline


func _create_disc(radius: float, side_count: int, colour: Color, height: float) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side_index in side_count:
		var angle_a := TAU * float(side_index) / float(side_count)
		var angle_b := TAU * float(side_index + 1) / float(side_count)
		surface_tool.add_vertex(Vector3.ZERO + Vector3.UP * height)
		surface_tool.add_vertex(Vector3(cos(angle_b) * radius, height, sin(angle_b) * radius))
		surface_tool.add_vertex(Vector3(cos(angle_a) * radius, height, sin(angle_a) * radius))
	var instance := MeshInstance3D.new()
	instance.mesh = surface_tool.commit()
	instance.material_override = _material(colour)
	return instance


func _create_ring(
	outer_radius: float,
	inner_radius: float,
	side_count: int,
	colour: Color,
	height: float
) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side_index in side_count:
		var angle_a := TAU * float(side_index) / float(side_count)
		var angle_b := TAU * float(side_index + 1) / float(side_count)
		var outer_a := Vector3(cos(angle_a) * outer_radius, height, sin(angle_a) * outer_radius)
		var outer_b := Vector3(cos(angle_b) * outer_radius, height, sin(angle_b) * outer_radius)
		var inner_a := Vector3(cos(angle_a) * inner_radius, height, sin(angle_a) * inner_radius)
		var inner_b := Vector3(cos(angle_b) * inner_radius, height, sin(angle_b) * inner_radius)
		surface_tool.add_vertex(outer_a)
		surface_tool.add_vertex(outer_b)
		surface_tool.add_vertex(inner_b)
		surface_tool.add_vertex(outer_a)
		surface_tool.add_vertex(inner_b)
		surface_tool.add_vertex(inner_a)
	var instance := MeshInstance3D.new()
	instance.mesh = surface_tool.commit()
	instance.material_override = _material(colour)
	return instance


func _create_side_wall(
	radius: float,
	bottom_height: float,
	top_height: float,
	side_count: int,
	colour: Color
) -> MeshInstance3D:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side_index in side_count:
		var angle_a := TAU * float(side_index) / float(side_count)
		var angle_b := TAU * float(side_index + 1) / float(side_count)
		var bottom_a := Vector3(cos(angle_a) * radius, bottom_height, sin(angle_a) * radius)
		var bottom_b := Vector3(cos(angle_b) * radius, bottom_height, sin(angle_b) * radius)
		var top_a := Vector3(cos(angle_a) * radius, top_height, sin(angle_a) * radius)
		var top_b := Vector3(cos(angle_b) * radius, top_height, sin(angle_b) * radius)
		surface_tool.add_vertex(bottom_a)
		surface_tool.add_vertex(top_b)
		surface_tool.add_vertex(bottom_b)
		surface_tool.add_vertex(bottom_a)
		surface_tool.add_vertex(top_a)
		surface_tool.add_vertex(top_b)
	var instance := MeshInstance3D.new()
	instance.mesh = surface_tool.commit()
	instance.material_override = _material(colour)
	return instance


func _create_triangle(points_north: bool) -> MeshInstance3D:
	var direction := -1.0 if points_north else 1.0
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.add_vertex(Vector3(-0.16, 0.435, direction * 0.03))
	surface_tool.add_vertex(Vector3(0.0, 0.435, direction * 0.62))
	surface_tool.add_vertex(Vector3(0.16, 0.435, direction * 0.03))
	var instance := MeshInstance3D.new()
	instance.name = "NorthNeedle" if points_north else "SouthNeedle"
	instance.mesh = surface_tool.commit()
	instance.material_override = _material(
		Palette.WOMAN_CLOTHING if points_north else Palette.TOOL_METAL
	)
	return instance


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _set_hover(is_hovered: bool) -> void:
	if is_instance_valid(_hover_outline):
		_hover_outline.visible = is_hovered
