extends RefCounted
## Axis rings rotate the selected scene element around its mesh centre.
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
var _gizmo: WeakRef
var gizmo: RefCounted:
	get: return _gizmo.get_ref()
var controls: VBoxContainer
var angle_spin: SpinBox
var axis := Vector3.UP
var apply_button: Button
var axis_buttons: Array[Button] = []
const DRAG_STEP := 15.0
const RING_HIT_RADIUS := 12.0 * Tokens.POINT

func _init(owner: RefCounted) -> void:
	_gizmo = weakref(owner)

func create_controls(parent: Control) -> void:
	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 4 * Tokens.GAP_UNIT)
	parent.add_child(controls)
	var presets := HBoxContainer.new()
	controls.add_child(presets)
	for index in 3:
		var direction := Vector3.ZERO
		direction[index] = 1
		var button: Button = gizmo.editor.host._button(presets, Tokens.BLUEPRINT_AXIS_LABELS[index], choose_axis.bind(direction))
		button.toggle_mode = true
		button.tooltip_text = "Rotate around %s · drag in 15° steps" % Tokens.BLUEPRINT_AXIS_LABELS[index]
		axis_buttons.append(button)
	gizmo.editor.host._button(presets, "Flip", func(): choose_axis(-axis)).tooltip_text = "Reverse the rotation axis"
	angle_spin = gizmo.editor.host._spin(controls, "Angle °", -180, 180, 15, func(_value): gizmo.editor.host.overlay.queue_redraw(), 0.1)
	apply_button = gizmo.editor.host._button(controls, "Rotate", apply_angle)
	apply_button.tooltip_text = "Apply the angle around the selected axis"
	choose_axis(axis)

func active() -> bool:
	return gizmo.active() and gizmo.mode == "angle"

func choose_axis(value: Vector3) -> void:
	if not value.is_finite() or value.length_squared() < 0.000001: return
	axis = value.normalized()
	for index in axis_buttons.size(): axis_buttons[index].set_pressed_no_signal(is_equal_approx(absf(axis[index]), 1.0))
	gizmo.editor.host.overlay.queue_redraw()

func sphere() -> Dictionary:
	if not active(): return {}
	if gizmo.dragging and gizmo.drag_handle.get("kind") == "rotation": return gizmo.drag_handle.sphere
	var camera: Camera3D = gizmo.editor.host.camera
	var part: Dictionary = gizmo.editor.selection_part()
	var bounds: AABB = gizmo.local_bounds(part)
	var pose := Kit.transform(part)
	var centre := pose * bounds.get_center()
	if camera.is_position_behind(centre): return {}
	var screen := camera.unproject_position(centre)
	var radius := 72.0 * Tokens.POINT
	for corner in 8:
		var point := pose * bounds.get_endpoint(corner)
		if not camera.is_position_behind(point): radius = maxf(radius, camera.unproject_position(point).distance_to(screen) + 16 * Tokens.POINT)
	var limit := maxf(72 * Tokens.POINT, minf(gizmo.editor.host.overlay.size.x, gizmo.editor.host.overlay.size.y) * 0.42)
	return {"centre": screen, "radius": minf(radius, limit), "basis": camera.global_basis.orthonormalized()}

static func tangent_for(normal: Vector3) -> Vector3:
	return normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()

func drag_handle(at: Vector2) -> Dictionary:
	var data := sphere()
	if data.is_empty(): return {}
	var direction := axis
	var nearest := RING_HIT_RADIUS
	var found := false
	# Hit the visible ring itself, including its flattened/back-facing half.
	for normal in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		var tangent := tangent_for(normal)
		var previous := project(tangent, data)
		for index in range(1, 97):
			var point := project(Basis(normal, TAU * index / 96.0) * tangent, data)
			var distance := at.distance_to(Geometry2D.get_closest_point_to_segment(at, previous, point))
			if distance < nearest:
				nearest = distance
				direction = normal * (-1 if axis.dot(normal) < 0 else 1)
				found = true
			previous = point
	if not found and at.distance_to(data.centre) > data.radius: return {}
	var tangent := tangent_for(direction)
	var u := project(tangent, data) - (data.centre as Vector2)
	var v := project(direction.cross(tangent), data) - (data.centre as Vector2)
	var handle := {"kind": "rotation", "axis": direction, "previous_axis": axis,
		"previous_angle": angle_spin.value, "sphere": data, "u": u, "v": v,
		"last_angle": 0.0, "total_angle": 0.0}
	handle.last_angle = pointer_angle(at, handle)
	return handle

static func pointer_angle(at: Vector2, handle: Dictionary) -> float:
	var delta: Vector2 = at - handle.sphere.centre
	var u: Vector2 = handle.u
	var v: Vector2 = handle.v
	var determinant := u.cross(v)
	if absf(determinant) < float(handle.sphere.radius) ** 2 * 0.05:
		# An edge-on ring has no invertible screen ellipse. A linear drag
		# remains usable even when looking exactly down another world axis.
		return (delta.x - delta.y) / float(handle.sphere.radius)
	return atan2(u.cross(delta) / determinant, delta.cross(v) / determinant)

func drag_part(part: Dictionary, handle: Dictionary, at: Vector2) -> Dictionary:
	var angle := pointer_angle(at, handle)
	var delta := angle - float(handle.last_angle)
	if absf((handle.u as Vector2).cross(handle.v)) >= float(handle.sphere.radius) ** 2 * 0.05:
		delta = wrapf(delta, -PI, PI)
	handle.total_angle += delta
	handle.last_angle = angle
	var degrees := snappedf(rad_to_deg(handle.total_angle), DRAG_STEP)
	angle_spin.set_value_no_signal(wrapf(degrees, -180, 180))
	return rotated(part, handle.axis, wrapf(degrees, -180, 180), gizmo.local_bounds(part).get_center())

static func rotated(part: Dictionary, direction: Vector3, degrees: float, local_centre: Vector3) -> Dictionary:
	if not direction.is_finite() or direction.length_squared() < 0.000001 or not is_finite(degrees): return part.duplicate(true)
	var result := part.duplicate(true)
	if is_zero_approx(degrees): return result
	var centre := Kit.transform(part) * local_centre
	var turn := Basis(direction.normalized(), deg_to_rad(degrees))
	# Compose outside the original imported basis and nonuniform local scale.
	result.rotation = (turn * Basis.from_euler(part.rotation)).get_euler()
	result.at = centre - Kit.transform(result).basis * local_centre
	if not (result.at as Vector3).is_finite(): return part.duplicate(true)
	for index in 3:
		if absf(result.at[index]) > 32: return part.duplicate(true)
	return result

func apply_angle() -> void:
	if not active(): return
	gizmo.end_drag()
	var part: Dictionary = gizmo.editor.selection_part()
	var result := rotated(part, axis, angle_spin.value, gizmo.local_bounds(part).get_center())
	gizmo.editor.commit_selection(result)

static func project(direction: Vector3, data: Dictionary) -> Vector2:
	var local: Vector3 = data.basis.transposed() * direction
	return data.centre + Vector2(local.x, -local.y) * float(data.radius)

func draw(canvas: Control) -> void:
	var data := sphere()
	if data.is_empty(): return
	var colour := Color("548b8b")
	canvas.draw_circle(data.centre, data.radius, Color(colour, 0.06))
	canvas.draw_arc(data.centre, data.radius, 0, TAU, 96, Color(colour, 0.5), Tokens.LINE_WIDTH, true)
	for index in 3:
		var normal := Vector3.ZERO
		normal[index] = 1
		draw_ring(canvas, data, normal, Color(gizmo.COLOURS[index], 0.65))
	draw_ring(canvas, data, axis, Color(Tokens.SELECTION_COLOR, 0.7))
	var front := project(axis, data)
	var back := project(-axis, data)
	canvas.draw_line(back, front, Tokens.SELECTION_COLOR, Tokens.LINE_WIDTH, true)
	canvas.draw_circle(data.centre, 5 * Tokens.POINT, Tokens.SELECTION_COLOR)
	canvas.draw_circle(back, 7 * Tokens.POINT, Tokens.SELECTION_COLOR, false, Tokens.LINE_WIDTH, true)
	canvas.draw_circle(front, 7 * Tokens.POINT, Tokens.SELECTION_COLOR)
	# The arc follows the actual rotation while dragging.
	var tangent := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var arc := PackedVector2Array()
	for index in 33:
		arc.append(project(Basis(axis, deg_to_rad(angle_spin.value) * index / 32.0) * tangent, data))
	if not is_zero_approx(angle_spin.value):
		canvas.draw_polyline(arc, Tokens.SELECTION_COLOR, Tokens.LINE_WIDTH, true)
		var direction: Vector2 = (arc[-1] - arc[-2]).normalized()
		var cross := Vector2(-direction.y, direction.x)
		canvas.draw_colored_polygon(PackedVector2Array([arc[-1], arc[-1] - direction * 12 * Tokens.POINT + cross * 6 * Tokens.POINT, arc[-1] - direction * 12 * Tokens.POINT - cross * 6 * Tokens.POINT]), Tokens.SELECTION_COLOR)

func draw_ring(canvas: Control, data: Dictionary, normal: Vector3, colour: Color) -> void:
	var tangent := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
	var points := PackedVector2Array()
	for index in 65: points.append(project(Basis(normal, TAU * index / 64.0) * tangent, data))
	canvas.draw_polyline(points, colour, Tokens.LINE_WIDTH, true)
