extends SceneTree
const Fixture = preload("res://tests/settlement/room_construction_test.gd")
const Plans = preload("res://scripts/settlement/generated_building_plan.gd")
const U = preload("res://scripts/settlement/room_utilities.gd")
const Save = preload("res://scripts/settlement/save_codec.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world=Fixture.fixture(); world.vines.clear()
	var proposal := Plans.prepare(world,Vector3i.ZERO,0)
	var stock=world.stores.values()[0]
	for resource in proposal.materials:
		if resource!="log": stock.store(resource,int(proposal.materials[resource])+30)
	var before: Dictionary=stock.amounts.duplicate()
	check(Plans.commit(world,proposal),"Generated plan includes utility installations")
	var owner: int=world.room_site.design[0].uid
	var pending := Save.snapshot(world)
	var restored=Fixture.fixture()
	check(Save.restore(restored,pending),"Queued utility recipes and reservations survive saving")
	for step in 22000:
		world.tick(0.1)
		if world.plans.is_empty(): break
	check(world.plans.is_empty(),"Workers deliver and install every stove, lamp and drain material")
	if not world.plans.is_empty(): print("Remaining ",world.plans.values().map(func(p):return [p.kind,p.get("utility_action"),p.installed,p.required]))
	for resource in proposal.materials:
		check(int(before.get(resource,0))-stock.count(resource)==int(proposal.materials[resource]),"Exact material conservation: "+resource)
	var service := U.state(world,owner)
	check(service.stove and service.rain and service.lamps.size()==4,"Real installed fixtures")
	check(world.navigation.blocked.has(U.barrel_cell(world,owner)),"Container occupies physical space")
	check(not world.request_collect_water(Vector3i(8,0,8)),"No water from absent connections")
	var lamp: Dictionary=service.lamps[owner]
	check(not lamp.pipe and not lamp.connected,"Lights need their paid supply connection")
	check(U.toggle_gas(world,owner,owner),"Connect queues real ceramic pipe work")
	check(not lamp.pipe,"Unbuilt gas pipe does not supply a lamp")
	for step in 3000:
		world.tick(0.1)
		if lamp.pipe: break
	check(lamp.pipe and lamp.connected and U.brightness(world,owner,owner)==1,"Completed pipe supplies lamp from stove")
	var fuel: float=service.fuel
	U.tick(world,3.0)
	check(is_equal_approx(service.fuel,fuel-3),"Gas generation consumes stored fuel time")
	U.toggle_gas(world,owner,owner); U.tick(world,100)
	check(is_equal_approx(service.fuel,fuel-3) and U.brightness(world,owner,owner)==0,"Disconnected charge expires without burning idle stove fuel")
	U.toggle_gas(world,owner,owner)
	var source := U.room(world,owner)
	var obstruction: Dictionary=source.duplicate(true); obstruction.uid=999; obstruction.cells=[U.Rooms.Layout.arr(U.Rooms.Layout.vec(source.cells[0])+Vector3i.UP)]; obstruction.id=999
	world.room_site.built.append(obstruction)
	fuel=service.fuel; U.tick(world,2)
	check(U.blocked(world,owner) and is_equal_approx(service.fuel,fuel) and U.brightness(world,owner,owner)==0,"Upper room blocks exhaust and stops gas without wasting fuel")
	world.room_site.built.pop_back()
	check(not U.blocked(world,owner) and U.brightness(world,owner,owner)==1,"Removing exhaust blockage restores connected supply")
	var drains := U.drains(world,owner)
	check(drains.size()==3,"All exposed roof and terrace catchments reach the container")
	for drain in drains:
		for i in range(1,drain.path.size()): check(drain.path[i].y<=drain.path[i-1].y,"Rain pipes always descend")
	var inventory=world.Hydrology.inventory_at(world,U.barrel_cell(world,owner)); inventory.amounts.clear()
	service.runoff=0.0; service.overflow=0; world.weather.raining=true
	for second in 16: U.rain_second(world)
	check(inventory.count("water")==mini(U.CAPACITY,drains.size()),"One rain event fills real inventory within container capacity")
	service.rain_connected=false
	var water: int=inventory.count("water")
	for second in 4: U.rain_second(world)
	check(inventory.count("water")==water,"Disconnected downpipe delivers no water")
	service.rain_connected=true
	world.weather.raining=false; U.rain_second(world)
	check(inventory.count("water")==water,"Dry weather cannot create water")
	world.weather.raining=true
	for second in 200: U.rain_second(world)
	check(inventory.count("water")==U.CAPACITY and service.overflow>0,"Container respects capacity and records overflow")
	check(world.request_collect_water(U.barrel_cell(world,owner)),"Container supports normal citizen collection orders")
	check(Save.restore(restored,Save.snapshot(world)),"Installed utilities, fuel, water orders and connections round-trip")
	check(restored.Hydrology.inventory_at(restored,U.barrel_cell(restored,owner)).count("water")==U.CAPACITY,"Water is neither lost nor refilled on load")
	check(U.state(restored,owner).fuel==service.fuel and U.state(restored,owner).lamps[owner].charge==lamp.charge,"No fuel/charge refill on load")
	# A citizen must physically collect and deliver a real bucket to household storage.
	var store_cell: Vector3i=world.stores.keys()[0]
	world.buildings[store_cell]={"kind":"house","direction":0,"house_tier":3}
	world.rebuild_navigation(); world.weather.seconds=0; world.weather.remainder=0; world.weather.raining=false
	world.workers[0].hunger=0; world.workers[1].hunger=0
	world.set_role(0,"hauler"); world.set_role(1,"idle")
	check(world.order_collect_water(0,U.barrel_cell(world,owner)),"Assign citizen to the real rain container")
	for step in 700:
		world.tick(0.1)
		if stock.count("water")>0: break
	check(stock.count("water")>0 and inventory.count("water")<U.CAPACITY,"Citizen carries collected runoff into town storage")
	var corrupt=world.room_site.duplicate(true); corrupt.utilities[owner].lamps[owner].charge=-1
	check(not U.Rooms.valid(corrupt,world.plans),"Malformed saved utility state is rejected")
	var view=preload("res://scripts/settlement/town_utility_view.gd").new(); root.add_child(view)
	view.sync(world,80); var geometry=view.geometry.get_child(0)
	U.tick(world,1); view.sync(world,80)
	check(is_instance_valid(geometry) and geometry==view.geometry.get_child(0),"Fuel ticks do not rebuild geometry")
	view.free()
	print("PASS: town utility construction, gas, rainfall, persistence and rendering" if failures==0 else "FAIL: %d checks" % failures)
	quit(failures)
