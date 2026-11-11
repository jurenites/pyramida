extends SceneTree
const Model=preload("res://scripts/settlement/world_model.gd")
const Islands=preload("res://scripts/settlement/solid_islands.gd")
const Volume=preload("res://scripts/settlement/terrain_volume.gd")
const View=preload("res://scripts/settlement/solid_island_view.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for seed_value in [1409,42,9182,101]:
		var world:=Model.new(); world.setup(seed_value,"normal")
		check(Islands.enabled(world),"Normal uses physical island solids")
		check(not world.ground.has(Vector3i(47,0,-47)),"Ocean remains nonwalkable")
		check(Volume.sea_depth(world,Vector3i(47,0,-47))>0,"Dry islands retain saltwater foundation volumes")
		check(world.ground.has(world.STARTING_HOUSE),"Village has a floor")
		var puddles:=0; var quarries:=0
		for cell: Vector3i in world.water_sources:
			if world.water_sources[cell].kind=="puddle" and not world.navigation.route(world.workers[0].cell,cell).is_empty(): puddles+=1
		for entry in world.deposits.values():
			if entry.kind=="limestone": quarries+=1
		check(puddles>0 and quarries==2,"Freshwater and two quarries survive in Sand")
		for details in world.chunk_details.values(): check(details.grass.is_empty(),"Dry islands do not generate grass carpets")
		var restored:=Model.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Normal island saves load")
		check(restored.difficulty=="normal" and restored.ground==world.ground,"Dry landscape and terrain persist")
		var fields:=world.Generator.generate_region(seed_value,world.Generator.INITIAL_BOUNDS,0,"easy")
		check(fields.ground==world.ground,"Biomes share exact solid coastline and elevations")
		check(not fields.grass.is_empty(),"Fields retain lower grass")
		for cell: Vector3i in fields.grass: check(cell.y<6,"Third terrace and higher have no natural grass")
		var view:=View.new()
		var material:=view.painted(Islands.Landform.material(Color("a8b966")),world)
		check(material.get_shader_parameter("dry_island") and material.get_shader_parameter("rocky_heights"),"Sand uses dry lowland and bare summit shader")
		view.free()
		print("Dry island ",seed_value," floors=",world.ground.size()," puddles=",puddles," quarries=",quarries)
	for version in [10,11,12,13]:
		var legacy:=Model.new(); legacy.setup(1409,"normal",version)
		check(not Islands.enabled(legacy),"Saved desert does not become an island")
		check(Model.new().restore(JSON.parse_string(JSON.stringify(legacy.snapshot()))),"Previous normal generator saves still load")
	if failures.is_empty(): print("PASS: dry island biomes, rock heights, water foundations, resources and legacy saves")
	quit(int(not failures.is_empty()))
