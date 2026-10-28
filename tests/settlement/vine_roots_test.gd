extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Vines = preload("res://scripts/settlement/vines.gd")
const Scene = preload("res://scenes/settlement/Terraces.tscn")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func reload_world(world):
	var restored = Model.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(world.snapshot()))), "Root state restores through JSON")
	return restored

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = Model.new()
	world.setup()
	var source := Vector3i(-4, 0, -1)
	check(world.vines.has(source), "A new map has a reachable wild root")
	check(world.vine_roots == 0 and not world.vine_discovered, "Wild roots do not grant inventory or unlock the menu")
	check(not world.request_build("seed_vine", Vector3i.ZERO), "Vines cannot be planted from unlimited seeds")
	check(world.request_build("seed_tree", Vector3i.ZERO), "Other seeds remain unlimited")
	world.delete_plan(world.next_plan_id - 1)
	for worker in world.workers: world.set_role(worker.id, "idle")
	check(Vines.request_collect(world, source), "Selecting Collect root queues physical uprooting")
	check(not Vines.request_collect(world, source), "A root cannot be collected twice")
	var id: int = world.next_plan_id - 1
	check(not world.order_build(2, id), "Children cannot uproot vines")
	check(world.order_build(0, id), "An adult can collect the root")
	for i in 400:
		world.tick(0.05)
		if world.plans[id].relocation.labour.applied_seconds > 0.5: break
	check(world.vine_roots == 0 and world.vines.has(source), "Collection waits for arrival and labour")
	world = reload_world(world)
	for i in 400:
		world.tick(0.05)
		if not world.plans.has(id): break
	check(world.vine_roots == 1 and world.vine_discovered and not world.vines.has(source), "Completed collection yields exactly one root")
	world.set_role(0, "idle")
	var cell := Vector3i(0, 0, -3)
	var offset := Vector3(0.37, 0, -0.28)
	check(world.placement_offset("seed_vine", cell, world.Navigation.point(cell) + offset).is_equal_approx(offset), "The root follows the exact cursor without snapping")
	check(world.request_build("seed_vine", cell, 0, offset), "A root can be planted away from any wall")
	id = world.next_plan_id - 1
	check(world.vine_roots == 0 and not world.request_build("seed_vine", Vector3i(3, 0, -3)), "Queued sowing reserves the last root immediately")
	world = reload_world(world)
	check(world.move_plan(id, cell + Vector3i.RIGHT, 0, offset), "Moving the reserved order does not need another root")
	check(world.delete_plan(id) and world.vine_roots == 1, "Deleting a restored sowing order returns its reserved root")
	# A building corner needs only root clearance, not an empty terrain cell.
	world.buildings[Vector3i.ZERO] = {"kind": "house", "direction": 0}
	world.rebuild_navigation()
	cell = Vector3i(1, 0, 1)
	offset = Vector3(0.23, 0, 0.31)
	check(world.request_build("seed_vine", cell, 0, offset), "Free placement fits just outside a building corner")
	id = world.next_plan_id - 1
	world._complete_plan(world.plans[id])
	check(world.vines[cell].placement_offset == offset and world.vine_roots == 0, "Sowing preserves the exact root position")
	world.Hydrology.tick(world, 360.0)
	check(world.vines[cell].nodes.size() > 4, "A freely placed root grows around the building autonomously")
	world = reload_world(world)
	check(world.vines[cell].placement_offset.is_equal_approx(offset), "Exact root position survives a save")
	var chunk := Vector2i(8, 0)
	world.Chunks.load_chunk(world, chunk)
	var remote := Vector3i(chunk.x * world.Generator.CHUNK_SIZE + 4, 0, 4)
	world.vines[remote] = Vines.create()
	world.vines[remote].wild = true
	world.Chunks.unload_chunk(world, chunk)
	check(not world.vines.has(remote), "Wild roots unload with their chunk")
	world = reload_world(world)
	world.Chunks.load_chunk(world, chunk)
	check(world.vines.has(remote), "Wild roots survive dormant saves")
	world.vines.erase(remote)
	world.Chunks.unload_chunk(world, chunk)
	world.Chunks.load_chunk(world, chunk)
	check(not world.vines.has(remote), "Collected wild roots do not regenerate on chunk reload")
	var game = Scene.instantiate()
	game.launch_to_menu = false
	game.capture = true
	root.add_child(game)
	game.set_process(false)
	game.model = world
	game.world.sync(world, 0, -1)
	var node: Node3D = game.world.entity_views["vine:%s" % cell]
	check(node.position.is_equal_approx(world.Navigation.point(cell) + offset), "Rendered root and its collider share the saved position")
	game.hud.show_category("nature")
	game.hud.update(world, -1, 1)
	var row: Button = game.hud.buttons.seed_vine
	check(row.visible and row.disabled and row.get_meta("plant_title").text.ends_with("(0)"), "Exhausted vine item stays visible and disabled with (0)")
	world.vine_roots = 2
	game.hud.update(world, -1, 1)
	check(not row.disabled and row.get_meta("plant_title").text.ends_with("(2)"), "Available roots enable the item and update its count")
	world.vine_roots = 0
	world.vine_discovered = false
	game.hud.update(world, -1, 1)
	check(not row.visible and not game.hud.buttons.seed_tree.disabled, "Undiscovered vines are hidden and other seeds stay enabled")
	game._set_tool("seed_vine")
	game.rig.focus = Vector3.ZERO
	game.rig.update_camera()
	for frame in 3: await physics_frame
	var target := Vector3(-1.24, 0, 3.39)
	var placement: Dictionary = game.placement_at(game.rig.camera.unproject_position(target))
	check(not placement.is_empty() and (world.Navigation.point(placement.cell) + placement.offset).distance_to(target) < 0.01, "Actual cursor picking preserves a free ground position")
	world.vines[source] = Vines.create()
	world.revision += 1
	game.world.sync(world, 0, -1)
	game._set_tool("inspect")
	game.selected_workers.assign([0])
	for frame in 2: await physics_frame
	game.command_at(game.rig.camera.unproject_position(world.Navigation.point(source) + Vector3.UP * 0.2))
	check(world.plans.values().any(func(plan): return plan.get("collect_vine", false) and plan.cell == source), "Right-clicking a wild root queues collection")
	check(world.workers[0].get("assigned_plan_id", -1) != -1, "Right-click assigns the selected adult to collect")
	game.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: %d collected vine root checks" % checks)
	quit(int(not failures.is_empty()))
