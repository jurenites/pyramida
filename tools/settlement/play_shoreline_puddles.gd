extends SceneTree
const Game=preload("res://scripts/settlement/settlement.gd")
const Model=preload("res://scripts/settlement/world_model.gd")
const Homes=preload("res://scripts/settlement/home_assembly.gd")
const POOLS=[Vector3i(-8,0,7),Vector3i(-6,0,8),Vector3i(-4,0,7)]
const WELL=Vector3i(-2,0,6)
const ROOFED_WELL=Vector3i(-2,0,3)
var capture_only := "--capture" in OS.get_cmdline_user_args()
var stock
func _initialize() -> void:
	if capture_only: root.unfocusable=true; root.hide()
	call_deferred("run")
func finish(world) -> void:
	for plan in world.plans.values():
		for resource in plan.materials:
			assert(stock.count(resource)>=plan.materials[resource],"Practice supplies: "+resource)
			stock.amounts[resource]-=plan.materials[resource]
		plan.used=plan.materials.duplicate(); plan.installed=plan.required
		if plan.kind=="home_utility": Homes.U.complete(Homes.context_for(world,plan.utility_owner),plan)
		else: world._complete_plan(plan)
func build(world,kind: String,cell: Vector3i,direction:=0) -> void:
	assert(world.request_build(kind,cell,direction),"Shoreline placement: "+world.last_message)
	finish(world)
func run() -> void:
	root.size=Vector2i(1440,1000); root.title="Town · Shoreline, Puddles and Wells"
	var world=Model.new(); world.setup(1409,"easy",11)
	# A separate practice save on the real generated island and simulation.
	for collection in [world.trees,world.deposits,world.vines,world.gardens]:
		for cell in collection.keys():
			if Vector2(cell.x+5,cell.z-5).length()<8: collection.erase(cell)
	stock=world.stores[world.STARTING_HOUSE]; stock.capacity=1000
	for resource in ["log","grain","plank","brick","pottery","rope","imbrex","stone"]: stock.store(resource,100)
	world.rebuild_navigation()

	build(world,"house",Vector3i(-4,0,2),1)
	build(world,"house",Vector3i(-4,0,2),1)
	build(world,"house",Vector3i(-4,2,2),1)
	build(world,"stairs",Vector3i(-6,0,4),3)
	build(world,"well",WELL)
	for i in 3: build(world,"well",ROOFED_WELL)
	var context=Homes.contexts(world).filter(func(c):return c.room_site.design.any(func(r):return r.get("home_cell")==Vector3i(-6,0,2)))[0]
	var owner: int=Homes.U.owner_for(context,context.room_site.design[0])
	assert(Homes.U.install(context,owner)); finish(world)
	for uid in Homes.U.state(context,owner).lamps: assert(Homes.U.toggle_gas(context,owner,uid))
	finish(world)
	for i in POOLS.size():
		var cell: Vector3i=POOLS[i]
		assert(world.ground.has(cell) and not world.buildings.has(cell))
		var inventory=world.Inventory.new(); inventory.capacity=3; inventory.store("water",3-i)
		world.water_sources[cell]={"kind":"puddle","inventory":inventory}
	world.rebuild_navigation(); world.revision+=1
	var game=Game.new(); game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-shoreline-puddles-practice"
	var display: Viewport=root
	if capture_only:
		display=SubViewport.new(); display.size=Vector2i(1440,1000); display.own_world_3d=true
		display.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(display)
	display.add_child(game); game.set_process(false); game.generated_building_tool.set_process(false)
	game.model=world; game.world.fog_enabled=false; game.fog.visible=false
	game.hud.build_panel.hide()
	game.rig.focus=Vector3(-4,0.5,6); game.rig.yaw=-0.3; game.rig.pitch=0.65; game.rig.zoom=16; game.rig.update_camera()
	world.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
	game.world.sync(world,0,-1); game.generated_building_tool._process(0)
	game.hud.update(world,-1,1,{}); game.Illustration.update(game.world_container.material,world.time)
	for cell in POOLS:
		var surface=game.world.water_view.sources[cell].get_node("Water")
		assert(surface.visible and surface.mesh.get_aabb().size.y<0.001,"Puddle water is horizontal inside the basin")
		assert(not world.navigation.route(world.workers[0].cell,cell).is_empty(),"Puddle is reachable")
	assert(world.Hydrology.units(world.buildings[WELL])==1 and world.Hydrology.units(world.buildings[ROOFED_WELL])==3)
	if "--check" in OS.get_cmdline_user_args():
		print("PASS: main shoreline, three collectible puddles, connected Homes and two Well silhouettes")
		game.free(); quit(); return
	for i in 16: await process_frame
	await RenderingServer.frame_post_draw
	display.get_texture().get_image().save_png("res://artifacts/settlement/shoreline-puddles-town.png")
	if capture_only:
		for phase in [[0.48,"evening"],[0.75,"night"]]:
			world.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*phase[0]
			game.world.sync(world,0,-1); game.generated_building_tool._process(0)
			game.Illustration.update(game.world_container.material,world.time)
			for i in 8: await process_frame
			await RenderingServer.frame_post_draw
			display.get_texture().get_image().save_png("res://artifacts/settlement/shoreline-puddles-%s.png" % phase[1])
		world.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
		game.world.sync(world,0,-1); game.Illustration.update(game.world_container.material,world.time)
		game.hud.hide(); game.rig.focus=Vector3(-6,0,7.5); game.rig.zoom=6; game.rig.update_camera()
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		display.get_texture().get_image().save_png("res://artifacts/settlement/puddle-basins-close.png")
		print("PASS: shoreline basins and flat building lighting rendered in daylight, evening and night")
		game.free(); quit(); return
	game.set_process(true); game.generated_building_tool.set_process(true)
	print("READY: main game shoreline with puddles, connected Homes and Wells")
