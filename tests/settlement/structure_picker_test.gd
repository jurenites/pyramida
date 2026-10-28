extends SceneTree
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
const Picker = preload("res://scripts/settlement/structure_picker.gd")
const Workshop = preload("res://scenes/settlement/StructureWorkshop.tscn")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func run() -> void:
	var corner := Shape.preset(0)
	var hit := Picker.pick(Vector3(0, 10, 0), Vector3.DOWN, corner.cells)
	check(hit.cell == Vector3i.UP, "Roof targets the next floor automatically")
	hit = Picker.pick(Vector3(10, 0.5, 0), Vector3.LEFT, corner.cells)
	check(hit.cell == Vector3i(2, 0, 0), "A side face grows the shape sideways")
	hit = Picker.pick(Vector3(1, 10, 1), Vector3.DOWN, corner.cells)
	check(hit.cell == Vector3i(1, 0, 1) and not hit.has("hit_cell"), "Sparse L gap reaches the ground, never an invented rectangular roof")
	var tower := Shape.preset(5)
	tower.cells[Vector3i.UP] = "stone"
	hit = Picker.pick(Vector3(0, 10, 0), Vector3.DOWN, tower.cells)
	check(hit.cell == Vector3i(0, 2, 0), "Nearest visible roof wins")
	hit = Picker.pick(Vector3(0, 10, 0), Vector3.DOWN, tower.cells, 0, false, false, 0)
	check(hit.cell == Vector3i.UP, "Hidden cutaway units cannot intercept a roof pick")
	hit = Picker.pick(Vector3(0, 10, 0), Vector3.DOWN, tower.cells, -2, true)
	check(hit.cell == Vector3i(0, -2, 0), "Manual level passes through roofs to underground")
	hit = Picker.pick(Vector3(0, 10, 0), Vector3.DOWN, tower.cells, 0, true)
	check(hit.cell == Vector3i.ZERO, "Manual level permits replacing a unit inside an existing volume")
	hit = Picker.pick(Vector3(0, 10, 0), Vector3.DOWN, tower.cells, 0, false, true)
	check(hit.cell == Vector3i.UP, "Erase and brace target the touched unit, not the next floor")
	check(Picker.pick(Vector3(0, 1, 0), Vector3.UP, {}).is_empty(), "A ray pointing away from ground returns no target")
	check(Picker.pick(Vector3(30, 10, 30), Vector3.DOWN, {}).is_empty(), "Out-of-bounds planes produce no target")
	var tallest := {Vector3i(0, Shape.MAX_LEVEL, 0): "stone"}
	check(Picker.pick(Vector3(0, 30, 0), Vector3.DOWN, tallest).is_empty(), "Top of workspace cannot produce an out-of-bounds unit")
	var offset := Shape.transformed(Shape.preset(5), Vector3i(3, 2, 1), 0)
	check(Picker.anchor(offset, 1) == Vector3i(-1, 2, 3), "Rotation respects an occupied anchor for off-origin drafts")
	check(Picker.anchor(Shape.preset(4), 0) == Vector3i.ZERO, "A cellar blueprint keeps its ground-level pivot")
	var workshop := Workshop.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	await process_frame
	workshop.draft = Shape.preset(5)
	workshop._refresh()
	var roof: Vector2 = workshop.camera.unproject_position(Vector3(0, 1, 0))
	workshop._pick(roof)
	check(workshop.hovered == Vector3i.UP and workshop.edit_level == 1, "Actual camera projection updates the hover and level to the roof")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = roof
	workshop._view_input(click)
	check(workshop.draft.cells.has(Vector3i.UP), "Clicking a roof adds a tile above without touching level controls")
	workshop.draft = Shape.preset(5)
	workshop.instances = [Shape.preset(5)]
	workshop.instances[0].ladders.append({"cell": Vector3i.ZERO, "side": Vector3i.BACK})
	workshop.origin = Vector3i(7, 5, 7)
	workshop.set_mode(1)
	roof = workshop.camera.unproject_position(Vector3(0, 1, 0))
	for index in 5:
		workshop._pick(roof)
	check(workshop.origin == Vector3i.UP, "Stack preview follows the roof without picking itself and climbing")
	click.position = roof
	workshop._view_input(click)
	check(workshop.instances.size() == 2 and workshop.instances[1].cells.has(Vector3i.UP), "3D click places the whole building directly on the hovered roof")
	roof = workshop.camera.unproject_position(Vector3(0, 2, 0))
	workshop._pick(roof)
	check(workshop.origin == Vector3i(0, 2, 0), "Next building snaps onto the newly placed roof")
	var down := InputEventKey.new()
	down.physical_keycode = KEY_Q
	down.pressed = true
	for index in 3:
		workshop._input(down)
	check(workshop.manual_level and workshop.edit_level == -1 and workshop.origin.y == -1, "Q lowers the current cursor floor into a locked underground level")
	var point: Vector2 = workshop.camera.unproject_position(Vector3(0, -1, 0))
	workshop._pick(point)
	check(workshop.hovered == Vector3i(0, -1, 0), "Manual cursor stays below the building instead of jumping back to a roof")
	var up := InputEventKey.new()
	up.physical_keycode = KEY_E
	up.pressed = true
	workshop._input(up)
	check(workshop.edit_level == 0 and workshop.manual_level, "E raises the locked level")
	var auto := InputEventKey.new()
	auto.physical_keycode = KEY_F
	auto.pressed = true
	workshop._input(auto)
	workshop._pick(roof)
	check(not workshop.manual_level and workshop.origin == Vector3i(0, 2, 0), "F restores cursor-driven roof snapping")
	workshop.mode = 0
	workshop.draft = tower
	workshop.manual_level = true
	workshop.edit_level = 0
	workshop.selected_material = "clay"
	workshop._refresh()
	click.position = workshop.camera.unproject_position(Vector3.ZERO)
	workshop._view_input(click)
	check(workshop.draft.cells[Vector3i.ZERO] == "clay" and workshop.draft.cells[Vector3i.UP] == "stone", "Manual click repaints the existing interior level without changing its roof")
	workshop.manual_level = false
	workshop.brush = 1
	workshop._refresh()
	click.position = workshop.camera.unproject_position(Vector3(0, 2, 0))
	workshop._view_input(click)
	check(not workshop.draft.cells.has(Vector3i.UP) and workshop.draft.cells.has(Vector3i.ZERO), "Erase selects the visible roof unit instead of empty space above")
	workshop.free()
	if failures.is_empty():
		print("PASS: %d cursor surface, manual level and real camera input checks" % checks)
	quit(0 if failures.is_empty() else 1)
