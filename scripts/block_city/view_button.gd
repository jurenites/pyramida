extends Button
const UI = preload("res://scripts/ui_visual_tokens.gd")
var mode := 0
func _draw() -> void:
	var color := Color("293b42")
	var left := Vector2(11,24)
	var top := Vector2(24,17)
	var right := Vector2(37,24)
	var front := Vector2(24,31)
	var polygon := PackedVector2Array([left,top,right,front,left])
	if mode==0:
		draw_colored_polygon(polygon,Color("d4b078"))
		draw_polyline(polygon,color,UI.LINE_WIDTH,true)
	else:
		draw_polyline(PackedVector2Array([left,top,right]),color,UI.LINE_WIDTH,true)
		if mode==1:
			draw_line(Vector2(13,13),Vector2(24,7),color,UI.LINE_WIDTH,true)
			draw_line(Vector2(24,7),Vector2(35,13),color,UI.LINE_WIDTH,true)
	var drop := 4.0 if mode==2 else 9.0
	for point in [left,front,right]: draw_line(point,point+Vector2(0,drop),color,UI.LINE_WIDTH,true)
	draw_polyline(PackedVector2Array([left+Vector2(0,drop),front+Vector2(0,drop),right+Vector2(0,drop)]),color,UI.LINE_WIDTH,true)
