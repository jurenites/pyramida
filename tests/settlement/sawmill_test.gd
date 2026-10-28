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
	build(world, "sawmill", cell)
	check(world.buildings[cell].sawmill_tier == 1, "New sawmill is sawhorses")
	check(not world.request_build("house", cell), "Bench upgrade required before shell")
	var rate1: float = world.Economy.production_speed(world, cell)
	check(world.snap_cell("sawmill", "sawmill", cell) == cell, "Upgrade snaps to same floor")
	check(world.request_build("sawmill", cell), "Queue bench upgrade")
	check(not world.Relocation.source_error(world, cell).is_empty(), "Cannot move workplace during upgrade")
	check(not world.move_plan_error(world.plans.values().back().id, Vector3i(8, 0, 0), 0, Vector3.ZERO).is_empty(), "Cannot detach upgrade from bench")
	world = reload_world(world)
	world._complete_plan(world.plans.values().back())
	check(world.buildings[cell].sawmill_tier == 2, "Bench upgrade survives pending save")
	check(world.Economy.production_speed(world, cell) > rate1, "Bench is faster")
	check(not world.request_build("sawmill", cell), "Cannot repeat bench upgrade")
	var housing: int = world.Economy.capacity(world)
	build(world, "house", cell)
	check(world.buildings[cell].kind == "sawmill" and world.buildings[cell].sawmill_tier == 3, "House wraps bench as sawmill")
	check(world.Economy.capacity(world) == housing, "Saw shed adds no residents")
	check(world.Economy.production_speed(world, cell) == 1.5, "Roof improves production")
	check(world.navigation.surfaces.has(cell + world.Grid.STOREY), "Completed shed supports upper floor")
	world = reload_world(world)
	check(world.buildings[cell].sawmill_tier == 3, "Completed tier survives save")
	check(world.construction_materials[cell] == {"log": 10, "plank": 2}, "All invested materials retained")
	check(not world.request_build("sawmill", cell), "Tier three rejects upgrades")
	check(world.Relocation.request(world, cell, Vector3i(8, 0, 0), 0, Vector3.ZERO), "Completed shed can move")
	world = reload_world(world)
	check(not world.plans.is_empty(), "Moving upgraded shed survives save")
	var elevated = fresh()
	var deck := Vector3i(4, 2, 0)
	elevated.platforms[deck] = true
	elevated.platforms[deck + Vector3i(2, 0, 0)] = true
	elevated.rebuild_navigation()
	check(elevated.request_build("sawmill", deck), "Sawmill can stand on completed elevated floor")
	var production = fresh()
	var operator: Dictionary = production.workers[0]
	for tier in range(1, 4):
		production.buildings[cell] = {"kind": "sawmill", "direction": 0, "sawmill_tier": tier}
		operator.route = []
		operator.route_index = 0
		operator.hunger = 0.0
		operator.erase("retry_at")
		operator.job = {"kind": "process", "phase": "work", "target": cell, "output": "plank", "labour": production.Jobs.Labour.new(5.0)}
		production.Jobs._tick_worker(production, operator, 1.0)
		check(is_equal_approx(operator.job.labour.applied_seconds, [0.75, 1.0, 1.5][tier - 1]), "Actual production applies tier speed")
	production.buildings[cell].erase("sawmill_tier")
	check(production.Economy.production_speed(production, cell) == 1.0, "Legacy sawmill retains current rate")
	for tier in range(1, 4):
		var node := Assets.create("sawmill")
		preload("res://scripts/settlement/sawmill_view.gd").sync(node, tier)
		check(node.get_node("Sawhorses").visible == (tier == 1), "Only tier one shows horses")
		check(node.get_node("TableTop").visible == (tier >= 2), "Bench appears at tier two")
		check(node.get_node("SawShed").visible == (tier == 3), "Only tier three has shed")
		node.free()
	for failure in failures: push_error(failure)
	print("PASS: %s sawmill checks" % checks if failures.is_empty() else "FAIL: %s" % failures)
	quit(0 if failures.is_empty() else 1)
