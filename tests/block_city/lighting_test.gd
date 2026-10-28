extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Net=preload("res://scripts/block_city/utility_network.gd")
var failures:=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; push_error(message)
func settle(game):
	for i in 180:
		await process_frame
		if game.analysis_thread==null and game.analysis_pending.is_empty() and game.room_redraw_queue.is_empty(): return
	check(false,"Lighting analysis completes")
func run():
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	for y in 2:
		game.model.queue[0]={"shape":"room_domino","color":y+1,"door":[0,0,0],"normal":[-1,0,0]}
		check(game.model.drop(0,0,0,false,y),"Fixture room")
	check(game.model.connect_power(Vector3i.ZERO,Vector3i.FORWARD),"Power lower room")
	game.refresh(); await settle(game)
	check(game.model.tint(game.model.rooms[0])==Model.STAIR_COLOR and game.model.tint(game.model.rooms[1])==Model.STAIR_COLOR,"Room types share concrete gray")
	check(game.debug_palette.cards.values().all(func(card):return card.tint==Model.STAIR_COLOR),"Palette also uses concrete gray")
	check(not game.geometry.get_node("Room0").find_children("PoweredWindow*","MeshInstance3D",true,false).is_empty(),"Supplied floor windows emit warm light")
	check(game.geometry.get_node("Room1").find_children("PoweredWindow*","MeshInstance3D",true,false).is_empty(),"Unconnected floor stays dark")
	var path:=Net.route(Net.graph(game.model,0,100,false),Net.node(Vector3i.ZERO,Vector3i.FORWARD,"wall"),Net.node(Vector3i(0,1,0),Vector3i.FORWARD,"wall"))
	check(Net.add(game.model,"power",path),"Draw power up to next floor")
	game.refresh(); await settle(game)
	check(not game.geometry.get_node("Room1").find_children("PoweredWindow*","MeshInstance3D",true,false).is_empty(),"Drawn electricity lights the newly connected floor")
	for mode in [1,2]:
		game.view_mode=mode; game.refresh()
		check(game.geometry.get_node("Room1").find_children("WarmEmitter*","MeshInstance3D",true,false).size()==2,"Each powered interior tile shows a ceiling emitter in cutaway")
		check(game.geometry.get_node("Room1").find_children("WarmLightPool*","MeshInstance3D",true,false).size()==2,"Cutaway floor shows warm light pools")
		check(game.geometry.get_node("Room1").find_children("*","Light3D",true,false).is_empty(),"Lighting adds no per-room dynamic shadow lights")
	check(game.model.remove_power_node(Vector3i.ZERO,Vector3i.FORWARD),"Remove supply")
	game.refresh(); await settle(game)
	check(game.geometry.find_children("WarmEmitter*","MeshInstance3D",true,false).is_empty(),"Removing supply turns off cutaway lighting")
	game.undo(); await settle(game)
	check(not game.geometry.find_children("WarmEmitter*","MeshInstance3D",true,false).is_empty(),"Undo restores electrical lighting")
	print("Block City concrete and power lighting: ",failures," failures")
	game.free(); quit(1 if failures else 0)
