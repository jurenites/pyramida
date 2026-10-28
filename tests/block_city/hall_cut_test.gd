extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func place(m, shape: String, x: int, z: int, basement := false) -> void:
	(m.basement_queue if basement else m.queue)[0]={"shape":shape,"color":0}
	check(m.drop(x,z,0,basement),"Place fixture "+shape)
func run() -> void:
	var m=Model.new()
	place(m,"rectangle",0,0)
	place(m,"rectangle",0,0)
	check(m.connect_power(Vector3i.ZERO,Vector3i.FORWARD),"Wire room before cutting")
	m.queue[0]={"shape":"domino","color":3}
	var before: Dictionary=m.snapshot()
	var plan: Dictionary=m.landing(m.current(),0,1,1,false,0,true)
	check(plan.ok and plan.remnants.size()==2,"Middle cut splits rectangle into two intact sections")
	check(m.snapshot()==before,"Cut preview never changes live rooms or supply")
	check(m.drop(0,1,1,false,0,true),"Hall replaces the two targeted room cells")
	check(m.rooms.size()==4 and m.occupied().size()==12,"Remaining sections and upper floor keep every occupied cell")
	check(m.rooms[-1].cells==[[1,0,1],[0,0,1]],"Only the selected cells become a hall")
	for room in m.rooms:
		check(room.id==m.rooms.find(room),"Room indices remain valid after splitting")
		if room.shape=="rectangle" and room.cells[0][1]==0:
			check(m.room_ports(m.rooms[-1]).any(func(port): return port.cell==m.approach(room)),"Every surviving section has a doorway facing the hall")
			check(m.has_access(room),"Carved hall grants access from the street")
	check(m.cables==before.cables and m.powered_cells().size()==2 and not m.powered_cells().has(Vector3i(0,0,1)),"Cut preserves the wired section; separate hall and room fragments need their own feeds")
	check(m.tint(m.rooms[-1])==Model.HALL_COLOR and m.tint({"shape":"cube","color":1})==Model.HALL_COLOR,"Both hall sizes ignore the supply color")
	check(m.save_game("/tmp/block-city-hall-cut.json"),"Save carved geometry")
	var loaded=Model.new()
	check(loaded.load_game("/tmp/block-city-hall-cut.json") and loaded.snapshot()==m.snapshot(),"Split rooms, entrances, halls and cables round-trip")
	check(m.undo() and m.snapshot()==before,"One undo restores original room, doors, supply and cables")
	check(not m.landing({"shape":"bar","color":0},0,0,0,false,0,true).ok,"Ordinary rooms cannot overwrite construction")
	place(m,"stairs",2,0)
	check(not m.landing({"shape":"cube","color":0},2,0,0,false,0,true).ok,"Cutting cannot remove a staircase")
	var full=Model.new()
	place(full,"bar",0,0)
	for z in 3:
		full.queue[0]={"shape":"cube","color":z}
		check(full.drop(0,z,0,false,0,true),"Can successively turn an entire room into hall cells")
	check(full.rooms.size()==3 and full.rooms.all(func(room): return full.room_role(room)=="hall"),"Fully replaced room leaves no empty room record")
	check(loaded.load_state(full.snapshot()),"Completely replaced rooms save safely")
	var underground=Model.new()
	place(underground,"small_square",0,0,true)
	underground.basement_queue[0]={"shape":"cube","color":4}
	check(underground.drop(0,0,0,true,-1,true),"Basement rooms also accept hall cutouts")

	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false
	root.add_child(game)
	game.set_holding(true)
	game.set_process_unhandled_input(false)
	place(game.model,"small_square",0,0)
	game.model.queue[0]={"shape":"cube","color":4}
	game.refresh()
	var roof: Vector2=game.camera.unproject_position(Vector3(0.5,0.975,0.5))
	game.position_anchor(roof)
	check(not game.carve_hall and game.preview.ok and game.preview.origin.y==1,"Hall defaults to roof stacking above the existing room")
	check(game.geometry.get_node("Room0").visible,"Stacking leaves the original room visible and intact")
	var original: Dictionary=game.model.rooms[0].duplicate(true)
	game.click_world(roof)
	if game.drop_tween!=null: game.drop_tween.custom_step(2.0)
	check(game.model.rooms[0]==original and game.model.rooms[-1].cells==[[0,1,0]],"Normal click adds an upper hall without moving or cutting the lower room")
	game.undo()
	game.model.queue[0]={"shape":"cube","color":4}
	game.refresh()
	var shift:=InputEventKey.new(); shift.keycode=KEY_SHIFT; shift.pressed=true; shift.shift_pressed=true
	game._input(shift)
	game.position_anchor(roof)
	check(game.carve_hall and game.preview.ok and game.preview.origin.y==0,"Shift explicitly previews insertion into the colored room")
	check(not game.geometry.get_node("Room0").visible,"Cut preview reveals the actual cut instead of covering it with the old roof")
	check(game.ghost.get_node("Supports").get_child_count()==4 and game.ghost.get_node("Walls").get_child_count()==0 and game.ghost.get_node("Roofs").get_child_count()==(1 if game.view_mode==0 else 0),"Hall preview has four columns and follows the roof view")
	game.click_world(roof)
	check(game.model.rooms.size()==2 and not game.animating,"Click carves in place without dropping from the sky")
	game.set_holding(false)
	for mode in 3:
		game.view_mode=mode; game.refresh()
		var hall: Node3D=game.geometry.get_node("Room1")
		check(hall.get_node("Supports").get_child_count()==4 and hall.get_node("Walls").get_child_count()==0 and hall.get_node("Roofs").get_child_count()==(1 if mode==0 else 0),"Exposed hall has a concrete roof only in roofed view")
	game.free()
	print("Block City hall cut: ",failures," failures")
	quit(1 if failures else 0)
