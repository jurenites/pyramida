extends Node
## UI points are logical pixels (UIVisualTokens.POINT). Only display density changes their scale;
## resizing the window changes the available layout area, never the UI size.

signal resize_settled

const SETTLE_MSEC := 200
const SURFACE_GROUP := &"window_resize_surfaces"
var _last_size := Vector2i.ZERO
var _last_change_msec := 0
var _pending := false
var _refresh_pending := false
var _verifying := false
var _synchronizing := false
var _repair_attempts := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	var window := get_window()
	var initial_size := window.size
	_update_display_scale()
	if window.mode == Window.MODE_WINDOWED:
		window.size = Vector2i(Vector2(initial_size) * window.content_scale_factor)
	window.dpi_changed.connect(_update_display_scale)
	window.size_changed.connect(_request_resize)
	window.focus_entered.connect(_request_resize)
	_request_resize()

func _request_resize() -> void:
	if _synchronizing:
		return
	_last_change_msec = Time.get_ticks_msec()
	_pending = true
	_refresh_pending = true
	_verifying = false
	_repair_attempts = 0

func _native_size() -> Vector2i:
	var window := get_window()
	if DisplayServer.get_name() == "headless" or window.is_embedded():
		return window.size
	return DisplayServer.window_get_size(window.get_window_id())

func _process(_delta: float) -> void:
	var window := get_window()
	if DisplayServer.get_name() != "headless" and window.mode == Window.MODE_MINIMIZED:
		return
	var native_size := _native_size()
	if native_size.x <= 0 or native_size.y <= 0:
		return
	# Read the backend as well as resize signals: a final native resize event
	# can arrive after the scene's layout has already run.
	if native_size != _last_size:
		_last_size = native_size
		_request_resize()
	if not _pending:
		return
	var quiet := Time.get_ticks_msec() - _last_change_msec >= SETTLE_MSEC
	if _verifying:
		if _layout_matches(native_size):
			_pending = false
			_verifying = false
			resize_settled.emit()
			return
		_repair_attempts += 1
		if _repair_attempts >= 3:
			_pending = false
			_verifying = false
			push_warning("Window layout did not settle after resizing.")
			return
	if _refresh_pending or quiet:
		_synchronizing = true
		if window.size != native_size:
			window.size = native_size
		# Reapplying the same density rebuilds Godot's screen attachment and
		# input transform together, without changing the user's window size.
		if quiet or not _root_matches(native_size):
			window.content_scale_factor = window.content_scale_factor
		_synchronizing = false
		_refresh_pending = false
		# Coalesce resize bursts and let Control/Container layout finish first.
		_sync_surfaces.call_deferred()
		_verifying = quiet

func _root_matches(native_size: Vector2i) -> bool:
	var window := get_window()
	var logical_size := Vector2(native_size) / window.content_scale_factor
	var transform := window.get_final_transform()
	return (window.size == native_size
		and window.get_visible_rect().size.is_equal_approx(logical_size)
		and transform.origin.is_zero_approx()
		and (transform * logical_size).is_equal_approx(Vector2(native_size)))

func _layout_matches(native_size: Vector2i) -> bool:
	if not _root_matches(native_size):
		return false
	for surface in get_tree().get_nodes_in_group(SURFACE_GROUP):
		if not surface.surface_matches():
			return false
	return true

func _sync_surfaces() -> void:
	get_tree().call_group(SURFACE_GROUP, &"synchronize_surface")

func _update_display_scale() -> void:
	var density := 1.0
	if DisplayServer.get_name() != "headless":
		density = DisplayServer.screen_get_scale(get_window().current_screen)
	apply_display_scale(density)

func apply_display_scale(density: float) -> void:
	var window := get_window()
	window.content_scale_factor = maxf(1.0, density)
	# Godot's native window bounds use physical pixels, unlike Control layouts.
	var logical_minimum := Vector2(
		ProjectSettings.get_setting("display/window/size/min_width", 0),
		ProjectSettings.get_setting("display/window/size/min_height", 0))
	window.min_size = Vector2i(logical_minimum * window.content_scale_factor)
	_request_resize()
