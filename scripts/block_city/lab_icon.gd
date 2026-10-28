extends Button
const UI=preload("res://scripts/ui_visual_tokens.gd")
var symbol := "home"
var ink := Color("293b42")
func line(a: Vector2,b: Vector2) -> void: draw_line(a,b,ink,UI.LINE_WIDTH,true)
func _draw() -> void:
	var c:=size*0.5
	match symbol:
		"home":
			draw_polyline(PackedVector2Array([c+Vector2(-15,0),c+Vector2(0,-14),c+Vector2(15,0)]),ink,UI.LINE_WIDTH,true)
			draw_rect(Rect2(c+Vector2(-10,0),Vector2(20,14)),ink,false,UI.LINE_WIDTH)
			line(c+Vector2(0,14),c+Vector2(0,5))
		"garden":
			line(c+Vector2(0,13),c+Vector2(0,-2)); draw_circle(c+Vector2(-5,-5),8,ink,false,UI.LINE_WIDTH,true); draw_circle(c+Vector2(6,-9),8,ink,false,UI.LINE_WIDTH,true)
		"bath":
			draw_rect(Rect2(c+Vector2(-10,-14),Vector2(20,9)),ink,false,UI.LINE_WIDTH)
			draw_arc(c+Vector2(0,-1),10,0,PI,16,ink,UI.LINE_WIDTH,true); line(c+Vector2(-10,-1),c+Vector2(10,-1)); line(c+Vector2(0,9),c+Vector2(0,15))
		"month":
			draw_circle(c,10,ink,false,UI.LINE_WIDTH,true)
			for i in 8:
				var d:=Vector2.from_angle(i*TAU/8); line(c+d*15,c+d*19)
		"section":
			for y in [-10,10]:
				draw_polyline(PackedVector2Array([c+Vector2(-16,y),c+Vector2(0,y-6),c+Vector2(16,y),c+Vector2(0,y+6),c+Vector2(-16,y)]),ink,UI.LINE_WIDTH,true)
		"coin":
			draw_circle(c,13,ink,false,UI.LINE_WIDTH,true); line(c+Vector2(0,-7),c+Vector2(0,7))
		"people":
			draw_circle(c+Vector2(0,-8),5,ink,false,UI.LINE_WIDTH,true)
			draw_arc(c+Vector2(0,13),11,PI,TAU,16,ink,UI.LINE_WIDTH,true)
		"lift":
			draw_rect(Rect2(c+Vector2(-13,-16),Vector2(26,32)),ink,false,UI.LINE_WIDTH)
			draw_polyline(PackedVector2Array([c+Vector2(-6,-4),c+Vector2(0,-10),c+Vector2(6,-4)]),ink,UI.LINE_WIDTH,true)
			draw_polyline(PackedVector2Array([c+Vector2(-6,4),c+Vector2(0,10),c+Vector2(6,4)]),ink,UI.LINE_WIDTH,true)
		"capacity":
			draw_polyline(PackedVector2Array([c+Vector2(-15,10),c+Vector2(-4,10),c+Vector2(-4,-10),c+Vector2(15,-10)]),ink,UI.LINE_WIDTH,true)
			draw_polyline(PackedVector2Array([c+Vector2(9,-16),c+Vector2(15,-10),c+Vector2(9,-4)]),ink,UI.LINE_WIDTH,true)
		"remove":
			line(c+Vector2(-10,-10),c+Vector2(10,10)); line(c+Vector2(10,-10),c+Vector2(-10,10))
