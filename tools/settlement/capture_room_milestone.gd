extends SceneTree
## Isolated visual check of the actual settlement; never writes a player save.
const Game=preload("res://scripts/settlement/settlement.gd")
const Fixture=preload("res://tests/settlement/room_construction_test.gd")
const Rooms=preload("res://scripts/settlement/room_construction.gd")
func _initialize() -> void: call_deferred("run")
func capture(game,name: String,phase:=0.125) -> void:
	game.model.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*phase
	game.Illustration.update(game.world_container.material,game.model.time)
	for actor in game.world.actors: actor.has_position=false
	game.world.sync(game.model,0,-1); game.room_editor.revision=-1; game.room_editor.sync()
	game.hud.update(game.model,-1,1,{})
	game.room_editor.sync()
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/settlement/"+name+".png")
func run() -> void:
	root.size=Vector2i(1100,760)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/settlement"))
	var game=Game.new(); game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-room-capture"
	root.add_child(game); game.set_process(false)
	game.model=Fixture.fixture(); game.room_editor.sync(); game.room_editor.set_active(true)
	game.hud.build_panel.hide(); game.world.fog_enabled=false
	game.rig.focus=Vector3(0.5,1,1.5); game.rig.yaw=-2.55; game.rig.pitch=0.58; game.rig.zoom=10; game.rig.update_camera()
	for y in 2:
		for x in 2:
			for z in 2: assert(Fixture.place(game.model,"cube",Vector3i(x,y,z)))
	await capture(game,"room-frame-planned")
	for step in 6000:
		game.model.tick(0.05)
		if game.model.plans.is_empty(): break
	assert(game.model.plans.is_empty())
	game.room_editor.set_floor(1)
	await capture(game,"room-frame-built")
	assert(Fixture.place(game.model,"stairs",Vector3i(0,0,1)))
	assert(Fixture.place(game.model,"room_domino",Vector3i(1,1,0),[0,0,0],[-1,0,0]))
	assert(Rooms.add_bed(game.model,Vector3i(1,1,0)))
	for step in 6000:
		game.model.tick(0.05)
		if game.model.plans.is_empty(): break
	assert(game.model.plans.is_empty())
	var target:=Rooms.bed_access(game.model,game.model.room_site.beds[0])
	game.model.workers[0].job={}; game.model.workers[0].route=[]
	assert(game.model.order_move(0,target))
	for step in 2000:
		game.model.tick(0.05)
		if game.model.workers[0].cell==target: break
	assert(game.model.workers[0].cell==target)
	game.room_editor.mode=2
	await capture(game,"room-upstairs-bed")
	game.room_editor.mode=0
	await capture(game,"room-house-roofed")
	game.room_editor.mode=2
	await capture(game,"room-upstairs-night",0.75)
	print("PASS: captured main-game frame, infill, stairs and upstairs bed")
	game.free(); quit()
