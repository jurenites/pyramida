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
	var cell := Vector3i(4, 0, 0)
	build(world, "stockpile", cell)
	var inventory = world.stores[cell]
	inventory.store("pottery", 5)
	inventory.store("block", 2)
	inventory.reserve(0, "pottery")
	check(world.request_build("stockpile", cell), "Pile upgrades to pottery rack")
	check(world.plans.values().back().kind == "goods_rack", "Tier two is rack")
	check(not world.Relocation.source_error(world, cell).is_empty(), "Upgrade locks moving source")
	world._complete_plan(world.plans.values().back())
	check(world.stores[cell] == inventory, "Upgrade preserves inventory object and reservations")
	check(world.stores[cell].count("block") == 2, "Existing non-pottery goods preserved for transfer")
	check(world.buildings[cell].kind == "goods_rack" and world.stores[cell].capacity == 48, "Rack has tier two capacity")
	for resource in world.Economy.RESOURCES:
		check(world.Economy.accepts(world, cell, resource) == (resource == "pottery"), "Rack fixed pottery acceptance: " + resource)
	world = reload_world(world)
	check(world.request_build("stockpile", cell), "Rack upgrades to small warehouse")
	check(world.plans.values().back().materials == {"plank": 10, "block": 6}, "Warehouse uses expensive processed materials")
	world = reload_world(world)
	world._complete_plan(world.plans.values().back())
	check(world.buildings[cell].kind == "small_warehouse", "Third tier completed")
	check(world.stores[cell].capacity == 64 and world.stores[cell].count("pottery") == 5, "Third tier retains goods and adds capacity")
	check(world.stores[cell].reservations.get(0) == "pottery", "Reservation survives upgrades and saves")
	check(world.construction_materials[cell] == {"stone": 1, "log": 2, "plank": 12, "block": 6}, "Invested recipe retained")
	for resource in world.Economy.RESOURCES:
		check(world.Economy.accepts(world, cell, resource) == (resource == "pottery"), "Warehouse fixed pottery acceptance: " + resource)
	check(world.Catalog.DEFINITIONS.small_warehouse.size == Vector3.ONE, "One metre cube asset contract")
	check(world.navigation.surfaces.has(cell + Vector3i.UP), "Flat top supports at one metre")
	check(not world.navigation.surfaces.has(cell + Vector3i(1, 1, 0)), "Roof does not create invisible surrounding floors")
	check(not world.supports_build_cell(cell + Vector3i(1, 2, 0)), "Warehouse does not support old two metre roof")
	check(not world.navigation.walkable(cell), "Warehouse body blocks walking")
	check(world.navigation.access_cells(cell) == [cell + Vector3i.BACK], "Front entrance remains accessible")
	check(world.snap_cell("small_warehouse", "small_warehouse", cell) == cell + Vector3i.UP, "Stacking uses one metre top")
	check(not world.build_error("house", cell + Vector3i.UP).is_empty(), "One warehouse cannot support a full sized house")
	check(world.request_build("small_warehouse", cell + Vector3i.UP), "Compact warehouse can stack")
	world.delete_plan(world.plans.values().back().id)
	world = reload_world(world)
	check(world.Relocation.request(world, cell, Vector3i(8, 0, 0), 1, Vector3.ZERO), "Warehouse can move with inventory")
	world = reload_world(world)
	check(not world.plans.is_empty(), "Relocation recipe survives save")
	for kind in ["goods_rack", "small_warehouse", "pottery"]:
		var node := Assets.create(kind)
		check(node != null, "Editable asset loads: " + kind)
		node.free()
	for failure in failures: push_error(failure)
	print("PASS: %s warehouse checks" % checks if failures.is_empty() else "FAIL: %s" % failures)
	quit(0 if failures.is_empty() else 1)
