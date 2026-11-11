extends SceneTree
const Game=preload("res://scripts/settlement/settlement.gd")
const Model=preload("res://scripts/settlement/world_model.gd")
const Stack=preload("res://scripts/settlement/home_stack.gd")
func _initialize() -> void:
	root.unfocusable=true; root.hide(); call_deferred("run")
func run() -> void:
	var model=Model.new(); model.world_seed=1409; model.streaming_enabled=false; model.difficulty="normal"; model.generator_version=11
	for x in range(-14,15):
		for z in range(-10,11): model.ground[Vector3i(x,0,z)]=true
	for item in [[-6,0.35],[0,0.75],[6,1.5]]:
		var x: int=item[0]; var offset: float=item[1]
		for z in [0,2]: model.buildings[Vector3i(x,0,z)]={"kind":"house","direction":0,"house_tier":2}
		model.buildings[Vector3i(x+2,0,2)]={"kind":"house","direction":1,"house_tier":2}
		var cell:=Vector3i(x+roundi(offset),2,0)
		var shift:=Vector3(offset-roundi(offset),0,0)
		assert(Stack.plan(model,cell,shift).error.is_empty(),"Support cannot fit")
		model.buildings[cell]={"kind":"house","direction":0,"house_tier":1,"placement_offset":shift}
		model.stairs[Vector3i(x,0,4)]=3
	model.rebuild_navigation()
	for item in [[-6,0.35],[0,0.75],[6,1.5]]:
		var x: int=item[0]; var target:=Vector3i(x+roundi(item[1]),2,0)
		assert(not model.navigation.route(Vector3i(x,0,6),target).is_empty(),"Stairs must reach the rotated upper Home")
	var display:=SubViewport.new(); display.size=Vector2i(1800,1100); display.own_world_3d=true; display.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(display)
	var game=Game.new(); game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-fence-capture"; display.add_child(game)
	game.set_process(false); game.generated_building_tool.set_process(false); game.model=model
	model.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
	game.world.fog_enabled=false; game.fog.visible=false; game.world.sync(model,0,-1)
	game.rig.focus=Vector3(0.4,1,1); game.rig.yaw=-0.65; game.rig.pitch=0.60; game.rig.zoom=18; game.rig.update_camera()
	model.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
	game.hud.update(model,-1,1,{}); game.hud.build_panel.hide(); game.Illustration.update(game.world_container.material,model.time)
	for i in 16: await process_frame
	await RenderingServer.frame_post_draw
	display.get_texture().get_image().save_png("res://artifacts/settlement/rotated-home-stacks.png")
	game.rig.focus=Vector3(0.8,1.1,1.2); game.rig.yaw=-0.8; game.rig.zoom=7.5; game.rig.update_camera()
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	display.get_texture().get_image().save_png("res://artifacts/settlement/rotated-home-detail.png")
	model.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.24
	game.world.scenery.update_lighting(model.time); game.Illustration.update(game.world_container.material,model.time)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	display.get_texture().get_image().save_png("res://artifacts/settlement/sunlit-roof-detail.png")
	print("PASS: main-game rotated off-grid Homes with 0.35 m, 0.75 m and 1.5 m offsets, fences and stairs rendered")
	game.free(); quit()
