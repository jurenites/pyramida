extends SceneTree
const Model=preload("res://scripts/block_city/model.gd")
const Cable=preload("res://scripts/block_city/cable.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	root.size=Vector2i(1100,760)
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	for y in 2:
		game.model.queue[0]={"shape":"cube","color":0}
		check(game.model.drop(0,0,0,false,y),"Place fixture")
	game.set_holding(false); game.refresh()
	game.orbit=-2.4; game.update_camera()
	game.click_world(game.camera.unproject_position(Cable.POLE))
	game.click_world(game.camera.unproject_position(Cable.socket(Vector3i.ZERO,Vector3i.FORWARD,0)))
	check(game.model.cables.size()==1 and game.wiring and int(game.wire_source.slot)==0,"Pole click installs a transformer and continues in local wiring mode")
	var at: Vector2=game.camera.unproject_position(Cable.socket(Vector3i(0,1,0),Vector3i.FORWARD,1))
	game.click_world(at)
	check(game.model.cables.size()==2 and game.model.cables[1].wall,"Next click places a wall-routed fuse connection")
	var saved: Dictionary=game.model.snapshot()
	game.set_holding(false)
	var start: Vector2=game.camera.unproject_position(Cable.endpoint(game.model.cables[0]))
	var target: Vector2=game.camera.unproject_position(Cable.socket(Vector3i.ZERO,Vector3i.FORWARD,1))
	var press:=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=start
	game._unhandled_input(press)
	var motion:=InputEventMouseMotion.new(); motion.position=target; motion.relative=target-start
	game._unhandled_input(motion)
	check(game.wire_dragging and game.wire_target.get("ok",false),"Dragging a box previews a valid new quadrant")
	var release:=InputEventMouseButton.new(); release.button_index=MOUSE_BUTTON_LEFT; release.position=target
	game._input(release)
	check(game.model.cables[0].slot==1 and game.model.cables[1].source_slot==1,"Release moves the box and its outgoing branch")
	check(game.model.rooms==saved.rooms,"Cable dragging never relocates a room")
	var wire: Node3D=game.geometry.get_node("Cables").get_child(0).get_node("Wire")
	var before: Vector3=wire.get_child(10).position
	game.PowerView.animate(game.geometry.get_node("Cables"),1.2)
	check(not before.is_equal_approx(wire.get_child(10).position),"Loose heavy cable sways")
	var wall_wire: Node3D=game.geometry.get_node("Cables").get_child(1).get_node("Wire")
	check(not wall_wire.has_meta("loose"),"Clipped wall wire does not sway")
	game.undo()
	check(game.model.snapshot()==saved,"Undo restores dragged connection")
	game.free()
	print("Block City power interaction: ",failures," failures")
	quit(1 if failures else 0)
