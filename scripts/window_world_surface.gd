extends SubViewportContainer
## Keep rendered world bounds and pointer coordinates on the same rectangle.
const DisplayScaling = preload("res://scripts/display_scale.gd")
var fill_window := false

func _ready() -> void:
	add_to_group(DisplayScaling.SURFACE_GROUP)

func surface_matches() -> bool:
	if fill_window and (not position.is_zero_approx() or not size.is_equal_approx(get_viewport_rect().size)):
		return false
	if stretch:
		var expected := Vector2i(size / stretch_shrink).max(Vector2i(2, 2))
		for child in get_children():
			if child is SubViewport and child.size != expected:
				return false
	return true

func synchronize_surface() -> void:
	if fill_window:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not surface_matches():
		# SubViewport.size cannot be assigned while its container owns stretch.
		# Ask the container to recalculate using its final laid-out bounds.
		notification(NOTIFICATION_RESIZED)
	queue_redraw()

func viewport_point(window_point: Vector2, world: SubViewport) -> Vector2:
	var local := get_global_transform_with_canvas().affine_inverse() * window_point
	return local * Vector2(world.size) / size.max(Vector2.ONE)
