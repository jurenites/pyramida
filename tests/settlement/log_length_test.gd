extends SceneTree
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
const Gizmo = preload("res://scripts/settlement/asset_transform_gizmo.gd")
var checks := 0
var failures := 0
var workshop: CanvasLayer
var editor: RefCounted

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + message)

func _initialize() -> void: call_deferred("run")

func select(part: Dictionary, mode := "size") -> void:
	editor.parts = [part.duplicate(true)]
	editor.selected = 0
	editor.selected_layers.clear()
	editor.selecting = true
	workshop._refresh()
	editor.gizmo.set_mode(mode)

func run() -> void:
	workshop = preload("res://scenes/settlement/StructureWorkshop.tscn").instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	editor = workshop.pieces
	editor.activate()
	var stock := Workspace.instance("log", Vector3(0.2, 0.3, -0.1), Vector3(0.2, 0.6, 0.4))
	for original in [stock, {"kind": "log", "at": stock.at, "rotation": stock.rotation}]:
		select(original)
		check(editor.gizmo.mode == "size", "Individual logs enable Size")
		var handles: Array = editor.gizmo.handles()
		check(handles.size() == 2 and handles.all(func(h): return h.kind == "face" and h.axis == 0), "Only the two length ends have resize handles")
		check(editor.scale_spins[0].editable and not editor.scale_spins[1].editable and not editor.scale_spins[2].editable, "Numeric scale only enables log length")
		check(editor.gizmo.nudge_buttons[2].disabled and editor.gizmo.nudge_buttons[4].disabled, "Thickness nudges are disabled")
		for handle: Dictionary in handles:
			var cut := Gizmo.transformed(original, handle, -0.3)
			var scale := Kit.transform(cut).basis.get_scale()
			check(scale.x < 1 and is_equal_approx(scale.y, 1) and is_equal_approx(scale.z, 1), "Tilted logs shorten without changing diameter")
			check(is_equal_approx(handle.length * scale.x, handle.length - 0.3), "The chosen end moves inward by the requested distance")
			check((Kit.transform(cut) * handle.anchor).is_equal_approx(Kit.transform(original) * handle.anchor), "The opposite end stays fixed")
			var cut_handle := handle.duplicate()
			cut_handle.length = handle.length * scale.x
			var restored := Gizmo.transformed(cut, cut_handle, 100)
			check(Kit.transform(restored).is_equal_approx(Kit.transform(original)), "Length cannot exceed original stock")
			var tiny := Gizmo.transformed(original, handle, -100)
			check(is_equal_approx(Kit.transform(tiny).basis.get_scale().x, 0.01), "Cutting past the opposite end cannot invert or collapse the log")
			var decoded := Kit.decode(JSON.parse_string(JSON.stringify(Kit.encode([cut]))))
			check(Kit.transform(decoded.parts[0]).is_equal_approx(Kit.transform(cut)), "Cuts survive JSON save/load")
		for invalid in [{"kind": "face", "axis": 1}, {"kind": "face", "axis": 2}, {"kind": "corner", "axis": -1}]:
			check(Gizmo.transformed(original, invalid, -0.3) == original, "Programmatic thickness/corner resizing is rejected")
		select(original, "face")
		check(editor.gizmo.handles().size() == 2 and editor.gizmo.face_picker.is_item_disabled(2), "Face mode only offers log ends")
		editor.gizmo.editing_face = 0
		editor.gizmo.nudge_face(-1)
		var cut: Dictionary = editor.parts[0].duplicate(true)
		check(Kit.transform(cut).basis.get_scale().x < 1, "Face nudge cuts the log")
		workshop.undo()
		check(editor.parts[0] == original, "Undo restores full stock")
		workshop.redo()
		check(editor.parts[0] == cut, "Redo restores the cut")
		select(original)
		editor.scale_spins[0].get_line_edit().text = "0.456789"
		editor.scale_spins[0].apply()
		check(is_equal_approx(Kit.transform(editor.parts[0]).basis.get_scale().x, 0.456789), "Numeric length retains entered precision")
		editor.scale_spins[1].value_changed.emit(3)
		check(is_equal_approx(Kit.transform(editor.parts[0]).basis.get_scale().y, 1), "Numeric signals cannot bypass diameter lock")
		editor.scale_spins[0].value_changed.emit(3)
		check(Kit.transform(editor.parts[0]).basis.get_scale().is_equal_approx(Vector3.ONE), "Numeric signals cannot exceed stock length")
	# Exercise actual pointer input, cancellation, file persistence and unpacking.
	select(stock)
	var handle: Dictionary = editor.gizmo.handles()[1]
	var start: Vector2 = workshop.camera.unproject_position(handle.point)
	check(editor.gizmo.begin(start), "Pointer selects a log end")
	editor.gizmo.drag(start - editor.gizmo.screen_axis * 0.3)
	check(Kit.transform(editor.parts[0]).basis.get_scale().x < 1, "Pointer drag shortens a log")
	editor.gizmo.cancel()
	check(editor.parts[0] == stock, "Cancelling a cut restores the original")
	editor.gizmo.nudge(0, -1)
	var cut: Dictionary = editor.parts[0].duplicate(true)
	var path := "/tmp/pyramida-log-cut-%d.pyrstructure" % Time.get_ticks_usec()
	check(workshop._save(path) and workshop._load(path), "A cut workspace saves and reloads")
	check(Kit.transform(editor.parts[0]).is_equal_approx(Kit.transform(cut)), "Workspace reload retains the cut length")
	DirAccess.remove_absolute(path)
	select(cut)
	var expected := Kit.bounds(cut)
	editor.ungroup_selected()
	var unpacked := {"kind": "assembly", "at": Vector3.ZERO, "rotation": Vector3.ZERO, "children": editor.parts}
	check(Kit.bounds(unpacked).is_equal_approx(expected), "Unpacking a cut log preserves bark and end positions")
	select(cut)
	editor.components.name_edit.text = "Short log"
	editor.components.store_selection()
	var stored: Dictionary = editor.library_instance(editor.library_choice)
	check(Kit.bounds(stored).size.is_equal_approx(Gizmo.local_bounds(cut).size * Kit.Appearance.resize_scale(cut)), "Stored reusable logs retain the cut instead of restoring stock length")
	for locked in [Workspace.instance("plank", Vector3.ZERO), Workspace.instance("house", Vector3.ZERO), {"kind": "assembly", "at": Vector3.ZERO, "rotation": Vector3.ZERO, "children": [cut]}]:
		select(locked)
		check(editor.gizmo.mode == "move" and editor.gizmo.mode_buttons[1].disabled, "Planks, buildings and groups remain locked")
	select(cut)
	editor.parts.append(stock.duplicate(true))
	editor.select_layer(1, true)
	editor.gizmo.set_mode("size")
	check(editor.gizmo.mode == "move", "Multi-selected logs cannot resize together")
	workshop.free()
	if failures == 0: print("PASS: %d log length checks" % checks)
	quit(int(failures > 0))
