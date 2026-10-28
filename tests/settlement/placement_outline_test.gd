extends SceneTree
const Outline = preload("res://scripts/settlement/placement_outline.gd")
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func has_edge(edges: Array, a: Vector3, b: Vector3) -> bool:
	for edge in edges:
		if (edge[0] == a and edge[1] == b) or (edge[0] == b and edge[1] == a): return true
	return false

func run() -> void:
	var cube := Outline.cell_edges({Vector3i.ZERO: true})
	var corners := {}
	for edge in cube:
		for point in edge: corners[point] = true
	check(cube.size() == 12 and corners.size() == 8, "A cube exposes twelve edges and all eight corners")
	var joined := Outline.cell_edges({Vector3i.ZERO: true, Vector3i.RIGHT: true})
	check(not has_edge(joined, Vector3(0.5, 0, -0.5), Vector3(0.5, 1, -0.5)), "Adjacent cubes have no coplanar wall seam")
	var shape := {Vector3i.ZERO: true, Vector3i.RIGHT: true, Vector3i.BACK: true}
	var bent := Outline.cell_edges(shape)
	check(has_edge(bent, Vector3(0.5, 0, 0.5), Vector3(0.5, 1, 0.5)), "L piece keeps its inward vertical corner")
	check(not has_edge(bent, Vector3(1.5, 0, 1.5), Vector3(1.5, 1, 1.5)), "L piece does not outline an empty bounding-box corner")
	shape[Vector3i.UP] = true
	check(Outline.cell_edges(shape, 0) == bent, "Slice outline follows only visible cells")
	var workshop = load("res://scenes/settlement/StructureWorkshop.tscn").instantiate()
	workshop.restore_last = false
	root.size = Vector2i(1440, 900)
	root.add_child(workshop)
	await process_frame
	workshop.draft = Shape.preset(0)
	workshop.set_mode(1)
	workshop._pick(workshop.camera.unproject_position(Vector3.ZERO))
	check(workshop.overlay.placement_visible and not workshop.overlay.placement_edges.is_empty(), "Blueprint placement displays the volume")
	check(not workshop.hover_mesh.visible, "Blueprint placement hides the roaming cell marker")
	workshop.rotate_draft()
	check(workshop.overlay.placement_edges == Outline.cell_edges(workshop.candidate().cells), "Outline follows rotation and destination")
	if OS.get_cmdline_user_args().has("--capture"):
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pyramida-placement-outline.png")
	workshop.scene_container.mouse_exited.emit()
	check(not workshop.overlay.placement_visible, "Leaving Blueprint world clears the volume")
	workshop.rotate_draft()
	check(not workshop.overlay.placement_visible, "Toolbar edits cannot restore an outline outside the world")
	workshop.brush = 3
	workshop._refresh()
	check(workshop.overlay.placement_edges.is_empty(), "Inspection does not keep a placement volume")
	workshop.free()
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.capture = true
	game.set_process(false)
	game.speed = 0
	await process_frame
	game._set_tool("house")
	game.preview.position = Vector3(0.18, 2, -0.12)
	game.preview.rotation.y = PI * 0.5
	game.hud.update_placement_outline(game.rig.camera, game.preview, "house")
	check(game.hud.placement_strokes.size() == 12, "Settlement house preview has twelve projected edges")
	var definition: Dictionary = game.model.Catalog.DEFINITIONS.house
	var edge := Outline.box_edges(definition.offset, definition.size)[0]
	var scale: Vector2 = game.hud.root.size / Vector2(game.viewport.size)
	check(game.hud.placement_strokes[0][0].is_equal_approx(game.rig.camera.unproject_position(game.preview.to_global(edge[0])) * scale), "Projection preserves height, rotation, offset and logical scale")
	game.hud.update_ground_hover(game.rig.camera, Vector3i.ZERO)
	game.hud.object_hover_strokes.append(PackedVector2Array([Vector2.ZERO, Vector2.ONE]))
	game._update_hover()
	check(game.hud.ground_hover_points.is_empty() and game.hud.object_hover_strokes.is_empty(), "Building placement suppresses both ground and object hover markers")
	game._clear_selection()
	check(game.hud.placement_strokes.is_empty(), "Cancelling clears the volume immediately")
	game.free()
	if failures.is_empty(): print("PASS: placement corners, irregular volume, rotation, offset, cursor suppression and cancellation")
	for failure in failures: printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
