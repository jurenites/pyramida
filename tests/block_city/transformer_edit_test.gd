extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Cable=preload("res://scripts/block_city/cable.gd")
const Editor=preload("res://scripts/block_city/editor_selection.gd")
var failures:=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; push_error(message)
func run():
	for yaw in 4:
		var m=Model.new(); m.queue[0]={"shape":"small_pole","color":0}
		check(m.drop(1,2,yaw,false,0),"Place pole in each crossarm direction")
		var normal:=Model.vec(m.rooms[0].normal)
		for slot in [2,0,1]:
			var available:=-1
			for target in 3:
				var terminal: Dictionary={"device":"pole","cell":[1,0,2],"normal":Model.arr(normal),"slot":target}
				if not m.terminal_used(terminal): available=target; break
			check(m.connect_power(Vector3i(1,0,2),normal,m.transformer_source(slot),available),"All three transformer outputs connect to one pole")
		check(m.cables.size()==3 and m.valid_power_state(),"Three-input pole is valid")
		var ordered: Array=m.cables.duplicate(); ordered.sort_custom(func(a,b):return int(a.source_slot)<int(b.source_slot))
		var curves: Array=ordered.map(func(c):return m.cable_points(c))
		for i in curves[0].size():
			check(curves[0][i].distance_to(curves[1][i])>0.16 and curves[1][i].distance_to(curves[2][i])>0.16,"Bundle retains separate parallel lanes")
		var before:=m.snapshot()
		check(m.move_transformer(Vector3i(2,0,-1)),"Transformer moves onto clear paving")
		check(m.cables.all(func(c):return c.source_cell==[2,0,-1]),"All output cables follow the cabinet")
		check(m.valid_power_state(),"Moved bundle remains valid")
		var loaded=Model.new()
		check(loaded.load_state(JSON.parse_string(JSON.stringify(m.snapshot()))),"Moved cabinet and three feeds survive JSON load")
		check(m.undo() and m.snapshot()==before,"One undo restores cabinet and cables")
		check(not m.move_transformer(Vector3i(1,0,2)),"Transformer cannot overlap a pole")
		check(not m.move_transformer(Vector3i(1,0,-2)),"Transformer cannot occupy the road")
		check(m.remove_equipment_branch(m.transformer_source(0)) and m.cables.size()==2,"Removing one parallel feed preserves the other two")
	var m=Model.new()
	for y in 3:
		m.queue[0]={"shape":"cube","color":0}; check(m.drop(2,2,0,false,y),"Build cable fixture")
	check(m.connect_power(Vector3i(2,2,2),Vector3i.FORWARD),"Connect existing cable")
	check(m.fits([Vector3i(0,3,0)],{},{},false),"Existing cable no longer blocks a construction cell")
	# A new room may cover a formerly exposed wall socket without deleting power.
	m=Model.new(); m.queue[0]={"shape":"cube","color":0}; m.drop(0,0,0,false,0)
	check(m.connect_power(Vector3i.ZERO,Vector3i.RIGHT),"Wire side socket through the room if needed")
	m.queue[0]={"shape":"cube","color":0}
	check(m.drop(1,0,0,false,0),"Build against wired wall without cable rejection")
	var saved:=m.snapshot(); var loaded=Model.new()
	check(loaded.load_state(JSON.parse_string(JSON.stringify(saved))),"Construction through cables still saves and loads")
	check(m.powered_cells().has(Vector3i.ZERO),"Covering a wire preserves its supplied room")
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game); game.set_process(false)
	game.camera.position=Vector3(-5,4,-6); game.camera.look_at(Vector3(0,0.5,0.5)); game.camera.size=6
	var body: Vector2=game.camera.unproject_position(Vector3(game.model.transformer_cell)+Vector3(0.5,0.45,0))
	game.click_world(body)
	check(game.selection_kind=="transformer" and not game.holding,"Click selects the transformer without moving immediately")
	check(game.editor_bar.visible and game.editor_bar.get_child(0).visible and not game.editor_bar.get_child(1).visible,"Transformer uses existing Move control")
	game.editor_action("move")
	check(game.holding and game.edit_action=="transformer_move" and game.ghost.has_node("StarterTransformer"),"Move picks up cabinet with a physical preview")
	game.anchor=Vector2i(1,-1); game.snap_y=0; game.refresh_preview(); game.drop()
	check(game.model.transformer_cell==Vector3i(1,0,-1) and not game.holding,"Click or Space commits transformer placement")
	game.undo()
	check(game.model.transformer_cell==Vector3i(-1,0,0),"UI Undo restores the original location")
	game.free()
	print("Block City transformer editing: ",failures," failures")
	quit(1 if failures else 0)
