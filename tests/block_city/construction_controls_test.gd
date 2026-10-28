extends SceneTree
const Net=preload("res://scripts/block_city/utility_network.gd")
var failures:=0
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
	if not ok: failures+=1; push_error(message)
func key(game,code):
	var event:=InputEventKey.new(); event.keycode=code; event.pressed=true; game._unhandled_input(event)
func run():
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game); game.set_process(false)
	game.select_debug_shape("room_bar")
	# Use the actual long ordinary-room ID from the palette configuration.
	if game.debug_shape!="room_bar": game.select_debug_shape("rectangle")
	var cells: Array=game.held_card().get("cells",game.model.shape_for(game.held_card().shape).cells).duplicate(true)
	var before: Dictionary=game.held_card().duplicate(true)
	key(game,KEY_F)
	check(game.held_card().door!=before.door or game.held_card().normal!=before.normal,"F cycles the held entrance")
	check(game.model.oriented(game.held_card(),0).cells==game.model.oriented(before,0).cells,"F preserves footprint and rotation")
	var meshes: Array=game.ghost.find_children("*","MeshInstance3D",true,false)
	check(meshes.any(func(mesh):return mesh.material_override.no_depth_test),"Held room is visible through obstacles")
	var mats: Array=game.ghost.find_children("Doormat*","MeshInstance3D",true,false)
	check(not mats.is_empty() and mats.all(func(mesh):return mesh.material_override.no_depth_test and mesh.material_override.render_priority==10),"Preview door status stays visible in front of held walls")
	key(game,KEY_3); check(game.forced_floor==2,"3 selects third floor")
	key(game,KEY_PERIOD); check(game.forced_floor==3,"Greater/period selects one floor higher")
	key(game,KEY_COMMA); check(game.forced_floor==2,"Less/comma selects one floor lower")
	game.model.queue[0]={"shape":"cube","color":0}; game.model.drop(0,0,0,false,0)
	game.select_debug_shape("cube"); key(game,KEY_2)
	var anchor: Vector2i=game.anchor
	key(game,KEY_RIGHT)
	check(game.anchor==anchor+Vector2i.RIGHT and game.snap_y==1,"Arrows move on the chosen grid level")
	game.set_holding(false); key(game,KEY_8)
	check(game.forced_floor==-100,"Floor hotkeys are inactive outside placement/tools")
	game.model.reset(); game.model.defer_analysis=true
	for role in ["stairs","elevator"]:
		game.model.reset(); game.model.queue[0]={"shape":role,"color":0}
		check(game.model.drop(0,0,1,false,0),"Vertical fixture")
		game.refresh(); game.select_debug_shape(role); game.select_floor(1); game.anchor=Vector2i.ZERO; game.refresh_preview()
		check(game.preview.normal==game.model.vec(game.model.rooms[0].normal),"Vertical module automatically follows the one below")
		game.rotate_shape(); var manual: int=game.yaw; game.refresh_preview()
		check(game.yaw==manual and game.manual_orientation,"Manual rotation overrides automatic alignment")
	game.model.reset(); game.model.defer_analysis=true
	for x in 3:
		game.model.queue[0]={"shape":"cube","color":0}; game.model.drop(x,0,0,false,0)
	game.refresh(); game.select_utility("pipe")
	game.camera.position=Vector3(1.5,0.6,-8); game.camera.look_at(Vector3(1.5,0.6,0.5)); game.camera.size=5
	var from: Vector2=game.camera.unproject_position(Vector3(0.5,0.5,0))
	var to: Vector2=game.camera.unproject_position(Vector3(2.5,0.5,0))
	var press:=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=from
	game._unhandled_input(press)
	var motion:=InputEventMouseMotion.new(); motion.position=to; game._unhandled_input(motion)
	check(game.utility_path.size()==3 and game.model.utility_links.is_empty(),"Drag previews interpolated face tiles without changing the model")
	var release:=InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.position=to
	game._input(release)
	check(game.model.utility_links.size()==2 and not game.utility_dragging,"Release commits the entire route")
	game.undo(); check(game.model.utility_links.is_empty(),"One undo removes one complete stroke")
	game.begin_utility_stroke(from); game.update_utility_hover(to); game.cancel_construction()
	check(game.model.utility_links.is_empty() and game.utility_kind.is_empty(),"Escape discards an unfinished stroke")
	# Newest snapshot wins after rapid consecutive physical changes.
	game.model.queue[0]={"shape":"cube","color":0}; game.model.drop(0,1,0,false,0); game.refresh()
	var revision: int=game.analysis_revision
	for i in 100:
		game.poll_analysis()
		if game.analysis_thread==null and game.analysis_pending.is_empty(): break
		await process_frame
	check(game.analysis_revision==revision and game.analysis_signature==hash([game.model.rooms,game.model.cables,game.model.utility_links]),"Background analysis applies only the current construction snapshot")
	print("Block City construction controls: ",failures," failures")
	game.free(); quit(1 if failures else 0)
