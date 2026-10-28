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
	for kind in ["windmill", "sawmill", "stone_storage", "well"]:
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
	assert(sandbox.save_layout("/tmp/layout-test.json"))
	assert(sandbox._load("/tmp/layout-test.json"))
	assert(sandbox.entries.size() == count + 1)
	print("PASS: mouse picking/dragging, gallery tiers, duplicate, rotation, undo/redo, snapping and persistence")
	sandbox.save_timer = 0
	sandbox.free()
	quit()
