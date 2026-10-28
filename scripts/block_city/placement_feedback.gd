extends RefCounted
const UI=preload("res://scripts/ui_visual_tokens.gd")
const BAD=Color("db735c")
const REASONS={"support":"No support below", "cantilever":"Overhang cannot carry another floor", "occupied":"Cell already occupied", "path":"Keep the access path clear", "stair_exit":"Keep the stair exit open", "cable":"Cable crosses this cell", "bounds":"Outside the building boundary", "height":"Beyond the floor limit", "protected":"Hall or stair cannot be replaced"}
static func marker(game, issue: Dictionary) -> Vector2:
	return game.camera.unproject_position(Vector3(issue.cell)+Vector3(0.5,1.15,0.5))
static func hint(game, screen: Vector2) -> String:
	for issue in game.preview.get("issues",[]):
		if screen.distance_to(marker(game,issue))<18*UI.POINT: return REASONS.get(issue.kind,"Placement blocked")
	return ""
static func line(game, at: Vector2, a: Vector2, b: Vector2) -> void:
	game.overlay.draw_line(at+a*UI.POINT,at+b*UI.POINT,BAD,UI.LINE_WIDTH,true)
static func draw(game) -> void:
	for issue in game.preview.get("issues",[]):
		var at:=marker(game,issue)
		game.overlay.draw_circle(at,14*UI.POINT,game.PAPER)
		match issue.kind:
			"support","cantilever":
				# Broken column and an arrow to the exact missing/weak support cell.
				line(game,at,Vector2(-7,-8),Vector2(7,-8))
				line(game,at,Vector2(0,-7),Vector2(0,-2))
				line(game,at,Vector2(0,4),Vector2(0,9))
				line(game,at,Vector2(-7,9),Vector2(7,9))
				line(game,at,Vector2(-5,3),Vector2(5,-2))
				var start: Vector2=game.camera.unproject_position(Vector3(issue.cell)+Vector3(0.5,0.05,0.5))
				var below: Vector2=game.camera.unproject_position(Vector3(issue.related)+Vector3(0.5,0.5,0.5))
				game.overlay.draw_dashed_line(start,below,BAD,UI.LINE_WIDTH,5*UI.POINT,true)
				var corners:=PackedVector2Array()
				for p in [Vector3(0.1,0.05,0.1),Vector3(0.9,0.05,0.1),Vector3(0.9,0.05,0.9),Vector3(0.1,0.05,0.9),Vector3(0.1,0.05,0.1)]:
					corners.append(game.camera.unproject_position(Vector3(issue.related)+p))
				game.overlay.draw_polyline(corners,BAD,UI.LINE_WIDTH,true)
			"height","bounds":
				line(game,at,Vector2(-9,-7),Vector2(9,-7))
				line(game,at,Vector2(0,9),Vector2(0,-3))
				line(game,at,Vector2(0,-3),Vector2(-5,2))
				line(game,at,Vector2(0,-3),Vector2(5,2))
			"cable":
				game.overlay.draw_polyline(PackedVector2Array([at+Vector2(-9,-7),at+Vector2(-3,5),at+Vector2(3,5),at+Vector2(9,-7)]),BAD,UI.LINE_WIDTH,true)
				line(game,at,Vector2(-7,9),Vector2(7,-9))
			"stair_exit":
				game.overlay.draw_polyline(PackedVector2Array([at+Vector2(-9,8),at+Vector2(-3,8),at+Vector2(-3,1),at+Vector2(3,1),at+Vector2(3,-6),at+Vector2(9,-6)]),BAD,UI.LINE_WIDTH,true)
				line(game,at,Vector2(-8,-9),Vector2(8,9))
			_:
				game.overlay.draw_rect(Rect2(at-Vector2(9,9),Vector2(18,18)),BAD,false,UI.LINE_WIDTH)
				line(game,at,Vector2(-6,-6),Vector2(6,6))
				line(game,at,Vector2(-6,6),Vector2(6,-6))
