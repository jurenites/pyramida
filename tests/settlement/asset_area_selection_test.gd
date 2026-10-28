extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Geometry = preload("res://scripts/settlement/asset_selection_geometry.gd")
var checks := 0
var failures: Array[String] = []
var workshop: CanvasLayer
var editor: RefCounted
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func button(at: Vector2, pressed: bool, shift := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	event.shift_pressed = shift
	return event
func drag(a: Vector2, b: Vector2, shift := false) -> void:
	var offset: Vector2 = workshop.scene_container.global_position
	root.push_input(button(offset + a, true, shift), true)
	var motion := InputEventMouseMotion.new()
	motion.position = offset + b
	root.push_input(motion, true)
	check(editor.marquee_pending and workshop.overlay.marquee_visible, "Real GUI drag displays a selection rectangle")
	root.push_input(button(offset + b, false, shift), true)
	await process_frame
func screen_box(part: Dictionary) -> Rect2:
	var bounds := Kit.bounds(part)
	var rect := Rect2(workshop.camera.unproject_position(bounds.position), Vector2.ZERO)
	for corner in 8: rect = rect.expand(workshop.camera.unproject_position(bounds.get_endpoint(corner)))
	return rect.grow(14)
func run() -> void:
	root.size = Vector2i(1440, 1000)
	workshop = Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	await process_frame
	editor = workshop.pieces
	editor.activate()
	# A rotated box must retain exactly its twelve edges, without triangle diagonals.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.5, 0.4, 0.7)
	Kit.bounds_cache["selection_fixture::%d" % Kit.Appearance.revision] = [{"bounds": mesh.get_aabb(), "mesh": mesh, "transform": Transform3D.IDENTITY}]
	var part := {"kind": "selection_fixture", "at": Vector3.ZERO, "rotation": Vector3(0.3, 0.5, 0.4)}
	var edges := Geometry.outline(part, workshop.camera)
	check(edges.size() == 12, "Rotated cuboid exposes its twelve actual edges")
	for edge in edges:
		for point in edge:
			var local: Vector3 = Kit.transform(part).affine_inverse() * point
			check(local.abs().is_equal_approx(mesh.size * 0.5), "Edge endpoints lie on rotated mesh corners")
	var assembly := {"kind": "assembly", "at": Vector3(1, 2, 3), "rotation": Vector3(0, 0.4, 0), "children": [part]}
	var nested := Geometry.outline(assembly, workshop.camera)
	check(nested.size() == edges.size() and nested[0][0].is_equal_approx(Kit.transform(assembly) * edges[0][0]), "Nested assembly outlines preserve parent and child poses")
	# A triangular prism has nine edges, not a rectangular enclosing cage.
	var wedge := PrismMesh.new()
	wedge.size = Vector3(2, 1, 1)
	Kit.bounds_cache["wedge_fixture::%d" % Kit.Appearance.revision] = [{"bounds": wedge.get_aabb(), "mesh": wedge, "transform": Transform3D.IDENTITY}]
	var wedge_part := {"kind": "wedge_fixture", "at": Vector3.ZERO, "rotation": Vector3(0.2, 0.5, 0)}
	check(Geometry.outline(wedge_part, workshop.camera).size() == 9, "Sloped prism follows its nine mesh edges instead of twelve box edges")
	var cylinder := CylinderMesh.new()
	cylinder.radial_segments = 32
	Kit.bounds_cache["curve_fixture::%d" % Kit.Appearance.revision] = [{"bounds": cylinder.get_aabb(), "mesh": cylinder, "transform": Transform3D.IDENTITY}]
	var curve := {"kind": "curve_fixture", "at": Vector3.ZERO, "rotation": Vector3.ZERO}
	var curve_before := Geometry.outline(curve, workshop.camera)
	workshop.yaw += 0.7
	workshop._camera_update()
	check(Geometry.outline(curve, workshop.camera) != curve_before, "Curved silhouettes follow camera orbit")
	workshop.yaw -= 0.7
	workshop._camera_update()
	# A thin diagonal mesh leaves empty corners inside its AABB.
	var thin := BoxMesh.new()
	thin.size = Vector3(3, 0.1, 0.1)
	Kit.bounds_cache["thin_fixture::%d" % Kit.Appearance.revision] = [{"bounds": thin.get_aabb(), "mesh": thin, "transform": Transform3D.IDENTITY}]
	var thin_part := {"kind": "thin_fixture", "at": Vector3.ZERO, "rotation": Vector3(0, 0, 0.7)}
	var corners := screen_box(thin_part)
	check(not Geometry.intersects(thin_part, Rect2(corners.position + Vector2(15, 15), Vector2(2, 2)), workshop.camera), "Area selection rejects empty bounding-box corners")
	var middle: Vector2 = workshop.camera.unproject_position(Vector3.ZERO)
	check(Geometry.intersects(thin_part, Rect2(middle - Vector2.ONE, Vector2.ONE * 2), workshop.camera), "Small rectangle within a projected face selects it")
	editor.parts = [
		{"kind": "block", "at": Vector3(-2, 0, 0), "rotation": Vector3(0, 0.4, 0.2)},
		{"kind": "block", "at": Vector3.ZERO, "rotation": Vector3.ZERO},
		{"kind": "block", "at": Vector3(3, 0, 0), "rotation": Vector3.ZERO},
	]
	editor.selected = -1
	editor.selecting = true
	workshop._refresh()
	workshop.zoom = 10
	workshop.focus = Vector3.ZERO
	workshop._camera_update()
	await process_frame
	var before: Array = editor.parts.duplicate(true)
	var history: Array = workshop.undo_stack.duplicate(true)
	var pair := screen_box(editor.parts[0]).merge(screen_box(editor.parts[1]))
	await drag(pair.end, pair.position)
	check(editor.selection_indices() == [0, 1], "Reverse-direction marquee selects both intersecting objects")
	check(Array(editor.layers.get_selected_items()) == [0, 1], "Marquee synchronizes Parts rows")
	check(not workshop.overlay.marquee_visible and not editor.marquee_pending, "Release clears rectangle and capture")
	check(editor.parts == before and workshop.undo_stack == history, "Selection never edits geometry or history")
	var outline_count: int = workshop.overlay.placement_edges.size()
	editor.hover(workshop.camera.unproject_position(Kit.bounds(editor.parts[2]).get_center()))
	check(workshop.overlay.placement_edges.size() == outline_count, "Hover adds no unselected outline")
	var third := screen_box(editor.parts[2])
	await drag(third.position, third.end, true)
	check(editor.selection_indices() == [0, 1, 2], "Shift-marquee adds to the existing selection")
	# Escape cancels the rectangle and selection, without committing document changes.
	root.push_input(button(workshop.scene_container.global_position + Vector2(8, 8), true), true)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	check(not editor.marquee_pending and not workshop.overlay.marquee_visible and editor.selection_indices().is_empty(), "Escape cancels capture and deselects")
	check(editor.parts == before and workshop.visible, "Escape preserves document and workspace")
	root.push_input(button(workshop.scene_container.global_position + Vector2(30, 30), false), true)
	editor.hover(middle)
	check(not workshop.overlay.placement_visible and workshop.overlay.placement_edges.is_empty(), "Deselected scene stays free of yellow object edges")
	await drag(pair.position, pair.end)
	editor.group_selected()
	check(editor.parts.size() == 2 and editor.parts[0].kind == "assembly", "Area-selected objects can be grouped")
	workshop.undo()
	check(editor.parts == before, "Grouping an area selection is one undoable action")
	# Releasing over the sidebar finishes the clamped area instead of getting stuck.
	await drag(Vector2(8, 8), workshop.scene_container.size + Vector2(200, 50))
	check(not editor.marquee_pending and editor.selection_indices() == [0, 1, 2], "Release outside the viewport finishes selection")
	if "--capture-selection" in OS.get_cmdline_user_args():
		editor.open_asset("house")
		var highest := 0
		for index in editor.parts.size():
			if Kit.bounds(editor.parts[index]).get_center().y > Kit.bounds(editor.parts[highest]).get_center().y: highest = index
		editor.select_layer(highest)
		editor.fit()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/blueprint-shape-selection.png")
	workshop.free()
	if failures.is_empty(): print("PASS: %d Blueprint area and shape selection checks" % checks)
	quit(int(not failures.is_empty()))
