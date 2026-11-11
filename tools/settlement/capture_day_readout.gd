extends SceneTree
## Render the real HUD at day and night for comparing the compact clock readout.
const HUD = preload("res://scripts/settlement/hud.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Settings = preload("res://scripts/gameplay_settings.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.get_node("DisplayScale").apply_display_scale(1.0)
	root.size = Vector2i(1400, 760)
	RenderingServer.set_default_clear_color(Color("c8baa8"))
	var index := 0
	for phase in [0.25, 0.75]:
		var model := Model.new()
		model.time = (11.0 + phase) * Settings.SIMULATION_DAY_SECONDS
		var hud := HUD.new()
		root.add_child(hud)
		hud.update(model, -1, 1)
		var panel: Control = hud.day_icon.get_parent().get_parent().get_parent()
		for node in hud.root.get_children():
			if node is Control and node != panel: node.hide()
		for kind in ["food", "water"]: hud.resource_counts[kind].get_parent().show()
		hud.resource_counts.citizens.text = "3/3"
		hud.resource_counts.food.text = "8/16  −3"
		hud.resource_counts.water.text = "2/4"
		hud._size_resource_bar(panel)
		hud.root.scale = Vector2.ONE * 2
		panel.position.y = index * 58
		index += 1
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var output := screenshot.get_region(Rect2i(0, 0, 1400, 216))
	var path := "res://artifacts/day-readout-comparison.png"
	var error := output.save_png(path)
	if error != OK:
		printerr("FAIL: day readout capture")
		quit(1)
		return
	print("PASS: day and night HUD captured to " + path)
	quit()
