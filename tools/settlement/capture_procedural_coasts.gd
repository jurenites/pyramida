extends SceneTree
const View=preload("res://scripts/settlement/solid_island_view.gd")
class PreviewWorld extends RefCounted:
	var world_seed:=1409
	var generator_version:=15
	var difficulty:="easy"
	var loaded_chunks: Dictionary={}
	var terrain_excavations: Array=[]
	var streaming_enabled:=false
	var water_sources: Dictionary={}
	var terrain_shapes: Dictionary={}
func _initialize() -> void:
	root.unfocusable=true; root.hide(); call_deferred("capture")
func capture() -> void:
	var screen:=SubViewport.new(); screen.size=Vector2i(1440,1120); screen.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(screen)
	var worlds: Array=[]
	RenderingServer.global_shader_parameter_set("settlement_daylight",1.0)
	for i in 4:
		var panel:=SubViewportContainer.new(); panel.position=Vector2((i%2)*720,(i/2)*560); panel.size=Vector2(720,560); screen.add_child(panel)
		var viewport:=SubViewport.new(); viewport.size=Vector2i(720,560); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; viewport.msaa_3d=Viewport.MSAA_4X; panel.add_child(viewport)
		var world:=PreviewWorld.new(); world.world_seed=[1409,42,9182,101][i]; world.difficulty="easy" if i<2 else "normal"; worlds.append(world)
		var terrain:=View.new(); viewport.add_child(terrain); terrain.sync(world)
		var main: Dictionary=terrain.Islands.definitions(world.world_seed,15)[0]
		var main_key:=hash([world.world_seed,world.difficulty,15,main.coast])
		for key in terrain.island_nodes: terrain.island_nodes[key].visible=key==main_key
		var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-55,-30,0); light.shadow_enabled=true; viewport.add_child(light)
		var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color("176f7b"); viewport.add_child(environment)
		var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=81; viewport.add_child(camera)
		var at:=Vector3(-5,3,0); camera.position=at+Vector3(1,0.9,1.25).normalized()*100; camera.look_at(at); camera.current=true
		var label:=Label.new(); label.text=("Fields" if i<2 else "Sand")+" / Seed "+str(world.world_seed); label.position=panel.position+Vector2(20,16); label.add_theme_font_size_override("font_size",20); screen.add_child(label)
	for frame in 18: await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://artifacts/settlement/unique-island-coasts.png")
	screen.free(); print("PASS: four production seeded coastline previews"); quit()
