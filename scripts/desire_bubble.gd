extends RefCounted
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const Icons = preload("res://scripts/speech_icon_library.gd")
const ICON_SIZE := 32 * Tokens.POINT
const PADDING := 8 * Tokens.PADDING_UNIT
const BOX_SIZE := Vector2(ICON_SIZE + PADDING * 2, ICON_SIZE + PADDING * 2)

static func draw_on(canvas: Control, anchor: Vector2, icon: String) -> void:
	var margin := 4 * Tokens.GAP_UNIT
	var corner := anchor - Vector2(BOX_SIZE.x * 0.5, BOX_SIZE.y + 12 * Tokens.GAP_UNIT)
	corner = corner.clamp(Vector2.ONE * margin, (canvas.size - BOX_SIZE - Vector2.ONE * margin).max(Vector2.ONE * margin))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff1cf")
	style.set_corner_radius_all(8 * Tokens.POINT)
	canvas.draw_style_box(style, Rect2(corner, BOX_SIZE))
	var tail := Vector2(clampf(anchor.x, corner.x + 8, corner.x + BOX_SIZE.x - 8), corner.y + BOX_SIZE.y)
	canvas.draw_colored_polygon(PackedVector2Array([tail + Vector2(-6, -1), tail + Vector2(6, -1), tail + Vector2(0, 8)]), style.bg_color)
	canvas.draw_texture_rect(Icons.texture(icon), Rect2(corner + Vector2.ONE * PADDING, Vector2.ONE * ICON_SIZE), false)
