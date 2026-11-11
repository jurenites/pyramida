extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Islands=preload("res://scripts/settlement/solid_islands.gd")
const Ocean=preload("res://scripts/settlement/ocean_surface.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for seed_value in [1409,42,9182,101]:
		var world:=Model.new(); world.setup(seed_value,"normal")
		var islands:=Islands.definitions(seed_value,world.generator_version)
		var repeat:=Islands.make_islands(seed_value,world.generator_version)
		var count:=0; var submerged:=0; var exposed:=0
		for i in islands.size():
			var island: Dictionary=islands[i]
			var local_count:=0
			for j in island.parts.size():
				var item: Dictionary=island.parts[j]
				if not item.get("decorative",false): continue
				count+=1; local_count+=1
				check(item.faces==repeat[i].parts[j].faces,"Decorative rocks regenerate exactly")
				var box: AABB=item.bounds; var centre:=box.get_center(); var at:=Vector2(centre.x,centre.z)
				check(Islands.shore_distance(at,seed_value,world.generator_version)>1.5,"Scenic stones stand in the water")
				check(box.position.y<Islands.seabed_height(at,seed_value,world.generator_version),"Scenic rocks are embedded in real submerged terrain")
				if box.end.y<Ocean.LEVEL: submerged+=1
				else: exposed+=1
				for cell: Vector3i in world.deposits:
					check(not box.grow(0.2).has_point(Vector3(cell)),"Scenic rocks never create collectible deposits")
				for cell: Vector3i in world.ground:
					check(not box.grow(0.05).has_point(Vector3(cell)),"Scenic rocks do not create walking steps through the sea")
			check(local_count<=6 if island.mainland else local_count<=3,"Water stones stay in sparse clusters")
		check(count>=9 and exposed>=5 and submerged>=3,"Archipelago has exposed and submerged decorative rocks")
		var limestone:=0
		for cell: Vector3i in world.deposits:
			if world.deposits[cell].kind=="limestone":
				limestone+=1
				check(Islands.shore_distance(Vector2(cell.x,cell.z),seed_value,world.generator_version)<0,"Collectible quarry deposits remain on land")
		check(limestone==2,"Two real quarry deposits remain separate from scenery")
		if world.generator_version>=21:
			check(not islands[0].fringe.is_empty(),"A continuous shallow reef follows the main island")
			check(islands.all(func(island): return island.get("reefs",[]).is_empty()),"Detached reef patches are absent")
		else: check(islands[0].reefs.size()==2,"Both broad reef building sites remain available")
		check(Model.new().restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Mountain and water-rock world survives saving")
		print("Seed ",seed_value," marine rocks=",count," exposed=",exposed," submerged=",submerged)
	if failures.is_empty(): print("PASS: sparse marine scenery, no gathering or walking targets, quarries, reefs and saves")
	quit(int(not failures.is_empty()))
