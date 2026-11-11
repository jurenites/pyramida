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
	var game=load("res://scenes/settlement/Terraces.tscn").instantiate(); game.slot_directory="/tmp/town-sculpted-islands-%d"%Time.get_ticks_usec()
	screen.add_child(game); game.set_process(false)
	await game._choose_slot(0,true)
	game.hud.hide(); game.fog.visible=false; game.world.fog_enabled=false; game.world.last_revision=-1; game.world.sync(game.model,0,-1)
	game.rig.focus=Vector3(-6,2,-1); game.rig.yaw=1.0; game.rig.pitch=0.60; game.rig.zoom=68; game.rig.update_camera()
	await picture(screen,"res://artifacts/settlement/connected-mountain-foothills.png")
	var main: Dictionary=Islands.definitions(game.model.world_seed,game.model.generator_version)[0]
	var rocks: Array=main.parts.filter(func(item): return item.get("decorative",false))
	assert(rocks.size()>=3,"Main island has decorative marine outcrops")
	var target: Vector3=rocks[0].bounds.get_center(); target.y=0.4
	var near:=INF; var outward:=Vector2.RIGHT
	for i in main.coast.size():
		var a: Vector2=main.coast[i]; var b: Vector2=main.coast[(i+1)%main.coast.size()]
		var distance:=Vector2(target.x,target.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(target.x,target.z),a,b))
		if distance<near: near=distance; outward=Vector2((b-a).y,-(b-a).x).normalized()
	game.rig.focus=target-Vector3(outward.x,0,outward.y)*3; game.rig.yaw=atan2(outward.x,outward.y)+0.25; game.rig.pitch=0.55; game.rig.zoom=26; game.rig.update_camera()
	await picture(screen,"res://artifacts/settlement/connected-mountain-waterline.png")
	game.model.streaming_enabled=false
	game.world.scenery.solid_view.signature=0; game.world.scenery.solid_view.sync(game.model)
	var small: Dictionary=Islands.definitions(game.model.world_seed,game.model.generator_version)[1]
	var centre:=Vector2.ZERO
	for p: Vector2 in small.coast: centre+=p
	centre/=small.coast.size()
	game.rig.focus=Vector3(centre.x,1,centre.y); game.rig.yaw=1.0; game.rig.pitch=0.60; game.rig.zoom=30; game.rig.update_camera()
	await picture(screen,"res://artifacts/settlement/connected-mountain-islets.png")
	game.chunk_loader.finish(); game.free(); screen.free()
	print("PASS: sculpted main-game mountain and decorative marine rock previews")
	quit()
