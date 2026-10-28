extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
var checks := 0
var failures: Array[String] = []
var workshop: CanvasLayer
var editor: RefCounted

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func same_data(a: Variant, b: Variant) -> bool:
	# JSON round trips double-precision contract values through decimal text.
	if (a is float or a is int) and (b is float or b is int): return is_equal_approx(a, b)
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same_data(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not same_data(a[index], b[index]): return false
		return true
	return a == b
func shortcut(command := true, ungroup := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_G
	event.meta_pressed = command
	event.ctrl_pressed = not command
	event.shift_pressed = ungroup
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
func mouse(point: Vector2, pressed := true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	return event
func select_pair() -> void:
	editor.select_layer(2)
	editor.select_layer(0, true)
	workshop.scene_container.grab_focus()

func run() -> void:
	workshop = Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	await process_frame
	editor = workshop.pieces
	editor.activate()
	editor.new_asset("prefab")
	var a := Workspace.instance("raw_stone", Vector3(-2.13, 0.4, 0), Vector3(0.2, -0.3, 0.1))
	a.scale = Vector3(1.2, 0.8, 1.1)
	a.basis = Basis(Vector3(-1, 0, 0), Vector3(0.1, 1, 0), Vector3(0, 0.2, 1))
	var b := Workspace.instance("log", Vector3(2.17, 1, 0), Vector3(0, 0.2, 0))
	Kit.Appearance.set_timber_species(b, "palm")
	var untouched := Workspace.instance("raw_stone", Vector3(0, 0, 4))
	var before: Array = [a.duplicate(true), untouched.duplicate(true), b.duplicate(true)]
	editor.parts = before.duplicate(true)
	select_pair()
	var history: int = workshop.undo_stack.size()
	editor.search.grab_focus()
	shortcut()
	check(editor.parts == before and workshop.undo_stack.size() == history, "Command-G does not group while editing text")
	workshop.scene_container.grab_focus()
	shortcut()
	check(editor.parts.size() == 2, "Command-G creates one group from non-adjacent selected rows")
	if editor.parts.size() != 2:
		workshop.free()
		quit(1)
		return
	var grouped: Array = editor.parts.duplicate(true)
	check(grouped[0].label == "Group" and grouped[0].kind == "assembly", "Group is a persistent assembly layer")
	check(grouped[0].children == [a, b], "Grouping retains exact source transforms, metadata and original child order")
	check(grouped[1] == untouched, "Unselected layers are unchanged")
	check(editor.selection_indices() == [0] and editor.layers.get_selected_items() == PackedInt32Array([0]), "New group becomes the sole selected Parts row")
	check(editor.layers.get_item_text(0) == "Group", "Parts list shows the grouping layer")
	check(workshop.undo_stack.size() == history + 1, "Grouping is one undo step")
	check(not editor.scale_spins[0].editable, "Grouping timber retains fixed-size protection")
	shortcut()
	check(editor.parts == grouped and workshop.undo_stack.size() == history + 1, "Single selection does not create redundant groups")
	workshop.undo()
	check(editor.parts == before, "Undo restores original layers and ordering exactly")
	workshop.redo()
	check(editor.parts == grouped, "Redo restores the persistent group")
	editor.select_layer(0)
	editor.search.grab_focus()
	shortcut(false, true)
	check(editor.parts == grouped, "Ctrl-Shift-G leaves groups intact while editing text")
	editor.layers.grab_focus()
	history = workshop.undo_stack.size()
	shortcut(false, true)
	check(editor.parts == [a, b, untouched], "Ctrl-Shift-G releases members in place from Parts keyboard focus")
	check(editor.selection_indices() == [0, 1] and editor.layers.get_selected_items() == PackedInt32Array([0, 1]), "Released members remain selected")
	check(workshop.undo_stack.size() == history + 1, "Ungrouping is one undo step")
	workshop.undo()
	check(editor.parts == grouped, "Undo ungroup restores the original group")
	workshop.redo()
	check(editor.parts == [a, b, untouched], "Redo ungroup restores released members")
	workshop.undo()
	editor.select_layer(-1)
	editor.fit()
	var screen: Vector2 = workshop.camera.unproject_position(Kit.bounds(a).get_center())
	workshop._view_input(mouse(screen))
	check(editor.selected == 0 and editor.dragging, "Clicking a member after deselection selects and drags its group")
	var motion := InputEventMouseMotion.new()
	motion.position = screen + Vector2(60, 0)
	workshop._view_input(motion)
	workshop._input(mouse(motion.position, false))
	var moved: Dictionary = editor.parts[0]
	check(moved.at != Vector3.ZERO and moved.children == [a, b], "Viewport drag moves the parent while preserving all local children")
	for child: Dictionary in moved.children:
		var pose := Kit.transform(moved) * Kit.transform(child)
		check(pose.origin.is_equal_approx(child.at + moved.at) and pose.basis.is_equal_approx(Kit.transform(child).basis), "Each grouped object follows the same translation with unchanged orientation and size")
	workshop.undo()
	check(editor.parts == grouped, "Group dragging undoes atomically")
	editor.select_layer(0)
	editor.gizmo.nudge(1, 1)
	check(is_equal_approx(editor.parts[0].at.y, 0.1), "Loose-part groups keep tenth-metre movement")
	var path := "/tmp/pyramida-grouping-%d.pyrstructure" % Time.get_ticks_usec()
	var saved: Array = Kit.encode(editor.parts)
	check(workshop._save(path) and workshop._load(path), "Grouped workspace saves and reloads")
	check(same_data(Kit.encode(editor.parts), saved), "Group hierarchy and all transforms survive the file round trip")
	DirAccess.remove_absolute(path)
	editor.select_layer(0)
	editor.enter_selected()
	check(editor.scopes.size() == 1 and same_data(Kit.encode(editor.parts), Kit.encode([a, b])), "Group opens for individual component edits")
	var inside: Array = editor.parts.duplicate(true)
	editor.select_layer(0)
	editor.select_layer(1, true)
	workshop.scene_container.grab_focus()
	shortcut()
	check(editor.parts.size() == 1 and editor.parts[0].children == inside, "Command-G also groups within an open component")
	shortcut(true, true)
	check(editor.parts == inside and editor.scopes.size() == 1, "Command-Shift-G ungroups one level inside the current scope")
	workshop.undo()
	workshop.undo()
	check(editor.parts == inside and editor.scopes.size() == 1, "Undo nested grouping restores the current editing scope")
	editor.select_layer(0)
	editor.gizmo.nudge(0, 1)
	var edited: Array = editor.parts.duplicate(true)
	editor.leave_scope()
	check(editor.parts[0].children == edited and same_data(Kit.encode([editor.parts[1]]), Kit.encode([untouched])), "Returning from group preserves edits and surrounding objects")
	# Ctrl-G must work from the Parts list as well as Command-G in the viewport.
	editor.parts = [Workspace.instance("house", Vector3(0.03, 0, 0)), untouched, a]
	select_pair()
	editor.layers.grab_focus()
	shortcut(false)
	check(editor.parts.size() == 2 and editor.parts[0].label == "Group", "Ctrl-G groups from Parts keyboard focus")
	editor.gizmo.nudge(0, 1)
	check(editor.parts[0].at == Vector3.RIGHT and is_equal_approx(editor.parts[0].children[0].at.x, 0.03), "Groups containing buildings use metre steps without changing authored offsets")
	# Compose full affine transforms, retaining nested children and metadata.
	var inner := {"kind": "assembly", "at": Vector3(1, 0, 0), "rotation": Vector3(0.2, 0.3, 0.4), "children": [a.duplicate(true)], "label": "Inner"}
	var transformed := {"kind": "assembly", "at": Vector3(2, 3, -1), "rotation": Vector3(0.3, -0.4, 0.5), "scale": Vector3(1.2, 0.8, 1.4), "basis": a.basis, "children": [a.duplicate(true), inner]}
	editor.parts = [untouched, transformed, grouped[0].duplicate(true)]
	editor.select_layer(1)
	editor.select_layer(2, true)
	workshop.scene_container.grab_focus()
	shortcut(false, true)
	check(editor.parts.size() == 5 and editor.parts[0] == untouched, "Ungrouping multiple groups preserves surrounding layers")
	for index in 2:
		var expected := Kit.transform(transformed) * Kit.transform(transformed.children[index])
		check(Kit.transform(editor.parts[index + 1]).is_equal_approx(expected), "Ungroup preserves the complete translated, rotated, scaled and sheared pose")
	check(editor.parts[2].children == inner.children and editor.parts[2].label == "Inner", "Ungroup releases only one level and preserves nested metadata")
	path = "/tmp/pyramida-ungrouping-%d.pyrstructure" % Time.get_ticks_usec()
	saved = Kit.encode(editor.parts)
	check(workshop._save(path) and workshop._load(path) and same_data(Kit.encode(editor.parts), saved), "Ungrouped transforms and hierarchy survive save/load")
	DirAccess.remove_absolute(path)
	editor.select_layer(-1)
	history = workshop.undo_stack.size()
	shortcut(false, true)
	check(workshop.undo_stack.size() == history, "Ungroup without selection creates no undo step")
	editor.parts = [a.children[0].duplicate(true)]
	editor.select_layer(0)
	shortcut(false, true)
	check(editor.parts.size() == 1 and workshop.undo_stack.size() == history, "Ungroup on a leaf leaves geometry and history unchanged")
	# Grouping within a component must respect the complete document depth.
	var leaves: Array = [a.children[0].duplicate(true), a.children[0].duplicate(true)]
	var nested := leaves
	for i in 8:
		nested = [{"kind": "assembly", "at": Vector3.ZERO, "rotation": Vector3.ZERO, "children": nested}]
	editor.parts = nested
	for i in 8:
		editor.select_layer(0)
		editor.enter_selected()
	editor.select_layer(0)
	editor.select_layer(1, true)
	workshop.scene_container.grab_focus()
	history = workshop.undo_stack.size()
	shortcut()
	check(editor.parts == leaves and workshop.undo_stack.size() == history, "Over-deep grouping is rejected without changing geometry or history")
	workshop.free()
	if failures.is_empty(): print("PASS: %d Blueprint grouping checks" % checks)
	quit(int(not failures.is_empty()))
