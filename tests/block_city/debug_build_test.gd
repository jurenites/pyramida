extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func place(m,shape: String,x: int,z: int,yaw:=0) -> void:
	m.queue[0]={"shape":shape,"color":0}
	check(m.drop(x,z,yaw),"Fixture places "+shape)
func run() -> void:
	for yaw in 4:
		var m=Model.new()
		place(m,"bar",0,0,yaw)
		var plan: Dictionary=m.landing({"shape":"bar","color":0},0,0,yaw,false,1)
		check(plan.ok and plan.issues.is_empty(),"Aligned 1×3 room stacks normally in every rotation")
		var overlap: Dictionary=m.landing({"shape":"bar","color":0},0,0,yaw,false,0)
		check(not overlap.ok and overlap.cells.size()==3 and overlap.issues.size()==3,"Overlap retains the footprint and identifies all occupied cells")
		check(overlap.issues.all(func(issue):return issue.kind=="occupied"),"Overlap is distinguished from missing support")
	var m=Model.new()
	place(m,"bar",0,0)
	var partial: Dictionary=m.landing({"shape":"bar","color":0},0,0,1,false,1)
	check(not partial.ok and partial.issues.size()==1 and partial.issues[0].cell==Vector3i(2,1,0),"Only the far unsupported cube is blamed; supported and braced cubes stay valid")
	check(partial.issues[0].kind=="support" and partial.issues[0].related==Vector3i(2,0,0),"Missing support points to the exact empty space below")
	m=Model.new(); place(m,"cube",0,0); place(m,"room_domino",0,0,1)
	var cantilever: Dictionary=m.landing({"shape":"domino","color":0},0,0,1,false,2)
	check(not cantilever.ok and cantilever.issues.size()==1 and cantilever.issues[0].kind=="cantilever" and cantilever.issues[0].cell==Vector3i(1,2,0),"A stacked overhang identifies its weak support instead of blaming the whole room")
	m=Model.new(); place(m,"stairs",0,0)
	var cap: Dictionary=m.landing({"shape":"small_square","color":0},0,0,0,false,1)
	check(not cap.ok and cap.issues.size()==1 and cap.issues[0].kind=="stair_exit","Covered stair exit highlights only its shaft cell")
	var limit: Dictionary=m.landing({"shape":"bar","color":0},0,0,0,false,9)
	check(limit.issues.size()==3 and limit.issues.all(func(issue):return issue.kind=="height"),"Height limit retains the exact invalid footprint")
	var edge: Dictionary=m.landing({"shape":"bar","color":0},2,1,1,false,1)
	check(edge.issues.size()==1 and edge.issues[0].cell.x==4 and edge.issues[0].kind=="bounds","Boundary marker singles out the out-of-lot cell")

	var protected: Dictionary=m.landing({"shape":"cube","color":0},0,0,0,false,0,true)
	check(not protected.ok and protected.issues.size()==1 and protected.issues[0].kind=="protected","Hall cutting identifies the protected stair cell")
	var paths: Array=m.fit_issues([Vector3i(2,0,2)],{},{Vector3i(2,0,2):true},false)
	check(paths.size()==1 and paths[0].kind=="path","Access-path collision has its own local cause")
	var basement: Dictionary=m.landing({"shape":"cube","color":0},0,0,0,true,-3)
	check(not basement.ok and basement.issues[0].related==Vector3i(0,-2,0),"Basement support marker points upward to missing support")
	m=Model.new()
	for level in 3: place(m,"cube",2,2)
	check(m.connect_power(Vector3i(2,2,2),Vector3i.FORWARD),"Cable diagnostic fixture")
	var cable: Dictionary=m.landing({"shape":"cube","color":0},0,0,0,false,3)
	check(cable.issues.all(func(issue):return issue.kind!="cable"),"Existing cables never create a placement error marker")

	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_holding(true)
	for i in 4: await process_frame
	check(game.debug_palette.cards.size()==game.model.config.shapes.filter(func(shape):return not shape.get("palette_hidden",false)).size(),"Debug palette includes all visible shapes and hides the duplicate mirrored L")
	for id in game.debug_palette.cards:
		game.click_world(game.debug_palette.cards[id].get_global_rect().get_center())
		check(game.model.current().shape==id and game.holding and game.model.rooms.is_empty(),"Clicking a palette icon selects it without placing into the world")
	game.select_debug_shape("bar")
	game.anchor=Vector2i.ZERO; game.yaw=0; game.snap_y=-100; game.refresh_preview(); game.drop(); game.refresh()
	check(game.model.rooms.size()==1 and game.model.current().shape=="bar","Selected debug shape remains available for repeated placements")
	game.yaw=1; game.snap_y=1; game.refresh_preview()
	check(game.preview.issues.size()==1 and game.preview.issues[0].cell==Vector3i(2,1,0),"Runtime previews exact support failure before clicking")
	var before: Dictionary=game.model.snapshot()
	game.drop()
	check(game.note.text.is_empty() and game.model.snapshot()==before,"Rejected placement shows no corner error and changes no state")
	var badge: Vector2=game.Feedback.marker(game,game.preview.issues[0])
	game.update_issue_hint(badge)
	check(game.issue_hint.visible and game.issue_hint.text=="No support below","Hovering a cell marker explains the cause concisely")
	game.update_issue_hint(Vector2.ZERO)
	check(not game.issue_hint.visible,"Reason text disappears away from the problem marker")
	game.set_holding(false)
	check(game.preview.is_empty() and not game.issue_hint.visible,"Deselection clears placement diagnostics")
	game.toggle_menu()
	var selected: String=game.debug_shape
	game.select_debug_shape("stairs")
	check(game.debug_shape==selected,"Escape menu blocks palette selection")
	game.toggle_menu()
	root.min_size=Vector2i.ZERO
	for size in [Vector2i(800,600),Vector2i(1600,900)]:
		root.size=size
		for i in 3: await process_frame
		var rect: Rect2=game.get_viewport().get_visible_rect()
		check(rect.encloses(game.debug_palette.get_global_rect()),"Palette fits resized viewport")
		for card in game.debug_palette.cards.values():
			check(game.debug_palette.get_global_rect().encloses(card.get_global_rect()),"Every shape is visible at the supported minimum window size")
	root.content_scale_factor=2.0
	root.size=Vector2i(800,600)
	for i in 4: await process_frame
	check(not game.cards_box.visible,"Compact viewport uses palette selection instead of a duplicate hand thumbnail")
	check(not game.menu_button.get_global_rect().intersects(game.debug_palette.get_global_rect()),"X menu stays separate from the compact palette")
	for card in game.debug_palette.cards.values():
		check(game.debug_palette.get_global_rect().encloses(card.get_global_rect()),"All shapes also fit a small Retina viewport")
	root.content_scale_factor=1.0
	game.free()
	print("Block City debug building: ",failures," failures")
	quit(1 if failures else 0)
