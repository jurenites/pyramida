extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sandbox = load("res://scripts/settlement/building_layout_sandbox.gd").new()
	sandbox.restore_last = false
	sandbox.auto_save = false
	root.add_child(sandbox)
	await process_frame
	for frame in 3: await physics_frame
	var screen: Vector2 = sandbox.camera.unproject_position(sandbox.entries[0].at + Vector3.UP * 0.5)
	assert(sandbox.pick(screen) == 0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	sandbox._view_input(press)
	assert(sandbox.dragging)
	var before: Vector3 = sandbox.entries[0].at
	var motion := InputEventMouseMotion.new()
	motion.position = screen + Vector2(80, 0)
	sandbox._view_input(motion)
	assert(sandbox.entries[0].at != before)
	press.pressed = false
	sandbox._view_input(press)
	assert(not sandbox.dragging)
	var count: int = sandbox.entries.size()
	assert(count > 20)
	for kind in ["well"]:
		assert(sandbox.entries.filter(func(e): return e.kind == kind).size() == 3)
	sandbox.selected = 0
	sandbox.duplicate_selected()
	assert(sandbox.entries.size() == count + 1)
	sandbox.rotate_selected()
	assert(sandbox.entries[-1].turn == 1)
	sandbox.undo()
	assert(sandbox.entries[-1].turn == 0)
	sandbox.redo()
	assert(sandbox.entries[-1].turn == 1)
	sandbox.snap = 0.5
	assert(sandbox.snapped_position(Vector3(0.3, 0, 0.9)) == Vector3(0.5, 0, 1))
	sandbox.snap = 1
	assert(sandbox.snapped_position(Vector3(0.3, 0, 0.9)) == Vector3(0, 0, 1))
	sandbox.snap = 0
	assert(sandbox.snapped_position(Vector3(0.3, 0, 0.9)) == Vector3(0.3, 0, 0.9))
	# Dragging across a building snaps to its real roof level in either render mode.
	sandbox.entries = [{"kind": "house", "tier": 1, "turn": 0, "at": Vector3.ZERO}, {"kind": "house", "tier": 1, "turn": 0, "at": Vector3(4, 0, 0)}]
	sandbox.selected = 1; sandbox._rebuild()
	for frame in 3: await physics_frame
	for pixel in [false, true]:
		sandbox.set_pixelated(pixel)
		await process_frame
		sandbox.entries[1].at = Vector3(4, 0, 0); sandbox.nodes[1].position = sandbox.entries[1].at
		for frame in 2: await physics_frame
		sandbox.dragging = true; sandbox.drag_offset = Vector3.ZERO
		var drag := InputEventMouseMotion.new()
		drag.position = sandbox.camera.unproject_position(Vector3(0, 2, 0)) * sandbox.container.stretch_shrink
		sandbox._view_input(drag)
		assert(sandbox.entries[1].at == Vector3(0, 2, 0), "Drag to stack with correct pixel-mode coordinates")
		sandbox.dragging = false
	sandbox._rebuild()
	assert(not sandbox.nodes[0].has_node("JoinedRoof") and not sandbox.nodes[0].get_node("Roof/Cap2").visible, "Covered house roof disappears")
	assert(sandbox.save_layout("/tmp/layout-test.json"))
	assert(sandbox._load("/tmp/layout-test.json"))
	assert(sandbox.entries.size() == 2 and sandbox.pixelated)
	print("PASS: mouse picking/dragging, gallery tiers, duplicate, rotation, undo/redo, snapping and persistence")
	sandbox.save_timer = 0
	sandbox.free()
	var workshop = preload("res://scenes/settlement/StructureWorkshop.tscn").instantiate()
	workshop.restore_last = false; root.add_child(workshop)
	workshop.open_layout()
	assert(is_instance_valid(workshop.layout_sandbox) and workshop.layout_sandbox.visible and not workshop.visible)
	workshop.layout_sandbox.auto_save = false
	# Use a disposable path so the navigation check cannot touch personal layouts.
	workshop.layout_sandbox.storage_path = "/tmp/arrangement-navigation-test.json"
	workshop.layout_sandbox.close(true)
	assert(workshop.visible and workshop.layout_sandbox == null)
	await process_frame
	workshop.free()
	print("PASS: Blueprints Arrange opens and returns to editor")
	quit()
