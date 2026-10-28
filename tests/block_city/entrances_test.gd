extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func place(m,shape: String,x: int,z: int,yaw:=0,door: Array=[],normal: Array=[]) -> void:
	m.queue[0]={"shape":shape,"color":0}
	if not door.is_empty(): m.queue[0].merge({"door":door,"normal":normal})
	check(m.drop(x,z,yaw),"Place entrance fixture "+shape)
func mats(node: Node) -> Array:
	return node.get_node("Door").get_children().filter(func(child):return child.has_meta("port_cell"))
func run() -> void:
	for shape in ["room_domino","bar","small_square","rectangle"]:
		var m=Model.new()
		var options: Array=m.entrance_options(shape)
		var seen: Dictionary={}
		for seed_value in 64:
			var card: Dictionary=m.make_card(shape,0,seed_value)
			seen[str(card.door)+str(card.normal)]=true
		check(seen.size()==options.size(),"Draws vary across every permitted entrance on "+shape)
		for option in options:
			for yaw in 4:
				m.reset()
				place(m,shape,0,0,yaw,option.door,option.normal)
				var room: Dictionary=m.rooms[0]
				var ports: Array=m.room_ports(room)
				check(ports.size()==1,"Each colored room has exactly one entrance")
				check(not room.cells.has(Model.arr(ports[0].cell+ports[0].normal)),"Entrance faces outside the footprint")
				check(ports[0].normal==Model.rotate_point(Model.vec(option.normal),yaw),"Chosen entrance rotates with the body")
				if shape!="small_square": check(option.normal[2]==0,"Elongated rooms use only long sides")
				var loaded=Model.new()
				check(loaded.load_state(JSON.parse_string(JSON.stringify(m.snapshot()))) and loaded.room_ports(loaded.rooms[0])==ports,"One selected entrance survives save/load")
		for spot in (2 if shape=="room_domino" else 3):
			if shape=="small_square": continue
			m.reset(); place(m,shape,1,0,0,[0,0,spot],[-1,0,0])
			place(m,"cube",0,(spot+1)%3)
			check(not m.has_access(m.rooms[0]),"A corridor at an unused position cannot connect through a wall")
			place(m,"cube",0,spot)
			check(m.has_access(m.rooms[0]),"The selected position connects through a matching corridor")
			check(m.undo() and not m.has_access(m.rooms[0]),"Undo removes only actual doorway access")
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_holding(true)
	game.set_process_unhandled_input(false)
	place(game.model,"rectangle",1,0,0,[0,0,1],[-1,0,0])
	place(game.model,"domino",0,1)
	game.set_holding(false); game.refresh()
	for i in 120:
		await process_frame
		if game.analysis_thread==null and game.analysis_pending.is_empty() and game.room_redraw_queue.is_empty(): break
	
	var room_mats:=mats(game.geometry.get_node("Room0"))
	check(room_mats.size()==1 and room_mats[0].material_override.albedo_color==game.ENTRY_CONNECTED,"Renderer shows only the single connected room doorway")
	var hall: Node=game.geometry.get_node("Room1")
	var hall_mats:=mats(hall)
	check(hall_mats.size()==4,"Corridor shows one room door and three sidewalk entrances")
	check(hall_mats.all(func(mat):return mat.material_override.albedo_color==game.ENTRY_CONNECTED),"Connected corridor entrances have green mats")
	check(hall.get_node("Supports").get_child_count()==4,"Unfinished edges keep the four-corner scaffold")
	game.model.reset(); place(game.model,"cube",1,1); place(game.model,"cube",1,1)
	game.refresh()
	check(game.geometry.get_node("Room1/Door").get_child_count()==0,"An isolated upper hall stays open scaffolding")
	game.model.reset(); place(game.model,"rectangle",1,0,0,[0,0,1],[-1,0,0])
	game.model.queue[0]={"shape":"cube","color":0}
	game.holding=true; game.anchor=Vector2i(0,1); game.snap_y=0; game.refresh()
	check(mats(game.ghost).size()==2 and mats(game.ghost).all(func(mat):return mat.material_override.albedo_color==game.ENTRY_CONNECTED),"Hall preview shows matching room and sidewalk doorways")
	game.animating=false
	var drawn: Dictionary={}
	for i in 32:
		game.select_debug_shape("rectangle")
		var card: Dictionary=game.model.current().duplicate(true)
		drawn[str(card.door)+str(card.normal)]=true
		for j in 4: game.rotate_shape()
		game.refresh(); game.set_holding(false); game.set_holding(true)
		check(game.model.current()==card,"Refresh, rotation and deselection never reroll the held door")
	check(drawn.size()>1,"Repeated palette selection draws a new entrance")
	game.model.reset(); game.select_debug_shape("bar")
	game.anchor=Vector2i(0,0); game.yaw=0; game.refresh()
	var held: Dictionary=game.model.current().duplicate(true)
	var planned: Dictionary=game.preview.duplicate(true)
	game.drop()
	check(game.model.rooms[0].door==Model.arr(planned.door) and game.model.rooms[0].normal==Model.arr(planned.normal),"Placed doorway exactly matches the preview")
	game.undo()
	check(game.model.current()==held,"Undo restores the exact held entrance")
	var saved: Dictionary=game.model.snapshot(); var loaded=Model.new()
	check(loaded.load_state(saved) and loaded.current()==held,"Held entrance survives save/load")
	saved.queue[0].door=[99,0,99]
	check(not loaded.load_state(saved),"Invalid saved card entrance is rejected")
	game.free()
	print("Block City entrances: ",failures," failures")
	quit(1 if failures else 0)
