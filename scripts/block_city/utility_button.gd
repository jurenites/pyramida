extends Button
const UI=preload("res://scripts/ui_visual_tokens.gd")
var kind:="power"
var active:=false
func _draw() -> void:
	var c:=size*0.5
	var ink:=UI.SELECTION_COLOR if active else Color("293b42")
	if kind=="power":
		draw_polyline(PackedVector2Array([c+Vector2(3,-14),c+Vector2(-8,1),c+Vector2(4,1),c+Vector2(-3,14)]),ink,UI.LINE_WIDTH,true)
	elif kind=="pipe":
		draw_polyline(PackedVector2Array([c+Vector2(-13,8),c+Vector2(-3,8),c+Vector2(-3,-8),c+Vector2(13,-8)]),ink,UI.LINE_WIDTH,true)
		for x in [-13,13]: draw_line(c+Vector2(x,3 if x<0 else -13),c+Vector2(x,13 if x<0 else -3),ink,UI.LINE_WIDTH,true)
	else:
		draw_rect(Rect2(c-Vector2(13,11),Vector2(26,22)),ink,false,UI.LINE_WIDTH)
		for y in [-5,5]: draw_line(c+Vector2(-8,y),c+Vector2(8,y),ink,UI.LINE_WIDTH,true)
