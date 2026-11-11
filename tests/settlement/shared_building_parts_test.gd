extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Construction = preload("res://scripts/settlement/construction_site_view.gd")
const Fields = preload("res://scripts/settlement/hay_field_view.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, text_: String) -> void:
	checks += 1
	if not ok: failures.append(text_)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var site := Assets.create("house")
	Construction.prepare(site, "house")
	var stake: MeshInstance3D = site.get_node("ConstructionCorners/Branch0/Stem")
	var field := Assets.create("hay_field")
	for seed_ in [17, 491, 8851]:
		Fields.arrange_pegs(field, Vector3i(4, 0, 8), seed_)
		for peg in field.get_children():
			if not peg.has_meta("hay_peg_slot"): continue
			check(peg.mesh == stake.mesh, "Field edges reuse the construction stake mesh")
			check(peg.basis.get_scale().is_equal_approx(Vector3.ONE), "Stake variation rotates without resizing stock")
			check(peg.get_active_material(0).albedo_color == stake.get_active_material(0).albedo_color, "All markers use the same brown wood")
	field.free()
	site.free()
	var world = Model.new()
	for x in range(-5, 10):
		for z in range(-5, 6): world.ground[Vector3i(x, 0, z)] = true
	world.buildings[Vector3i.ZERO] = {"kind": "log_shed", "direction": 0}
	world.buildings[Vector3i(4, 0, 0)] = {"kind": "house", "direction": 0}
	world.add_store(Vector3i.ZERO, {"log": 1})
	world.add_store(Vector3i(4, 0, 0), {"log": 1, "grain": 1})
	world.rebuild_navigation()
	var view := View.new()
	root.add_child(view)
	view.setup(world)
	var shed: Node3D = view.store_views[Vector3i.ZERO]
	var house: Node3D = view.store_views[Vector3i(4, 0, 0)]
	var post: Transform3D = shed.get_node("ShedPost").transform
	var wall: Transform3D = house.get_node("PlasterWall").transform
	world.plans[999] = {"id": 999, "kind": "house", "cell": Vector3i(0, 2, 0)}
	check(not world.roof_panel_covered(Vector3i.ZERO, Vector3.ZERO), "An unbuilt plan does not remove the existing rain cover")
	world.plans.erase(999)
	check(view.entity_views["building:%s" % Vector3i(4, 0, 0)] == house, "House inventory uses the authored house, without duplicate building geometry")
	for cell in [Vector3i(0, 2, 0), Vector3i(4, 2, 0)]:
		world.buildings[cell] = {"kind": "house", "direction": 0}
	world.rebuild_navigation()
	view.sync(world, 0, -1)
	check(not shed.get_node("Canopy").visible, "An upper storey hides the log shed canopy")
	check(house.get_node("Roof").get_children().all(func(part): return not part.visible), "An upper storey hides the lower house roof")
	check(shed.get_node("ShedPost").transform == post and house.get_node("PlasterWall").transform == wall, "Stacking preserves both authored building bodies")
	world.buildings.erase(Vector3i(0, 2, 0))
	world.buildings.erase(Vector3i(4, 2, 0))
	world.stores.erase(Vector3i(0, 2, 0))
	world.stores.erase(Vector3i(4, 2, 0))
	world.rebuild_navigation()
	view.sync(world, 0, -1)
	check(shed.get_node("Canopy").visible and house.get_node("Roof").get_children().all(func(part): return part.visible), "Exposed roofs return when the upper storey is removed")
	world.add_store(Vector3i(0, 0, 4), {"plank": 2})
	view.sync(world, 0, -1)
	check(not view.store_views[Vector3i(0, 0, 4)].has_node("CornerStone0"), "Legacy material supplies no longer render the retired stone-edged pile")
	check(world.stores[Vector3i(0, 0, 4)].count("plank") == 2, "Retiring pile geometry does not delete existing resources")
	view.free()
	if failures.is_empty(): print("PASS: %d shared stake, authored building, automatic roof and legacy supply checks" % checks)
	else:
		for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
