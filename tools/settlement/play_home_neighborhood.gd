extends SceneTree
const Game=preload("res://scripts/settlement/settlement.gd")
const Neighborhood=preload("res://tools/settlement/home_neighborhood.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,1000); root.title="Town · Stacked Homes"
	var game=Game.new(); game.launch_to_menu=false
	game.slot_directory="/tmp/pyramida-home-neighborhood-practice"
	root.add_child(game); game.set_process(false); game.generated_building_tool.set_process(false)
	game.model=Neighborhood.create()
	game.world.fog_enabled=false
	game.hud.build_panel.show(); game.hud.show_category("housing")
	game.rig.focus=Vector3(1.4,1,3.8); game.rig.yaw=-0.65; game.rig.pitch=0.58; game.rig.zoom=23; game.rig.update_camera()
	game.model.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
	game.world.sync(game.model,0,-1); game.generated_building_tool._process(0)
	game.hud.update(game.model,-1,1,{})
	game.Illustration.update(game.world_container.material,game.model.time)
	if "--check" in OS.get_cmdline_user_args():
		assert(Neighborhood.Homes.contexts(game.model).size()==3)
		assert(game.model.Economy.capacity(game.model)==13)
		assert(not game.model.stores.has(Neighborhood.STOCK),"No debug supply account in play")
		for cell in game.model.stores:
			var inventory=game.model.stores[cell]
			assert(inventory.total()<=inventory.capacity,"Shared storage limit")
			for resource in inventory.amounts:
				assert(inventory.count(resource)<=game.model.Economy.resource_capacity(game.model,cell,resource),"Per-resource storage limit")
		for i in 3: assert(game.model.Hydrology.rain_yield(game.model,Neighborhood.WELLS[i])==3-i)
		for cell in game.model.buildings:
			if cell.y>0:
				assert(not game.model.navigation.route(Neighborhood.ANCHORS[0]+Vector3i(0,0,3),cell).is_empty(),"Upper Home reachable: "+str(cell))
		var restored=Neighborhood.Fixture.fixture()
		assert(Neighborhood.Fixture.Save.restore(restored,JSON.parse_string(JSON.stringify(Neighborhood.Fixture.Save.snapshot(game.model)))),"Practice map saves and loads")
		print("PASS: three connected native Home stacks, paid utilities, upper-floor access, well yields, save/load")
		game.free(); quit(); return
	for frame in 20: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/settlement/home-neighborhood.png")
	if "--capture" in OS.get_cmdline_user_args():
		game.hud.set_housing_preview(game.model,game.model.Houses.ROOM_RESIDENTS)
		var cell: Vector3i=Neighborhood.WELLS[0]
		game.hud.update_object_tooltips(game.world,game.rig.camera,game.model,{}, {"kind":"well","cell":cell,"entity_key":"well:%s" % cell})
		for frame in 12: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/settlement/home-neighborhood-feedback.png")
		game.free(); quit(); return
	game.generated_building_tool.set_process(true); game.set_process(true)
	print("READY: playable main-town neighborhood; Housing menu open")
