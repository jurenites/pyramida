extends SceneTree
## Run through a non-activating launcher with no_focus/minimized project overrides.
const Ocean=preload("res://scripts/settlement/ocean_surface.gd")
var failures: Array[String]=[]
func check(value: bool,message: String) -> void:
	if not value: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void:
	check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"Capture native window must start unfocusable")
	root.unfocusable=true
	root.hide()
	call_deferred("capture")
func frame_image(viewport: SubViewport) -> Image:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func difference(a: Image,b: Image) -> float:
	var sum:=0.0; var count:=0
	for y in range(80,940,9):
		for x in range(80,940,9):
			var ca:=a.get_pixel(x,y); var cb:=b.get_pixel(x,y)
			sum+=Vector3(ca.r,ca.g,ca.b).distance_to(Vector3(cb.r,cb.g,cb.b)); count+=1
	return sum/count
func uniform_coast(material: ShaderMaterial,shore: float,exposure: float,land: float) -> void:
	var data:=Image.create(2,2,false,Image.FORMAT_RGBAF); data.fill(Color(shore,exposure,land,1))
	material.set_shader_parameter("coast_field",ImageTexture.create_from_image(data))
	material.set_shader_parameter("coast_bounds",Vector4(-40,-40,80,80))
	material.set_shader_parameter("coast_enabled",true)
func capture() -> void:
	var viewport:=SubViewport.new(); viewport.size=Vector2i(1024,1024); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var material:=ShaderMaterial.new(); material.shader=preload("res://shaders/island_water.gdshader")
	material.set_shader_parameter("wind_direction",Vector2.RIGHT)
	var sea:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2.ONE*80; sea.mesh=plane; sea.material_override=material; viewport.add_child(sea)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=32
	viewport.add_child(camera); camera.position=Vector3(0,30,0); camera.look_at(Vector3.ZERO,Vector3.FORWARD); camera.current=true
	material.set_shader_parameter("wave_time_override",0.0)
	var first: Image=await frame_image(viewport)
	material.set_shader_parameter("wave_time_override",0.8)
	var second: Image=await frame_image(viewport)
	# 1.25 m/s * 0.8 s = 1 m = 32 pixels: the pattern must travel downwind.
	var forward:=0.0; var backward:=0.0; var still:=0.0; var samples:=0
	for y in range(80,940,9):
		for x in range(80,940,9):
			var colour:=Vector3(second.get_pixel(x,y).r,second.get_pixel(x,y).g,second.get_pixel(x,y).b)
			var a:=first.get_pixel(x-32,y); var b:=first.get_pixel(x+32,y); var c:=first.get_pixel(x,y)
			forward+=colour.distance_to(Vector3(a.r,a.g,a.b)); backward+=colour.distance_to(Vector3(b.r,b.g,b.b)); still+=colour.distance_to(Vector3(c.r,c.g,c.b)); samples+=1
	check(forward<backward*0.3 and forward<still*0.3,"Rendered waves move downwind at the configured speed")
	print("Wave advection errors: downwind=",forward/samples," upwind=",backward/samples," stationary=",still/samples)
	uniform_coast(material,100,0.18,100)
	material.set_shader_parameter("wave_time_override",0.0)
	var sheltered_first: Image=await frame_image(viewport)
	material.set_shader_parameter("wave_time_override",0.8)
	var sheltered_second: Image=await frame_image(viewport)
	var sheltered_change:=difference(sheltered_first,sheltered_second)
	check(sheltered_change<still/samples*0.4,"Sheltered water has visibly less wave motion")
	# Change a real opaque floor's colour under the water: the shallow surface must
	# transmit much more of it than the deep surface, rather than merely tinting blue.
	var floor_node:=MeshInstance3D.new(); floor_node.mesh=plane
	var floor_material:=StandardMaterial3D.new(); floor_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_node.material_override=floor_material; viewport.add_child(floor_node)
	uniform_coast(material,8,1,8)
	material.set_shader_parameter("wave_time_override",0.0)
	var contrasts: Array[float]=[]
	for depth in [0.35,8.0]:
		floor_node.position.y=-depth
		floor_material.albedo_color=Color(0.7,0.25,0.15)
		var red: Image=await frame_image(viewport)
		floor_material.albedo_color=Color(0.15,0.25,0.7)
		var blue: Image=await frame_image(viewport)
		contrasts.append(difference(red,blue))
	check(contrasts[0]>0.1 and contrasts[0]>contrasts[1]*5,"Shallows reveal actual submerged geometry; deep water absorbs it")
	var no_foam: Image=await frame_image(viewport)
	uniform_coast(material,0.12,1,8)
	var foam_first: Image=await frame_image(viewport)
	material.set_shader_parameter("wave_time_override",1.8)
	var foam_second: Image=await frame_image(viewport)
	uniform_coast(material,8,1,8)
	var no_foam_peak: Image=await frame_image(viewport)
	uniform_coast(material,0.12,1,8)
	material.set_shader_parameter("wave_time_override",4.9)
	var foam_faded: Image=await frame_image(viewport)
	uniform_coast(material,8,1,8)
	var no_foam_faded: Image=await frame_image(viewport)
	var impact:=difference(no_foam_peak,foam_second)
	check(impact>0.005,"Arriving packets produce contact foam")
	check(difference(no_foam,foam_first)<impact*0.15,"No permanent foam before the wave hits")
	check(difference(no_foam_faded,foam_faded)<impact*0.15,"Foam fades after impact before the next packet")
	print("Coastal GPU checks: sheltered motion=",sheltered_change," floor contrast shallow/deep=",contrasts," foam change=",difference(foam_first,foam_second))
	viewport.queue_free(); await process_frame
	# Capture the actual main game camera into its offscreen 3D viewport.
	var game=load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu=false; game.slot_directory="/tmp/town-wind-capture-%d"%Time.get_ticks_usec()
	root.add_child(game); game.speed=0; game.capture=true; game.set_process(false)
	var model=preload("res://scripts/settlement/world_model.gd").new(); model.setup(1409,"easy")
	game.model=model; game.world.last_revision=-1; game.fog.visible=false; game.world.fog_enabled=false; game.hud.hide()
	game.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	game.world.sync(model,0,-1)
	# Use the game's own final grading pass; the raw HDR 3D texture is linear.
	var output:=SubViewport.new(); output.size=game.viewport.size; output.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(output)
	var picture:=TextureRect.new(); picture.texture=game.viewport.get_texture(); picture.material=game.world_container.material
	picture.size=Vector2(output.size); output.add_child(picture)
	var water: ShaderMaterial=game.world.scenery.solid_view.sea.material_override
	var sand: ShaderMaterial=game.world.scenery.solid_view.seabed.material_override
	sand.set_shader_parameter("wave_time_override",0.0)
	check(is_equal_approx(game.world.scenery.solid_view.sea.position.y,Ocean.LEVEL),"Rendered sea matches shoreline height")
	game.rig.focus=Vector3(-6,2,-1); game.rig.zoom=78; game.rig.yaw=1.0; game.rig.pitch=0.55; game.rig.update_camera()
	water.set_shader_parameter("wave_time_override",0.0)
	var overview: Image=await frame_image(output)
	overview.save_png("res://artifacts/settlement/wind-water-island.png")
	game.rig.focus=Vector3(-23,1,8); game.rig.zoom=31; game.rig.yaw=1.1; game.rig.pitch=0.60; game.rig.update_camera()
	var shore: Image=await frame_image(output)
	shore.save_png("res://artifacts/settlement/raised-shore-water.png")
	for i in 60:
		water.set_shader_parameter("wave_time_override",float(i)/12.0)
		sand.set_shader_parameter("wave_time_override",float(i)/12.0)
		var frame: Image=await frame_image(output)
		frame.save_png("/tmp/town-wave-%03d.png"%i)
	if failures.is_empty(): print("PASS: downwind travel, bay attenuation, translucent shallows, animated foam and main-game shoreline")
	quit(int(not failures.is_empty()))
