class_name SpeechIconLibrary
extends RefCounted

const Palette = preload("res://scripts/game_palette.gd")

const DESIRE_ASSETS := {
 "water": "res://assets/ui/desires/water.svg",
 "heat": "res://assets/ui/desires/heat.svg",
 "door_blocked": "res://assets/ui/desires/door_blocked.svg",
 "electricity": "res://assets/ui/desires/electricity.svg",
}

static var _textures: Dictionary = {}


static func texture(icon_id: String) -> Texture2D:
	if _textures.has(icon_id):
		return _textures[icon_id] as Texture2D
	if DESIRE_ASSETS.has(icon_id):
		_textures[icon_id] = load(DESIRE_ASSETS[icon_id])
		return _textures[icon_id] as Texture2D
	var icon_image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	icon_image.fill(Color.TRANSPARENT)
	match icon_id:
		"log":
			_draw_log(icon_image)
		"plank":
			_draw_plank(icon_image)
		"food":
			_draw_food(icon_image)
		"water":
			_draw_water(icon_image)
		"construction":
			_draw_construction(icon_image)
		"air":
			_draw_air(icon_image)
		"heat":
			_draw_heat(icon_image)
		"connection":
			_draw_connection(icon_image)
		_:
			_draw_footsteps(icon_image)
	var icon_texture := ImageTexture.create_from_image(icon_image)
	_textures[icon_id] = icon_texture
	return icon_texture


static func _draw_log(icon_image: Image) -> void:
	_draw_thick_line(icon_image, Vector2(5, 16), Vector2(18, 8), 4.0, Palette.ROOF_LOG)
	_draw_disc(icon_image, Vector2(18, 8), 4.0, Palette.WOODEN_ROOF)
	_draw_disc(icon_image, Vector2(18, 8), 1.5, Palette.ROOF_LOG)


static func _draw_plank(icon_image: Image) -> void:
	_draw_thick_line(icon_image, Vector2(5, 16), Vector2(19, 8), 3.0, Palette.WOODEN_ROOF)
	_draw_disc(icon_image, Vector2(5, 16), 3.0, Palette.WOODEN_ROOF)
	_draw_disc(icon_image, Vector2(19, 8), 3.0, Palette.WOODEN_ROOF)
	_draw_thick_line(icon_image, Vector2(7, 14), Vector2(17, 9), 0.8, Palette.ROOF_LOG)


static func _draw_food(icon_image: Image) -> void:
	_draw_disc(icon_image, Vector2(9, 14), 4.0, Palette.WOODEN_ROOF)
	_draw_disc(icon_image, Vector2(15, 14), 4.0, Palette.WOODEN_ROOF)
	_draw_disc(icon_image, Vector2(12, 9), 4.0, Palette.WOODEN_ROOF)


static func _draw_water(icon_image: Image) -> void:
	_draw_disc(icon_image, Vector2(12, 15), 6.0, Color("4B91B8"))
	_draw_thick_line(icon_image, Vector2(9, 13), Vector2(12, 5), 3.0, Color("4B91B8"))
	_draw_thick_line(icon_image, Vector2(15, 13), Vector2(12, 5), 3.0, Color("4B91B8"))


static func _draw_construction(icon_image: Image) -> void:
	# Tools are the deliberate sharp-edge exception in the visual language.
	_draw_thick_line(icon_image, Vector2(7, 19), Vector2(15, 7), 2.5, Palette.ROOF_LOG)
	_draw_thick_line(icon_image, Vector2(10, 7), Vector2(19, 11), 3.0, Palette.TOOL_METAL)


static func _draw_footsteps(icon_image: Image) -> void:
	_draw_disc(icon_image, Vector2(8, 15), 3.0, Palette.CITIZEN_SKIN)
	_draw_disc(icon_image, Vector2(15, 9), 3.0, Palette.CITIZEN_SKIN)
	_draw_disc(icon_image, Vector2(6, 10), 1.5, Palette.CITIZEN_SKIN)
	_draw_disc(icon_image, Vector2(17, 14), 1.5, Palette.CITIZEN_SKIN)


static func _draw_air(icon_image: Image) -> void:
	for line_y in [7, 12, 17]:
		_draw_thick_line(icon_image, Vector2(4, line_y), Vector2(18, line_y), 1.5, Color("7AAFC4"))
		_draw_disc(icon_image, Vector2(18, line_y - 1), 2.0, Color("7AAFC4"))


static func _draw_heat(icon_image: Image) -> void:
	_draw_disc(icon_image, Vector2(12, 12), 5.0, Palette.SUN)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_draw_thick_line(icon_image, Vector2(12, 12) + direction * 7.0, Vector2(12, 12) + direction * 9.0, 1.5, Palette.SUN)


static func _draw_connection(icon_image: Image) -> void:
	_draw_disc(icon_image, Vector2(7, 12), 4.0, Palette.TOOL_METAL)
	_draw_disc(icon_image, Vector2(17, 12), 4.0, Palette.TOOL_METAL)
	_draw_thick_line(icon_image, Vector2(9, 12), Vector2(15, 12), 2.0, Palette.WOODEN_ROOF)


static func _draw_thick_line(
	icon_image: Image,
	line_start: Vector2,
	line_end: Vector2,
	line_radius: float,
	colour: Color
) -> void:
	var distance := line_start.distance_to(line_end)
	var step_count := maxi(1, ceili(distance * 2.0))
	for step_index in range(step_count + 1):
		var progress := float(step_index) / float(step_count)
		_draw_disc(icon_image, line_start.lerp(line_end, progress), line_radius, colour)


static func _draw_disc(icon_image: Image, centre: Vector2, radius: float, colour: Color) -> void:
	var minimum_x := maxi(0, floori(centre.x - radius))
	var maximum_x := mini(icon_image.get_width() - 1, ceili(centre.x + radius))
	var minimum_y := maxi(0, floori(centre.y - radius))
	var maximum_y := mini(icon_image.get_height() - 1, ceili(centre.y + radius))
	var radius_squared := radius * radius
	for pixel_x in range(minimum_x, maximum_x + 1):
		for pixel_y in range(minimum_y, maximum_y + 1):
			var pixel_centre := Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5)
			if pixel_centre.distance_squared_to(centre) <= radius_squared:
				icon_image.set_pixel(pixel_x, pixel_y, colour)
