extends SceneTree
## Render-only contact sheet of the production generator; no gameplay/save changes.
const Islands=preload("res://scripts/settlement/solid_islands.gd")
class PreviewWorld extends RefCounted:
	var world_seed := 1409
	var generator_version := 8
	var loaded_chunks := {}
	var terrain_excavations := []
	var streaming_enabled := false
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.size=Vector2i(1440,1000)
	for i in 3: await process_frame
	var tile := root.get_visible_rect().size*0.5
	var world := World3D.new()
	var data := PreviewWorld.new()
	var viewports: Array[SubViewport] = []
	var islands:=Islands.definitions(data.world_seed,8)
	for i in 4:
		var container := SubViewportContainer.new()
		container.position=Vector2(i%2,i/2)*tile
		container.size=tile; container.stretch=true
		root.add_child(container)
		var viewport:=SubViewport.new(); viewport.size=Vector2i(tile); viewport.world_3d=world
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; viewport.msaa_3d=Viewport.MSAA_4X
		container.add_child(viewport); viewports.append(viewport)
		if i==0:
			var terrain=preload("res://scripts/settlement/solid_island_view.gd").new()
			viewport.add_child(terrain); terrain.sync(data)
			terrain.sea.layers=32
			for index in islands.size():
				var group: Node3D=terrain.island_nodes[hash([data.world_seed,8,islands[index].coast])]
				for child in group.get_children():
					if child is VisualInstance3D: child.layers=1<<index
			var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-55,-30,0); light.shadow_enabled=true; viewport.add_child(light)
			var env:=WorldEnvironment.new(); env.environment=Environment.new()
			env.environment.background_mode=Environment.BG_COLOR; env.environment.background_color=Color("176f7b"); viewport.add_child(env)
		var island: Dictionary=islands[i+1]
		var at: Vector3=island.transform.origin+Vector3.UP*island.top_height*0.4
		var side: Vector2=island.cliff_direction.rotated(-0.9)
		var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		camera.size=24 if island.family!="headland" else 27
		camera.cull_mask=(1<<(i+1))|32
		viewport.add_child(camera); camera.position=at+Vector3(side.x,0.8,side.y).normalized()*60
		camera.look_at(at); camera.current=true
		var label:=Label.new(); label.text=island.family.capitalize(); label.position=container.position+Vector2(24,16)
		label.add_theme_font_size_override("font_size",24); label.add_theme_color_override("font_color",Color("fef1cf")); root.add_child(label)
	RenderingServer.global_shader_parameter_set("settlement_daylight",1.0)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/generated-island-variety.png")
	print("PASS: captured production-generated island variety")
	quit()
