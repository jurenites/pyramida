extends SceneTree
const World=preload("res://scripts/settlement/world_model.gd")
const Layout=preload("res://scripts/settlement/building_assembly_layout.gd")
const Assembly=preload("res://scripts/settlement/building_assembly.gd")
const Paths=preload("res://scripts/settlement/building_assembly_navigation.gd")
const Assets=preload("res://scripts/settlement/asset_library.gd")
var failures:=0
var checks:=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func fixture():
	var world=World.new()
	for x in range(-10,11):
		for z in range(-10,11): world.ground[Vector3i(x,0,z)]=true
	return world
func asset(world,cell: Vector3i) -> Node3D:
	var data: Dictionary=world.buildings[cell]
	var node:=Assets.create(data.kind); node.set_meta("asset",data.kind); node.set_meta("cell",cell)
	node.position=Vector3(cell); node.rotation.y=-data.direction*PI/2; root.add_child(node)
	return node
func run() -> void:
	var world=fixture()
	world.buildings[Vector3i.ZERO]={"kind":"bakery","direction":0}
	world.buildings[Vector3i(2,0,0)]={"kind":"house","direction":1,"house_tier":2}
	world.buildings[Vector3i(0,2,0)]={"kind":"house","direction":0,"house_tier":2}
	world.rebuild_navigation()
	var entries:=Layout.build(world)
	check(entries[Vector3i.ZERO].joins.size()==1,"Home door joins a differently sized Bakery wall")
	check(entries[Vector3i.ZERO].terrace and entries[Vector3i.ZERO].above.size()==1,"Upper Home turns exposed workplace roof into a terrace")
	check(not world.navigation.route(Vector3i(2,0,0),Vector3i.ZERO).is_empty(),"Home doorway reaches the actual workplace")
	check(Vector3i.ZERO in world.navigation.access_cells(Vector3i.ZERO),"Workplace jobs use the connected interior approach")
	var views: Dictionary={}
	for cell in world.buildings: views[str(cell)]=asset(world,cell)
	Assembly.sync(world,views)
	var bakery: Node3D=views[str(Vector3i.ZERO)]
	check(bakery.get_node("Oven").visible and bakery.get_node("Flue").visible,"Oven and working flue survive shell replacement")
	check(not bakery.get_node("Walls").visible and not bakery.get_node("Roof").visible,"Original solid shell is replaced")
	check(bakery.has_node("AssembledBuilding"),"Workplace shares the live assembly renderer")
	var root_id: int=bakery.get_node("AssembledBuilding").get_instance_id()
	Assembly.sync(world,views)
	check(root_id==bakery.get_node("AssembledBuilding").get_instance_id(),"Unchanged assembly reuses geometry")
	world.buildings.erase(Vector3i(0,2,0)); world.rebuild_navigation(); Assembly.sync(world,views)
	check(not Layout.build(world)[Vector3i.ZERO].terrace,"Removing upper room restores workplace roof")
	check(root_id!=bakery.get_node("AssembledBuilding").get_instance_id(),"Neighbour removal rebuilds only the changed shell")
	for node in views.values(): node.free()
	world=fixture()
	world.buildings[Vector3i.ZERO]={"kind":"school","direction":0}
	world.buildings[Vector3i(2,0,0)]={"kind":"house","direction":1}
	entries=Layout.build(world)
	check(entries[Vector3i.ZERO].posts.size()+entries[Vector3i(2,0,0)].posts.size()==6,"Mixed two-metre rooms share six corner posts")
	world.buildings[Vector3i(2,0,0)].direction=0
	check(Layout.build(world)[Vector3i.ZERO].joins.is_empty(),"Wall-only contact keeps enclosed buildings separate")
	for kind in Layout.ENCLOSED+Layout.OPEN+Layout.SOCKETS:
		if kind in ["support","stair"]: continue
		world=fixture(); world.buildings[Vector3i.ZERO]={"kind":kind,"direction":1}
		world.rebuild_navigation()
		var node:=asset(world,Vector3i.ZERO); Assembly.sync(world,{"one":node})
		check(node.has_node("AssembledHome" if kind=="house" else "AssembledBuilding"),kind+" participates without changing its identity")
		check(world.buildings[Vector3i.ZERO].kind==kind,"Assembly preserves "+kind+" gameplay kind")
		node.free()
	var fixture_script=preload("res://tests/settlement/reviewed_balance_test.gd").new()
	world=fixture_script.fixture()
	for item in [["bakery",Vector3i.ZERO],["house",Vector3i(2,0,0)]]:
		check(world.request_build(item[0],item[1],1 if item[0]=="house" else 0),"Mixed construction uses the ordinary build tool")
		for plan in world.plans.values():
			check(plan.materials==world.Catalog.recipe(item[0]),"Workplace connection preserves its construction recipe")
			plan.used=plan.materials.duplicate(); plan.installed=plan.required; world._complete_plan(plan)
	var original: Dictionary=world.buildings[Vector3i.ZERO].assembly_exemplar.duplicate(true)
	var saved: Dictionary=world.snapshot(); var loaded=World.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(saved))),"Mixed building identities and inventories survive JSON saves")
	check(loaded.buildings[Vector3i.ZERO].assembly_exemplar==original,"Workplace material exemplars remain compact and persistent")
	var moved: Dictionary=loaded.buildings[Vector3i.ZERO]
	loaded.buildings.erase(Vector3i.ZERO); loaded.buildings[Vector3i(-4,0,0)]=moved
	Layout.build(loaded)
	check(moved.assembly_exemplar==original,"Moving a workplace keeps its material seed")
	world.buildings[Vector3i(2,2,0)]={"kind":"pottery_workshop","direction":0}
	world.rebuild_navigation()
	var Homes=preload("res://scripts/settlement/home_assembly.gd")
	var context=Homes.context_for(world,world.buildings[Vector3i(2,0,0)].home_uid)
	check(Homes.U.blocked(context,world.buildings[Vector3i(2,0,0)].home_uid),"A workplace above a Home blocks its stove chimney")
	fixture_script.free()
	if failures==0: print("PASS: %d mixed building assembly, routes, equipment and restoration checks" % checks)
	quit(int(failures>0))
