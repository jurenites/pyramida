extends Control
## A rotating cycle arc surrounds the current sun/moon, beside the day number.
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const INK := Color("64452f")
const SYMBOL_SCALE := 0.75 * Tokens.POINT * Tokens.GAME_ICON_SCALE
var phase := 0.0
var is_night := false

func _ready() -> void:
	custom_minimum_size = Vector2(32, 32) * Tokens.POINT * Tokens.GAME_ICON_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_phase(value: float) -> void:
	phase = fposmod(value, 1.0)
	is_night = phase >= 0.5
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var angle := phase * TAU - PI * 0.5
	draw_arc(center, 13 * Tokens.POINT * Tokens.GAME_ICON_SCALE, angle, angle + PI * 1.5, 48, INK, Tokens.LINE_WIDTH, true)
	if is_night:
		# A true crescent silhouette; no background-coloured masking disc.
		var crescent := PackedVector2Array()
		for index in 25:
			var theta := -PI * 0.5 - PI * index / 24.0
			crescent.append(center + Vector2(cos(theta), sin(theta)) * 10 * SYMBOL_SCALE)
		for index in 25:
			var theta := PI * 0.5 + PI * index / 24.0
			crescent.append(center + Vector2(4 * cos(theta), 10 * sin(theta)) * SYMBOL_SCALE)
		draw_colored_polygon(crescent, INK)
	else:
		draw_circle(center, 4 * SYMBOL_SCALE, INK)
		for index in 8:
			var ray := Vector2.from_angle(angle + index * TAU / 8)
			draw_line(center + ray * 8 * SYMBOL_SCALE, center + ray * 11 * SYMBOL_SCALE, INK, Tokens.LINE_WIDTH, true)
