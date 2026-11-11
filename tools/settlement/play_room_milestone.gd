extends SceneTree
## Live integration fixture in the real settlement scene. Player saves stay untouched.
const Fixture=preload("res://tests/settlement/room_construction_test.gd")
const Rooms=preload("res://scripts/settlement/room_construction.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1100,760)
	root.title="... Town · Room construction"
	var game=preload("res://scripts/settlement/settlement.gd").new()
	game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-room-practice"
	root.add_child(game)
	game.model=Fixture.fixture()
	game.rig.focus=Vector3(0.5,1,1.5); game.rig.yaw=-2.55; game.rig.pitch=0.68; game.rig.zoom=11
	game.rig.update_camera()
	game.hud.build_panel.hide()
	game.room_editor.sync(); game.room_editor.set_active(true); game.room_editor.set_floor(1)
	for y in 2:
		for x in 2:
			for z in 2: Fixture.place(game.model,"cube",Vector3i(x,y,z))
	# Let the real workers finish the frame before requesting its interior.
	while is_instance_valid(game) and not game.model.plans.is_empty(): await process_frame
	if not is_instance_valid(game): return
	# Editing the prepared layout is allowed; do not overwrite a player's changes.
	if game.model.room_site.get("built",[]).size()!=8: return
	if not Fixture.place(game.model,"stairs",Vector3i(0,0,1)): return
	if not Fixture.place(game.model,"room_domino",Vector3i(1,1,0),[0,0,0],[-1,0,0]): return
	Rooms.add_bed(game.model,Vector3i(1,1,0))
	game.room_editor.mode=2; game.room_editor.revision=-1
