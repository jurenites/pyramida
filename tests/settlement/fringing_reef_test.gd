extends "res://tests/settlement/reef_village_test.gd"

func run() -> void:
	for seed_value in [1409,42,9182,101]:
		var world:=Model.new(); world.setup(seed_value,"easy")
		var islands:=Islands.definitions(seed_value,world.generator_version)
		var main: Dictionary=islands[0]; var fringe: Dictionary=main.fringe
		check(not fringe.is_empty(),"Main island has one continuous fringing shelf")
		check(islands.all(func(island):return island.get("reefs",[]).is_empty()),"No detached reef ovals remain")
		for i in range(1,islands.size()): check(islands[i].get("fringe",{}).is_empty(),"Small islands have no added reef")
		check(Array(fringe.widths).min()>1.5 and Array(fringe.widths).max()>15,"Shelf wraps the island with substantial width variation")
		if world.generator_version>=22:
			check(fringe.channels.size()>=2,"Seeded channels interrupt the shallow band")
			for channel in fringe.channels:
				var tangent:=Vector2(-channel.outward.y,channel.outward.x)
				var centre: Vector2=channel.at+channel.outward*9+tangent*channel.bend*sin(9*0.18)
				var middle:=Islands.seabed_height(centre,seed_value,world.generator_version)
				var left:=Islands.seabed_height(centre+tangent*channel.width*2,seed_value,world.generator_version)
				var right:=Islands.seabed_height(centre-tangent*channel.width*2,seed_value,world.generator_version)
				check(middle<maxf(left,right)-0.5,"Each channel is physically deeper than its adjacent shelf")
		var sand_depth:=0.0; var cliff_depth:=0.0; var sand_samples:=0; var cliff_samples:=0
		var build_target:=Vector3i.ZERO; var best:=INF
		for i in main.coast.size():
			var a: Vector2=main.coast[i]; var b: Vector2=main.coast[(i+1)%main.coast.size()]
			var outward:=Vector2((b-a).y,-(b-a).x).normalized(); var edge: Vector2=(a+b)*0.5
			var width: float=(fringe.widths[i]+fringe.widths[(i+1)%main.coast.size()])*0.5
			var p:=edge+outward*7
			if Islands.shore_distance(p,seed_value,world.generator_version)<5: continue
			var depth: float=Foundation.water_level(world)-Islands.seabed_height(p,seed_value,world.generator_version)
			if width>13:
				sand_depth+=depth; sand_samples+=1
				for d in [1.0,3.0,5.0,7.0]:
					var at: Vector2=edge+outward*d
					var bed:=Islands.seabed_height(at,seed_value,world.generator_version)
					var channel: float=preload("res://scripts/settlement/fringing_reef.gd").channel_depth(at,fringe)
					check(bed<Foundation.water_level(world) and bed>Foundation.water_level(world)-2-channel,"Beach shelves remain connected between the intentional channels")
				var at:=edge+outward*5
				var target:=Vector3i(roundi(at.x),0,roundi(at.y))
				var affordable:=0
				for x in range(-2,3):
					for z in range(-2,3):
						var cell:=target+Vector3i(x,0,z)
						if Islands.shore_distance(Vector2(cell.x,cell.z),seed_value,world.generator_version)>0 and Foundation.recipe(world,cell).log<=10: affordable+=1
				var distance:=target.distance_to(world.STARTING_HOUSE)
				if affordable==25 and distance<best: best=distance; build_target=target
			elif width<5:
				cliff_depth+=depth; cliff_samples+=1
		check(sand_samples>=3 and cliff_samples>=3,"Both beach shelves and steep coastal drop-offs survive")
		if sand_samples>0 and cliff_samples>0: check(sand_depth/sand_samples+2<cliff_depth/cliff_samples,"Cliff water deepens much sooner than beach water")
		check(build_target!=Vector3i.ZERO,"Continuous beach reef retains an affordable 5x5 pier site")
		check(main.ledge_count>=2,"Broken mountain includes several low embedded ledges")
		if seed_value==1409 and build_target!=Vector3i.ZERO: build_village(world,build_target)
		var saved:=Model.new(); check(saved.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Fringing coast and constructions survive saving")
		check(Islands.definitions(seed_value,saved.generator_version)[0].fringe==fringe,"The same seed restores the same shallow shelf")
		print("Seed ",seed_value," beach sections=",sand_samples," cliff sections=",cliff_samples," ledges=",main.ledge_count)
	if failures.is_empty(): print("PASS: continuous beach reef, narrow cliff water, no satellite reefs, low rock ledges and pier construction")
	quit(int(not failures.is_empty()))
