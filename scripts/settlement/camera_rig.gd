extends Node3D
const Catalog = preload("res://data/settlement/catalog.gd")
var hotkeys = preload("res://scripts/settlement/hotkeys.gd").new()
var camera: Camera3D
var focus := Vector3(-1, 1.0, 0)
var yaw := -0.65
var pitch := 0.68
var zoom := 23.0
var rotating := false
var world_limit := float(Catalog.WORLD_LIMIT) * preload("res://scripts/settlement/navigation.gd").CELL_SIZE

func setup() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 240.0
	add_child(camera)
	get_viewport().size_changed.connect(update_camera)
	update_camera()

func update_camera() -> void:
	camera.size = zoom
	camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 85.0
	# Derive orientation from yaw/pitch only, so panning cannot perturb it.
	camera.basis = Basis.looking_at(-Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)))
	# Keep the logical focus continuous; only the rendered camera is quantized.
	# KEEP_HEIGHT gives one world-space pixel per zoom / viewport height.
	var height := get_viewport().get_visible_rect().size.y
	if height > 0:
		var texel := zoom / height
		var screen_position := camera.basis.inverse() * camera.position
		screen_position.x = snappedf(screen_position.x, texel)
		screen_position.y = snappedf(screen_position.y, texel)
		camera.position = camera.basis * screen_position

func reset_view() -> void:
	yaw = -0.65
	pitch = 0.68
	zoom = 23.0
	rotating = false
	update_camera()

func handle(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			rotating = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(10.0, zoom - 1.2)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(110.0, zoom + 1.2)
	if event is InputEventMouseMotion and rotating:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.004, 0.40, 1.15)
	update_camera()

func advance(delta: float) -> void:
	var movement := Vector2.ZERO
	if hotkeys.held("pan_forward"): movement.y -= 1
	if hotkeys.held("pan_back"): movement.y += 1
	if hotkeys.held("pan_left"): movement.x -= 1
	if hotkeys.held("pan_right"): movement.x += 1
	if movement != Vector2.ZERO:
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var back := Vector3(sin(yaw), 0, cos(yaw))
		# Pan on the current world-space height, independent of terrain below.
		focus += (right * movement.x + back * movement.y) * delta * 7.0
		focus.x = clampf(focus.x, -Catalog.WORLD_RADIUS * preload("res://scripts/settlement/navigation.gd").CELL_SIZE, Catalog.WORLD_RADIUS * preload("res://scripts/settlement/navigation.gd").CELL_SIZE)
		focus.z = clampf(focus.z, -Catalog.WORLD_RADIUS * preload("res://scripts/settlement/navigation.gd").CELL_SIZE, Catalog.WORLD_RADIUS * preload("res://scripts/settlement/navigation.gd").CELL_SIZE)
		update_camera()
