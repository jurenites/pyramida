extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Islands = preload("res://scripts/settlement/solid_islands.gd")
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var started := Time.get_ticks_msec()
	var difficulty := "normal" if "--dry" in OS.get_cmdline_user_args() else "easy"
	var world := Model.new(); world.setup(1409,difficulty)
	print("Generated solid world in ",Time.get_ticks_msec()-started," ms; floors ",world.ground.size())
	check(world.generator_version==world.Generator.VERSION,"New islands use solid geometry")
	var merged := {}
	for x in range(2,-4,-1):
		for z in range(2,-4,-1): merged.merge(world.Generator.generate_chunk(1409,Vector2i(x,z),difficulty,world.generator_version).ground)
	check(merged==world.ground,"Reverse chunk generation reproduces all exposed elevations")
	check(not world.terrain_shapes.is_empty(),"Beach slopes provide walking surfaces down to the shore")
	check(not world.build_error("support",Vector3i(-22,0,-15)).is_empty(),"Cannot begin construction deep inside inaccessible rock")
	var overhang := false
	for x in range(-40,-7):
		for z in range(-26,0):
			var at := Vector3(x,4,z)
			if not Islands.solid(world,at) and Islands.solid(world,at+Vector3.UP*1.6): overhang=true
	# Seeded plateaus no longer have one fixed lip height or orientation.
	for shelf in Islands.definitions(world.world_seed,world.generator_version)[0].get("shelves",[]):
		for i in shelf.outline.size():
			var a: Vector2=shelf.outline[i]; var b: Vector2=shelf.outline[(i+1)%shelf.outline.size()]
			var inward:=Vector2(-(b-a).y,(b-a).x).normalized()
			var p: Vector2=(a+b)*0.5+inward*0.10
			var at:=Vector3(p.x,shelf.height-0.7,p.y)
			if not Islands.solid(world,at) and Islands.solid(world,at+Vector3.UP*0.65): overhang=true
	if world.generator_version<16: check(overhang,"Legacy rock projects above an actual air space")
	world.trees.clear(); world.deposits.clear(); world.rebuild_navigation()
	var target := Vector3i.ZERO; var found := false; var offset := Vector3.ZERO
	for cell: Vector3i in world.ground:
		if cell.y!=0: continue
		if world.navigation.route(world.workers[0].cell,cell).is_empty(): continue
		for step in world.DIRECTIONS:
			var at: Vector3i=cell+step
			if not Islands.solid(world,Vector3(at)+Vector3.UP*0.5) or not Islands.solid(world,Vector3(at)+Vector3.UP*2.1): continue
			if world.build_error("support",at).is_empty() and preload("res://scripts/settlement/support_runtime.gd").foundation_error(world,at,Vector3.ZERO,0).is_empty(): target=at; offset=-Vector3(step)*0.4; found=true; break
		if found: break
	print("Excavation fixture ",target)
	check(found,"Exposed cliff accepts a supported construction site")
	if found:
		var before := world.terrain_excavations.size()
		check(world.request_build("support",target,0,offset),"Support excavation queues through ordinary construction")
		check(world.terrain_excavations.size()==before and Islands.solid(world,Vector3(target)+Vector3.UP*0.5),"Blueprint does not remove rock")
		var plan_id := world.next_plan_id-1
		check(world.delete_plan(plan_id),"Unstarted excavation can be cancelled")
		check(world.terrain_excavations.size()==before,"Cancelled blueprint leaves rock unchanged")
		check(world.request_build("support",target,0,offset),"Excavation can be queued again")
		plan_id=world.next_plan_id-1
		for worker in world.workers: world.set_role(worker.id,"idle")
		var supply=world.stores.values()[0]; supply.amounts={"log":12,"plank":12}
		check(world.order_build(0,plan_id),"Worker accepts real excavation construction")
		for tick in 5000:
			if not world.plans.has(plan_id): break
			for worker in world.workers: worker.hunger=0
			world.tick(0.1)
		check(world.buildings.has(target),"Worker delivers materials and completes excavation")
		check(not Islands.solid(world,Vector3(target)+Vector3.UP*0.5),"Completed Support excavates its occupied volume")
		check(not world.navigation.walkable(target),"One metre tunnel lacks citizen headroom")
		check(world.request_build("support",target+Vector3i.UP,0,offset),"Second Support can be built from the exterior")
		check(world.debug_finish_plan(world.next_plan_id-1),"Upper excavation completes")
		check(world.navigation.walkable(target),"Two metres of excavation open a walking passage")
		check(not world.navigation.edges.get(target,[]).is_empty(),"Offset tunnel mouth connects to outside without crossing rock")
		check(Islands.solid(world,Vector3(target)+Vector3.UP*2.1),"Ceiling above tunnel remains solid")
		var saved: Variant=JSON.parse_string(JSON.stringify(world.snapshot()))
		var restored := Model.new()
		check(restored.restore(saved),"Solid island and permanent excavation save/load")
		check(restored.terrain_excavations==world.terrain_excavations,"Exact excavation position and yaw round trip")
		check(not Islands.solid(restored,Vector3(target)+Vector3.UP*0.5),"Reload does not refill tunnel")
		world.buildings.erase(target); world.buildings.erase(target+Vector3i.UP); world.rebuild_navigation()
		check(not Islands.solid(world,Vector3(target)+Vector3.UP*0.5),"Removing timber does not refill rock")
		var chunk := world.Chunks.chunk_for(target)
		world.Chunks.unload_chunk(world,chunk); world.rebuild_navigation()
		check(not world.navigation.surfaces.has(target),"Unloaded tunnel has no stale navigation")
		world.Chunks.integrate(world,chunk,world.Generator.generate_chunk(world.world_seed,chunk,difficulty,world.generator_version))
		check(not Islands.solid(world,Vector3(target)+Vector3.UP*0.5),"Streaming does not refill excavation")
		check(world.navigation.walkable(target),"Streamed tunnel restores its exposed lower floor")
		check(Model.new().restore(JSON.parse_string(JSON.stringify(world.snapshot()))),"Excavated streamed world still validates")
	for version in [7,8]:
		var legacy := Model.new(); legacy.setup(1409,"easy",version)
		for y in [0,1]:
			check(legacy.request_build("support",Vector3i(-33,y,-18),0,Vector3(-0.4,0,0)),"Legacy island construction remains available")
			check(legacy.debug_finish_plan(legacy.next_plan_id-1),"Legacy excavation completes")
		var old_save := Model.new()
		check(old_save.restore(JSON.parse_string(JSON.stringify(legacy.snapshot()))),"Previous generator excavation save still loads")
		check(old_save.generator_version==version and old_save.ground==legacy.ground,"Old islands retain their saved geometry")
		check(not Islands.solid(old_save,Vector3(-33.4,0.5,-18)),"Old tunnel remains excavated")
	var before_blending:=Model.new(); before_blending.setup(1409,"easy",19)
	var saved_previous:=Model.new()
	check(saved_previous.restore(JSON.parse_string(JSON.stringify(before_blending.snapshot()))),"Pre-blended terrain save still loads")
	check(saved_previous.generator_version==19 and saved_previous.ground==before_blending.ground,"Existing version-19 settlements keep their original mountains")
	var previous:=Model.new(); previous.setup(1409,"easy",9)
	var restored_previous:=Model.new()
	check(restored_previous.restore(JSON.parse_string(JSON.stringify(previous.snapshot()))),"Version 9 island and stone save still loads")
	check(previous.ground==restored_previous.ground and restored_previous.generator_version==9,"Version 9 keeps previous geometry")
	check(not Islands.valid([{"origin":Vector3(NAN,0,0),"yaw":0.0}]),"Invalid excavation rejected")
	print("Finished in ",Time.get_ticks_msec()-started," ms")
	if failures.is_empty(): print("PASS: solid islands, overhangs, construction excavation, clearance and persistence")
	quit(int(not failures.is_empty()))
