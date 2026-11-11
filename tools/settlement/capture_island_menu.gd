extends SceneTree
## Silent offscreen capture; run with render_background.py after any needed approval.
func _initialize() -> void:
	root.unfocusable=true; root.hide(); call_deferred("capture")
func picture(viewport: SubViewport,path: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(path)
func capture() -> void:
	var screen:=SubViewport.new(); screen.size=Vector2i(1100,760)
	screen.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(screen)
	seed(1409)
	var game=load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.slot_directory="/tmp/town-island-menu-%d"%Time.get_ticks_usec()
	screen.add_child(game); game.set_process(false)
	await picture(screen,"res://artifacts/settlement/island-main-menu.png")
	assert(game.menu.visible and game.menu_preview.difficulty=="easy")
	assert(game.world.scenery.solid_view!=null)
	await game._choose_slot(0,true)
	assert(game.model.difficulty=="easy" and not game.menu.visible)
	await picture(screen,"res://artifacts/settlement/island-gameplay.png")
	game.hud.hide(); game.fog.visible=false; game.world.fog_enabled=false
	game.rig.focus=Vector3(game.model.STARTING_HOUSE)+Vector3.UP*0.5
	game.rig.yaw=0.35; game.rig.pitch=0.50; game.rig.zoom=7; game.rig.update_camera()
	game.world.last_revision=-1; game.world.sync(game.model,0,-1)
	var house: Node3D=game.world.entity_views["building:%s"%game.model.STARTING_HOUSE]
	var floor_count:=0
	for mesh: MultiMeshInstance3D in house.find_children("*","MultiMeshInstance3D",true,false):
		if mesh.get_meta("exemplar_kind","")!="plank": continue
		var local:=house.global_transform.affine_inverse()*mesh.global_transform
		for i in mesh.multimesh.instance_count:
			var bounds: AABB=local*mesh.multimesh.get_instance_transform(i)*mesh.multimesh.mesh.get_aabb()
			if bounds.end.y>0.2: continue
			assert(absf(bounds.end.y-0.06)<0.001 and bounds.position.y>=0,"Visible floorboards must meet the walking surface above land")
			floor_count+=1
	assert(floor_count>10,"House must contain the complete plank floor")
	await picture(screen,"res://artifacts/settlement/island-house-floor.png")
	game.rig.focus=Vector3(-6,2,-1); game.rig.yaw=1.0; game.rig.pitch=0.60; game.rig.zoom=55; game.rig.update_camera()
	await picture(screen,"res://artifacts/settlement/village-terraces.png")
	game.chunk_loader.finish(); game.free(); screen.free()
	print("PASS: island main menu, same-world gameplay and house floor capture")
	quit()
