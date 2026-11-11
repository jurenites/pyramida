extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Islands = preload("res://scripts/settlement/solid_islands.gd")
const Fixture = preload("res://tests/settlement/reef_village_test.gd")
const SNAPSHOT = "/tmp/pyramida-reef-village-preview.json"
func _initialize() -> void:
	root.unfocusable=true; root.hide(); call_deferred("run")
func run() -> void:
	var world := Model.new()
	if "--prepare" in OS.get_cmdline_user_args():
		world.setup(1409,"easy")
		var centre: Vector2 = Islands.definitions(1409,18)[0].reefs[0].centre
		var at := Vector3i(roundi(centre.x),0,roundi(centre.y))
		var fixture := Fixture.new()
		fixture.build_village(world,at)
		if not fixture.failures.is_empty(): fixture.free(); quit(1); return
		var pad: Array[Vector3i] = []
		for x in range(-5,6):
			for z in range(-2,4):
				if absi(x)==5 and z in [-2,3]: continue
				pad.append(at+Vector3i(x,0,z))
		pad.sort_custom(func(a,b): return absi(a.x-at.x)+absi(a.z-at.z)<absi(b.x-at.x)+absi(b.z-at.z))
		for cell in pad:
			if not world.buildings.has(cell) and not fixture.finish(world,"support",cell): fixture.free(); quit(1); return
		for offset in [Vector3i(-3,1,0),Vector3i(3,1,0)]:
			if not fixture.finish(world,"house",at+offset): fixture.free(); quit(1); return
		for i in world.workers.size():
			var cell := at+Vector3i(i%5-2,1,2)
			world.workers[i].cell=cell; world.workers[i].position=world.navigation.surface_point(cell)
		var file := FileAccess.open(SNAPSHOT,FileAccess.WRITE)
		file.store_string(JSON.stringify(world.snapshot())); file.close()
		fixture.free(); print("PASS: three-Home reef village prepared through normal building placement"); quit(); return
	if not world.restore(JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT))): printerr("FAIL: preview snapshot"); quit(1); return
	var centre: Vector2 = Islands.definitions(world.world_seed,world.generator_version)[0].reefs[0].centre
	var screen := SubViewport.new(); screen.size=Vector2i(1600,1100); screen.own_world_3d=true
	screen.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(screen)
	var game=load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.capture=true; game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-reef-preview-slots"
	screen.add_child(game); game.set_process(false); game.speed=0
	game.model=world; game.world.last_revision=-1; game.world.fog_enabled=false; game.fog.visible=false; game.hud.hide()
	world.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
	game.world.sync(world,0,-1); game.Illustration.update(game.world_container.material,world.time)
	game.rig.focus=Vector3(centre.x,0.2,centre.y); game.rig.yaw=0.35; game.rig.pitch=0.7; game.rig.zoom=24; game.rig.update_camera()
	for frame in 24: await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://artifacts/settlement/reef-village.png")
	game.rig.zoom=39; game.rig.pitch=0.95; game.rig.update_camera()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://artifacts/settlement/reef-village-wide.png")
	print("PASS: production reef village close and wide previews captured")
	game.free(); quit()
