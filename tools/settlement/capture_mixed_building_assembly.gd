extends SceneTree
const Game=preload("res://scripts/settlement/settlement.gd")
const Model=preload("res://scripts/settlement/world_model.gd")
func _initialize() -> void:
	root.unfocusable=true; root.hide(); call_deferred("run")
func run() -> void:
	var world=Model.new(); world.setup(1409,"easy",11)
	for collection in [world.trees,world.deposits,world.vines,world.gardens,world.water_sources]:
		for cell in collection.keys():
			if Vector2(cell.x+4,cell.z-5).length()<10: collection.erase(cell)
	var stock=world.stores[world.STARTING_HOUSE]; stock.capacity=4000
	for resource in ["log","grain","plank","brick","pottery","rope","imbrex","stone","block","clay"]: stock.store(resource,200)
	for producer in ["sawmill","claypit","masonry","kiln","tilery"]: world.unlock_production(producer)
	world.rebuild_navigation()
	# Normal completed building records, inventories and paid construction plans.
	for item in [["bakery",Vector3i(-5,0,5),0],["house",Vector3i(-3,0,5),1],["house",Vector3i(-5,2,5),0],["sawmill",Vector3i(0,0,5),0],["house",Vector3i(0,2,5),0],["pottery_workshop",Vector3i(2,0,5),0],["stairs",Vector3i(-3,0,7),3]]:
		world.unlock_production(item[0])
		assert(world.request_build(item[0],item[1],item[2]),world.last_message+str(item))
		for plan in world.plans.values():
			for resource in plan.materials: stock.amounts[resource]-=plan.materials[resource]
			plan.used=plan.materials.duplicate(); plan.installed=plan.required; world._complete_plan(plan)
	world.rebuild_navigation()
	var display:=SubViewport.new(); display.size=Vector2i(1440,1000); display.own_world_3d=true; display.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(display)
	var game=Game.new(); game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-mixed-buildings-capture"; display.add_child(game)
	game.set_process(false); game.generated_building_tool.set_process(false); game.model=world
	game.world.fog_enabled=false; game.fog.visible=false; game.hud.build_panel.hide()
	game.rig.focus=Vector3(-2,1,5); game.rig.yaw=-0.5; game.rig.pitch=0.65; game.rig.zoom=13; game.rig.update_camera()
	world.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
	game.world.sync(world,0,-1); game.generated_building_tool._process(0)
	game.hud.update(world,-1,1,{}); game.Illustration.update(game.world_container.material,world.time)
	for i in 16: await process_frame
	await RenderingServer.frame_post_draw
	display.get_texture().get_image().save_png("res://artifacts/settlement/mixed-building-assembly.png")
	print("PASS: mixed Home, Bakery, Sawmill and Pottery assembly rendered in the main game")
	game.free(); quit()
