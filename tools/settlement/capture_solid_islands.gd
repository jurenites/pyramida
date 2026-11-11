extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size=Vector2i(1440,980)
	var game=load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu=false; game.slot_directory="/tmp/town-solid-capture-%d"%Time.get_ticks_usec()
	root.add_child(game); game.speed=0; game.capture=true; game.set_process(false)
	var model:=Model.new(); model.setup(1409,"easy")
	game.model=model; game.world.last_revision=-1; game.fog.visible=false; game.world.fog_enabled=false
	game.world.sync(model,0,-1); game.hud.hide()
	game.rig.focus=Vector3(2,1,2); game.rig.zoom=113; game.rig.yaw=0.2; game.rig.pitch=1.0; game.rig.update_camera()
	for index in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/greece-islands.png")
	game.rig.focus=Vector3(-22,4,-15); game.rig.zoom=37; game.rig.yaw=1.0; game.rig.pitch=0.55; game.rig.update_camera()
	for index in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/main-irregular-terraces.png")
	model.trees.clear(); model.deposits.clear(); model.rebuild_navigation()
	var islands=preload("res://scripts/settlement/solid_islands.gd")
	var target:=Vector3i.ZERO; var outside:=Vector3.ZERO
	for cell: Vector3i in model.ground:
		if cell.y!=0: continue
		for step in model.DIRECTIONS:
			var at: Vector3i=cell+step
			if not islands.solid(model,Vector3(at)+Vector3.UP*0.5) or not islands.solid(model,Vector3(at)+Vector3.UP*2.1): continue
			if model.build_error("support",at).is_empty() and preload("res://scripts/settlement/support_runtime.gd").foundation_error(model,at,Vector3.ZERO,0).is_empty():
				target=at; outside=-Vector3(step); break
		if outside!=Vector3.ZERO: break
	if outside==Vector3.ZERO: printerr("FAIL: no accessible excavation fixture"); quit(1); return
	var focus:=Vector3(target)+Vector3.UP*1.4
	var angle:=atan2(outside.x,outside.z)
	var query:=PhysicsRayQueryParameters3D.create(focus+outside*3,focus-outside*2,1)
	await physics_frame
	var before: Dictionary=game.viewport.world_3d.direct_space_state.intersect_ray(query)
	if before.is_empty() or not before.collider.has_meta("terrain"): printerr("FAIL: solid terrain picking"); quit(1); return
	game.rig.focus=Vector3(target)+Vector3.UP*1.2; game.rig.zoom=8; game.rig.yaw=angle; game.rig.pitch=0.4; game.rig.update_camera()
	game.tool="support"
	var picked: Dictionary=game.placement_at(game.rig.camera.unproject_position(before.position),false)
	if picked.is_empty() or picked.cell.y>2: printerr("FAIL: cliff placement picks the visible face rather than the mountain summit"); quit(1); return
	game.tool="inspect"
	for y in [0,1]:
		if not model.request_build("support",target+Vector3i.UP*y,0,outside*0.4) or not model.debug_finish_plan(model.next_plan_id-1):
			printerr("FAIL: excavation construction ",model.last_message); quit(1); return
	game.world.sync(model,0,-1)
	for index in 12: await process_frame
	await physics_frame
	var after: Dictionary=game.viewport.world_3d.direct_space_state.intersect_ray(query)
	if after.is_empty() or (before.position-after.position).dot(outside)<0.2: printerr("FAIL: physical tunnel opening ",before," -> ",after); quit(1); return
	if model.navigation.edges.get(target,[]).is_empty(): printerr("FAIL: passage has no outside route"); quit(1); return
	game.rig.focus=Vector3(target)+Vector3.UP*1.2; game.rig.zoom=8; game.rig.yaw=angle; game.rig.pitch=0.40; game.rig.update_camera()
	for index in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/main-support-excavation.png")
	print("PASS: main terrain rendering, picking, physical tunnel collision and passage access")
	quit()
