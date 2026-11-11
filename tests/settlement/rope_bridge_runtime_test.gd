extends SceneTree
const Demo = preload("res://scripts/settlement/rope_bridge_demo.gd")
const Fixture = Demo.Fixture
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var demo = Demo.new(); root.add_child(demo); demo.running = false
	await process_frame
	assert(demo.model.delete_plan(demo.model.plans.keys()[0]))
	demo.bridge_button.button_pressed = true
	var first := Fixture.START + Vector3(-0.13, 0, -0.17)
	var last := Fixture.END + Vector3(0.15, 0, 0.18)
	for point in [first, last]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
		event.position = demo.rig.camera.unproject_position(point)
		demo._unhandled_input(event)
	assert(demo.model.plans.size() == 1, "Two clicks queue the bridge")
	var record: Dictionary = demo.model.plans.values()[0].bridge
	assert(record.start.distance_to(first) < 0.001 and record.end.distance_to(last) < 0.001, "Pointer placement preserves fractional world coordinates")
	assert(not demo.placing and demo.preview.get_child_count() == 0, "Placement exits and clears its preview")
	demo.refresh()
	assert(demo.spans.get_child_count() == 1, "Construction preview is visible")
	# Exercise the actual removal button for an unfinished plan.
	for button in demo.find_children("*", "Button", true, false):
		if button.text == "Remove bridge": button.pressed.emit()
	assert(demo.model.plans.is_empty(), "Remove cancels an unbuilt bridge without errors")
	demo.reset(); demo.running = false
	var seen := false
	for step in 8000:
		demo.model.tick(0.05)
		var worker: Dictionary = demo.model.workers[0]
		if worker.cargo == "log" and worker.position.x > 1 and worker.position.x < 2:
			seen = true; demo.refresh()
			for frame in 10: demo.refresh()
			assert(demo.actors[0].last_cargo == "log" and is_instance_valid(demo.actors[0].cargo), "Hauler renders the actual log cargo")
			assert(absf(demo.actors[0].position.y - worker.position.y) < 0.05, "Rendered citizen stays on suspended deck")
			break
	assert(seen)
	# Main settlement rendering and menus also accept the new workplace/resource.
	var view = preload("res://scripts/settlement/world_view.gd").new(); root.add_child(view); view.setup(demo.model)
	assert(view.bridge_view.get_child_count() == 1)
	var hud = preload("res://scripts/settlement/hud.gd").new(); root.add_child(hud)
	await process_frame
	hud.update(demo.model, -1, 0)
	assert(hud.buttons.has("rope_maker") and hud.resource_counts.has("rope"))
	view.free(); hud.free(); demo.free()
	print("PASS: free bridge placement, cancellation, log rendering and settlement UI")
	quit()
