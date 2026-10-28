extends Button
const UI=preload("res://scripts/ui_visual_tokens.gd")
var direction:=1
var locked:=false
func _draw() -> void:
	var ink:=Color("7a8b8b") if disabled else Color("293b42")
	var center:=size*0.5
	var tip:=center+Vector2(0,-10*direction)*UI.POINT
	draw_line(center+Vector2(0,10*direction)*UI.POINT,tip,ink,UI.LINE_WIDTH,true)
	draw_polyline(PackedVector2Array([tip+Vector2(-8,8*direction)*UI.POINT,tip,tip+Vector2(8,8*direction)*UI.POINT]),ink,UI.LINE_WIDTH,true)
	if locked: draw_line(Vector2(12,size.y-6),Vector2(size.x-12,size.y-6),UI.SELECTION_COLOR,UI.LINE_WIDTH,true)
