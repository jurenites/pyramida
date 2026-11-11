extends SceneTree
const Game=preload("res://scripts/settlement/settlement.gd")
const Model=preload("res://scripts/settlement/world_model.gd")
const Preview=preload("res://scripts/settlement/home_placement_preview.gd")
func _initialize() -> void:
	root.unfocusable=true; root.hide(); call_deferred("run")
func run() -> void:
	var model=Model.new(); model.world_seed=1409; model.streaming_enabled=false; model.difficulty="normal"; model.generator_version=11
	for x in range(-14,15):
		for z in range(-10,11): model.ground[Vector3i(x,0,z)]=true
	for x in [-5,0,5]: model.buildings[Vector3i(x,0,0)]={"kind":"house","direction":0,"house_tier":2}
	model.buildings[Vector3i(-5,2,0)]={"kind":"house","direction":0,"house_tier":1,"placement_offset":Vector3(0.3,0,0)}
	model.buildings[Vector3i(1,2,0)]={"kind":"house","direction":0,"house_tier":1,"placement_offset":Vector3(-0.25,0,0)}
	model.rebuild_navigation()
	var display:=SubViewport.new(); display.size=Vector2i(1540,1000); display.own_world_3d=true; display.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(display)
	var game=Game.new(); game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-overhang-capture"; display.add_child(game)
	game.set_process(false); game.generated_building_tool.set_process(false); game.model=model
	game.world.fog_enabled=false; game.fog.visible=false; game.world.sync(model,0,-1)
	game.tool="house"; game.hovered=Vector3i(7,2,0); game.direction=0; game.hover_offset=Vector3(-0.5,0,0); game._refresh_preview()
	game.preview.position=Vector3(6.5,2,0); game.preview.visible=true
	Preview.sync(game.preview,model,game.hovered,0,game.hover_offset)
	Game.Assets.tint(game.preview,Color(0.75,0.9,0.75))
	game.rig.focus=Vector3(1,1,0); game.rig.yaw=0.35; game.rig.pitch=0.60; game.rig.zoom=17; game.rig.update_camera()
	model.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
	game.hud.update(model,-1,1,{}); game.hud.build_panel.hide(); game.Illustration.update(game.world_container.material,model.time)
	for i in 16: await process_frame
	await RenderingServer.frame_post_draw
	display.get_texture().get_image().save_png("res://artifacts/settlement/overhang-preview.png")
	print("PASS: main-game 0.3 m, 0.75 m and live 1.5 m support preview rendered")
	game.free(); quit()
