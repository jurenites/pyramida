extends Node3D
## Standalone experiment: Support construction excavates irregular solid terrain.
const Terrain = preload("res://scripts/terrain_sandbox/terrain.gd")
const Palette = preload("res://scripts/game_palette.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const Text = preload("res://scripts/ui_text_catalog.gd")
const SAVE_PATH := "user://support-groups-terrain-sandbox.json"
var terrain := Terrain.new()
var rig = preload("res://scripts/settlement/camera_rig.gd").new()
var preview = preload("res://scripts/terrain_sandbox/support_preview.gd").new()
var support_button := Button.new()
var ghost: Node3D
var undo_button := Button.new()
var toolbar := PanelContainer.new()
var proposal: Dictionary = {}
var capture_mode := false
var persistence_enabled := true
var last_build_frame := -10
var fine_placement := false
var plank_override := -1
var support_yaw := 0.0

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.MORNING_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.SAND_SURFACE
	env.ambient_light_energy = 0.4
	env.ssao_enabled = true
	env.ssao_radius = 3.0
	env.ssao_intensity = 1.2
	var environment := WorldEnvironment.new(); environment.environment = env; add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 0.4
	sun.directional_shadow_max_distance = 120
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(200, 200)
	ground.mesh = plane
	ground.material_override = Terrain.Landform.material(Palette.SAND_SURFACE.darkened(0.04))
	ground.position.y = -2.02
	add_child(ground)
	add_child(terrain)
	add_child(rig); rig.setup()
	rig.focus = Vector3(0, 4.6, 0)
	rig.yaw = 0.56; rig.pitch = 0.52; rig.zoom = 34
	rig.update_camera()
	_ui()
	ghost = Terrain.support_model()
	add_child(ghost)
	var ghost_material := StandardMaterial3D.new()
	ghost_material.albedo_color = Color(Tokens.SELECTION_COLOR,0.32)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh: MeshInstance3D in ghost.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = ghost_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.hide()
	if persistence_enabled and not capture_mode and FileAccess.file_exists(SAVE_PATH):
		terrain.restore(JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)))
	_update_actions()

func _ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	layer.add_child(preview); preview.camera = rig.camera
	layer.add_child(toolbar)
	toolbar.position = Vector2(16, 16) * Tokens.POINT
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SAND_SURFACE
	style.border_color = Palette.TIMBER_SIDE
	style.set_border_width_all(int(Tokens.LINE_WIDTH))
	style.content_margin_left = Tokens.PANEL_PADDING_X
	style.content_margin_right = Tokens.PANEL_PADDING_X
	style.content_margin_top = Tokens.PANEL_PADDING_Y
	style.content_margin_bottom = Tokens.PANEL_PADDING_Y
	toolbar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8 * Tokens.GAP_UNIT); toolbar.add_child(row)
	support_button.text = Text.text("terrain_sandbox_support_text")
	support_button.tooltip_text = Text.text("terrain_sandbox_support_hover_text")
	support_button.toggle_mode = true
	support_button.button_pressed = true
	support_button.toggled.connect(func(_on): proposal.clear())
	row.add_child(support_button)
	undo_button.text = Text.text("terrain_sandbox_undo_text")
	undo_button.pressed.connect(undo)
	row.add_child(undo_button)
	var reset := Button.new(); reset.text = Text.text("settlement_reset_text"); reset.pressed.connect(reset_terrain); row.add_child(reset)
	for button in row.get_children():
		button.add_theme_font_size_override("font_size", Tokens.UI_FONT_SIZE)
		button.custom_minimum_size.y = Tokens.GAME_TOOLBAR_BUTTON_SIZE

func _update_actions() -> void:
	undo_button.disabled = terrain.supports.is_empty()
	support_button.disabled = terrain.supports.size() >= Terrain.MAX_SUPPORTS

func save_sandbox() -> void:
	if capture_mode or not persistence_enabled: return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(terrain.snapshot()))

func undo() -> void:
	proposal.clear()
	terrain.undo(); _update_actions(); save_sandbox()

func reset_terrain() -> void:
	proposal.clear()
	terrain.clear(); _update_actions(); save_sandbox()

func _process(delta: float) -> void:
	if capture_mode: return
	rig.advance(delta)
	update_proposal(get_viewport().get_mouse_position())
	preview.active = not proposal.is_empty()
	ghost.visible = preview.active
	if ghost.visible:
		ghost.position = proposal.origin
		ghost.rotation.y=support_yaw
		ghost.get_node("Deck").rotation.y = proposal.turn * PI / 2
	if preview.active:
		preview.origin = proposal.origin
		preview.yaw=support_yaw
		preview.valid = proposal.valid
	preview.queue_redraw()

func update_proposal(mouse: Vector2) -> void:
	proposal.clear()
	if not support_button.button_pressed or support_button.disabled or rig.rotating or get_viewport().gui_get_hovered_control() != null: return
	if Engine.get_physics_frames() - last_build_frame < 2: return
	var start: Vector3 = rig.camera.project_ray_origin(mouse)
	var direction: Vector3 = rig.camera.project_ray_normal(mouse)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,start + direction * 200,3))
	if hit.is_empty(): return
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var origin: Vector3
	if hit.collider.has_meta("support_origin"):
		origin = hit.collider.get_meta("support_origin")
		if normal.y > 0.5: origin += Vector3.UP * Terrain.BAY
		elif normal.y < -0.5: origin -= Vector3.UP * Terrain.BAY
		elif absf(normal.x) > absf(normal.z): origin.x += signf(normal.x) * Terrain.BAY
		else: origin.z += signf(normal.z) * Terrain.BAY
	elif normal.y > 0.7:
		# Preserve the mountain's actual elevation; only buildings use a grid.
		origin = Vector3(snap_position(point.x),point.y,snap_position(point.z))
	else:
		# A cliff placement occupies the next building volume inside its exposed face.
		var inside := point - Vector3(normal.x,0,normal.z).normalized() * 0.48
		origin = Vector3(snap_position(inside.x),floorf(point.y / Terrain.BAY) * Terrain.BAY,snap_position(inside.z))
	if not fine_placement: origin = terrain.snap_to_existing(origin)
	proposal = {"origin":origin,"valid":terrain.can_place_support(origin,support_yaw),"turn":terrain.default_turn(origin) if plank_override < 0 else plank_override}

func snap_position(value: float) -> float:
	return snappedf(value,Terrain.FINE_STEP if fine_placement else Terrain.BAY)

func confirm_proposal() -> bool:
	if proposal.is_empty() or not proposal.valid: return false
	if not terrain.place_support(proposal.origin,proposal.turn,support_yaw): return false
	last_build_frame = Engine.get_physics_frames()
	proposal.clear(); _update_actions(); save_sandbox()
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		fine_placement = event.pressed

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: fine_placement = false

func _unhandled_input(event: InputEvent) -> void:
	if capture_mode: return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
			support_yaw=clampf(support_yaw+deg_to_rad(-2.0 if event.keycode==KEY_BRACKETLEFT else 2.0),-PI/12,PI/12)
		if event.keycode == KEY_R:
			plank_override = 1 - int(proposal.get("turn",0))
		if event.keycode == KEY_ESCAPE: support_button.button_pressed = false
		if event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed): undo()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		update_proposal(event.position)
		confirm_proposal()
		return
	var previous_pitch: float = rig.pitch
	var previous_zoom: float = rig.zoom
	rig.handle(event)
	# The sandbox can look horizontally into excavations and inspect them close up.
	if event is InputEventMouseMotion and rig.rotating:
		rig.pitch = clampf(previous_pitch + event.relative.y * 0.004, 0.08, 1.3)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: rig.zoom = maxf(3.0, previous_zoom - 1.2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: rig.zoom = minf(80.0, previous_zoom + 1.2)
	rig.update_camera()
