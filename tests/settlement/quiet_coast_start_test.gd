extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Islands=preload("res://scripts/settlement/solid_islands.gd")
const WaterView=preload("res://scripts/settlement/water_view.gd")
const Deposits=preload("res://scripts/settlement/geological_deposits.gd")
var failures: Array[String]=[]
func check(value: bool,message: String) -> void:
	if not value: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for seed_value in [1409,42,9182,101,7,25]:
		var world:=Model.new(); world.setup(seed_value,"easy",11)
		check(world.generator_version==11,"New games use the sparse coast generation")
		var fresh:=Islands.definitions(seed_value,11); var old:=Islands.definitions(seed_value,10)
		var rock_count:=0; var old_count:=0
		for i in fresh.size():
			rock_count+=fresh[i].shoals.size(); old_count+=old[i].shoals.size()
			check(fresh[i].coast==old[i].coast,"Reducing outcrops does not reshape island coasts")
		check(rock_count<old_count and rock_count<=10,"New coastline has fewer emergent rocks")
		var deposits:=0
		for cell: Vector3i in world.deposits:
			if world.deposits[cell].kind!="limestone": continue
			deposits+=1
			check(Deposits.quarry_site(world,cell,world.workers[0].cell)!=Vector3i.ZERO,"Retained stone has an accessible quarry site")
		check(deposits==2,"Starting island has two usable stone patches")
		var view:=WaterView.new(); root.add_child(view); view.sync(world)
		var nearby: Array[Vector3i]=[]
		for cell: Vector3i in world.water_sources:
			if cell.distance_to(world.workers[0].cell)>14 or world.water_sources[cell].kind!="puddle": continue
			if world.navigation.route(world.workers[0].cell,cell).is_empty(): continue
			var water: MeshInstance3D=view.sources[cell].get_node("Water")
			check(water.visible and water.mesh!=null and water.mesh.get_faces().size()>0,"Opening freshwater is actually drawable on solid land")
			check(water.global_position.y>world.navigation.surface_height(cell,Vector3(cell)),"Puddle is above the opaque island cap")
			check(world.water_sources[cell].inventory.count("water")==3,"Opening puddle starts full")
			nearby.append(cell)
		check(not nearby.is_empty(),"Every starting seed has reachable nearby freshwater")
		if seed_value==1409 and not nearby.is_empty():
			var cell:=nearby[0]
			# Collection needs a vessel under the existing economy; supply one only
			# in this delivery fixture, without changing starting goods in the game.
			world.stores[world.STARTING_HOUSE].store("pottery",1)
			check(world.order_collect_water(0,cell),"Citizen accepts opening puddle collection")
			for tick in 1200:
				for worker in world.workers: worker.hunger=0
				world.tick(0.1)
				if world.stores[world.STARTING_HOUSE].count("water")>0: break
			check(world.stores[world.STARTING_HOUSE].count("water")>0,"Opening puddle water reaches home")
			var restored:=Model.new()
			check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Sparse coast and freshwater save restores")
			check(restored.generator_version==11 and restored.water_sources.has(cell),"Reload retains selected coast and puddle")
		view.free()
		print("Seed ",seed_value," coast rocks ",old_count," -> ",rock_count," quarry patches=",deposits," reachable puddles=",nearby.size())
	# Sand still uses its bowl mesh, not the island's surface fallback.
	var sand:=Model.new(); sand.setup(1409,"normal")
	var sand_view:=WaterView.new(); root.add_child(sand_view); sand_view.sync(sand)
	var source:=Vector3i(-8,0,0)
	check(sand.water_sources.has(source),"Sand retains its guaranteed opening puddle")
	check(sand_view.sources[source].get_node("Water").mesh!=null,"Sand hollow water remains visible")
	sand_view.free()
	var legacy:=Model.new(); legacy.setup(1409,"easy",10)
	check(legacy.deposits.values().filter(func(item): return item.kind=="limestone").size()==4,"Version 10 retains its four quarry patches")
	if failures.is_empty(): print("PASS: sparse rocks, quarry access, visible starting puddles, water delivery and persistence")
	quit(int(not failures.is_empty()))
