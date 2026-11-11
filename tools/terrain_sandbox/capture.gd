extends SceneTree
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame
func run() -> void:
	root.size = Vector2i(1440,980)
	var sandbox = load("res://scenes/terrain_sandbox/TerrainSandbox.tscn").instantiate()
	sandbox.capture_mode = true
	root.add_child(sandbox)
	sandbox.toolbar.hide()
	await settle()
	for z in range(8,2,-1):
		for x in [0,1]:
			for y in [2,3]:
				if not sandbox.terrain.place_support(Vector3(x,y,z)):
					printerr("FAIL: underground Support fixture ",Vector3(x,y,z)); quit(1); return
				await settle()
	for x in [2,3,4.1,5.1]:
		for z in [2,3]:
			for y in [6.6,7.6]:
				if not sandbox.terrain.place_support(Vector3(x,y,z+(0.1 if x>4 else 0.0))):
					printerr("FAIL: surface Support fixture ",Vector3(x,y,z)); quit(1); return
				await settle()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/support-mountain.png")
	sandbox.rig.focus = Vector3(0.5,3.1,7)
	sandbox.rig.yaw = 0.18; sandbox.rig.pitch = 0.16; sandbox.rig.zoom = 9
	sandbox.rig.update_camera()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/support-excavation.png")
	sandbox.rig.focus = Vector3(3.5,7.6,2.5)
	sandbox.rig.yaw = 0.56; sandbox.rig.pitch = 0.6; sandbox.rig.zoom = 7
	sandbox.rig.update_camera()
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/support-joins.png")
	print("PASS: captured Support construction above and inside the mountain")
	quit()
