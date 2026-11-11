extends SceneTree
const Fixture = preload("res://tests/settlement/room_construction_test.gd")
const Plans = preload("res://scripts/settlement/generated_building_plan.gd")
const Save = preload("res://scripts/settlement/save_codec.gd")
const Materials = preload("res://scripts/settlement/material_exemplars.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = Fixture.fixture()
	world.vines.clear()
	var supplies: Dictionary=world.stores.duplicate(); world.stores.clear()
	var existing: Dictionary=world.buildings.duplicate(); world.buildings.clear()
	var footprints := {}
	for seed_ in 12:
		for yaw in 4:
			var proposal := Plans.prepare(world,Vector3i.ZERO,seed_,yaw)
			check(proposal.error.is_empty(),"Generated layout is structurally valid: %s" % proposal.error)
			footprints[str(proposal.added.map(func(room):return room.cells))]=true
	check(footprints.size()>12,"Seeds produce distinct room layouts")
	world.stores=supplies
	world.buildings=existing
	var proposal := Plans.prepare(world,Vector3i.ZERO,2)
	for resource in proposal.materials:
		if resource!="log": world.stores.values()[0].store(resource,proposal.materials[resource])
	check(Plans.commit(world,proposal),"Place generated construction alongside existing House tool")
	var cost := 0
	for plan in world.plans.values(): cost+=plan.required
	check(cost==proposal.cost,"Displayed cost equals actual construction plus beds")
	var design_count: int=world.room_site.design.size()
	var duplicate := Plans.prepare(world,Vector3i.ZERO,2)
	check(not duplicate.error.is_empty() and not Plans.commit(world,duplicate),"Overlapping building is rejected")
	check(world.room_site.design.size()==design_count,"Rejected batch leaves no partial records")
	world.room_site.design[0].generated.exemplar.overrides["stove/3"]=19
	var snapshot := Save.snapshot(world)
	var restored = Fixture.fixture()
	check(Save.restore(restored,snapshot),"Generated plans survive normal settlement save/load")
	check(restored.room_site.design[0].generated.exemplar.overrides["stove/3"]==19,"Sparse component damage persists")
	var expected := Materials.variant(world.room_site.design[0].generated.exemplar,"deck/70")
	check(expected==Materials.variant(restored.room_site.design[0].generated.exemplar,"deck/70"),"Untouched component detail is identical after load")
	var canonical: Vector3=Materials.source("brick").mesh.get_aabb().size
	check(canonical.is_equal_approx(Vector3(0.45,0.2,0.25)),"Installed bricks use the game's canonical stock dimensions")
	for variant in range(1,64):
		var mesh := Materials.mesh("brick",variant)
		check(mesh.get_aabb().size.is_equal_approx(canonical),"Chips never stretch or enlarge stock")
	print("Compact exemplar state bytes: ",JSON.stringify(Materials.record(2345)).to_utf8_buffer().size())
	# Real workers, real material consumption, normal dependency scheduling.
	for step in 24000:
		world.tick(0.1)
		if world.plans.is_empty(): break
	check(world.plans.is_empty(),"Workers finish all dependent rooms, terraces, stairs and beds")
	if not world.plans.is_empty(): print("Outstanding: ",world.plans.values().map(func(plan):return [plan.kind,plan.installed,plan.required,plan.cell]))
	check(world.room_site.beds.size()==proposal.beds.size() and not proposal.beds.is_empty(),"Bedrooms receive beds; circulation rooms remain clear")
	check(Save.restore(restored,Save.snapshot(world)),"Completed generated building survives save/load")
	var view := preload("res://scripts/settlement/room_editor_view.gd").new(); root.add_child(view); view.rebuild(restored)
	Materials.detail(view,100); Materials.detail(view,10); Materials.detail(view,100)
	print("PASS: generated building integration" if failures==0 else "FAIL: %d checks" % failures)
	quit(failures)
