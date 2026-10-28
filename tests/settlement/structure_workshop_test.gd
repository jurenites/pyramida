extends SceneTree
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
const Workshop = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Settlement = preload("res://scenes/settlement/Terraces.tscn")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)

func run() -> void:
	var example := Shape.parse_document(JSON.parse_string(FileAccess.get_file_as_string("res://data/structures/stacking-example.pyrstructure")))
	check(not example.is_empty() and int(example.workspace.origin[0]) == 1 and int(example.workspace.origin[1]) == 2 and int(example.workspace.origin[2]) == 0, "Checked-in example loads with its intended placement state")
	var corner := Shape.preset(0)
	check(corner.cells.size() == 3 and Shape.bounds(corner) == Vector3i(2, 1, 2), "L occupies three units rather than its rectangular four-unit bounds")
	var filler := Shape.transformed(Shape.preset(5), Vector3i(1, 0, 1), 0)
	check(Shape.placement_error(filler, [corner]).is_empty(), "A separate building fits inside an L's empty corner")
	check(not Shape.placement_error(corner, [corner]).is_empty(), "Actual occupied-unit overlap is blocked")
	var rotated := Shape.transformed(corner, Vector3i(3, -2, 0), 1)
	check(rotated.cells.has(Vector3i(2, -2, 0)) and rotated.cells.has(Vector3i(3, -2, 1)), "Rotation and below-ground translation preserve irregular footprint")
	check(Shape.unsupported(rotated).is_empty(), "Underground workshop volumes use earth bearings")
	var base := Shape.preset(5)
	var upper := Shape.transformed(base, Vector3i.UP, 0)
	check(not Shape.placement_error(upper, [base]).is_empty(), "A roof supports a unit but does not grant entrance access")
	base.ladders.append({"cell": Vector3i.ZERO, "side": Vector3i.BACK})
	check(Shape.placement_error(upper, [base]).is_empty(), "A ladder supplies entrance access to the supported upper unit")
	var overhang := Shape.transformed(base, Vector3i(1, 1, 0), 0)
	overhang.door = {"cell": Vector3i(1, 1, 0), "side": Vector3i.LEFT}
	check(not Shape.placement_error(overhang, [base]).is_empty(), "Unsupported overhang cannot be placed")
	var additions := Shape.suggest_braces(overhang, [base])
	check(additions.size() == 1 and additions[0].from == Vector3i.ZERO, "Suggested diagonal resolves to a real supported bearing")
	overhang.braces = additions
	check(Shape.placement_error(overhang, [base]).is_empty(), "Diagonal brace supports offset building")
	var floating_base := Shape.transformed(base, Vector3i(0, 2, 0), 0)
	var floating_top := Shape.transformed(base, Vector3i(1, 3, 0), 0)
	floating_top.braces = [{"from": Vector3i(0, 2, 0), "to": Vector3i(1, 3, 0)}]
	check(Shape.unsupported(Shape.merged([floating_base, floating_top])).size() == 2, "A brace cannot turn a floating source into a foundation")
	check(not Shape.valid_brace(Vector3i.ZERO, Vector3i(3, 1, 0)), "Long spans are rejected rather than implying arbitrary structural strength")
	corner.work_per_cell = 10.0
	corner.work_per_brace = 4.0
	check(is_equal_approx(Shape.work(corner), 30.0) and is_equal_approx(Shape.work(overhang), 9.0), "Work depends on occupied units and additional braces")
	var data := Shape.document(corner, [base, overhang])
	var decoded := Shape.parse_document(JSON.parse_string(JSON.stringify(data)))
	check(not decoded.is_empty() and decoded.draft.cells == corner.cells and decoded.instances[1].braces == overhang.braces, "JSON round trip preserves shape, work and cross-building braces")
	var malformed := data.duplicate(true)
	malformed.draft.cells[0].at = [0.5, 0, 0]
	check(Shape.parse_document(malformed).is_empty(), "Fractional cell addresses are rejected")
	malformed = data.duplicate(true)
	malformed.draft.cells.append(malformed.draft.cells[0].duplicate(true))
	check(Shape.parse_document(malformed).is_empty(), "Duplicate occupied units are rejected")
	malformed = data.duplicate(true)
	malformed.assembly.reverse()
	check(not Shape.parse_document(malformed).is_empty(), "Complete assembly support is independent of list order after relocation")
	malformed = data.duplicate(true)
	malformed.draft.work_per_cell = -5
	check(Shape.parse_document(malformed).is_empty(), "Invalid construction budgets are rejected")
	var workshop := Workshop.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	await process_frame
	workshop.act_on_cell(Vector3i(0, -2, 0))
	check(workshop.draft.cells.has(Vector3i(0, -2, 0)), "Editor can sculpt below grade")
	workshop.undo()
	check(not workshop.draft.cells.has(Vector3i(0, -2, 0)), "Undo restores geometry")
	workshop.redo()
	check(workshop.draft.cells.has(Vector3i(0, -2, 0)), "Redo restores geometry")
	workshop.draft = Shape.preset(5)
	workshop.instances = [Shape.preset(5)]
	workshop.instances[0].ladders.append({"cell": Vector3i.ZERO, "side": Vector3i.BACK})
	workshop.draft.door.side = Vector3i.LEFT
	workshop.origin = Vector3i(1, 1, 0)
	workshop.set_mode(1)
	workshop.brush = 2
	workshop.level_spin.value = 0
	workshop.act_on_cell(Vector3i.ZERO)
	workshop.level_spin.value = 1
	workshop.act_on_cell(Vector3i(1, 1, 0))
	check(workshop.origin == Vector3i(1, 1, 0), "Picking brace layers does not move the draft building")
	check(Shape.placement_error(workshop.candidate(), workshop.instances).is_empty(), "Manual brace connects a placed lower building to the draft across layers")
	workshop.load_example()
	check(Shape.placement_error(workshop.candidate(), workshop.instances).is_empty(), "Shipped stacking example is structurally placeable")
	check(workshop.instances[1].braces.size() == 2, "Example demonstrates a real supported overhang")
	workshop.place_copy()
	check(workshop.instances.size() == 3, "Place creates an independent building snapshot")
	workshop.selected_instance = 0
	workshop._remove_selected()
	check(workshop.instances.size() == 3, "Editor blocks removal of a bearing used by upper buildings")
	workshop.draft.cells.clear()
	check(workshop.instances[2].cells.size() == 3, "Editing draft cannot mutate placed geometry")
	workshop.undo()
	var path := "/tmp/pyramida-structure-test-%d.pyrstructure" % Time.get_ticks_usec()
	check(workshop._save(path), "Workshop writes actual project file")
	var before: Dictionary = workshop.draft.duplicate(true)
	var state_before: Dictionary = workshop.workspace_state()
	workshop.act_on_cell(Vector3i(4, 0, 4))
	check(workshop._load(path) and workshop.draft == before, "Opening saved project restores authored data")
	check(workshop.workspace_state() == state_before, "Save/load restores placement offsets, rotation, mode, layer and worker estimate")
	var bad := FileAccess.open(path + ".bad", FileAccess.WRITE)
	bad.store_string('{"format":"wrong"}')
	bad.close()
	check(not workshop._load(path + ".bad") and workshop.draft == before, "Invalid import preserves current work")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bad")
	workshop.close()
	check(not workshop.visible, "Close hides the workspace")
	workshop.open()
	check(workshop.visible and workshop.draft == before, "Reopening retains unsaved authoring state")
	workshop.free()
	var game := Settlement.instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-structure-slots-%d" % Time.get_ticks_usec()
	root.add_child(game)
	await process_frame
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_F2
	shortcut.pressed = true
	Input.parse_input_event(shortcut)
	await process_frame
	check(is_instance_valid(game.structure_workshop) and game.structure_workshop.is_open(), "F2 opens the real workshop through input dispatch")
	check(game.structure_workshop.pieces.enabled and not is_instance_valid(game.structure_workshop.layout_sandbox), "Blueprints opens the unified asset editor without a gallery detour")
	var time_before: float = game.model.time
	game._process(0.5)
	check(is_equal_approx(game.model.time, time_before), "Settlement simulation pauses while authoring")
	check(not game.hud.visible and not game.world_container.visible, "Workshop owns the screen while open")
	Input.parse_input_event(shortcut)
	await process_frame
	check(not game.structure_workshop.is_open(), "F2 closes the workshop without reopening it")
	check(game.hud.visible and game.world_container.visible, "Closing restores the existing settlement view")
	game._process(0.2)
	check(game.model.time > time_before, "Settlement resumes with its existing simulation state")
	game._open_menu(false)
	game.menu.buttons.structure_editor.pressed.emit()
	check(game.structure_workshop.is_open() and game.menu.visible, "Visible debug menu button opens the in-game editor and retains the menu underneath")
	check(game.structure_workshop.pieces.enabled and not is_instance_valid(game.structure_workshop.layout_sandbox), "Blueprints opens the unified asset editor without a gallery detour")
	game.structure_workshop.close()
	check(game.menu.visible and not game.hud.visible, "Closing debug mode returns to the menu when opened there")
	game.free()
	if failures.is_empty():
		print("PASS: %d structure authoring, support, work, persistence and integration checks" % checks)
	quit(0 if failures.is_empty() else 1)
