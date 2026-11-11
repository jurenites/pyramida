extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Rain=preload("res://scripts/settlement/roof_rain.gd")
func _initialize() -> void:
	root.unfocusable=true; root.hide(); call_deferred("run")
func finish(world,spec: Dictionary) -> bool:
	if not Rain.request(world,spec): return false
	return world.debug_finish_plan(world.next_plan_id-1)
func run() -> void:
	var world:=Model.new()
	if not world.restore(JSON.parse_string(FileAccess.get_file_as_string("/tmp/pyramida-reef-village-preview.json"))): printerr("FAIL: reef preview snapshot"); quit(1); return
	var centre: Vector2=preload("res://scripts/settlement/solid_islands.gd").definitions(world.world_seed,world.generator_version)[0].reefs[0].centre
	var anchor:=Vector3i(roundi(centre.x),1,roundi(centre.y))
	var receivers: Array[Vector3i]=[]
	for index in 2:
		var point:=Vector3(anchor)+Vector3(-1.5+index*3.0,0,0.8)
		var cell:=Vector3i(roundi(point.x),anchor.y,roundi(point.z))
		if not finish(world,{"kind":"barrel" if index==1 else "vase","cell":cell,"offset":point-Vector3(cell)}): printerr("FAIL: gap vessel ",world.last_message); quit(1); return
		receivers.append(cell)
	var lanes:=Rain.roof_lanes(world,true); var count:=0
	for cell in receivers:
		var end:=Rain.inlet(world,cell)
		var keys:=lanes.keys(); keys.sort_custom(func(a,b):return lanes[a].b.distance_to(end)<lanes[b].b.distance_to(end))
		for key in keys:
			if lanes[key].cell.y!=1 or not key.ends_with(":s7"): continue
			if not finish(world,{"kind":"gutter","lane":key}): continue
			var gutter: int=world.roof_rain.next_id-1
			var start: Vector3=lanes[key].b
			var connected:=false
			for path in [[start,Vector3(end.x,start.y-0.06,end.z),end],[start,end]]:
				if finish(world,{"kind":"pipe","gutter":gutter,"target":cell,"path":path}): connected=true; count+=1; break
			if not connected: Rain.remove(world,{"kind":"gutter","id":gutter})
			else:
				for section in 7: finish(world,{"kind":"gutter","lane":key.trim_suffix("s7")+"s%d" % section})
				break
	if count!=2: printerr("FAIL: two real gutter connections"); quit(1); return
	for i in world.workers.size():
		var cell:=anchor+Vector3i((i-1)*4,0,2)
		world.workers[i].cell=cell; world.workers[i].position=world.navigation.surface_point(cell)
	world.weather.raining=true
	for i in 48: Rain.rain_second(world)
	world.time=35
	var screen:=SubViewport.new(); screen.size=Vector2i(1600,1100); screen.own_world_3d=true; screen.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(screen)
	var game=load("res://scenes/settlement/Terraces.tscn").instantiate(); game.capture=true; game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-rain-preview-slots"
	screen.add_child(game); game.set_process(false); game.speed=0; game.model=world; game.world.last_revision=-1; game.world.fog_enabled=false; game.fog.visible=false; game.hud.hide()
	game.world.sync(world,0,-1); game.Illustration.update(game.world_container.material,world.time)
	game.world.water_view.rain.position=Vector3(anchor.x,36.0,anchor.z)
	game.rig.focus=Rain.floor_position(world,anchor)+Vector3.UP*0.9; game.rig.yaw=-0.35; game.rig.pitch=0.8; game.rig.zoom=14; game.rig.update_camera()
	for frame in 20: await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://artifacts/settlement/reef-rain-collection.png")
	game.rig.zoom=24; game.rig.update_camera()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://artifacts/settlement/reef-rain-wide.png")
	game.rig.focus=Rain.floor_position(world,anchor)+Vector3(-1.5,1.1,0.5); game.rig.zoom=7; game.rig.yaw=0.6; game.rig.pitch=1.1; game.rig.update_camera()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://artifacts/settlement/reef-rain-detail.png")
	game.rig.focus=Rain.tank_position(world,receivers[1])+Vector3.UP*0.95; game.rig.zoom=4.5; game.rig.yaw=-0.8; game.rig.pitch=0.7; game.rig.update_camera()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://artifacts/settlement/reef-rain-barrel.png")
	game.rig.focus=Rain.floor_position(world,anchor)+Vector3.UP*0.9; game.rig.yaw=-0.35; game.rig.pitch=0.8
	game.rig.zoom=14; game.rig.update_camera()
	game.rain_editor.begin(anchor)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://artifacts/settlement/reef-rain-editor.png")
	game.rain_editor.cancel()
	var exposure=load("res://scripts/settlement/rain_exposure.gd")
	var worker: Dictionary=world.workers[0]
	world.roof_rain.wet[worker.cell]=1.0
	for step in 90:
		exposure.movement(world,worker,worker.cell,0.1)
		if worker.get("slip_remaining",0)>0: break
	exposure.recover(worker,0.4)
	game.world.sync(world,0.1,-1)
	game.rig.focus=worker.position+Vector3.UP*0.5; game.rig.zoom=5; game.rig.pitch=0.55; game.rig.yaw=-0.6; game.rig.update_camera()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://artifacts/settlement/reef-rain-slip.png")
	game.free(); print("PASS: gap vessels, half-round gutters, connected pipes and Rain editing toolbar rendered"); quit()
