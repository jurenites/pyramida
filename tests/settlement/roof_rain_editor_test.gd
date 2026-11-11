extends SceneTree
const Scene=preload("res://scenes/settlement/Terraces.tscn")
const Fixture=preload("res://tests/settlement/reviewed_balance_test.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=Scene.instantiate()
	game.capture=true; game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-rain-editor-test-slots"
	root.add_child(game); game.set_process(false); game.speed=0
	game.rain_editor.set_process(false)
	var fixture:=Fixture.new(); var world=fixture.fixture(); world.generator_version=4
	fixture.finish(world,"house",Vector3i.ZERO)
	game.model=world; game.menu.hide(); game.hud.show()
	game.selected_object={"kind":"house","cell":Vector3i.ZERO}
	game.hud.update(world,-1,0,game.selected_object)
	check(game.hud.rain_edit_button.is_visible_in_tree(),"A selected Home exposes the Rain action")
	game.hud.rain_edit_button.pressed.emit()
	check(game.rain_editor.active and game.rain_editor.toolbar.visible,"Rain action opens the fitting tool")
	var editor=game.rain_editor
	editor.toolbar.get_child(1).pressed.emit()
	check(editor.mode=="barrel","Barrel button selects barrel placement")
	editor.spec={"kind":"barrel","cell":Vector3i(3,0,3),"offset":Vector3.ZERO}
	var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
	game._unhandled_input(click)
	check(world.plans.values().any(func(p):return p.kind=="rain_fitting" and p.rain_spec.kind=="barrel"),"Placement input queues a real barrel construction job")
	var escape:=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	game._input(escape)
	check(not editor.active and not editor.toolbar.visible,"Escape closes Rain editing")
	game.room_editor.anchor=Vector3i(2,0,4); game.room_editor.floor_level=1; game.room_editor.set_active(true)
	for child in game.room_editor.palette.get_children():
		if child is Button and child.text=="Rain": child.pressed.emit(); break
	check(editor.active and editor.anchor==Vector3i(2,2,4) and not game.room_editor.active,"Room details open Rain editing on the selected floor")
	editor.path=[Vector3.ONE,Vector3.ZERO]; editor.gutter=1
	game._input(escape)
	check(editor.active and editor.path.is_empty(),"Escape first cancels an unfinished pipe route")
	for child in editor.toolbar.get_children():
		if child is Button and child.text=="Done": child.pressed.emit(); break
	check(not editor.active,"Done returns to normal inspection")
	var rain=preload("res://scripts/settlement/roof_rain.gd")
	var lane: String=rain.roof_lanes(world,true).keys()[0]
	check(rain.request(world,{"kind":"gutter","lane":lane}) and world.debug_finish_plan(world.next_plan_id-1),"Prepare an actual fitted section for editor input")
	var gutter_id: int=world.roof_rain.next_id-1
	editor.begin(Vector3i.ZERO); editor.toolbar.get_child(3).pressed.emit()
	editor.hovered={"kind":"gutter","id":gutter_id}; game._unhandled_input(click)
	check(editor.path.size()==1 and editor.gutter==gutter_id,"Pipe input begins at the selected gutter outlet")
	editor.spec={"waypoint":editor.path[0]+Vector3(0,-0.25,1)}; game._unhandled_input(click)
	check(editor.path.size()==2,"Clicking a bend extends the drawn route")
	var undo:=InputEventKey.new(); undo.keycode=KEY_BACKSPACE; undo.pressed=true; game._unhandled_input(undo)
	check(editor.path.size()==1,"Backspace removes the last route bend without deleting a fitting")
	var old_height: float=editor.route_height
	for child in editor.toolbar.get_children():
		if child is Button and child.text=="↓": child.pressed.emit(); break
	check(is_equal_approx(editor.route_height,old_height-0.25),"Pipe height changes in quarter-metre increments")
	editor.ground_button.button_pressed=true
	check(editor.path.size()==1,"Choosing a ground outlet preserves the drawn route")
	var outlet:=Vector3i(3,0,4); var start: Vector3=editor.path[0]
	editor.spec=editor.routed([start,Vector3(start.x,start.y-0.02,3),rain.end_point(world,{"outfall":outlet})],{"outfall":outlet})
	game._unhandled_input(click)
	check(world.plans.values().any(func(p):return p.kind=="rain_fitting" and p.rain_spec.has("outfall")),"Ground outlet input queues a real paid pipe route")
	editor.cancel()
	game.free(); fixture.free()
	if failures.is_empty(): print("PASS: Rain action, room floor handoff, placement input and editor dismissal")
	quit(0 if failures.is_empty() else 1)
