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
	game.rig.focus=Vector3(-6,2,-1); game.rig.zoom=78; game.rig.yaw=1.0; game.rig.pitch=0.55; game.rig.update_camera()
	for index in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/main-generated-island.png")
	game.rig.focus=Vector3(-23,2,8); game.rig.zoom=29; game.rig.yaw=1.1; game.rig.pitch=0.60; game.rig.update_camera()
	for index in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/eroded-coast-detail.png")
	print("PASS: captured main island generator in the main game")
	quit()
