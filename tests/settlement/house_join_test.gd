extends SceneTree
const Model = preload("res://scripts/settlement/world_model.gd")
const Houses = preload("res://scripts/settlement/house_groups.gd")
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
const Life = preload("res://scripts/settlement/structure_life.gd")
const View = preload("res://scripts/settlement/world_view.gd")
const HUD = preload("res://scripts/settlement/hud.gd")
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + message)
func house(model, cell: Vector3i, direction := 0) -> void:
	model.buildings[cell] = {"kind": "house", "direction": direction, "placement_offset": Vector3.ZERO}
func run() -> void:
	var model = Model.new()
	model.setup()
	model.trees.clear()
	model.deposits.clear()
	model.buildings.clear()
	house(model, Vector3i.ZERO)
	house(model, Vector3i(0, 0, 2))
	check(Houses.members(model, Vector3i.ZERO).size() == 2, "Door-to-wall houses form a 1x2 building")
	house(model, Vector3i(2, 0, 0))
	house(model, Vector3i.UP)
	check(Houses.members(model, Vector3i.ZERO).size() == 2, "Side contact and vertical stacking do not join houses")
	model.buildings.erase(Vector3i.UP)
	model.buildings.erase(Vector3i(2, 0, 0))
	model.rebuild_navigation()
	var saved = Model.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) and Houses.members(saved, Vector3i.ZERO).size() == 2, "Joined identity survives save/load using saved room addresses and doors")
	check(model.Economy.capacity(model) == 6, "Both rooms retain their housing capacity")
	var hud := HUD.new()
	check(hud._tooltip_key({"kind": "house", "cell": Vector3i.ZERO}, model) == hud._tooltip_key({"kind": "house", "cell": Vector3i(0, 0, 2)}, model), "Either room shares one selection identity")
	hud.free()
	var view := View.new()
	root.add_child(view)
	view.setup(model)
	var first: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	var second: Node3D = view.entity_views["building:%s" % Vector3i(0, 0, 2)]
	check(not first.has_node("JoinedWalls") and not second.has_node("JoinedWalls") and first.get_node("BackWall").visible and second.get_node("BackWall").visible, "Adjoining houses preserve their authored shells")
	check(first.get_node("Roof").visible and second.get_node("Roof").visible, "Joined house retains complete roof coverage")
	model.buildings.erase(Vector3i(0, 0, 2))
	model.stores.erase(Vector3i(0, 0, 2))
	model.rebuild_navigation()
	view.sync(model, 0, -1)
	check(not first.has_node("JoinedWalls") and first.get_node("DoorSide").visible, "Removing a neighbour leaves the original facade intact")
	view.free()
	var offset := Vector3(0.12, 0, -0.08)
	model.buildings[Vector3i.ZERO].placement_offset = offset
	check(model.request_build("house", Vector3i(0, 0, 2), 0, Vector3(-0.1, 0, 0.1)), "An adjoining house can be planned")
	var plan: Dictionary = model.plans[model.next_plan_id - 1]
	check(plan.placement_offset == offset, "Door connection aligns the new plan with the existing shell")
	model._complete_plan(plan)
	check(Houses.members(model, Vector3i.ZERO).size() == 2, "Completing an extension joins the existing house")
	model.buildings[Vector3i.ZERO].placement_offset = Vector3.ZERO
	model.buildings[Vector3i(0, 0, 2)].placement_offset = Vector3.ZERO
	var stamp := Houses.stamp(model, Vector3i.ZERO)
	var targets := Houses.targets(stamp, Vector3i(4, 0, 0), 1)
	check(targets[1].cell == Vector3i(2, 0, 0) and targets[1].direction == 1, "Whole-house rotation transforms both room positions and doors")
	var count: int = model.plans.size()
	check(not Houses.request(model, stamp, Vector3i.ZERO, 0, Vector3.ZERO) and model.plans.size() == count, "Invalid whole-house placement creates no partial plans")
	check(Houses.request(model, stamp, Vector3i(6, 0, 0), 0, Vector3.ZERO) and model.plans.size() == count + 2, "Copy queues both rooms with normal construction recipes")
	model.plans.clear()
	check(Houses.request(model, stamp, Vector3i(6, 0, 0), 0, Vector3.ZERO, true) and model.plans.size() == 2, "Move queues physical relocation of the whole house")
	var ids: Array = model.plans.keys()
	check(model.order_build(0, ids[0]) and model.order_build(1, ids[1]), "Builders accept both parts of a house move")
	for step in 2400:
		for worker: Dictionary in model.workers: worker.hunger = 0
		model.tick(0.05)
		if step == 40:
			var restored = Model.new()
			check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "In-progress whole-house move saves and restores")
			model = restored
		if model.plans.is_empty(): break
	check(model.plans.is_empty() and not model.buildings.has(Vector3i.ZERO) and Houses.members(model, Vector3i(6, 0, 0)).size() == 2, "Builders physically move and reconnect both rooms after reload")
	check(model.Deconstruction.request(model, Vector3i(6, 0, 0)) and model.plans.size() == 2, "Remove queues salvage-preserving dismantling for both rooms")
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	workshop.instances = [Shape.preset(5)]
	workshop.draft = Shape.preset(5)
	workshop.draft.work_per_cell = 12.0
	workshop.origin = Vector3i.BACK
	workshop.set_mode(1)
	workshop.place_copy()
	check(workshop.instances.size() == 1 and Shape.bounds(workshop.instances[0]) == Vector3i(1, 1, 2), "Blueprint placement merges into one selectable 1x2 instance")
	check(Shape.work(workshop.instances[0]) == 18.0 and workshop.instances[0].door.cell == Vector3i.BACK, "Merge preserves total work and exterior entrance")
	workshop.undo()
	check(workshop.instances.size() == 1 and workshop.instances[0].cells.size() == 1, "Undo removes the extension atomically")
	workshop.redo()
	check(workshop.instances[0].cells.size() == 2, "Redo restores the whole joined house")
	var joined: Dictionary = workshop.instances[0].duplicate(true)
	joined.extra_doors.append({"cell": Vector3i.ZERO, "side": Vector3i.RIGHT})
	var loaded := Shape.decode(JSON.parse_string(JSON.stringify(Shape.encode(joined))))
	check(loaded.cells.size() == 2 and Life.doors(loaded).size() == 2, "Joined building round trip preserves all exterior entrances")
	workshop.selected_instance = 0
	workshop.begin_move()
	workshop.origin = Vector3i(5, 0, 0)
	workshop.turns = 1
	var before: Array = workshop.instances.duplicate(true)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = workshop.camera.unproject_position(Vector3(0, 0.5, 0))
	var yaw_before: float = workshop.yaw
	workshop._view_input(right)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(25, 10)
	workshop._view_input(motion)
	check(workshop.yaw != yaw_before and workshop.instances == before and workshop.move_index == 0, "Right drag in Map rotates the view without deleting or cancelling a move")
	right.pressed = false
	workshop._view_input(right)
	check(workshop.commit_move() and workshop.instances.size() == 1 and Shape.bounds(workshop.instances[0]) == Vector3i(2, 1, 1), "Move and rotation preserve the joined Blueprint building")
	workshop.set_mode(0)
	workshop.draft = Shape.preset(5)
	workshop.brush = 1
	workshop._refresh()
	right.pressed = true
	workshop._view_input(right)
	right.pressed = false
	workshop._view_input(right)
	check(workshop.draft.cells.size() == 1, "Right-click with the Erase tool active does not delete a room")
	workshop.free()
	await test_game_controls()
	if failures == 0: print("PASS: %d joined house and camera checks" % checks)
	quit(1 if failures else 0)

func test_game_controls() -> void:
	var game := preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-joined-slots-%d" % Time.get_ticks_usec()
	root.add_child(game)
	game.set_process(false)
	game.model.trees.clear()
	game.model.deposits.clear()
	house(game.model, Vector3i.ZERO)
	house(game.model, Vector3i(0, 0, 2))
	game.model.rebuild_navigation()
	game.world.sync(game.model, 0, -1)
	game.selected_object = {"cell": Vector3i.ZERO, "kind": "house", "entity_key": "building:%s" % Vector3i.ZERO}
	game._copy_selected_building()
	check(game.house_stamp.size() == 2 and game.preview.get_child_count() == 2, "Live Copy creates a two-room preview")
	check(game.preview.has_meta("placement_edges"), "Joined preview outlines its entire volume")
	game._set_tool("inspect")
	game._begin_relocation()
	check(game.house_stamp.size() == 2 and game.relocation_source == Vector3i.ZERO, "Live Move includes the whole connected house")
	game._clear_selection()
	check(game.house_stamp.is_empty(), "Cancelling clears the house placement template")
	game.free()
