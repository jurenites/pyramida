extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/economy_lab.gd").new()
	root.add_child(game)
	for i in 4: await process_frame
	check(not game.auto_save and not game.restore_last,"Lab never uses construction save")
	check(game.economy.teaching_step()==0 and not game.tool_buttons.garden.visible,"Level zero starts with one action, without a tool lecture")
	game.lab_click(game.camera.unproject_position(Vector3(1.5,0.08,0.5)))
	check(game.economy.floors[0].rooms.size()==1 and game.economy.teaching_step()==1,"Click an empty cell to build first home")
	for kind in ["water","sewer"]:
		game.lab_click(game.camera.unproject_position(game.port_position(-1,kind)))
		check(game.pipe_source==-1 and game.pipe_kind==kind,"Street port selects correct service")
		game.lab_click(game.camera.unproject_position(game.port_position(0,kind)))
		check(game.economy.linked(0,kind) and game.pipe_source==-99,"Click bathroom port to complete service")
	check(game.economy.teaching_step()==3,"Month action becomes the next visual prompt")
	game.month_button.pressed.emit()
	check(game.economy.residents()==2 and game.lesson_complete and game.tool_buttons.garden.visible,"Serviced home admits residents and opens free play")
	var before: Dictionary=game.economy.snapshot()
	check(game.level_y(2)==2.0,"Floors retain their physical height without an exploded view")
	game.add_level_button.pressed.emit()
	check(game.economy.floors.size()==2 and game.focused_floor==1,"World plus adds a supported floor and focuses it")
	var levels: Array=game.floor_buttons.get_children().filter(func(b):return b.text in ["1","2","3"]).map(func(b):return b.text)
	check(levels==["2","1"],"Floor controls read from upper floors down to ground")
	game.tool_buttons.bath.pressed.emit()
	game.lab_click(game.camera.unproject_position(Vector3(2.5,game.level_y(1)+0.08,2.5)))
	check(game.economy.bath_slot(1)==Vector2i(2,2),"Bathroom move tool places an offset wet room")
	for kind in ["water","sewer"]:
		game.lab_click(game.camera.unproject_position(game.port_position(0,kind)))
		game.lab_click(game.camera.unproject_position(game.port_position(1,kind)))
		check(game.economy.linked(1,kind),"Daisy service connection works through floor separation")
	for kind in ["water","sewer"]:
		var route: Array[Vector3]=game.visual_route(1,kind)
		check(route[0]==game.port_position(1,kind) and route[-1]==game.port_position(0,kind),"Rendered routes meet their exact selected ports")
	before=game.economy.snapshot()
	game.menu.show()
	game.advance_month(); game.lab_click(game.camera.unproject_position(Vector3(1.5,game.level_y(1)+0.08,0.5)))
	check(game.economy.snapshot()==before,"Escape menu blocks world and monthly accounting")
	game.menu.hide()
	game.economy.reset(); game.refresh_lab()
	root.min_size=Vector2i.ZERO
	for size in [Vector2i(800,600),Vector2i(1600,900)]:
		root.size=size
		for i in 3: await process_frame
		var rect: Rect2=game.get_viewport().get_visible_rect()
		check(rect.encloses(game.cards_box.get_global_rect()) and rect.encloses(game.month_button.get_global_rect()),"Lab controls stay inside resized viewport")
	game.free()
	print("Economy lab runtime: ",failures," failures")
	quit(1 if failures else 0)
