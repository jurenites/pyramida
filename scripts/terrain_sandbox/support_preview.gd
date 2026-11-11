extends Control
const Tokens = preload("res://scripts/ui_visual_tokens.gd")
const Palette = preload("res://scripts/game_palette.gd")
var camera: Camera3D
var yaw := 0.0
var origin := Vector3.ZERO
var active := false
var valid := true
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _draw() -> void:
	if not active or camera == null: return
	var colour := Tokens.SELECTION_COLOR if valid else Palette.PLACEMENT_BLOCKED
	var rings: Array = []
	for height in [0.0,1.0]:
		var points: Array[Vector2] = []
		for p: Vector2 in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
			points.append(camera.unproject_position(origin + Basis(Vector3.UP,yaw)*Vector3(p.x,height,p.y)))
		rings.append(points)
	for index in 4:
		var next := (index+1)%4
		for ring in rings: draw_line(ring[index],ring[next],colour,Tokens.LINE_WIDTH,true)
		draw_line(rings[0][index],rings[1][index],colour,Tokens.LINE_WIDTH,true)
