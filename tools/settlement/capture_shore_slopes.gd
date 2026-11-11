extends SceneTree
const Islands=preload("res://scripts/settlement/solid_islands.gd")
func _initialize() -> void:
	root.unfocusable=true; root.hide(); call_deferred("capture")
func picture(viewport: SubViewport,path: String) -> void:
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(path)
func capture() -> void:
	var screen:=SubViewport.new(); screen.size=Vector2i(1200,850); screen.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(screen)
	seed(1409)
	var game=load("res://scenes/settlement/Terraces.tscn").instantiate(); game.slot_directory="/tmp/town-shore-slopes-%d"%Time.get_ticks_usec()
	screen.add_child(game); game.set_process(false)
	await game._choose_slot(0,true)
	game.hud.hide(); game.fog.visible=false; game.world.fog_enabled=false; game.world.last_revision=-1; game.world.sync(game.model,0,-1)
	game.rig.focus=Vector3(-6,2,-1); game.rig.yaw=1.0; game.rig.pitch=0.60; game.rig.zoom=68; game.rig.update_camera()
	var terrain=game.world.scenery.solid_view
	assert(terrain.seabed.has_node("SeabedCollision"),"Submerged ground needs a real collider")
	await picture(screen,"res://artifacts/settlement/angled-island-main-game.png")
	var main: Dictionary=Islands.definitions(game.model.world_seed,game.model.generator_version)[0]
	var target:=Vector3.ZERO; var best:=INF; var outward:=Vector2.ONE.normalized()
	for i in main.coast.size():
		var a: Vector2=main.coast[i]; var b: Vector2=main.coast[(i+1)%main.coast.size()]; var point: Vector2=(a+b)*0.5
		var high: float=-INF
		for part in main.parts:
			var inward:=Vector2(-(b-a).y,(b-a).x).normalized()
			var levels:=Islands.hits(part,point+inward*2.0)
			if not levels.is_empty(): high=maxf(high,levels.back())
		if high>0.1: continue
		var distance:=point.distance_to(Vector2(-6,2))
		if distance<best: best=distance; target=Vector3(point.x,-0.3,point.y); outward=Vector2((b-a).y,-(b-a).x).normalized()
	assert(best<INF,"A sheltered beach must be available for inspection")
	game.rig.focus=target; game.rig.yaw=atan2(outward.x,outward.y); game.rig.pitch=0.55; game.rig.zoom=20; game.rig.update_camera()
	for level in [-0.8,-0.65,-0.5]:
		terrain.sea.position.y=level
		terrain.seabed.material_override.set_shader_parameter("water_level",level)
		await picture(screen,"res://artifacts/settlement/beach-level-%s.png"%str(level))
	terrain.sea.position.y=-0.65
	game.chunk_loader.finish(); game.free(); screen.free()
	print("PASS: main game angled cliffs, seabed collision and low/mean/high water previews")
	quit()
