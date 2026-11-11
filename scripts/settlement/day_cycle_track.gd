extends Control
## The two halves show daylight and night; the marker follows saved cycle time.
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const DAY := Color("c8995c")
const NIGHT := Color("71869b")
const INK := Color("64452f")
var phase := 0.0

func _ready() -> void:
	custom_minimum_size.y = 8 * Tokens.POINT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_phase(value: float) -> void:
	phase = fposmod(value, 1.0)
	queue_redraw()

func _draw() -> void:
	var inset := 2 * Tokens.POINT
	var left := inset
	var right := size.x - inset
	var middle := (left + right) * 0.5
	var y := size.y * 0.5
	draw_line(Vector2(left, y), Vector2(middle - inset, y), DAY, Tokens.LINE_WIDTH)
	draw_line(Vector2(middle + inset, y), Vector2(right, y), NIGHT, Tokens.LINE_WIDTH)
	var x := lerpf(left, right, phase)
	draw_line(Vector2(x, 0), Vector2(x, size.y), INK, Tokens.LINE_WIDTH)
