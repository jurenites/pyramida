extends SceneTree
const Land=preload("res://scripts/block_city/land.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_process(false)
	var plots:=Land.plots(game.model.config)
	# Top-down targeting removes occlusion ambiguity from the hover test.
	game.camera.position=Vector3(1,30,1.5); game.camera.look_at(Vector3(1,0,1.5),Vector3.FORWARD); game.camera.size=24
	for id in [3,0,8]:
		var plot: Rect2i=plots[id]
		var center:=Vector2(plot.position)+Vector2(plot.size)*0.5
		var screen: Vector2=game.camera.unproject_position(Vector3(center.x,0,center.y))
		game.update_land_hover(screen)
		check(game.hovered_plot==id and game.purchase_button.visible,"Hover offers Purchase on the unowned plot")
		game.update_land_hover(game.purchase_button.position+game.purchase_button.size*0.5)
		check(game.hovered_plot==id,"Purchase stays stable while moving onto its button")
		game.set_holding(true)
		check(game.hovered_plot==-1 and not game.purchase_button.visible,"Picking up a room immediately clears Purchase and its plot outline")
		game.update_land_hover(screen)
		check(game.hovered_plot==-1 and not game.purchase_button.visible,"Held rooms cannot hover a purchase plot")
		game.hovered_plot=id
		game.purchase_button.pressed.emit()
		check(not game.model.owned_plots.has(id),"A stale Purchase action cannot buy land while holding a room")
		game.hovered_plot=-1
		game.set_holding(false)
		game.update_land_hover(screen)
		check(game.purchase_button.visible,"Empty hand restores Purchase on hover")
		game.purchase_button.pressed.emit()
		check(game.model.owned_plots.has(id),"Purchase control unlocks its plot")
		check(not game.neighbours.any(func(n):return n.plot_id==id),"Purchase removes only that plot's grey building")
		game.select_debug_shape("cube")
		game.forced_floor=0
		game.position_anchor(game.camera.unproject_position(Vector3(plot.position.x+0.5,0,plot.position.y+0.5)))
		check(game.preview.ok and game.anchor==plot.position,"Cursor placement works on purchased land")
		game.drop()
		check(game.model.rooms.size()>0 and game.model.rooms.back().cells[0][0]==plot.position.x,"Click placement builds on purchased plot")
		game.set_holding(false)
		game.undo(); game.undo()
		check(not game.model.owned_plots.has(id) and game.neighbours.any(func(n):return n.plot_id==id),"Undo construction then purchase restores neighbor")
		game.camera.position=Vector3(1,30,1.5); game.camera.look_at(Vector3(1,0,1.5),Vector3.FORWARD); game.camera.size=24
	game.update_land_hover(game.camera.unproject_position(Vector3(1.5,0,1.5)))
	check(not game.purchase_button.visible,"Owned starting land does not offer Purchase")
	game.update_land_hover(game.camera.unproject_position(Vector3(1.5,0,-2)))
	check(not game.purchase_button.visible,"Road does not offer Purchase")
	game.toggle_menu(); game.update_land_hover(Vector2.ZERO)
	check(not game.purchase_button.visible,"Purchase hides in menu")
	print("Block City land interaction: ",failures," failures")
	game.free(); quit(1 if failures else 0)
