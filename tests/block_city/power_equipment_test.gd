extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Cable=preload("res://scripts/block_city/cable.gd")
const Editor=preload("res://scripts/block_city/editor_selection.gd")
var failures:=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; push_error(message)
func place(m,shape: String,x: int,z: int,y:=0):
	m.queue[0]={"shape":shape,"color":0}
	check(m.drop(x,z,0,false,y),"Place "+shape)
func run():
	var m=Model.new()
	check(m.transformer_feed().size()>2 and m.next_power_feed()==0,"Starter transformer has an incoming service feed")
	place(m,"small_pole",0,2)
	var pole: Dictionary={"device":"pole","cell":[0,0,2],"normal":[0,0,-1],"slot":0}
	check(m.connect_power(Vector3i(0,0,2),Vector3i.FORWARD,m.transformer_source(0),0),"Transformer output feeds small pole")
	check(m.connection(Vector3i(0,0,2),Vector3i.FORWARD,m.transformer_source(1),1).ok,"A powered pole can accept another input on a free terminal")
	check(not m.landing({"shape":"cube","color":0},0,2,0,false,3).ok,"A pole cannot support a room above it")
	check(not m.landing({"shape":"cube","color":0},0,2,0,false,1).ok,"Pole reserves headroom")
	check(m.room_ports(m.rooms[0]).is_empty(),"Power poles never become walk-through rooms")
	place(m,"cube",1,0)
	place(m,"cube",2,1)
	pole.slot=1
	check(m.connect_power(Vector3i(1,0,0),Vector3i.BACK,pole,0),"First pole output supplies a room")
	pole.slot=2
	check(m.connect_power(Vector3i(2,0,1),Vector3i.BACK,pole,1),"Second pole output supplies another room")
	check(m.powered_cells().has(Vector3i(1,0,0)) and m.powered_cells().has(Vector3i(2,0,1)),"Downstream rooms receive electricity")
	for slot in 3:
		pole.slot=slot
		check(not m.connection(Vector3i(2,0,1),Vector3i.RIGHT,pole,0).ok,"All three pole terminals are occupied")
	var loaded=Model.new()
	check(loaded.load_state(JSON.parse_string(JSON.stringify(m.snapshot()))),"Pole input, outputs and transformer survive JSON save/load")
	check(loaded.powered_cells()==m.powered_cells(),"Loaded network supplies the same rooms")
	var move:=Editor.plan(m,[0],Vector3i(0,0,1),0,false)
	check(move.ok,"Moving pole reroutes attached cables")
	if move.ok:
		check(Editor.commit(m,move),"Commit pole move")
		check(m.valid_power_state(),"Moved network remains valid")
		check(m.undo(),"Undo pole move")
	check(m.remove_equipment_branch(m.transformer_source(0)),"Transformer output branch can be deleted")
	check(m.cables.is_empty() and m.powered_cells().is_empty(),"Disconnecting input prunes downstream pole wires")
	check(m.undo() and m.cables.size()==3,"Undo restores complete branch")
	var copy:=Editor.plan(m,[0],Vector3i(1,0,2),0,true)
	check(copy.ok and copy.proposed_cables.size()==m.cables.size(),"Copying a pole creates no duplicate supply")
	var remove:=Editor.removal(m,[0])
	check(remove.ok and remove.proposed_cables.is_empty(),"Deleting pole removes its attached branch")
	var unpowered=Model.new(); place(unpowered,"small_pole",0,2); place(unpowered,"cube",1,0)
	check(not unpowered.connection(Vector3i(1,0,0),Vector3i.BACK,pole,0).ok,"Unconnected pole does not create electricity")
	var capacity=Model.new(); place(capacity,"cube",1,0)
	for slot in 3:
		check(capacity.connect_power(Vector3i(1,0,0),Vector3i.LEFT,capacity.transformer_source(slot),slot),"Transformer accepts its three output cables")
	check(not capacity.connection(Vector3i(1,0,0),Vector3i.LEFT,capacity.transformer_source(0),3).ok,"An occupied transformer output cannot branch twice")
	check(not capacity.connection(Vector3i(1,0,0),Vector3i.LEFT,capacity.transformer_source(3),3).ok,"No fourth transformer output exists")
	check(loaded.load_state(JSON.parse_string(JSON.stringify(capacity.snapshot()))),"Three-output transformer saves correctly")
	var invalid: Dictionary=m.snapshot(); invalid.cables[0].slot=3
	check(not loaded.load_state(invalid),"Invalid fourth pole terminal rejected on load")
	var legacy: Dictionary=capacity.snapshot(); legacy.erase("transformer_cell"); legacy.cables=[]
	check(loaded.load_state(legacy),"Old saves get a starter transformer without losing rooms")
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game); game.set_process(false)
	game.model.restore(m.snapshot()); game.refresh()
	check(game.debug_palette.cards.has("small_pole"),"Small pole appears in the build palette")
	check(game.geometry.get_node("Neighbourhood").has_node("StarterTransformer"),"Starter transformer is rendered")
	check(game.geometry.get_node("Room0").has_node("SmallPole"),"Built pole renders its half-height model")
	game.camera.position=Vector3(-5,5,-6); game.camera.look_at(Vector3(0.5,0.8,0.8)); game.camera.size=6
	var terminal: Dictionary=game.model.transformer_source(1)
	game.click_world(game.camera.unproject_position(Cable.endpoint(terminal)))
	check(game.wiring and game.wire_source==terminal,"Clicking a transformer output starts wiring")
	game.set_holding(false)
	game.begin_move(0,game.camera.unproject_position(Vector3(0.5,0,2.5)))
	check(game.preview.get("ok",false),"Picking up an existing pole preserves its wired preview")
	game.set_holding(false)
	game.select_debug_shape("small_pole")
	check(game.holding and game.ghost.has_node("SmallPole"),"Held pole renders actual equipment, without room walls")
	game.free()
	print("Block City power equipment: ",failures," failures")
	quit(1 if failures else 0)
