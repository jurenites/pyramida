extends SceneTree
const Style = preload("res://scripts/settlement/illustration_style.gd")
func _initialize() -> void:
	root.unfocusable=true; root.hide(); call_deferred("run")
func run() -> void:
	var view := SubViewport.new(); view.size = Vector2i(640, 640); view.own_world_3d = true; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; view.msaa_3d = Viewport.MSAA_4X; root.add_child(view)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new(); environment.environment.background_mode = Environment.BG_COLOR; environment.environment.background_color = Color("fef1cf"); view.add_child(environment)
	var wall := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(2, 2, 0.2); wall.mesh = box; wall.position.y = 1
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color("eee2c8"); wall.material_override = Style.shadowed(paint); view.add_child(wall)
	var neighbour := MeshInstance3D.new(); box = BoxMesh.new(); box.size = Vector3(1, 4, 1); neighbour.mesh = box; neighbour.position = Vector3(-1.6, 2, 2)
	paint = StandardMaterial3D.new(); paint.albedo_color = Color("ba674d"); neighbour.material_override = Style.shadowed(paint); view.add_child(neighbour)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -30, 0); Style.configure_sun(sun, 30); view.add_child(sun)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 5; camera.position = Vector3(0, 2.5, 8); view.add_child(camera); camera.look_at(Vector3(0, 1.5, 0))
	RenderingServer.global_shader_parameter_set("settlement_daylight", 1.0)
	neighbour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 24: await process_frame
	var without := view.get_texture().get_image()
	neighbour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for i in 24: await process_frame
	var with_shadow := view.get_texture().get_image()
	var max_change := 0.0; var changed := 0
	for x in range(-7, 8):
		for y in range(3, 18):
			var pixel := Vector2i(camera.unproject_position(Vector3(x * 0.1, y * 0.1, 0.101)))
			var difference := without.get_pixelv(pixel).v - with_shadow.get_pixelv(pixel).v
			max_change = maxf(max_change, difference)
			if difference > 0.025: changed += 1
	with_shadow.save_png("res://artifacts/settlement/building-shadow-check.png")
	print("Building receiver: %d darkened samples; max difference %.3f" % [changed, max_change])
	var passed := changed > 10 and max_change > 0.06
	# A face turned away from the sun keeps one ambient shade, regardless of
	# self-shadow-map precision. This is the roof/interior speckling regression.
	neighbour.visible = false; sun.rotation_degrees.y += 180; sun.shadow_enabled = false
	for i in 12: await process_frame
	var backlit_without := view.get_texture().get_image()
	sun.shadow_enabled = true
	for i in 12: await process_frame
	var backlit_with := view.get_texture().get_image(); var backlit_change := 0.0
	for x in range(-7, 8):
		for y in range(3, 18):
			var pixel := Vector2i(camera.unproject_position(Vector3(x * 0.1, y * 0.1, 0.101)))
			backlit_change = maxf(backlit_change, absf(backlit_with.get_pixelv(pixel).v - backlit_without.get_pixelv(pixel).v))
	passed = passed and backlit_change < 0.01
	print("Backlit self-shadow variation: %.4f" % backlit_change)
	var lamp:=OmniLight3D.new(); lamp.position=Vector3(0,0.25,0.7); lamp.omni_range=5; lamp.light_color=Color("ff8c24"); view.add_child(lamp)
	var lamp_change:=0.0
	for daylight in [1.0,0.15,0.0]:
		RenderingServer.global_shader_parameter_set("settlement_daylight",daylight)
		lamp.light_energy=0
		for i in 4: await process_frame
		var off:=view.get_texture().get_image()
		lamp.light_energy=20
		for i in 4: await process_frame
		var on:=view.get_texture().get_image()
		for x in range(-7,8):
			for y in range(3,18):
				var pixel:=Vector2i(camera.unproject_position(Vector3(x*0.1,y*0.1,0.101)))
				lamp_change=maxf(lamp_change,absf(off.get_pixelv(pixel).v-on.get_pixelv(pixel).v))
	passed=passed and lamp_change<0.005
	print("Point-light wall gradient: %.4f" % lamp_change)
	print("PASS: separate building casts a soft shadow onto the receiving wall" if passed else "FAIL: building shadow receiver")
	view.queue_free(); await process_frame; quit(0 if passed else 1)
