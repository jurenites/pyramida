extends SceneTree
const Deck=preload("res://scripts/settlement/walkable_planks.gd")
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: "+message)
func _initialize() -> void:
	for seed_ in range(20):
		for rect in [Rect2(-1,-1,2,2),Rect2(-0.3,-0.8,0.23,1.7),Rect2(0,0,0.91,0.31)]:
			var boards:=Deck.boards(rect,seed_)
			check(boards==Deck.boards(rect,seed_),"Board cuts and relief regenerate identically")
			var area:=0.0
			for i in boards.size():
				var board: Dictionary=boards[i]
				check(rect.grow(0.00001).encloses(board.rect),"Planks stop exactly at the fenced boundary")
				check(board.rect.size[board.axis]<=Deck.Timber.BOARD.x+0.00001 and board.rect.size[1-board.axis]<=Deck.Timber.BOARD.z+0.00001,"Cut lengths never stretch the canonical stock")
				check(Rect2(board.patch,Vector2.ONE).grow(0.00001).encloses(board.rect),"Each board stays within an exact metre-square patch")
				area+=board.rect.get_area()
				for j in range(i): check(board.rect.intersection(boards[j].rect).get_area()<0.000001,"Fitted plank bases do not overlap")
			check(is_equal_approx(area,rect.get_area()),"Closed plank bases leave no gaps through the walking surface")
			var mesh:=Deck.mesh(rect,seed_,Rect2())
			var box:=mesh.get_aabb()
			check(is_equal_approx(box.position.x,rect.position.x) and is_equal_approx(box.end.x,rect.end.x) and is_equal_approx(box.position.z,rect.position.y) and is_equal_approx(box.end.z,rect.end.y),"Rendered deck and fence have the same extents")
	var hole:=Rect2(-0.2,-1,0.4,2)
	for board in Deck.boards(Rect2(-1,-1,2,2),7,hole): check(board.rect.intersection(hole).get_area()<0.000001,"Shaft opening stays open")
	print("PASS: closed fitted plank coverage, stock sizes, boundaries and stable relief" if failures==0 else "FAIL: walkable plank geometry")
	quit(int(failures>0))
