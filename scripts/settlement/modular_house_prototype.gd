extends Node3D
## Disposable scene/controller; reusable geometry and rules are separate.
## Deliberately never instantiates settlement saves, economy, or construction jobs.
const Rules = preload("res://scripts/settlement/modular_house_rules.gd")
const View = preload("res://scripts/settlement/modular_house_view.gd")
const Draw = preload("res://scripts/settlement/rope_visuals.gd")
const P = preload("res://scripts/game_palette.gd")
const Services = preload("res://scripts/settlement/modular_house_services.gd")
const DayCycle = preload("res://scripts/settlement/day_cycle.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
var rig = preload("res://scripts/settlement/camera_rig.gd").new()
var structure := Node3D.new()
var smoke := Node3D.new()
var upper := true
var overhang := 1.0
var exterior_flue := true
var section := 0
var variant := 0
var elapsed := 0.0
var records: Array[Dictionary] = []
var state: Dictionary = {}
var buttons: Dictionary = {}
var hover := Label.new()
var services = Services.new()
var service_view := Node3D.new()
var powered_nodes: Array = []
var environment := WorldEnvironment.new()
var sun := DirectionalLight3D.new()
var moon := DirectionalLight3D.new()
var sky_floor: MeshInstance3D
var phase := 0.48
var time_mode := 0
var animate := true
var exemplars := View.Exemplars.record(0)
var detailed := true
const SUPPLY_BOX := AABB(Vector3(-0.45, 0, 1.85), Vector3(0.9, 0.7, 0.6))
const SOCKET_BOX := AABB(Vector3(1.55, 0.35, 1.06), Vector3(0.4, 0.5, 0.22))

func _ready() -> void:
	DisplayServer.window_set_title("... Town · Connected rooms prototype")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = P.MORNING_SKY
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = P.SAND_SURFACE
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	sun.rotation_degrees = Vector3(-48, -35, 0); sun.light_energy = 1.1; sun.shadow_enabled = true; add_child(sun)
	moon.rotation_degrees = Vector3(-40, 35, 0); moon.light_color = P.NIGHT_LIGHT; moon.shadow_enabled = true; add_child(moon)
	sky_floor = Draw.box(self, Vector3(200, 0.1, 200), Vector3(0, -0.65, 0), P.MORNING_SKY)
	# Low faceted sandstone base avoids confusing the fixture with another room.
	var mesh := CylinderMesh.new(); mesh.top_radius = 7.5; mesh.bottom_radius = 7.9; mesh.height = 0.55; mesh.radial_segments = 7
	var base := MeshInstance3D.new(); base.mesh = mesh; base.material_override = Draw.material(P.LIMESTONE_SIDE); base.position.y = -0.3; add_child(base)
	add_child(structure); add_child(smoke); add_child(service_view)
	add_child(rig); rig.setup(); home_camera()
	_ui(); rebuild()

func home_camera() -> void:
	rig.focus = Vector3(0, 1.8, 0); rig.yaw = -0.6; rig.pitch = 0.55; rig.zoom = 15.0; rig.update_camera()

func _ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var panel := PanelContainer.new(); layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12 * Tokens.POINT; panel.offset_right = -12 * Tokens.POINT; panel.offset_top = 12 * Tokens.POINT
	var style := StyleBoxFlat.new(); style.bg_color = P.SAND_SURFACE
	style.content_margin_left = Tokens.PANEL_PADDING_X; style.content_margin_right = Tokens.PANEL_PADDING_X
	style.content_margin_top = Tokens.PANEL_PADDING_Y; style.content_margin_bottom = Tokens.PANEL_PADDING_Y
	panel.add_theme_stylebox_override("panel", style)
	var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 8 * Tokens.GAP_UNIT); panel.add_child(row)
	for key in ["section", "upper", "overhang", "flue", "variant", "time", "upgrade", "reset"]:
		var button := Button.new(); button.add_theme_font_size_override("font_size", Tokens.UI_FONT_SIZE)
		button.add_theme_color_override("font_color", P.HOME_DOORWAY)
		button.add_theme_color_override("font_hover_color", P.HOME_DOORWAY)
		button.add_theme_color_override("font_pressed_color", P.HOME_DOORWAY)
		button.custom_minimum_size.y = Tokens.GAME_TOOLBAR_BUTTON_SIZE
		for appearance in ["normal", "hover", "pressed", "focus"]:
			var background := StyleBoxFlat.new(); background.bg_color = P.PEACH_SHADOW if appearance in ["hover", "pressed"] else P.SAND_SURFACE
			background.content_margin_left = 8 * Tokens.POINT; background.content_margin_right = 8 * Tokens.POINT
			if appearance == "focus": background.set_border_width_all(int(Tokens.LINE_WIDTH)); background.border_color = Tokens.SELECTION_COLOR
			button.add_theme_stylebox_override(appearance, background)
		button.pressed.connect(_action.bind(key)); row.add_child(button); buttons[key] = button
	buttons.section.tooltip_text = "Reveal the lower or upper rooms"
	buttons.upper.tooltip_text = "Remove or restore the upper room"
	buttons.overhang.tooltip_text = "Extend the upper room; supports adapt automatically"
	buttons.flue.tooltip_text = "Compare a straight flue with a route around the upper room"
	buttons.variant.tooltip_text = "Another roof and window arrangement, using the same materials"
	buttons.time.tooltip_text = "Preview daylight, night, or the moving sun"
	buttons.upgrade.tooltip_text = "Collect metal from the supply beside the entrance"
	buttons.reset.tooltip_text = "Restore this example and camera"
	hover.add_theme_font_size_override("font_size", Tokens.UI_FONT_SIZE); hover.add_theme_color_override("font_color", P.HOME_DOORWAY)
	hover.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(hover); hover.hide()

func _action(key: String) -> void:
	match key:
		"section": section = (section + 1) % (3 if upper else 2)
		"upper": upper = not upper; section = mini(section, 1) if not upper else section
		"overhang": overhang = 2.0 if overhang == 1.0 else 1.0
		"flue": exterior_flue = not exterior_flue
		"variant": variant += 1; exemplars = View.Exemplars.record(variant)
		"time": time_mode = (time_mode + 1) % 3
		"upgrade":
			if not services.upgrade(): return
		"reset": upper = true; overhang = 1.0; exterior_flue = true; section = 0; variant = 0; exemplars = View.Exemplars.record(0); services = Services.new(); time_mode = 0; phase = 0.48; home_camera()
	rebuild()

func rebuild() -> void:
	records = Rules.layout(variant, upper, true)
	state = View.build(structure, records, section, variant, exterior_flue, services.tier, exemplars, detailed)
	buttons.section.text = ["Exterior", "Inside · lower", "Inside · upper"][section]
	buttons.upper.text = "Upper room · on" if upper else "Upper room · off"
	buttons.overhang.text = "Overhang · %d m" % int(overhang); buttons.overhang.hide()
	buttons.flue.text = "Flue · blocked" if state.blocked else ("Flue · exterior" if exterior_flue and upper else "Flue · straight")
	if services.tier == 0: buttons.flue.text = "Brick chimney"
	buttons.flue.disabled = services.tier == 0
	buttons.variant.text = "Generate"; buttons.reset.text = "Reset"
	buttons.time.text = ["Sun · moving", "Day", "Night"][time_mode]
	buttons.upgrade.visible = true
	buttons.upgrade.disabled = not services.can_upgrade()
	buttons.upgrade.text = "Metal stove" if services.tier > 0 else "Upgrade · 6 metal"
	buttons.upgrade.tooltip_text = "%d / 6 metal" % services.metal
	powered_nodes = structure.find_children("*", "OmniLight3D", true, false)
	for node in structure.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("powered_glow"): powered_nodes.append(node)
	_draw_services(); _lighting(0)
	for child in smoke.get_children(): child.free()
	if not state.blocked:
		for i in 8:
			var puff := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius = 0.1; mesh.height = 0.16; mesh.radial_segments = 8; mesh.rings = 4
			puff.mesh = mesh; var mat := Draw.material(P.CLOUD); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color.a = 0.32
			puff.material_override = mat; puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; smoke.add_child(puff)
	_hover()

func _process(delta: float) -> void:
	rig.advance(delta); elapsed += delta
	var next_detail: bool = get_viewport().get_visible_rect().size.y / rig.zoom >= 40
	if next_detail != detailed: detailed = next_detail; rebuild()
	View.Exemplars.detail(structure, get_viewport().get_visible_rect().size.y / rig.zoom)
	_lighting(delta if animate else 0)
	for i in smoke.get_child_count():
		var age := fmod(elapsed * 0.45 + i / 8.0, 1.0)
		var puff := smoke.get_child(i) as MeshInstance3D
		puff.position = state.outlet + Vector3(age * 0.4, 0.08 + age * 1.1, sin(age * 3) * 0.06)
		puff.scale = Vector3.ONE * (0.55 + age * 1.4)
		puff.material_override.albedo_color.a = (1 - age) * 0.34

func _unhandled_input(event: InputEvent) -> void:
	rig.handle(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hit := _service_hit()
		_activate_service(hit)
	if event is InputEventMouseMotion: _hover()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: section = 0; rebuild()

func _hover() -> void:
	hover.hide()
	if get_viewport().gui_get_hovered_control() != null: return
	var service := _service_hit()
	if not service.is_empty():
		hover.text = "Metal · +3" if service == "supply" else ("Disconnect power" if services.connected else "Connect power")
		hover.position = get_viewport().get_mouse_position() + Vector2(16, 20); hover.show(); return
	if section == 1: return
	var mouse := get_viewport().get_mouse_position()
	var origin: Vector3 = rig.camera.project_ray_origin(mouse)
	var direction: Vector3 = rig.camera.project_ray_normal(mouse)
	var point = Plane(Vector3.UP, 2).intersects_ray(origin, direction)
	if point == null: return
	# Do not identify a terrace through a room that occludes it.
	for record in records:
		if record.origin.y == 2 and Rules.bounds(record).intersects_segment(origin, point): return
	for tile in Rules.terrace_tiles(records):
		if absf(point.x - tile.x) <= 0.5 and absf(point.z - tile.z) <= 0.5:
			hover.text = "Open terrace · %d m²" % Rules.terrace_tiles(records).size()
			hover.position = mouse + Vector2(16, 20) * Tokens.POINT
			hover.position.x = minf(hover.position.x, get_viewport().get_visible_rect().size.x - 280)
			hover.show(); return

func _lighting(delta: float) -> void:
	services.advance(delta)
	if time_mode == 0: phase = fposmod(phase + delta / 150.0, 1)
	var shown_phase := phase if time_mode == 0 else (0.25 if time_mode == 1 else 0.7)
	DayCycle.apply(sun, environment.environment, shown_phase * DayCycle.Settings.SIMULATION_DAY_SECONDS)
	moon.light_energy = 0.35 * (1.0 - DayCycle.daylight_at(shown_phase * DayCycle.Settings.SIMULATION_DAY_SECONDS))
	sky_floor.material_override.albedo_color = environment.environment.background_color
	View.set_power(powered_nodes, services.brightness())
	if service_view.has_node("Charge"):
		var charge_light := service_view.get_node("Charge") as MeshInstance3D
		charge_light.material_override.albedo_color = P.SUN if services.brightness() > 0 else P.TOOL_METAL
		charge_light.scale.x = 1.0 if services.connected else maxf(0.06, services.charge / Services.INITIAL_CHARGE)

func _draw_services() -> void:
	for child in service_view.get_children(): child.free()
	if services.supply > 0:
		Draw.box(service_view, Vector3(0.9, 0.12, 0.6), Vector3(0, 0.06, 2.15), View.Wood.WOOD[0])
		for i in services.supply:
			Draw.box(service_view, Vector3(0.64, 0.065, 0.13), Vector3(0, 0.16 + (i / 3) * 0.08, 1.98 + (i % 3) * 0.17), P.TOOL_METAL)
	# A fixture power source; the visible cable is the connection state.
	Draw.box(service_view, Vector3(0.38, 0.2, 0.4), Vector3(3.6, 0.1, 2), P.TOOL_METAL)
	Draw.box(service_view, Vector3(0.24, 0.35, 0.12), Vector3(1.75, 0.6, 1.13), P.TOOL_METAL)
	var indicator := Draw.box(service_view, Vector3(0.17, 0.06, 0.025), Vector3(1.75, 0.67, 1.205), P.SUN); indicator.name = "Charge"
	if services.connected:
		var points := [Vector3(3.6, 0.4, 2.32), Vector3(3.6, 0.12, 2.5), Vector3(1.75, 0.12, 2.5), Vector3(1.75, 0.12, 1.3), Vector3(1.75, 0.56, 1.205)]
		for i in range(1, points.size()): Draw.beam(service_view, points[i - 1], points[i], 0.025, P.TOOL_METAL)

func _activate_service(hit: String) -> void:
	if hit == "supply": services.collect(); rebuild()
	elif hit == "socket": services.connected = not services.connected; _draw_services(); _lighting(0)

func _service_hit() -> String:
	return _service_at(get_viewport().get_mouse_position())

func _service_at(mouse: Vector2) -> String:
	var origin: Vector3 = rig.camera.project_ray_origin(mouse)
	var end: Vector3 = origin + rig.camera.project_ray_normal(mouse) * 200
	for target in [{"id": "supply", "box": SUPPLY_BOX}, {"id": "socket", "box": SOCKET_BOX}]:
		if target.id == "supply" and services.supply == 0: continue
		if not target.box.intersects_segment(origin, end): continue
		var obscured := false
		for record in records:
			if section == 1 and record.id == 2: continue
			if Rules.bounds(record).intersects_segment(origin, target.box.get_center()): obscured = true
		if not obscured: return target.id
	return ""
