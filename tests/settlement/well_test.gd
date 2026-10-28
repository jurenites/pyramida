extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Hydro = preload("res://scripts/settlement/hydrology.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const WellView = preload("res://scripts/settlement/well_view.gd")
const Tooltip = preload("res://scripts/settlement/object_tooltip.gd")
var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func fresh():
	var world = Model.new()
	world.setup()
	world.trees.clear()
	world.deposits.clear()
	world.water_sources.clear()
	world.streaming_enabled = false
	world.loaded_chunks.clear()
	world.chunk_details.clear()
	world.terrain_shapes.clear()
	world.ground.clear()
	world.terrain_heights.clear()
	for x in range(-12, 13):
		for z in range(-12, 13):
			world.ground[Vector3i(x, 0, z)] = true
			world.terrain_heights[Vector2i(x, z)] = 0
	world.rebuild_navigation()
	for worker in world.workers: world.set_role(worker.id, "idle")
	return world

func build(world, kind: String, cell: Vector3i) -> void:
	check(world.request_build(kind, cell), "Can place %s at %s: %s" % [kind, cell, world.last_message])
	if not world.plans.is_empty(): world._complete_plan(world.plans.values().back())

func reload_world(world):
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Water state survives JSON save")
	return restored

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = fresh()
	Hydro.populate(world, {Vector3i.ZERO: "puddle"})
	check(Hydro.rain_yield(world, Vector3i.ZERO) == 3, "Puddle yields three")
	check(Hydro.rain_yield(world, Vector3i.RIGHT) == 2, "One tile away yields two")
	check(Hydro.rain_yield(world, Vector3i(2, 0, 0)) == 1, "Two tiles away yields one")
	check(Hydro.rain_yield(world, Vector3i(10, 0, 0)) == 1, "Dry ground still yields one")
	build(world, "well", Vector3i.ZERO)
	check(world.wells[Vector3i.ZERO].count("water") == 3 and world.wells[Vector3i.ZERO].capacity == 6, "Puddle becomes 3/6, without free water")
	check(world.water_sources[Vector3i.ZERO].inventory.count("water") == 0, "Puddle does not duplicate stored water")
	check(Tooltip.describe(world, {"kind": "well", "cell": Vector3i.ZERO}).rows == [{"icon": "water", "value": "3/6"}], "Well selection shows its water capacity")
	Hydro.tick(world, 89)
	check(world.wells[Vector3i.ZERO].count("water") == 3, "No dry-weather refill or evaporation")
	Hydro.tick(world, 17)
	check(world.wells[Vector3i.ZERO].count("water") == 6, "Rain fills 6/6")
	build(world, "well", Vector3i.ZERO)
	check(world.wells[Vector3i.ZERO].capacity == 9 and world.wells[Vector3i.ZERO].count("water") == 6, "Second well adds three storage, no free water")
	build(world, "well", Vector3i.ZERO)
	check(world.wells[Vector3i.ZERO].capacity == 12 and world.buildings[Vector3i.ZERO].well_units == 3, "Third well adds another three storage")
	world = reload_world(world)
	var housing: int = world.Economy.capacity(world)
	check(world.snap_cell("house", "well", Vector3i.ZERO) == Vector3i.ZERO, "Building wraps same-floor utility")
	build(world, "house", Vector3i.ZERO)
	check(world.buildings[Vector3i.ZERO].kind == "waterworks", "Enclosed utility becomes waterworks")
	check(world.Economy.capacity(world) == housing, "Waterworks adds no housing")
	check(world.wells[Vector3i.ZERO].capacity == 12 and world.wells[Vector3i.ZERO].count("water") == 6, "Shell retains water and capacity")
	world = reload_world(world)
	check(world.Relocation.request(world, Vector3i.ZERO, Vector3i(6, 0, 0), 0, Vector3.ZERO), "Waterworks can relocate with utility")
	world = reload_world(world)
	var id: int = world.next_plan_id - 1
	check(world.order_build(0, id), "Builder accepts waterworks relocation")
	for i in 8000:
		world.tick(0.05)
		if not world.plans.has(id): break
	check(world.wells.has(Vector3i(6, 0, 0)) and not world.wells.has(Vector3i.ZERO), "Wrapped well moves as one construction")
	check(world.buildings.get(Vector3i(6, 0, 0), {}).get("kind") == "waterworks", "Relocated utility is still waterworks")
	world = reload_world(world)

	world = fresh()
	Hydro.populate(world, {Vector3i.ZERO: "puddle"})
	build(world, "well", Vector3i.ZERO)
	build(world, "well", Vector3i.RIGHT)
	check(world.wells[Vector3i.RIGHT].capacity == 5, "Adjacent well has five capacity")
	build(world, "well", Vector3i(4, 0, 0))
	check(world.wells[Vector3i(4, 0, 0)].capacity == 4, "Dry well has four capacity")
	world.wells[Vector3i(4, 0, 0)].store("water", 4)
	world.wells[Vector3i.ZERO].store("water", 3)
	check(world.Relocation.request(world, Vector3i(4, 0, 0), Vector3i.ZERO, 0, Vector3.ZERO), "Relocating another well onto a well merges")
	var plan_id: int = world.next_plan_id - 1
	check(not world.Relocation.request(world, Vector3i.ZERO, Vector3i(8, 0, 0), 0, Vector3.ZERO), "Merge destination cannot move away")
	world = reload_world(world)
	check(world.order_build(0, plan_id), "Builder accepts merging")
	for i in 5000:
		world.tick(0.05)
		if not world.plans.has(plan_id): break
	check(not world.wells.has(Vector3i(4, 0, 0)) and world.wells[Vector3i.ZERO].capacity == 9, "Merge consumes moved well, adds exactly three capacity")
	check(world.buildings[Vector3i.ZERO].well_units == 2, "Moved well raises destination tier")
	world = reload_world(world)
	check(world.Deconstruction.request(world, Vector3i.ZERO), "Merged well can be dismantled")
	world = reload_world(world)

	world = fresh()
	Hydro.populate(world, {Vector3i.ZERO: "puddle"})
	var original = world.water_sources[Vector3i.ZERO].inventory
	original.reserve(0, "water")
	world.workers[0].job = {"source": original}
	build(world, "well", Vector3i.ZERO)
	check(world.workers[0].job.source == world.wells[Vector3i.ZERO] and world.wells[Vector3i.ZERO].reservations.has(0), "Puddle collector keeps reservation when well finishes")
	world.workers[0].job = {}
	world.wells[Vector3i.ZERO].release(0)
	build(world, "well", Vector3i(4, 0, 0))
	world.wells[Vector3i.ZERO].store("water", 3)
	world.wells[Vector3i(4, 0, 0)].store("water", 4)
	check(world.Relocation.request(world, Vector3i(4, 0, 0), Vector3i.ZERO, 0, Vector3.ZERO), "Full wells can merge")
	var merge: Dictionary = world.plans.values().back()
	merge.relocation.payload = {"buildings": world.buildings[Vector3i(4, 0, 0)], "wells": world.wells[Vector3i(4, 0, 0)]}
	merge.relocation.stage = "rebuild"
	world.buildings.erase(Vector3i(4, 0, 0))
	world.wells.erase(Vector3i(4, 0, 0))
	world.construction_materials.erase(Vector3i(4, 0, 0))
	world._complete_plan(merge)
	check(world.wells[Vector3i.ZERO].count("water") == 9 and world.plans.values()[0].relocation.parts.count("water") == 1, "Full merge preserves ten droplets as nine stored and one haulable overflow")
	check(world.construction_materials[Vector3i.ZERO] == {"log": 12}, "Merge preserves both material recipes")
	world = reload_world(world)
	world.plans.clear()
	check(world.request_collect_water(Vector3i.ZERO), "Well water can be collected using existing action")
	world = reload_world(world)
	check(world.water_orders[Vector3i.ZERO] == 9, "Larger collection order survives save")
	world.water_orders[Vector3i.ZERO] = 8
	world.wells[Vector3i.ZERO].reserve(0, "water")
	world.workers[0].job = {"kind": "collect_water", "target": Vector3i.ZERO, "source": world.wells[Vector3i.ZERO]}
	world.Jobs._cancel_job(world, world.workers[0])
	check(world.water_orders[Vector3i.ZERO] == 9, "Interrupted collector restores the full merged-well order")
	check(world.request_build("sawmill", Vector3i(5, 0, 0)), "Room plan can start away from well")
	var shell_plan: int = world.next_plan_id - 1
	check(world.move_plan(shell_plan, Vector3i.ZERO, 0, Vector3.ZERO), "Moving room plan over well converts its role")
	world = reload_world(world)
	world._complete_plan(world.plans[shell_plan])
	check(world.buildings[Vector3i.ZERO].kind == "waterworks" and world.wells[Vector3i.ZERO].capacity == 9, "Moved room plan wraps well without replacing inventory")
	check(world.construction_materials[Vector3i.ZERO] == {"log": 22}, "Converted room retains installed material recipe")
	check(world.snap_cell("house", "waterworks", Vector3i.ZERO) == Vector3i.UP, "Completed waterworks still supports an upper floor")

	for count in [1, 2, 3]:
		var node := Assets.create("well")
		root.add_child(node)
		WellView.sync(node, count, 3, 3 + count * 3)
		check(node.get_node("WellStone").visible == (count >= 2), "Tier %d masonry" % count)
		check(node.get_node("Canopy").visible == (count >= 3), "Tier %d roof" % count)
		check(node.get_node("Water").position.y < 0.06 if count == 1 else true, "First well sits at the ground surface")
		node.free()
	var shell := Assets.create("waterworks")
	check(shell.has_node("BackWall") and shell.get_node("Roof").visible, "Waterworks has open utility shell")
	shell.free()
	var generated: Dictionary = Model.Generator.generate_region(1409, Rect2i(-14, -14, 28, 28))
	check(generated.water.values().count("puddle") == 1, "Sand opening has one puddle instead of three")
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d well checks" % checks)
	quit(int(not failures.is_empty()))
