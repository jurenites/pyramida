extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,980)
	var sandbox = load("res://scenes/terrain_sandbox/TerrainSandbox.tscn").instantiate()
	sandbox.persistence_enabled = false
	root.add_child(sandbox)
	for frame in 4: await physics_frame
	check(sandbox.support_button.text == "Support" and sandbox.undo_button.disabled, "Toolbar offers Support construction rather than a cutting tool")
	var terrace := Vector3(4,6.6,2)
	sandbox.update_proposal(sandbox.rig.camera.unproject_position(terrace))
	check(not sandbox.proposal.is_empty() and sandbox.proposal.valid, "A terrace pick previews a founded Support")
	if not sandbox.proposal.is_empty():
		check(absf(sandbox.proposal.origin.y-6.6)<0.002, "Surface placement follows the actual mountain elevation")
		check(sandbox.confirm_proposal(), "One click constructs the previewed Support")
	check(sandbox.terrain.supports.size()==1 and not sandbox.undo_button.disabled, "Placement adds a real building and enables Undo")
	for frame in 4: await physics_frame
	if not sandbox.terrain.supports.is_empty():
		var base: Vector3 = sandbox.terrain.supports[0]
		sandbox.update_proposal(sandbox.rig.camera.unproject_position(base+Vector3(0.15,1,0)))
		check(not sandbox.proposal.is_empty() and sandbox.proposal.valid, "Clicking a Support roof previews the next module")
		if not sandbox.proposal.is_empty():
			check(sandbox.proposal.origin.is_equal_approx(base+Vector3.UP), "Stacked structure snaps exactly one metre above its supporting module")
			check(sandbox.confirm_proposal(), "Stacking builds the actual upper Support")
		sandbox.undo_button.pressed.emit()
		check(sandbox.terrain.supports.size()==1, "Undo button removes only the last placed module")
	var shift := InputEventKey.new(); shift.keycode=KEY_SHIFT; shift.pressed=true; shift.shift_pressed=true
	sandbox._input(shift)
	await process_frame
	check(is_equal_approx(sandbox.snap_position(2.13),2.1), "Shift uses precise tenth-metre positioning")
	var release := InputEventKey.new(); release.keycode=KEY_SHIFT; release.pressed=false; sandbox._input(release)
	await process_frame
	await process_frame
	check(is_equal_approx(sandbox.snap_position(2.13),2.0), "Default placement snaps whole metre modules")
	sandbox.proposal = {"turn":0}
	var rotate := InputEventKey.new(); rotate.keycode=KEY_R; rotate.pressed=true
	sandbox._unhandled_input(rotate)
	check(sandbox.plank_override == 1, "R changes board direction without rotating the footprint")
	var escape := InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true
	sandbox._unhandled_input(escape)
	check(not sandbox.support_button.button_pressed, "Escape leaves construction mode")
	sandbox.free()
	for failure in failures: printerr("FAIL: "+failure)
	if failures.is_empty(): print("PASS: Support toolbar, mountain placement, one-click construction, stacking and Undo")
	quit(int(not failures.is_empty()))
