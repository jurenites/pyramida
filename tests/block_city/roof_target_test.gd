extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func place(game,shape: String,x: int,z: int,y: int) -> void:
	game.model.queue[0]={"shape":shape,"color":0}
	check(game.model.drop(x,z,0,false,y),"Place roof fixture")
func run() -> void:
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	game.set_holding(true)
	game.set_process_unhandled_input(false)
	for mode in 3:
		for angle in [-2.4,-0.8,0.8,2.4]:
			game.model.reset(); game.reset_placement_aim()
			place(game,"cube",1,1,0)
			game.select_debug_shape("cube")
			game.view_mode=mode; game.orbit=angle; game.refresh()
			var inside: Vector2=game.camera.unproject_position(Vector3(1.5,0.08,1.5))
			check(game.position_anchor(inside) and game.preview.ok and game.preview.origin==Vector3i(1,1,1),"Pointing into an open hall stacks the next hall above it in every view/angle")
			game.drop()
			if game.drop_tween!=null: game.drop_tween.custom_step(2.0)
			check(game.model.rooms[-1].cells==[[1,1,1]],"Hall stacks in the same column")
			inside=game.camera.unproject_position(Vector3(1.5,1.08,1.5))
			check(game.position_anchor(inside) and game.preview.ok and game.preview.origin==Vector3i(1,2,1),"A second open hall can be targeted for the next storey")
			game.select_debug_shape("rectangle")
			game.position_anchor(inside)
			game.rotate_shape()
			var rotated: Vector2i=game.anchor
			game.position_anchor(inside)
			check(game.anchor==rotated,"Repeated hall targeting preserves centered rotation")
			game.nudge_room(Vector2i.LEFT)
			var nudged: Vector2i=game.anchor
			game.position_anchor(inside)
			check(game.anchor==nudged,"Repeated hall targeting preserves keyboard adjustments")
	game.model.reset(); game.reset_placement_aim()
	place(game,"rectangle",0,0,0)
	place(game,"bar",0,0,1); place(game,"bar",0,0,2)
	game.select_debug_shape("room_domino"); game.view_mode=0; game.yaw=0; game.refresh()
	game.camera.position=Vector3(7,8,6)
	game.camera.look_at(Vector3(1,1,1.5)); game.camera.size=7
	var upper: Vector2=game.camera.unproject_position(Vector3(0.5,2.99,0.5))
	var ledge: Vector2=game.camera.unproject_position(Vector3(1.5,0.99,0.5))
	check(game.position_anchor(upper) and game.snap_y==3,"First target the three-storey tower top")
	check(game.position_anchor(ledge) and game.preview.ok and game.preview.origin==Vector3i(1,1,0),"A two-cell room targets the exposed second-floor ledge immediately, without Alt")
	check(game.preview.cells==[Vector3i(1,1,0),Vector3i(1,1,1)],"The complete 1×2 footprint remains at the lower roof level")
	ledge=game.camera.unproject_position(Vector3(1.5,0.99,1.5))
	check(game.position_anchor(ledge) and game.preview.ok and game.preview.origin==Vector3i(1,1,1),"Sliding along the ledge stays on that roof")
	game.click_world(ledge)
	check(game.model.rooms[-1].cells==[[1,1,1],[1,1,2]],"Click places on the exact lower ledge rather than the highest level")
	game.free()
	print("Block City roof targeting: ",failures," failures")
	quit(1 if failures else 0)
