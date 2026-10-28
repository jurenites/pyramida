extends Button
const UI=preload("res://scripts/ui_visual_tokens.gd")
func _draw() -> void:
	var center:=size*0.5
	var arm:=Vector2(9,9)*UI.POINT
	var ink:=Color("293b42")
	draw_line(center-arm,center+arm,ink,UI.LINE_WIDTH,true)
	draw_line(center+Vector2(-arm.x,arm.y),center+Vector2(arm.x,-arm.y),ink,UI.LINE_WIDTH,true)
