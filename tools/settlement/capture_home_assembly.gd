extends SceneTree
const Game=preload("res://scripts/settlement/settlement.gd")
const Fixture=preload("res://tests/settlement/home_assembly_test.gd")
const Homes=Fixture.Homes
const U=Homes.U
func _initialize() -> void: call_deferred("run")
func capture(game, name_: String) -> void:
	game.world.sync(game.model,0,-1)
	game.generated_building_tool._process(0)
	game.hud.update(game.model,-1,1,{})
	game.Illustration.update(game.world_container.material,game.model.time)
	for frame in 12: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/settlement/"+name_+".png")
func run() -> void:
	root.size=Vector2i(1440,1000)
	var game=Game.new(); game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-home-assembly-practice"
	root.add_child(game); game.set_process(false); game.generated_building_tool.set_process(false)
	game.model=Fixture.fixture()
	var world=game.model
	for entry in [[Vector3i.ZERO,0],[Vector3i(2,0,0),1],[Vector3i(2,0,0),1]]:
		assert(world.request_build("house",entry[0],entry[1])); Fixture.step(world); assert(world.plans.is_empty())
	assert(world.request_build("house",Vector3i(2,2,0),1))
	assert(world.request_build("stairs",Vector3i(0,0,2),3)); Fixture.step(world); assert(world.plans.is_empty())
	# Extend the lower storey through the existing Home tool, keeping each address.
	assert(world.request_build("house",Vector3i(2,0,-2),0)); Fixture.step(world); assert(world.plans.is_empty())
	var context=Homes.contexts(world)[0]; var owner: int=U.owner_for(context,context.room_site.design[0])
	var cost:=U.installation_cost(context,owner)
	game.selected_object={"kind":"house","cell":Vector3i.ZERO,"entity_key":"building:%s" % Vector3i.ZERO}
	game.hud.update(world,-1,1,game.selected_object)
	assert(game.hud.utilities_button.visible and not game.hud.utilities_button.disabled)
	game.hud.utilities_button.pressed.emit()
	assert(not world.plans.is_empty()); Fixture.step(world,26000); assert(world.plans.is_empty())
	game.selected_object={}
	for uid in U.state(context,owner).lamps: assert(U.toggle_gas(context,owner,uid))
	Fixture.step(world,18000)
	for i in 3000:
		if U.supply(context,owner) and U.state(context,owner).fuel>30: break
		world.birth_clock=0; world.tick(0.1)
	assert(U.supply(context,owner))
	# Move unused fixture stock outside the camera; this does not alter installed materials.
	var supplies=world.stores[Vector3i(-5,0,0)]; world.stores.erase(Vector3i(-5,0,0)); world.stores[Vector3i(-9,0,-8)]=supplies; world.rebuild_navigation()
	game.world.fog_enabled=false; game.hud.build_panel.hide()
	game.rig.focus=Vector3(0.8,1,0); game.rig.yaw=-0.65; game.rig.pitch=0.56; game.rig.zoom=10; game.rig.update_camera()
	world.weather.raining=true
	for second in 16: Homes.rain_second(world)
	world.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
	await capture(game,"assembled-homes-day")
	assert(world.request_build("house",Vector3i(4,0,0),1))
	var preview_id: int=world.next_plan_id-1
	game.world.planning=true
	await capture(game,"assembled-homes-solid-plan")
	assert(world.delete_plan(preview_id))
	game.world.planning=false
	world.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.75
	await capture(game,"assembled-homes-night")
	var report={"scope":"Completed Home shells and utility meshes; excludes external stairs, terrain, citizens, UI and unused fixture stock.","homes":4,"installation_materials":cost,"shell":{},"utilities":{}}
	var counts: Array=[]
	var all_roots: Array=[]
	for asset in game.world.entity_views.values():
		if asset.has_node("AssembledHome"):
			all_roots.append(asset.get_node("AssembledHome"))
			counts.append(Homes.V.Exemplars.inventory(asset.get_node("AssembledHome")))
	report.shell=counts
	for view in game.generated_building_tool.home_services.values():
		all_roots.append(view.geometry)
		report.utilities=Homes.V.Exemplars.inventory(view.geometry)
	report.assembly_total=Homes.V.Exemplars.inventory_roots(all_roots)
	FileAccess.open("res://artifacts/settlement/assembled-homes-inventory.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PASS: main Home construction, terrace, utility jobs, day/night capture")
	if "--play" in OS.get_cmdline_user_args():
		root.title="Town · Connected Homes"
		game.generated_building_tool.set_process(true); game.set_process(true)
		return
	game.free(); quit()
