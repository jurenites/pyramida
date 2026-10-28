extends SceneTree
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func run() -> void:
	for kind in ["log", "plank", "grain", "house"]:
		var piece := Kit.create(kind)
		var game := Assets.create(kind)
		var source := game.find_children("*", "MeshInstance3D", true, false)
		var authored := piece.find_children("*", "MeshInstance3D", true, false)
		check(authored[0].mesh == source[0].mesh and authored[0].material_override == source[0].material_override, kind + " uses the actual shared game mesh and material")
		check(piece.scale == Vector3.ONE, kind + " retains game scale")
		if kind == "plank": check(authored.size() == 1 and source.size() == 3, "A single board is extracted from the game's three-board cargo model")
		piece.free()
		game.free()
	var plank := Kit.placement("plank", Vector3.ZERO, Vector3.ZERO, Vector3.UP)
	check(absf(Kit.bounds(plank).position.y) < 0.0001, "Ground snap seats actual plank underside on ground")
	var post := Kit.placement("log", Vector3(0, 0, PI / 2), Vector3.ZERO, Vector3.UP)
	check(absf(Kit.bounds(post).position.y) < 0.0001 and Kit.bounds(post).size.y > 0.9, "Upright original log remains full length and touches ground")
	var hit := Kit.pick([post], Vector3(Kit.bounds(post).get_center().x, 5, 0), Vector3.DOWN)
	check(not hit.is_empty(), "Picker intersects rotated component geometry")
	check(Kit.pick([post], Vector3(0.45, 5, 0.45), Vector3.DOWN).is_empty(), "Empty space beside a narrow post stays empty")
	var cabin := Kit.cabin()
	var saved := Kit.decode(JSON.parse_string(JSON.stringify(Kit.encode(cabin))))
	check(saved.parts.size() == cabin.size() and saved.parts[0].kind == "log", "Cabin preserves every individual piece through JSON")
	var bad := Kit.encode(cabin)
	bad[0].kind = "../../unknown"
	check(Kit.decode(bad).is_empty(), "Unknown assets rejected before loading paths")
	bad = Kit.encode(cabin)
	bad[0].at = [0, "invalid", 0]
	check(Kit.decode(bad).is_empty(), "Malformed component transforms rejected")
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	await process_frame
	workshop.pieces.activate()
	check(workshop.pieces.panel.visible and not workshop.legacy_controls.visible and not workshop.support_label.visible, "Pieces shows concise component controls without room instructions or support claims")
	var point: Vector2 = workshop.camera.unproject_position(Vector3.ZERO)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	workshop._view_input(click)
	check(workshop.pieces.parts.size() == 1 and workshop.pieces.parts[0].kind == "log", "Real viewport click places an individual log")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = point
	var saved_parts: Array = workshop.pieces.parts.duplicate(true)
	var yaw_before: float = workshop.yaw
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = Vector2(30, 10)
	workshop._view_input(right)
	workshop._view_input(motion)
	check(workshop.orbiting and workshop.yaw != yaw_before and workshop.pieces.parts == saved_parts, "Right drag orbits without removing or placing pieces")
	right.pressed = false
	workshop._input(right)
	check(not workshop.orbiting, "Releasing right mouse outside the viewport stops orbiting")
	for i in 4: workshop.pieces.hover(point)
	var candidate_before: Dictionary = workshop.pieces.candidate.duplicate(true)
	workshop.pieces.hover(point)
	check(workshop.pieces.candidate == candidate_before, "Preview never picks itself and climbs")
	workshop.undo()
	check(workshop.pieces.parts.is_empty() and workshop.pieces.enabled, "Piece placement is undoable without leaving Pieces")
	workshop.redo()
	check(workshop.pieces.parts.size() == 1, "Piece placement is redoable")
	workshop.pieces.selecting = true
	workshop.pieces.click(workshop.camera.unproject_position(Vector3(0, 0.12, 0)))
	check(workshop.pieces.selected == 0, "Selection picks the placed log")
	workshop.pieces.coordinates[0].value = 0.5
	check(is_equal_approx(workshop.pieces.parts[0].at.x, 0.5), "Selected pieces can be moved precisely")
	workshop.pieces.rotate(2, PI / 2)
	check(is_equal_approx(workshop.pieces.parts[0].rotation.z, PI / 2), "Selected log rotates upright")
	workshop.pieces.parts = cabin
	workshop.pieces.selected = -1
	workshop._refresh()
	var path := "/tmp/pyramida-pieces-%d.pyrstructure" % Time.get_ticks_usec()
	check(workshop._save(path), "Building made from components saves")
	workshop.pieces.parts = []
	check(workshop._load(path) and workshop.pieces.enabled and workshop.pieces.parts.size() == cabin.size(), "Opening restores component building and active Pieces tab")
	var invalid := Shape.document(workshop.draft, [], workshop.workspace_state())
	invalid.workspace.parts[0].rotation = [0, 0]
	check(Shape.parse_document(invalid).is_empty(), "Document validation rejects invalid piece transforms atomically")
	workshop.close()
	workshop.open()
	check(workshop.pieces.parts.size() == cabin.size(), "F2 close and reopen retains individual building pieces")
	workshop.pieces.selected = 0
	workshop.pieces.remove_selected()
	check(workshop.pieces.parts.size() == cabin.size() - 1, "Remove deletes only the selected component")
	workshop.undo()
	check(workshop.pieces.parts.size() == cabin.size(), "Removing one component can be undone")
	DirAccess.remove_absolute(path)
	workshop.free()
	if failures == 0: print("PASS: %d shared-asset component construction checks" % checks)
	quit(0 if failures == 0 else 1)
