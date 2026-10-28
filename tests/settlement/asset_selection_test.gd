extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Kit = preload("res://scripts/settlement/structure_parts.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)

func settle() -> void:
	for frame in 5: await process_frame

func click_at(at: Vector2, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.shift_pressed = shift
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await settle()

func run() -> void:
	root.size = Vector2i(1440, 900)
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await settle()
	var editor = workshop.pieces
	editor.activate()
	editor.parts = []
	for index in 40:
		editor.parts.append({"kind": "block", "at": Vector3(30 + index, 0, 0), "rotation": Vector3.ZERO})
	editor.parts[0].at = Vector3(-2, 0, 0)
	editor.parts[1].at = Vector3.ZERO
	editor.parts[39].at = Vector3(2, 0, 0)
	editor.selected = -1
	editor.selecting = true
	workshop._refresh()
	workshop.focus = Vector3.ZERO
	workshop.zoom = 10
	workshop._camera_update()
	await settle()
	var original: Array = editor.parts.duplicate(true)
	for index in [0, 1, 39]:
		var at: Vector2 = workshop.scene_container.global_position + workshop.camera.unproject_position(Kit.bounds(editor.parts[index]).get_center())
		await click_at(at, index != 0)
		var expected := [0] if index == 0 else ([0, 1] if index == 1 else [0, 1, 39])
		check(Array(editor.selection_indices()) == expected, "Scene Shift-click adds object %d without losing prior objects" % index)
		check(Array(editor.layers.get_selected_items()) == expected, "Parts rows match the scene selection for object %d" % index)
	check(editor.layers.get_v_scroll_bar().value > 0, "Scene selection reveals a Parts row below the fold")
	var last_at: Vector2 = workshop.scene_container.global_position + workshop.camera.unproject_position(Kit.bounds(editor.parts[39]).get_center())
	await click_at(last_at, true)
	check(Array(editor.selection_indices()) == [0, 1, 39], "Shift-clicking a selected object keeps it in the additive selection")
	check(editor.layers.get_v_scroll_bar().value > 0, "Reselecting keeps the active Parts row visible")
	var scroll: float = editor.layers.get_v_scroll_bar().value
	workshop._refresh()
	await settle()
	check(is_equal_approx(editor.layers.get_v_scroll_bar().value, scroll), "Refreshing the inspector preserves Parts scroll position")
	check(editor.parts == original, "Additive clicks never move or edit geometry")
	var list_height: float = editor.layers.size.y
	root.size = Vector2i(1440, 1200)
	await settle()
	check(is_equal_approx(editor.layers.size.y - list_height, 300), "Parts list absorbs added screen height")
	check(editor.layers.get_parent().get_global_rect().end.y <= root.size.y, "Parts actions stay inside the screen")
	editor.layers.get_v_scroll_bar().value = 0
	await settle()
	await click_at(editor.layers.global_position + editor.layers.get_item_rect(0).get_center())
	check(Array(editor.selection_indices()) == [0] and Array(editor.layers.get_selected_items()) == [0], "A plain Parts click selects exactly its scene object")
	await click_at(editor.layers.global_position + editor.layers.get_item_rect(1).get_center(), true)
	check(Array(editor.selection_indices()) == [0, 1] and Array(editor.layers.get_selected_items()) == [0, 1], "Shift-click in Parts adds exactly once")
	await click_at(workshop.scene_container.global_position + Vector2(12, 12), true)
	check(Array(editor.selection_indices()) == [0, 1], "Shift-clicking empty space keeps the selection")
	editor.gizmo.nudge(0, 1)
	check(editor.parts[0].at.is_equal_approx(original[0].at + Vector3(0.1, 0, 0)) and editor.parts[1].at.is_equal_approx(original[1].at + Vector3(0.1, 0, 0)), "Selected objects move together")
	check(editor.parts[39] == original[39], "Moving the selection leaves unselected objects alone")
	workshop.undo()
	check(editor.parts == original, "Moving several selected objects is one undo step")
	check(editor.layers.get_selected_items().is_empty(), "Clearing selection clears Parts highlights")
	root.size = Vector2i(1100, 760)
	await settle()
	check(editor.panel.get_global_rect().end.y < 760, "Parts and its actions fit the minimum window height")
	workshop.free()
	if failures.is_empty(): print("PASS: %d asset selection checks" % checks)
	quit(0 if failures.is_empty() else 1)
