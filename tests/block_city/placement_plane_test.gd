extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func place(m,x: int,z: int,y: int) -> void:
	m.queue[0]={"shape":"cube","color":0}
	check(m.drop(x,z,0,false,y),"Place support fixture")
func screen(game,p: Vector3) -> Vector2: return game.camera.unproject_position(p)
func run() -> void:
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_holding(true)
	game.set_process_unhandled_input(false)
	place(game.model,1,1,0); place(game.model,1,1,1)
	place(game.model,0,0,0)
	game.select_debug_shape("room_domino")
	game.refresh()
	# Look from above to make both the high roof and the lower roof visible.
	game.camera.position=Vector3(1.5,12,5)
	game.camera.look_at(Vector3(1.5,0,1.5)); game.camera.size=7
	var roof:=screen(game,Vector3(1.3,1.99,1.3))
	check(game.position_anchor(roof) and game.snap_y==2,"Roof acquires the floor above it")
	var door_normal: Vector3i=game.preview.normal
	var edge:=screen(game,Vector3(1.3,2,0.3))
	check(game.position_anchor(edge) and game.anchor==Vector2i(1,0) and game.preview.origin.y==2,"A partly supported room keeps its floor while moving across an edge")
	var bare_ground:=screen(game,Vector3(2.3,0,0.3))
	check(game.pick(bare_ground).is_empty(),"Ground fixture is visibly clear of existing rooms")
	check(game.position_anchor(bare_ground) and game.anchor==Vector2i(2,0) and game.preview.origin.y==0 and game.preview.ok,"A detached room settles onto visible empty ground")
	check(game.placement_plane==-100,"Returning to ground releases the stale raised plane")
	check(game.position_anchor(roof) and game.preview.origin.y==2,"Moving back onto a roof reacquires its floor without Alt")
	game.select_floor(2)
	var above_low:=screen(game,Vector3(0.3,2,0.3))
	game.position_anchor(above_low)
	check(game.anchor==Vector2i.ZERO and game.preview.origin.y==2,"An empty gap retains the chosen floor while positioning an unsupported room")
	check(game.preview.normal==door_normal,"Translation preserves the doorway orientation")
	var before: Dictionary=game.model.snapshot()
	game.drop()
	check(game.model.snapshot()==before and game.snap_y==2,"An invalid position still cannot be placed or change construction")
	game.nudge_room(Vector2i.RIGHT)
	check(game.anchor==Vector2i(1,0) and game.preview.origin.y==2,"Keyboard nudging also preserves the level")
	game.forced_floor=-100
	game.select_debug_shape("rectangle")
	game.position_anchor(roof)
	var original: Vector2i=game.anchor
	var pivot:=Vector2(original)+Vector2(game.footprint_extent())*0.5
	var original_cells: Array=game.preview.cells.duplicate()
	for i in 4:
		game.rotate_shape()
		var center:=Vector2(game.anchor)+Vector2(game.footprint_extent())*0.5
		check(absf(center.x-pivot.x)<=0.5 and absf(center.y-pivot.y)<=0.5,"Rotation stays within half a grid cell of the original footprint center")
		check(game.preview.origin.y==2,"Rotation keeps the elevation")
	check(game.anchor==original and game.preview.cells==original_cells,"Four rotations return to the exact original footprint without drift")
	game.rotate_shape()
	var rotated: Vector2i=game.anchor
	game.position_anchor(roof)
	check(game.anchor==rotated,"Re-evaluating the same mouse position does not undo the centered rotation")
	game.retarget_floor_held=true; game.cursor_offset=Vector2i.ZERO
	var low_roof:=screen(game,Vector3(0.3,0.99,0.3))
	game.position_anchor(low_roof)
	check(game.snap_y==1 and game.placement_plane==1,"Alt targeting can explicitly select a lower roof")
	game.retarget_floor_held=false
	game.position_anchor(low_roof)
	check(game.preview.origin.y==1,"The new supported floor stays selected after releasing Alt")
	game.set_holding(false); game.set_holding(true)
	check(game.placement_plane==-100 and game.cursor_offset==Vector2i.ZERO,"Putting the piece aside clears floor and cursor offsets")
	game.position_anchor(roof)
	check(game.snap_y==2,"Picking up the piece allows another roof to be acquired")
	game.select_debug_shape("cube")
	game.position_anchor(roof)
	game.position_anchor(bare_ground)
	check(game.preview.ok and game.preview.origin.y==0,"One-cell hall from the reported floating case settles to ground")
	game.click_world(bare_ground)
	check(game.model.rooms[-1].cells==[[2,0,0]],"Click commits the grounded preview at the pointer")
	if game.drop_tween!=null: game.drop_tween.custom_step(2.0)
	game.camera.position=Vector3(1.5,12,5)
	game.camera.look_at(Vector3(1.5,0,1.5)); game.camera.size=7
	roof=screen(game,Vector3(1.3,1.99,1.3))
	game.select_debug_shape("cube")
	check(game.placement_plane==-100,"Selecting another palette piece clears the floor lock")
	game.position_anchor(roof)
	var desired: Array=game.preview.cells.map(func(p):return Model.arr(p))
	check(game.preview.ok,"Supported plane placement is valid")
	game.click_world(roof)
	check(game.model.rooms[-1].cells==desired,"Mouse click commits exactly the displayed floor and cells")
	check(game.placement_plane==-100,"Successful placement releases the plane for the next piece")
	game.free()
	print("Block City placement plane: ",failures," failures")
	quit(1 if failures else 0)
