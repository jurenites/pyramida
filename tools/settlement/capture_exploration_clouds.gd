extends SceneTree
## Offscreen GPU review. Run only through render_background.py.
var failures: Array[String] = []
func _initialize() -> void:
	root.unfocusable = true; root.hide(); call_deferred("capture")
func picture(viewport: SubViewport) -> Image:
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); printerr("FAIL: ",message)
func capture() -> void:
	check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"Renderer starts without focus")
	var screen := SubViewport.new(); screen.size = Vector2i(1400,1000)
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(screen)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	screen.add_child(game)
	game.speed = 0; game.capture = true; game.set_process(false); game.hud.hide()
	game.rig.zoom = 90; game.rig.focus = Vector3(8,0,0); game.rig.update_camera()
	game.world.fog_enabled = true; game.world.sync(game.model,0,-1)
	game.fog.sync(game.model,true)
	check(game.fog.spheres.size() > 30,"Cloud bank contains real merged mesh instances")
	var initial := await picture(screen)
	check(initial.save_png("res://artifacts/settlement/exploration-clouds-3d-opening.png") == OK,"Opening capture saved")
	# Review wind motion independently of discovery and world simulation.
	game.fog.material.set_shader_parameter("cloud_time",float(game.model.time)+18.0)
	game.fog.fading_material.set_shader_parameter("cloud_time",float(game.model.time)+18.0)
	var windy := await picture(screen)
	check(windy.save_png("res://artifacts/settlement/exploration-clouds-wind.png") == OK,"Wind capture saved")
	check(windy.get_data() != initial.get_data(),"Wind moves rendered cloud groups")
	game.fog.sync(game.model,true)
	var count := 0
	for sphere in game.fog.spheres:
		if sphere.remaining > 0.99: count += 1
	check(count > 0,"Unvisited surroundings retain full clouds")
	var coast: PackedVector2Array = game.model.exploration.islands[1]
	var triangles := Geometry2D.triangulate_polygon(coast)
	var point := (coast[triangles[0]] + coast[triangles[1]] + coast[triangles[2]]) / 3.0
	game.model.exploration.reveal(Vector3(point.x,0,point.y))
	game.world.sync(game.model,0,-1); game.fog.sync(game.model,true)
	var pending := 0
	for sphere in game.fog.spheres:
		if sphere.remaining > sphere.target: pending += 1
	check(pending > 0,"Arrival starts individual cloud dissolves")
	# Move only the cloud clock; the paused world stays unchanged for comparison.
	DirAccess.make_dir_recursive_absolute("/tmp/town-cloud-reveal")
	for frame in 7:
		if frame > 0: game.model.time += 0.15; game.fog.sync(game.model,true)
		(await picture(screen)).save_png("/tmp/town-cloud-reveal/frame-%02d.png" % frame)
	var partial := 0
	for sphere in game.fog.spheres:
		if sphere.remaining > 0.01 and sphere.remaining < 0.99: partial += 1
	check(partial > 0,"Spheres shrink and become translucent during reveal")
	var middle := await picture(screen)
	check(middle.save_png("res://artifacts/settlement/exploration-clouds-3d-revealing.png") == OK,"Transition capture saved")
	var states: Array = game.fog.spheres.map(func(sphere): return sphere.remaining)
	game.fog.sync(game.model,true)
	check(game.fog.spheres.map(func(sphere): return sphere.remaining) == states,"Paused simulation freezes the dissolve")
	for frame in range(7,17):
		game.model.time += 0.15; game.fog.sync(game.model,true)
		(await picture(screen)).save_png("/tmp/town-cloud-reveal/frame-%02d.png" % frame)
	var final := await picture(screen)
	check(final.save_png("res://artifacts/settlement/exploration-clouds-3d-expanded.png") == OK,"Expanded capture saved")
	check(final.get_data() != initial.get_data(),"Discovery visibly clears clouds")
	for sphere in game.fog.spheres:
		check(is_equal_approx(sphere.remaining,sphere.target),"Reveal reaches its final state")
	game.rig.yaw += 1.2; game.rig.pitch = 0.45; game.rig.update_camera()
	game.fog.sync(game.model,true); game.model.time += 3.0; game.fog.sync(game.model,true)
	check((await picture(screen)).save_png("res://artifacts/settlement/exploration-clouds-3d-orbit.png") == OK,"Orbit capture saved")
	game.chunk_loader.finish(); game.free(); screen.free()
	if failures.is_empty(): print("PASS: 3D cloud geometry, island arrival, shrinking, translucency, pause and orbit captures")
	quit(int(not failures.is_empty()))
