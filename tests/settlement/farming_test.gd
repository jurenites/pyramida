extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Farm = preload("res://scripts/settlement/farming.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func complete(world, kind: String, cell: Vector3i) -> bool:
	if not world.request_build(kind, cell):
		check(false, "Queue %s at %s: %s" % [kind, cell, world.last_message])
		return false
	world._complete_plan(world.plans[world.next_plan_id - 1])
	return true
func fresh():
	var world = Model.new()
	world.setup()
	world.streaming_enabled = false
	world.loaded_chunks.clear()
	world.trees.clear()
	world.deposits.clear()
	world.water_sources.clear()
	for worker in world.workers: worker.role = "idle"
	for entry in [["hay_barn", Vector3i(-4, 0, -4)], ["log_shed", Vector3i(-4, 0, 0)]]:
		world.buildings[entry[1]] = {"kind": entry[0], "direction": 0}
		world.add_store(entry[1])
	world.rebuild_navigation()
	return world
func _initialize() -> void:
	var world = fresh()
	check(Farm.footprint("hay_field", Vector3i.ZERO).size == Vector2(4, 4), "Field is twice a house wide and deep")
	check(Farm.footprint("soil_bed", Vector3i.ZERO).size == Vector2(2, 2), "Soil bed is one house footprint")
	check(world.build_error("hay_field", Vector3i.ZERO).is_empty(), "Field accepts flat sand")
	world.terrain_shapes[Vector3i.RIGHT] = [0.0, 0.1, 0.1, 0.0]
	check(not world.build_error("hay_field", Vector3i.ZERO).is_empty(), "Any sloped part of the four-room footprint rejects a field")
	world.terrain_shapes.clear()
	world.ground.erase(Vector3i.RIGHT)
	check(not world.build_error("hay_field", Vector3i.ZERO).is_empty(), "Missing sand in one quarter rejects a field")
	world.ground[Vector3i.RIGHT] = true
	check(world.request_build("hay_field", Vector3i.ZERO), "Ground field reserves its four room-sized quadrants")
	check(not world.build_error("hay_field", Vector3i.RIGHT).is_empty(), "Fields cannot overlap one tile")
	check(world.build_error("hay_field", Vector3i(4, 0, 0)).is_empty(), "Adjacent four-metre fields share an edge without overlap")
	world.plans.clear()
	var roof := Vector3i(0, 1, 0)
	for bed in Farm.bed_cells(roof): world.platforms[bed] = true
	world.rebuild_navigation()
	check(not world.build_error("hay_field", roof).is_empty(), "Bare rooftop cannot grow a hay field")
	for bed in Farm.bed_cells(roof).slice(0, 3): complete(world, "soil_bed", bed)
	check(world.soil_beds.size() == 3 and not world.build_error("hay_field", roof).is_empty(), "Three adjoining soil tiles are insufficient")
	complete(world, "soil_bed", roof + Vector3i(2, 0, 2))
	check(world.build_error("hay_field", roof).is_empty(), "Four completed soil beds support a rooftop field")
	complete(world, "hay_field", roof)
	check(world.soil_beds.size() == 4, "Building a field retains all four foundations")
	check(world.buildings[roof].placement_offset == Farm.FIELD_OFFSET, "Field centre aligns exactly with the four room-sized soil beds")
	check(not world.build_error("soil_bed", roof + Vector3i(2, 0, 0)).is_empty(), "An occupied bed cannot be replaced or doubled")
	check(not world.Relocation.source_error(world, roof + Vector3i(2, 0, 0)).is_empty(), "Beds beneath a field cannot be moved or dismantled")
	check(not world.build_error("house", roof + Vector3i(2, 0, 0)).is_empty(), "Building footprint cannot clip the edge of the shifted field")
	var saved = Model.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Soil and field serialize together")
	check(saved.soil_beds == world.soil_beds and saved.buildings == world.buildings, "Reload preserves four foundations and field alignment")
	var crop: Dictionary = world.gardens[roof]
	crop.water = 1
	Farm.tick_crops(world, 12)
	check(is_equal_approx(crop.growth, 12), "Open sky grows at normal speed")
	for cover in Farm.bed_cells(roof + Vector3i.UP): world.platforms[cover] = true
	world.rebuild_navigation()
	crop.growth = 0.0
	Farm.tick_crops(world, 24)
	check(is_equal_approx(crop.growth, 2.4) and crop.food == 0, "Full overhead cover gives exactly ten percent growth")
	for cover in [Vector3i(2, 2, 0), Vector3i(2, 2, 2)]: world.platforms.erase(cover)
	world.rebuild_navigation()
	check(is_equal_approx(Farm.light_rate(world, roof, true), 0.55), "Half-covered field averages lit and shaded halves")
	for cover in [Vector3i(0, 2, 0), Vector3i(0, 2, 2)]: world.platforms.erase(cover)
	world.rebuild_navigation()
	Farm.tick_crops(world, 22)
	check(crop.food == 4 and crop.growth == 0.0, "Removing the roof restores growth and ripens four hay")
	world.platforms[Vector3i(4, 1, 0)] = true
	world.rebuild_navigation()
	check(is_equal_approx(Farm.light_rate(world, Vector3i(4, 0, 0)), 0.1), "Living bushes also receive the shade growth rate")
	# An assigned gatherer keeps cutting past the automatic economy's small buffer.
	var harvest = fresh()
	for bed in Farm.bed_cells(Vector3i.ZERO): complete(harvest, "soil_bed", bed)
	complete(harvest, "hay_field", Vector3i.ZERO)
	harvest.gardens[Vector3i.ZERO].food = 4
	harvest.stores.values()[0].store("grain", 8)
	check(harvest.set_role(0, "farmer"), "Grass gatherer assignment is available")
	check(harvest.Jobs._assign_farm(harvest, harvest.workers[0]), "Assigned gatherer cuts ripe hay even when eight are already stored")
	var carried := false
	for i in 800:
		harvest.tick(0.05)
		carried = carried or harvest.workers[0].cargo == "grain"
		if harvest.resource_total("grain") > 8: break
	check(carried and harvest.resource_total("grain") > 8 and harvest.gardens[Vector3i.ZERO].food < 4, "Harvest is cut, physically carried and delivered as the existing hay resource")
	harvest.set_role(0, "builder")
	# Leave room for the field's fourth crop bundle plus dismantled timber.
	harvest.stores.values()[0].capacity += 4
	check(harvest.Deconstruction.request(harvest, Vector3i.ZERO), "Gathered field can be dismantled independently of its soil")
	for i in 3000:
		harvest.tick(0.05)
		if harvest.plans.is_empty(): break
	check(harvest.plans.is_empty(), "Field salvage is fully delivered")
	check(not harvest.gardens.has(Vector3i.ZERO) and harvest.soil_beds.size() == 4, "Dismantling a field leaves all four soil beds in place")
	check(harvest.Relocation.source_error(harvest, Vector3i(2, 0, 0)).is_empty(), "Uncovered foundations become movable again: " + harvest.Relocation.source_error(harvest, Vector3i(2, 0, 0)))
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(harvest.snapshot()))) and restored.soil_beds.size() == 4, "Exposed foundations survive reload after field removal")
	check_quarter_harvest()
	if failures.is_empty(): print("PASS: %d farming foundation, shade, save and physical harvest checks" % checks)
	for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))

func check_quarter_harvest() -> void:
	var world = fresh()
	complete(world, "hay_field", Vector3i.ZERO)
	var crop: Dictionary = world.gardens[Vector3i.ZERO]
	crop.water = 1
	Farm.tick_crops(world, Farm.GROW_SECONDS)
	check(crop.food == 4 and Farm.standing_quarters(crop) == 15, "New growth fills four quarters")
	var field = preload("res://scripts/settlement/asset_library.gd").create("hay_field")
	var plants: Node3D = field.get_node("Plants")
	var citizen = preload("res://scripts/settlement/asset_library.gd").create("citizen_0")
	var knee_height: float = citizen.get_node("LeftLeg").position.y + citizen.get_node("LeftLeg/Knee").position.y
	var canopy: MeshInstance3D = plants.get_node("Quarter0/Canopy")
	var canopy_top: float = plants.position.y + (canopy.transform * canopy.mesh.get_aabb()).end.y
	check(is_equal_approx(canopy_top, knee_height), "Solid mature hay reaches the adult knee")
	var soil: MeshInstance3D = field.get_node("Soil")
	check((soil.transform * soil.mesh.get_aabb()).end.y <= 0.015, "Harvest exposes a ground-level bed")
	check(soil.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Harvested soil is opaque")
	citizen.free()
	var fields = preload("res://scripts/settlement/hay_field_view.gd")
	fields.sync(world, Vector3i.ZERO, field)
	var restored_map = Model.new()
	check(restored_map.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Field appearance map reloads")
	var rebuilt = preload("res://scripts/settlement/asset_library.gd").create("hay_field")
	fields.sync(restored_map, Vector3i.ZERO, rebuilt)
	for peg in field.get_children():
		if peg.has_meta("hay_peg_slot"):
			check(peg.transform == rebuilt.get_node(NodePath(peg.name)).transform, "Saved map restores each stick exactly")
	rebuilt.free()
	var worker: Dictionary = world.workers[0]
	world.set_role(0, "farmer")
	var cut := 0
	for remaining in range(4, 0, -1):
		check(world.Jobs._assign_farm(world, worker), "Assign quarter %d" % remaining)
		if worker.job.is_empty(): break
		var quarter: int = worker.job.quarter
		check((cut & (1 << quarter)) == 0, "Citizen chooses an uncut quarter")
		check(worker.route.back() == Farm.quarter_cell(world, Vector3i.ZERO, quarter), "Citizen walks to the quarter being cut")
		# Reach the actual work location before testing partial and completed labour.
		for step in 1000:
			world.Jobs._tick_worker(world, worker, 0.05)
			if worker.route_index >= worker.route.size(): break
		world.Jobs._tick_worker(world, worker, 0.25)
		check(crop.food == remaining, "Partial work does not prematurely clear crops")
		if remaining == 4:
			var saved = Model.new()
			check(saved.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "In-progress quarter work survives save/load")
			world = saved
			worker = world.workers[0]
			crop = world.gardens[Vector3i.ZERO]
			check(worker.job.quarter == quarter and worker.job.labour.applied_seconds > 0.0, "Reload retains the chosen quarter and applied work")
		world.Jobs._tick_worker(world, worker, 3.0)
		cut |= 1 << quarter
		check(crop.food == remaining - 1 and Farm.standing_quarters(crop) == (15 & ~cut), "Completed cut removes exactly its quarter")
		check(worker.cargo == "grain", "Each cut yields one physical wheat cargo")
		preload("res://scripts/settlement/world_view.gd").sync_hay_quarters(plants, crop)
		var visible := 0
		for tuft: Node3D in plants.get_children():
			visible += int(tuft.visible)
			check(tuft.visible == ((cut & (1 << Farm.quarter_at(tuft.position))) == 0), "Cut quadrant is bare; other quadrants retain every tuft")
		check(visible == plants.get_child_count() * (remaining - 1) / 4, "Visible coverage matches remaining quarters")
		var saved = Model.new()
		check(saved.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Partly harvested field reloads")
		check(Farm.standing_quarters(saved.gardens[Vector3i.ZERO]) == Farm.standing_quarters(crop), "Reload preserves exactly which quarters are cut")
		# Deliver each bundle through the existing hauling job before the next cut.
		for step in 1000:
			world.Jobs._tick_worker(world, worker, 0.05)
			if worker.job.is_empty(): break
		check(worker.job.is_empty() and worker.cargo.is_empty(), "Citizen delivers the cut quarter")
	Farm.tick_crops(world, Farm.GROW_SECONDS)
	check(crop.food == 0 and crop.growth == 0.0, "Fully harvested field stays bare until watered")
	crop.water = 1
	Farm.tick_crops(world, 1.0)
	preload("res://scripts/settlement/world_view.gd").sync_hay_quarters(plants, crop)
	check(plants.get_children().all(func(tuft): return tuft.visible), "Watered regrowth returns across the whole field")
	Farm.tick_crops(world, Farm.GROW_SECONDS)
	check(crop.food == 4 and Farm.standing_quarters(crop) == 15, "Next harvest restores all four quarters")
	check(Farm.standing_quarters({"food": 3}) == 7, "Legacy three-wheat saves retain their remaining crop")
	world.gardens[Vector3i(6, 0, 0)] = {"water": 1, "growth": 0.0, "food": 0, "reserved": -1}
	Farm.tick_crops(world, Farm.GROW_SECONDS)
	check(world.gardens[Vector3i(6, 0, 0)].food == 3, "Vegetable gardens keep their existing three-food yield")
	field.free()
