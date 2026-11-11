extends SceneTree
## Exercise the additive plan tool in the actual game, without touching player saves.
const Game = preload("res://scripts/settlement/settlement.gd")
const Fixture = preload("res://tests/settlement/room_construction_test.gd")
const Plans = preload("res://scripts/settlement/generated_building_plan.gd")
func _initialize() -> void: call_deferred("run")
func capture(game, filename: String) -> void:
	game.world.sync(game.model,0,-1)
	game.room_editor.revision=-1; game.room_editor.sync()
	game.hud.update(game.model,-1,1,{})
	game.generated_building_tool.services.sync(game.model,80)
	for frame in 12: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/settlement/"+filename+".png")
func run() -> void:
	root.size=Vector2i(1440,1000)
	var game=Game.new(); game.launch_to_menu=false; game.slot_directory="/tmp/pyramida-generated-capture"
	root.add_child(game); game.set_process(false)
	game.model=Fixture.fixture(); game.model.vines.clear()
	game.world.fog_enabled=false; game.hud.build_panel.hide()
	game.rig.focus=Vector3(1,1,-1); game.rig.yaw=-0.65; game.rig.pitch=0.58; game.rig.zoom=14; game.rig.update_camera()
	var buttons=game.hud.find_children("*","Button",true,false)
	assert(buttons.any(func(button):return button.text=="Building plan"))
	assert(game.hud.buttons.has("house"))
	game._set_tool("generated_plan")
	var tool=game.generated_building_tool
	assert(tool.active and tool.toolbar.visible and not game.room_editor.active)
	tool.set_process(false)
	tool.anchor=Vector3i.ZERO; tool.seed_=2; tool.proposal=Plans.prepare(game.model,tool.anchor,tool.seed_)
	assert(tool.proposal.error.is_empty())
	for resource in tool.proposal.materials:
		if resource!="log": game.model.stores.values()[0].store(resource,tool.proposal.materials[resource]+(100 if resource=="pottery" else 20))
	var installed_materials: Dictionary=tool.proposal.materials.duplicate()
	var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
	tool.handle(click)
	assert(not tool.active and not game.model.plans.is_empty())
	assert(not game.hud.status_label.is_visible_in_tree())
	await capture(game,"generated-building-planned")
	for step in 24000:
		game.model.tick(0.1)
		if game.model.plans.is_empty(): break
	assert(game.model.plans.is_empty())
	game.model.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
	game.Illustration.update(game.world_container.material,game.model.time)
	await capture(game,"generated-building-main-game")
	var utilities=Plans.Utilities
	var owner: int=game.model.room_site.design[0].uid
	for uid in utilities.state(game.model,owner).lamps: assert(utilities.toggle_gas(game.model,owner,uid))
	for step in 12000:
		game.model.tick(0.1)
		if utilities.state(game.model,owner).lamps.values().all(func(lamp):return lamp.pipe): break
	assert(utilities.state(game.model,owner).lamps.values().all(func(lamp):return lamp.pipe))
	for step in 3000:
		if utilities.state(game.model,owner).fuel>30: break
		game.model.tick(0.1)
	assert(utilities.supply(game.model,owner))
	print("Active gas lamps: ",utilities.state(game.model,owner).lamps.size()," fuel: ",utilities.state(game.model,owner).fuel)
	game.model.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.125
	game.Illustration.update(game.world_container.material,game.model.time)
	await capture(game,"town-utilities-day")
	game.model.weather.raining=true
	for second in 12: utilities.rain_second(game.model)
	await capture(game,"town-utilities-rain")
	game.model.time=game.Illustration.Settings.SIMULATION_DAY_SECONDS*0.75
	game.Illustration.update(game.world_container.material,game.model.time)
	await capture(game,"town-utilities-night")
	var report={"building":Plans.Exemplars.inventory(game.room_editor.view),"utilities":Plans.Exemplars.inventory(game.generated_building_tool.services.geometry),"installation_materials":installed_materials,"gas_lamps":utilities.state(game.model,owner).lamps.size()}
	var output=FileAccess.open("res://artifacts/settlement/generated-building-main-inventory.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")); output.close()
	game._set_tool("generated_plan"); assert(tool.active)
	game._set_tool("inspect"); assert(not tool.active)
	print("PASS: main Housing tool, plan placement, workers, additive House, cancellation and render")
	if "--play" in OS.get_cmdline_user_args():
		root.title="... Town · Generated buildings"
		tool.set_process(true); game.set_process(true)
		return
	game.free(); quit()
