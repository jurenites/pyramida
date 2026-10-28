extends RefCounted
## Shared original day/night dial, driven by each simulation’s saved clock.
const Palette = preload("res://scripts/game_palette.gd")
const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")

static func mount(parent: Node) -> TextureRect:
	var wheel_container := Control.new()
	wheel_container.name = "DayNightWheelContainer"
	wheel_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wheel_container.position = Vector2(-21.5, 6.0)
	wheel_container.size = Vector2(43.0, 43.0)
	wheel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wheel_container)

	var wheel_image := Image.create(43, 43, false, Image.FORMAT_RGBA8)
	wheel_image.fill(Color.TRANSPARENT)
	for pixel_x in 43:
		for pixel_y in 43:
			var offset := Vector2(float(pixel_x) - 21.0, float(pixel_y) - 21.0)
			if offset.length() > 18.5:
				continue
			var wheel_colour := Palette.SUN if pixel_x < 21 else Palette.NIGHT_SKY
			if offset.length() >= 18.5 - VisualTokens.LINE_WIDTH:
				wheel_colour = Color.BLACK
			wheel_image.set_pixel(pixel_x, pixel_y, wheel_colour)
	var wheel := TextureRect.new()
	wheel.name = "RotatingDayNightWheel"
	wheel.texture = ImageTexture.create_from_image(wheel_image)
	wheel.size = Vector2(43.0, 43.0)
	wheel.pivot_offset = Vector2(21.5, 21.5)
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_container.add_child(wheel)

	var sun_marker := Panel.new()
	sun_marker.name = "FixedSunMarker"
	sun_marker.position = Vector2(16.0, -1.0)
	sun_marker.size = Vector2(10.0, 10.0)
	sun_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sun_style := StyleBoxFlat.new()
	sun_style.bg_color = Palette.SUN
	sun_style.border_color = Color.BLACK
	sun_style.set_border_width_all(int(VisualTokens.OUTLINE_PIXELS))
	sun_style.corner_radius_top_left = 5
	sun_style.corner_radius_top_right = 5
	sun_style.corner_radius_bottom_left = 5
	sun_style.corner_radius_bottom_right = 5
	sun_marker.add_theme_stylebox_override("panel", sun_style)
	wheel_container.add_child(sun_marker)

	return wheel
