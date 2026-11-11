extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size=Vector2i(1440,980)
	var game=load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-island-capture-%d"%Time.get_ticks_usec()
	root.add_child(game); game.speed=0; game.capture=true; game.set_process(false)
	var model=preload("res://scripts/settlement/world_model.gd").new(); model.setup(1409,"easy")
	game.model=model; game.world.last_revision=-1; game.fog.visible=false; game.world.fog_enabled=false
	game.world.sync(model,0,-1); game.hud.hide()
	game.rig.focus=Vector3(2,1,2); game.rig.zoom=113; game.rig.yaw=0.2; game.rig.pitch=1.0; game.rig.update_camera()
	for index in 16: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/greece-islands.png")
	# Clear only the isolated capture fixture's building pad, never a player save.
	for collection in [model.trees,model.deposits,model.gardens]:
		for cell in collection.keys():
			if cell.x>=2 and cell.x<=8 and cell.z>=0 and cell.z<=5: collection.erase(cell)
	for worker in model.workers:
		worker.cell=Vector3i(0,0,-4); worker.position=Vector3(0,0,-4)
	model.rebuild_navigation()
	# Actual settlement construction, including the saved small rotation.
	for x in [3,4]:
		for z in [2,3]:
			for y in [0,1]:
				if not model.request_build("support",Vector3i(x,y,z)) or not model.debug_finish_plan(model.next_plan_id-1):
					printerr("FAIL: support fixture ",Vector3i(x,y,z)," ",model.last_message); quit(1); return
	for x in [5,6]:
		for z in [2,3]:
			for y in [0,1]:
				var at: Vector3 = Vector3(5.1,y,2)+Basis(Vector3.UP,deg_to_rad(4))*Vector3(x-5,0,z-2)
				if not model.request_build("support",Vector3i(x,y,z),0,at-Vector3(x,y,z),true,deg_to_rad(4)) or not model.debug_finish_plan(model.next_plan_id-1):
					printerr("FAIL: rotated fixture ",Vector3i(x,y,z)," ",model.last_message); quit(1); return
	game.world.sync(model,0,-1)
	game.rig.focus=Vector3(4.5,1,2.5); game.rig.zoom=8; game.rig.pitch=0.6; game.rig.yaw=0.55; game.rig.update_camera()
	for index in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/main-support-fitting.png")
	print("PASS: captured main-game islands and fitted Supports")
	quit()
