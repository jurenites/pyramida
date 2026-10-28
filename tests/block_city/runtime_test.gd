extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func key(game, code: Key) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.pressed=true
	game._unhandled_input(event)
func mouse(game, button: MouseButton, position: Vector2, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button; event.position = position; event.pressed = pressed
	game._input(event)
	game._unhandled_input(event)
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_holding(true)
	for i in 5: await process_frame
	check(game.canvas.find_children("*","Button",true,false).filter(func(b): return b.is_visible_in_tree())==[game.view_button,game.menu_button,game.floor_up,game.floor_down],"Only the view, menu, and requested floor arrows are visible while holding")
	var texts: Array = game.canvas.find_children("*","Label",true,false).filter(func(l): return l.is_visible_in_tree() and not l.text.is_empty()).map(func(l): return l.text)
	check(texts.size()==2 and texts.has(game.version_label.text) and texts.has(game.fps_label.text),"Only the requested version and FPS readouts are persistent text")
	check(game.cards_box.get_child_count()==1,"Only the current coloured piece is shown")
	check(game.get_viewport().get_visible_rect().encloses(game.cards_box.get_global_rect()),"Piece previews fit minimum window")
	check(game.ghost.has_node("Door"),"Landing preview shows its actual door")
	check(game.ghost.get_node("Roofs").get_child_count()==game.preview.cells.size(),"Preview roof matches landing cells")
	for mesh in game.ghost.find_children("*","MeshInstance3D",true,false):
		if mesh is MeshInstance3D:
			check(mesh.position.y<1.1 and mesh.material_override.no_depth_test,"Preview stays at the landing height and is visible through obstacles")
	# Empty-lot edges used to stop the fall at y=1 because upper overhang bounds differ.
	for rotation in 4:
		game.yaw=rotation
		for x in range(-1,4):
			for z in range(-1,4):
				var screen: Vector2=game.camera.unproject_position(Vector3(x+0.25,0,z+0.25))
				game.position_anchor(screen)
				game.refresh_preview()
				check(game.preview.ok and game.preview.origin.y==0,"First room always sits on the ground at every lot edge and rotation")
				for cell in game.preview.cells:
					check(cell.x>=0 and cell.x<3 and cell.z>=0 and cell.z<3,"First footprint snaps fully inside the foundation")
	game.model.queue[0].merge({"door":[0,0,0],"normal":[0,0,-1]},true)
	game.yaw=0; game.anchor=Vector2i.ZERO; game.refresh_preview()
	check(game.ghost.get_node("Door/Doormat").material_override.albedo_color==game.ENTRY_CONNECTED,"First outward-facing doorway has a green mat")
	game.yaw=2; game.refresh_preview()
	check(game.preview.ok and game.ghost.get_node("Door/Doormat").material_override.albedo_color==game.ENTRY_PENDING,"Inward-facing doorway remains placeable with a yellow mat")
	for roof in game.ghost.get_node("Roofs").get_children():
		check(Color(roof.material_override.albedo_color,1.0)==game.model.CONCRETE_FLOOR,"Roof stays concrete regardless of door status")
	game.anchor=Vector2i(3,3); game.rotate_shape()
	check(game.preview.ok and game.preview.origin.y==0,"Rotating at an edge keeps first room grounded")
	game.yaw=0; game.anchor=Vector2i.ZERO; game.refresh()
	var before_view: Dictionary = game.model.snapshot()
	check(game.view_button.text.is_empty(),"View toggle is icon-only")
	game.view_button.pressed.emit()
	check(game.view_mode==1 and game.ghost.get_node("Roofs").get_child_count()==0,"First click removes roofs from preview")
	game.view_button.pressed.emit()
	check(game.view_mode==2,"Second click selects low-wall cutaway")
	for mesh in game.ghost.get_node("Walls").get_children():
		check(mesh.position.y+mesh.mesh.size.y/2<=0.25,"Cutaway lowers wall geometry")
	game.view_button.pressed.emit()
	check(game.view_mode==0 and game.model.snapshot()==before_view,"View cycles without changing construction state")
	var initial_normal: Vector3i = game.preview.normal
	key(game,KEY_R)
	check(game.preview.normal!=initial_normal and game.ghost.has_node("Door"),"Door follows preview rotation")
	game.yaw=0; game.refresh()
	key(game,KEY_ESCAPE)
	check(not game.holding and game.preview.is_empty() and not game.menu.visible,"Escape deselects the held room without opening a menu")
	check(game.debug_palette.cards.values().all(func(card):return not card.selected),"Escape removes the palette selection highlight")
	key(game,KEY_SPACE)
	check(game.model.rooms.is_empty(),"Space cannot place a deselected room")
	key(game,KEY_ESCAPE)
	check(not game.menu.visible,"Repeated Escape never opens a menu")
	check(game.menu_button.text.is_empty(),"Menu button uses an X icon without a label")
	game.click_world(game.menu_button.get_global_rect().get_center())
	check(game.menu.visible and game.model.rooms.is_empty(),"Top-right X opens the menu without placing anything")
	key(game,KEY_SPACE)
	mouse(game,MOUSE_BUTTON_LEFT,game.camera.unproject_position(Vector3(1.5,0,0.5)))
	check(game.model.rooms.is_empty(),"Menu blocks construction input")
	var buttons: Array = game.menu.find_children("*","Button",true,false).map(func(b):return b.text)
	check(buttons==["Resume","New Game","Quit"],"Construction menu has no economy experiments or game modes")
	key(game,KEY_ESCAPE)
	check(not game.menu.visible and not game.holding,"Escape closes an open menu without picking up the room")
	game.set_holding(true)
	key(game,KEY_R); check(game.yaw==1,"R only rotates")
	key(game,KEY_T); check(game.yaw==1,"Removed tip key does nothing")
	game.yaw=0; game.refresh()
	key(game,KEY_SPACE); game.refresh()
	check(game.model.rooms.size()==1,"Space places room")
	check(not game.preview.is_empty(),"Next placement immediately available without Inspect/Place mode")
	var pole: Vector2 = game.camera.unproject_position(game.Cable.POLE)
	check(not game.pole_hit(pole+Vector2(20,0)),"Clicks outside the top circle do not activate wiring")
	check(not game.pole_hit(game.camera.unproject_position(game.Cable.POLE-Vector3.UP*2)),"Pole shaft is click-through")
	game.click_world(pole)
	check(game.wiring,"Clicking actual pole begins connection")
	var socket: Vector3 = game.Cable.socket(Vector3i(0,0,0),Vector3i.FORWARD)
	var screen: Vector2 = game.camera.unproject_position(socket)
	game.click_world(screen)
	check(game.model.cables.size()==1 and game.wiring and not game.wire_source.is_empty(),"Pole then wall click creates a transformer and continues local wiring")
	check(game.model.powered_cells().size()==4,"World click powers chosen floor")
	key(game,KEY_Z)
	check(game.model.cables.is_empty() and game.model.rooms.size()==1,"Undo cable preserves room")
	key(game,KEY_ESCAPE)
	game.new_game()
	game.set_holding(true)
	check(game.model.rooms.is_empty() and not game.menu.visible,"New Game resets via menu")
	var behind_pole: Vector2 = game.camera.unproject_position(Vector3(0.5,0,0.5))
	mouse(game,MOUSE_BUTTON_LEFT,behind_pole)
	check(game.model.rooms.size()==1 and not game.wiring,"Clicking through the shaft places the building behind it")
	game.new_game()
	game.set_holding(true)
	mouse(game,MOUSE_BUTTON_LEFT,game.cards_box.get_global_rect().get_center())
	check(game.model.rooms.is_empty() and not game.holding and game.preview.is_empty(),"Clicking current piece sets it aside")
	game.select_debug_shape("small_square")
	check(game.holding,"Choosing a palette shape resumes building")
	mouse(game,MOUSE_BUTTON_LEFT,game.camera.unproject_position(Vector3(1.5,0,0.5)))
	check(game.model.rooms.size()==1,"Left mouse places a room at the clicked anchor")
	check(game.anchor==Vector2i(1,0),"Click updates placement position without a prior mouse-motion event")
	var start: float = game.orbit
	key(game,KEY_E)
	check(is_equal_approx(game.orbit,start),"E starts without snapping the camera")
	game.orbit_tween.custom_step(0.175)
	check(game.orbit>start and game.orbit<start+PI/2,"E passes through intermediate angles")
	key(game,KEY_E)
	game.orbit_tween.custom_step(0.4)
	check(is_equal_approx(game.orbit,start+PI),"Repeated turns accumulate quarter turns")
	key(game,KEY_Q)
	game.orbit_tween.custom_step(0.4)
	check(is_equal_approx(game.orbit,start+PI/2),"Q animates in the opposite direction")
	var previous_zoom: float = game.zoom
	mouse(game,MOUSE_BUTTON_WHEEL_UP,Vector2.ZERO)
	check(game.zoom<previous_zoom and is_equal_approx(game.camera.size,game.fitted_camera_size*game.zoom),"Scroll zooms during a room drop")
	mouse(game,MOUSE_BUTTON_WHEEL_DOWN,Vector2.ZERO)
	check(is_equal_approx(game.zoom,previous_zoom),"Scroll down zooms back out")
	key(game,KEY_E)
	game.wiring=true
	mouse(game,MOUSE_BUTTON_RIGHT,Vector2(400,400))
	check(not game.orbit_tween.is_valid(),"Right drag interrupts a camera turn")
	var before_drag: float = game.orbit
	var before_elevation: float = game.elevation
	var before_yaw: int = game.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative=Vector2(40,20)
	game._unhandled_input(motion)
	check(game.orbit<before_drag and game.elevation>before_elevation,"Right drag orbits horizontally and vertically")
	check(game.yaw==before_yaw and game.model.rooms.size()==1,"Right drag neither rotates nor places rooms")
	var release := InputEventMouseButton.new()
	release.button_index=MOUSE_BUTTON_RIGHT; release.pressed=false
	game._input(release)
	check(not game.orbiting,"Release stops dragging even when UI consumes the event")
	check(game.wiring,"Orbiting preserves a pending wire connection")
	mouse(game,MOUSE_BUTTON_RIGHT,Vector2(400,400))
	mouse(game,MOUSE_BUTTON_RIGHT,Vector2(400,400),false)
	check(not game.wiring,"A short right-click still cancels wiring")
	game.begin_wire({"cell":[0,0,0],"normal":[0,0,-1]})
	var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	game._input(escape)
	check(not game.wiring and game.wire_source.is_empty() and game.wire_target.is_empty() and not game.holding,"Escape cancels wiring even when handled through focused UI input")
	key(game,KEY_E)
	key(game,KEY_ESCAPE)
	check(not game.orbit_tween.is_valid() and not game.menu.visible,"Escape deselects and stops camera motion without opening a menu")
	key(game,KEY_ESCAPE)
	root.min_size=Vector2i.ZERO
	game.zoom=1.0
	for dimensions in [Vector2i(800,600),Vector2i(1600,900),Vector2i(900,1200)]:
		root.size=dimensions
		for i in 3: await process_frame
		var visible: Rect2 = game.get_viewport().get_visible_rect()
		check(visible.size.is_equal_approx(Vector2(dimensions)),"Resize uses the new logical viewport dimensions")
		for point in game.framing_points:
			check(visible.grow(-20).has_point(game.camera.unproject_position(point)),"Scene fits after window resize")
		check(visible.encloses(game.fps_label.get_global_rect()) and visible.encloses(game.version_label.get_global_rect()),"Diagnostics stay inside the resized viewport")
		check(not game.fps_label.get_global_rect().intersects(game.menu_button.get_global_rect()) and not game.version_label.get_global_rect().intersects(game.view_button.get_global_rect()),"Diagnostics do not overlap corner buttons")
		check(visible.encloses(game.cards_box.get_global_rect()) and visible.encloses(game.view_button.get_global_rect()) and visible.encloses(game.menu_button.get_global_rect()) and visible.encloses(game.floor_up.get_global_rect()) and visible.encloses(game.floor_down.get_global_rect()),"Corner controls stay inside the resized viewport")
		check(is_equal_approx(game.zoom,1.0),"Resize preserves the relative zoom setting")
	for i in 30: mouse(game,MOUSE_BUTTON_WHEEL_UP,Vector2.ZERO)
	check(is_equal_approx(game.zoom,game.MIN_ZOOM),"Zoom-in has a gentle close-up limit")
	root.size=Vector2i(1100,760)
	for i in 3: await process_frame
	check(is_equal_approx(game.zoom,game.MIN_ZOOM) and is_equal_approx(game.camera.size,game.fitted_camera_size*game.MIN_ZOOM),"Close-up remains proportional after resize")
	for i in 30: mouse(game,MOUSE_BUTTON_WHEEL_DOWN,Vector2.ZERO)
	check(is_equal_approx(game.zoom,game.MAX_ZOOM),"Zoom-out is bounded")
	game.free()
	print("Block City runtime: ",failures," failures")
	quit(1 if failures else 0)
