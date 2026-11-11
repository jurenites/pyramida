extends RefCounted
## Solid, faceted miniatures. Log is the long stock reference; berries stay small.
const Palette = preload("res://scripts/settlement/resource_palette.gd")
const Tokens = preload("res://scripts/ui_visual_tokens.gd")

static func polygon(canvas: Control, points: Array, colour: Color) -> void:
	var vertices := PackedVector2Array()
	for point: Vector2 in points: vertices.append(point * Tokens.GAME_ICON_SCALE)
	canvas.draw_colored_polygon(vertices, colour)

static func disc(canvas: Control, at: Vector2, radius: float, colour: Color) -> void:
	canvas.draw_circle(at * Tokens.GAME_ICON_SCALE, radius * Tokens.GAME_ICON_SCALE, colour, true, -1, true)

static func draw_icon(canvas: Control, kind: String) -> bool:
	if not Palette.COLOURS.has(kind): return false
	var c := Palette.colour(kind)
	var dark := c.darkened(0.22)
	var light := c.lightened(0.18)
	match kind:
		"log":
			polygon(canvas, [Vector2(4,22),Vector2(24,6),Vector2(31,12),Vector2(11,28)], c)
			polygon(canvas, [Vector2(11,24),Vector2(31,9),Vector2(31,14),Vector2(11,29)], dark)
			disc(canvas, Vector2(7,25), 5, Palette.colour("plank"))
			disc(canvas, Vector2(7,25), 2, c)
		"plank", "block", "brick":
			var points: Array = [Vector2(3,23),Vector2(26,6),Vector2(31,10),Vector2(8,27)]
			var depth := 3.0
			if kind == "block":
				points = [Vector2(5,17),Vector2(19,10),Vector2(29,16),Vector2(15,23)]
				depth = 5.0
			elif kind == "brick":
				points = [Vector2(9,19),Vector2(22,12),Vector2(28,16),Vector2(15,23)]
				depth = 5.0
			polygon(canvas, [points[0],points[3],points[2],points[2]+Vector2(0,depth),points[3]+Vector2(0,depth),points[0]+Vector2(0,depth)], dark)
			polygon(canvas, points, light)
			if kind == "plank": polygon(canvas,[Vector2(10,22),Vector2(26,10),Vector2(27,11),Vector2(11,23)], c)
		"grain":
			for x in [8,12,16,20,24]:
				polygon(canvas,[Vector2(x-2,26),Vector2(x-3,8+(x%3)),Vector2(x+2,5+(x%4)),Vector2(x+3,26)], c if x%3 else light)
			polygon(canvas,[Vector2(6,17),Vector2(27,17),Vector2(27,21),Vector2(6,21)], Palette.colour("rope"))
		"water":
			polygon(canvas,[Vector2(17,4),Vector2(25,17),Vector2(26,24),Vector2(21,29),Vector2(13,29),Vector2(8,24),Vector2(9,17)], c)
			polygon(canvas,[Vector2(17,10),Vector2(13,22),Vector2(10,23),Vector2(11,18)], light)
		"stone":
			polygon(canvas,[Vector2(5,23),Vector2(8,14),Vector2(15,10),Vector2(25,13),Vector2(29,24),Vector2(18,28)], c)
			polygon(canvas,[Vector2(8,14),Vector2(15,10),Vector2(25,13),Vector2(18,19)], light)
			polygon(canvas,[Vector2(18,19),Vector2(25,13),Vector2(29,24),Vector2(18,28)], dark)
		"clay":
			polygon(canvas,[Vector2(5,24),Vector2(9,19),Vector2(12,16),Vector2(21,17),Vector2(25,21),Vector2(29,24),Vector2(23,28),Vector2(10,28)], c)
			polygon(canvas,[Vector2(9,19),Vector2(12,16),Vector2(21,17),Vector2(23,22),Vector2(14,24)], light)
		"ore":
			polygon(canvas,[Vector2(8,25),Vector2(12,8),Vector2(18,12),Vector2(23,7),Vector2(28,25),Vector2(18,29)], c)
			polygon(canvas,[Vector2(12,8),Vector2(18,12),Vector2(16,26),Vector2(8,25)], dark)
			polygon(canvas,[Vector2(20,17),Vector2(23,12),Vector2(25,23),Vector2(20,26)], Palette.Palette.TOOL_METAL)
		"flour":
			polygon(canvas,[Vector2(12,8),Vector2(22,8),Vector2(20,13),Vector2(26,22),Vector2(24,28),Vector2(10,28),Vector2(8,22),Vector2(14,13)], c)
			polygon(canvas,[Vector2(20,16),Vector2(26,22),Vector2(24,28),Vector2(18,28),Vector2(22,23)], dark)
			polygon(canvas,[Vector2(12,12),Vector2(22,12),Vector2(22,16),Vector2(12,16)], Palette.colour("rope"))
		"pottery":
			polygon(canvas,[Vector2(12,7),Vector2(22,7),Vector2(21,13),Vector2(27,19),Vector2(24,29),Vector2(10,29),Vector2(7,19),Vector2(13,13)], c)
			polygon(canvas,[Vector2(12,7),Vector2(22,7),Vector2(21,10),Vector2(13,10)], dark)
			polygon(canvas,[Vector2(11,18),Vector2(14,15),Vector2(13,25),Vector2(10,24)], light)
		"imbrex":
			polygon(canvas,[Vector2(5,25),Vector2(7,18),Vector2(20,7),Vector2(25,8),Vector2(29,15),Vector2(17,28),Vector2(14,20),Vector2(10,19),Vector2(8,26)], c)
			polygon(canvas,[Vector2(10,19),Vector2(23,8),Vector2(25,8),Vector2(14,20),Vector2(17,28),Vector2(14,28)], light)
		"rope":
			canvas.draw_arc(Vector2(16,18)*Tokens.GAME_ICON_SCALE,9*Tokens.GAME_ICON_SCALE,0.0,TAU,32,c,Tokens.LINE_WIDTH,true)
			canvas.draw_arc(Vector2(16,18)*Tokens.GAME_ICON_SCALE,4*Tokens.GAME_ICON_SCALE,0.0,TAU,24,light,Tokens.LINE_WIDTH,true)
			polygon(canvas,[Vector2(23,22),Vector2(28,26),Vector2(31,26),Vector2(31,30),Vector2(26,30),Vector2(21,25)], c)
		"food":
			polygon(canvas,[Vector2(7,25),Vector2(7,20),Vector2(11,16),Vector2(23,14),Vector2(28,18),Vector2(28,24),Vector2(23,28),Vector2(11,29)], c)
			polygon(canvas,[Vector2(11,17),Vector2(14,16),Vector2(18,21),Vector2(15,22)], light)
			polygon(canvas,[Vector2(19,15),Vector2(22,15),Vector2(25,19),Vector2(22,20)], light)
		"berry":
			for at in [Vector2(13,21),Vector2(21,21),Vector2(17,25)]:
				disc(canvas, at, 3, c)
			polygon(canvas,[Vector2(17,18),Vector2(17,14),Vector2(23,15),Vector2(20,18)], Palette.Palette.BUSHES)
	return true
