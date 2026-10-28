extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
const Gizmo = preload("res://scripts/settlement/asset_transform_gizmo.gd")
const Rotation = preload("res://scripts/settlement/asset_rotation_tool.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func run() -> void:
	var group := Workspace.instance("sawmill", Vector3(0.3, 0.7, -0.2), Vector3(0.2, 0.6, -0.1))
	group.scale = Vector3(1.3, 0.8, 1.1)
	var mesh: Dictionary = Kit.Appearance.defaults("house")[0]
	# Imported skew, mirrored axis, existing Euler rotation and nonuniform scale.
	mesh.basis = Basis(Vector3(-1, 0, 0), Vector3(0.2, 1, 0), Vector3(0, 0.1, 1)) * mesh.basis
	mesh.rotation = Vector3(0.4, -0.3, 0.1)
	mesh.scale = Vector3(0.8, 1.2, 0.9)
	for part in [group, mesh]:
		var bounds := Gizmo.local_bounds(part)
		var pose := Kit.transform(part)
		var centre := pose * bounds.get_center()
		for axis in [Vector3.UP, Vector3(1, 2, -3).normalized()]:
			for degrees in [0.1, 45.0, -90.0, 180.0]:
				var rotated := Rotation.rotated(part, axis, degrees, bounds.get_center())
				var new_pose := Kit.transform(rotated)
				check((new_pose * bounds.get_center()).is_equal_approx(centre), "Rotation keeps the actual mesh centre fixed")
				check(rotated.get("basis") == part.get("basis") and rotated.scale == part.scale, "Rotation preserves imported basis and scale")
				check(rotated.get("children") == part.get("children") and rotated.get("contract") == part.get("contract"), "Rotation preserves prefab children and occupied volume")
				var turn := Basis(axis, deg_to_rad(degrees))
				for corner in 8:
					var expected := centre + turn * (pose * bounds.get_endpoint(corner) - centre)
					check((new_pose * bounds.get_endpoint(corner)).is_equal_approx(expected), "Every mesh corner rotates rigidly around the selected centre")
				check(not Kit.decode(Kit.encode([rotated])).is_empty(), "Arbitrary-axis rotation remains serializable")
	check(Rotation.rotated(group, Vector3.ZERO, 30, Vector3.ZERO) == group, "Zero axis is rejected")
	check(Rotation.rotated(group, Vector3.UP, NAN, Vector3.ZERO) == group, "Nonfinite angle is rejected")

	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	await process_frame
	var editor = workshop.pieces
	editor.activate()
	editor.parts = [group.duplicate(true)]
	editor.selected = 0
	editor.selecting = true
	editor.gizmo.set_mode("angle")
	workshop._refresh()
	editor.fit()
	var tool = editor.gizmo.rotation_tool
	check(tool.controls.visible and editor.gizmo.handles().is_empty(), "Angle mode shows rotation controls and hides size/move handles")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var motion := InputEventMouseMotion.new()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(-100, -100)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	var plank := {"kind": "plank", "at": Vector3(0.3, 0.7, -0.2), "rotation": Vector3.ZERO}
	for index in 3:
		editor.parts = [plank.duplicate(true)]
		editor.selected = 0
		workshop._refresh()
		editor.fit()
		var axis := Vector3.ZERO
		axis[index] = 1
		tool.axis_buttons[index].pressed.emit()
		check(tool.axis == axis and tool.axis_buttons[index].button_pressed, "Every XYZ shortcut selects its exact axis")
		var sphere: Dictionary = tool.sphere()
		var tangent := Rotation.tangent_for(axis)
		# Find an unambiguous point on this ring, away from ring intersections.
		var radial := tangent
		var start := Vector2.ZERO
		for sample in range(1, 24):
			radial = Basis(axis, sample * TAU / 24) * tangent
			start = Rotation.project(radial, sphere)
			var handle: Dictionary = tool.drag_handle(start)
			if not handle.is_empty() and handle.axis == axis: break
		press.position = start
		var before_drag: int = workshop.undo_stack.size()
		var old_dirty: bool = workshop.dirty
		var old_redo: Array = workshop.redo_stack.duplicate(true)
		workshop._view_input(press)
		check(editor.gizmo.dragging and tool.axis == axis, "Each visible ring locks dragging to its world axis")
		motion.position = Rotation.project(Basis(axis, deg_to_rad(43)) * radial, sphere)
		workshop._view_input(motion)
		var turned := Rotation.rotated(plank, axis, 45, Gizmo.local_bounds(plank).get_center())
		check(Kit.transform(editor.parts[0]).is_equal_approx(Kit.transform(turned)), "Ring drag snaps the plank to 45 degrees on each axis")
		var nodes: Array = workshop.geometry.get_children().filter(func(node): return node.get_meta("source_asset", "") == "plank")
		check(nodes.size() == 1 and nodes[0].transform.is_equal_approx(Kit.transform(turned)), "Dragging updates the actual plank Node3D in the scene")
		check(workshop.undo_stack.size() == before_drag + 1, "Live rotation records one undo entry")
		check(tool.sphere() == sphere, "Rotation keeps the displayed ring aligned with its drag projection")
		# Additional motion must not compound the first preview's rotation.
		motion.position = Rotation.project(Basis(axis, deg_to_rad(89)) * radial, sphere)
		workshop._view_input(motion)
		turned = Rotation.rotated(plank, axis, 90, Gizmo.local_bounds(plank).get_center())
		check(Kit.transform(editor.parts[0]).is_equal_approx(Kit.transform(turned)), "Quarter-turn remains exact across multiple drag events")
		workshop._input(escape)
		check(editor.parts[0] == plank and workshop.undo_stack.size() == before_drag and workshop.redo_stack == old_redo and workshop.dirty == old_dirty, "Escape restores geometry and history after live rotation")
		check(not editor.gizmo.dragging and workshop.visible, "Escape cancels rotation without closing Blueprints")
		editor.selected = 0
		workshop._refresh()
		workshop._view_input(press)
		workshop._view_input(motion)
		workshop._input(release)
		check(not editor.gizmo.dragging and Kit.transform(editor.parts[0]).is_equal_approx(Kit.transform(turned)), "Release outside the viewport commits the rotation")
		workshop.undo()
		check(editor.parts[0] == plank, "Undo restores the plank after a ring drag")
		workshop.redo()
		check(Kit.transform(editor.parts[0]).is_equal_approx(Kit.transform(turned)), "Redo restores the dragged rotation")
	# The inverse ellipse becomes singular in an exactly edge-on camera view.
	var edge_handle := {"axis": Vector3.RIGHT, "sphere": {"centre": Vector2.ZERO, "radius": 100.0},
		"u": Vector2.ZERO, "v": Vector2(0, -100), "last_angle": 0.0, "total_angle": 0.0}
	var edge_result: Dictionary = tool.drag_part(plank, edge_handle, Vector2(PI * 50, 0))
	check(Kit.transform(edge_result).is_equal_approx(Kit.transform(Rotation.rotated(plank, Vector3.RIGHT, 90, Gizmo.local_bounds(plank).get_center()))), "Edge-on rings still rotate the model without a singular projection")
	# Crossing the +/-180-degree branch must continue smoothly in either direction.
	var wrap_handle := {"axis": Vector3.BACK, "sphere": {"centre": Vector2.ZERO, "radius": 100.0},
		"u": Vector2(100, 0), "v": Vector2(0, 100), "last_angle": deg_to_rad(170), "total_angle": 0.0}
	var wrap_result: Dictionary = tool.drag_part(plank, wrap_handle, Vector2.from_angle(deg_to_rad(-160)) * 100)
	check(Kit.transform(wrap_result).is_equal_approx(Kit.transform(Rotation.rotated(plank, Vector3.BACK, 30, Gizmo.local_bounds(plank).get_center()))), "Dragging across the angle seam preserves the rotation direction")
	wrap_result = tool.drag_part(plank, wrap_handle, Vector2.from_angle(deg_to_rad(170)) * 100)
	check(wrap_result == plank, "Dragging back to the start restores the exact original pose")
	# Keep precise arbitrary-axis numeric rotation available for imported parts.
	editor.parts = [group.duplicate(true)]
	editor.selected = 0
	workshop._refresh()
	tool.choose_axis(Vector3(1, 2, -3).normalized())
	var before: int = workshop.undo_stack.size()
	var chosen_axis: Vector3 = tool.axis
	tool.choose_axis(-tool.axis)
	check(tool.axis.is_equal_approx(-chosen_axis), "Flip reaches the opposite hemisphere")
	tool.choose_axis(chosen_axis)
	tool.angle_spin.get_line_edit().text = "37.27"
	tool.angle_spin.apply()
	check(is_equal_approx(tool.angle_spin.value, 37.27), "Typed angles retain extra decimal places")
	tool.apply_button.pressed.emit()
	var rotated: Dictionary = editor.parts[0].duplicate(true)
	var expected := Rotation.rotated(group, chosen_axis, 37.27, Gizmo.local_bounds(group).get_center())
	check(Kit.transform(rotated).is_equal_approx(Kit.transform(expected)), "Rotate applies the chosen sphere axis and angle")
	check(workshop.undo_stack.size() == before + 1, "A rotation is one undo step")
	workshop.undo()
	check(editor.parts[0] == group, "Undo restores original pose and children")
	workshop.redo()
	check(Kit.transform(editor.parts[0]).is_equal_approx(Kit.transform(rotated)), "Redo restores arbitrary-axis rotation")
	var path := "/tmp/pyramida-angle-%d.pyrstructure" % Time.get_ticks_usec()
	check(workshop._save(path) and workshop._load(path) and Kit.transform(editor.parts[0]).is_equal_approx(Kit.transform(rotated)), "Rotation survives document save/load")
	DirAccess.remove_absolute(path)
	tool.angle_spin.value = 0
	before = workshop.undo_stack.size()
	tool.apply_button.pressed.emit()
	check(workshop.undo_stack.size() == before, "Zero angle adds no undo step")
	editor.gizmo.set_mode("move")
	check(not tool.controls.visible and tool.sphere().is_empty(), "Sphere hides outside Angle mode")
	editor.gizmo.set_mode("angle")
	editor.selected = -1
	workshop._refresh()
	check(not tool.controls.visible and tool.sphere().is_empty(), "Deselecting hides the sphere and controls")
	workshop.free()
	if failures.is_empty(): print("PASS: %d axis rotation checks" % checks)
	quit(int(not failures.is_empty()))
