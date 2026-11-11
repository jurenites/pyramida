extends RefCounted
## Prebuilt practice map. Uses ordinary plans and pays every installed recipe.
const Fixture=preload("res://tests/settlement/home_assembly_test.gd")
const Homes=Fixture.Homes
const U=Homes.U
const STOCK=Vector3i(-16,0,-14)
const ANCHORS=[Vector3i(-7,0,-4),Vector3i(3,0,-4),Vector3i(-2,0,5)]
const WELLS=[Vector3i(-8,0,5),Vector3i(-8,0,7),Vector3i(-8,0,10)]

static func pay_and_finish(world) -> void:
	for plan in world.plans.values():
		for resource in plan.materials:
			assert(world.stores[STOCK].count(resource)>=plan.materials[resource],"Practice stock: "+resource)
			world.stores[STOCK].amounts[resource]-=plan.materials[resource]
		plan.used=plan.materials.duplicate(); plan.installed=plan.required
		if plan.kind=="home_utility": U.complete(Homes.context_for(world,plan.utility_owner),plan)
		else: world._complete_plan(plan)

static func build(world, kind: String, at: Vector3i, direction:=0) -> void:
	assert(world.request_build(kind,at,direction),"Practice placement %s %s: %s" % [kind,at,world.last_message])
	pay_and_finish(world)

static func create():
	var world=Fixture.fixture()
	world.soil_shapes.clear(); world.surface_edits.clear()
	for x in range(-18,19):
		for z in range(-18,19): world.ground[Vector3i(x,0,z)]=true
	world.stores.clear(); world.add_store(STOCK)
	var stock=world.stores[STOCK]; stock.capacity=2000
	var supplies={"log":250,"grain":100,"plank":200,"brick":240,"pottery":240,"rope":80,"food":150,"imbrex":80,"stone":80,"clay":8}
	for resource in supplies: stock.store(resource,supplies[resource])
	world.Hydrology.populate(world,{WELLS[0]:"puddle"})
	world.rebuild_navigation()
	for index in ANCHORS.size():
		var a: Vector3i=ANCHORS[index]
		build(world,"house",a)
		build(world,"house",a+Vector3i(2,0,0),1)
		if index>0: build(world,"house",a+Vector3i(0,0,-2),0)
		if index==2: build(world,"house",a+Vector3i(2,0,-2),1)
		var top: Vector3i=a+Vector3i(0,2,0) if index==1 else a+Vector3i(2,2,0)
		build(world,"house",top-Vector3i.UP*2) # Reinforce the bearing room.
		build(world,"house",top,3 if index==1 else 1)
		var stair: Vector3i=a+Vector3i(2,0,2) if index==1 else a+Vector3i(0,0,2)
		build(world,"stairs",stair,3)
		if index==1:
			build(world,"house",top); build(world,"house",top) # Tile roof.
		if index==2:
			build(world,"house",a+Vector3i(2,0,-2))
			build(world,"house",a+Vector3i(2,2,-2),0)
			build(world,"house",top) # Plank roof beside the hay roof.
	for cell in WELLS: build(world,"well",cell)
	for context in Homes.contexts(world):
		var owner: int=U.owner_for(context,context.room_site.design[0])
		assert(U.install(context,owner),"Install practice utilities")
		pay_and_finish(world)
		for uid in U.state(context,owner).lamps: assert(U.toggle_gas(context,owner,uid))
		pay_and_finish(world)
		assert(U.supply(context,owner),"Clear chimney and connected gas supply")
	world.weather.raining=true
	for second in 16: Homes.rain_second(world)
	world.weather.raining=false
	for i in world.workers.size():
		world.workers[i].cell=ANCHORS[i]+Vector3i(0,0,3)
		world.workers[i].position=Vector3(world.workers[i].cell)
		world.workers[i].hunger=0
	# Construction funding is a temporary fixture account, not player storage.
	# Finish real dedicated stores, then discard the unspent debug allowance.
	var stores := {"log_shed":Vector3i(-13,0,-10), "hay_barn":Vector3i(-10,0,-10),
		"stone_storage":Vector3i(-6,0,-12), "brickyard":Vector3i(0,0,-12)}
	world.unlock_production("sawmill")
	world.unlock_production("claypit")
	for kind: String in stores: build(world,kind,stores[kind])
	world.stores.erase(STOCK)
	var opening := {"log_shed":{"log":4,"plank":4}, "hay_barn":{"grain":4},
		"stone_storage":{"stone":6}, "brickyard":{"clay":4,"brick":4}}
	for kind: String in opening:
		for resource: String in opening[kind]:
			var amount: int = opening[kind][resource]
			assert(world.Economy.storage_space(world,stores[kind],resource)>=amount)
			assert(world.stores[stores[kind]].store(resource,amount))
	for cell: Vector3i in world.buildings:
		if world.buildings[cell].kind == "house":
			assert(world.stores[cell].store("food",mini(2,world.Houses.ROOM_FOOD)))
	world.rebuild_navigation()
	return world
