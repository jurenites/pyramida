extends SceneTree
const HUD = preload("res://scripts/settlement/hud.gd")
const VisualTokens = preload("res://scripts/ui_visual_tokens.gd")
const Menu = preload("res://scripts/settlement/main_menu.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func run() -> void:
	var scaling := root.get_node("DisplayScale")
	var hud := HUD.new()
	root.add_child(hud)
	var menu := Menu.new()
	root.add_child(menu)
	menu.root.theme = hud.root.theme
	menu.show_page("home")
	menu.visible = true
	var world_container := SubViewportContainer.new()
	world_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_container.stretch = true
	world_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(world_container)
	var world := SubViewport.new()
	preload("res://scripts/settlement/illustration_style.gd").configure(world_container, world)
	world_container.add_child(world)
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED,
		"Project disables window-dependent UI stretching")
	# Include returning from Retina to 1x, as when moving between monitors.
	var densities := [1.0, 2.0, 1.0]
	var sizes := [Vector2i(1100, 760), Vector2i(1440, 900), Vector2i(1920, 1080), Vector2i(1200, 1000)]
	if OS.get_cmdline_user_args().has("--native-display"):
		densities = [root.content_scale_factor]
		sizes = [Vector2i(1100, 760), Vector2i(1200, 800)]
		print("Native display density: %s" % root.content_scale_factor)
	for density in densities:
		scaling.apply_display_scale(density)
		for logical_size: Vector2i in sizes:
			root.size = Vector2i(Vector2(logical_size) * density)
			for frame in 4:
				await process_frame
			var context := "%s at %sx" % [logical_size, density]
			var border := hud.build_panel.get_theme_stylebox("panel") as StyleBoxFlat
			check(is_equal_approx(border.border_width_left * density, 4.0 * density),
				"Four-point border scales exactly once with monitor density: " + context)
			check(border.content_margin_left == 8 * VisualTokens.POINT and border.content_margin_top == 5 * VisualTokens.POINT,
				"Padding retains its proportions in the same point unit: " + context)
			var divider := hud.root.theme.get_stylebox("separator", "VSeparator") as StyleBoxLine
			check(divider.vertical and divider.thickness == 4 and hud.root.theme.get_constant("separation", "VSeparator") == 1,
				"Four-point divider retains one-point layout spacing: " + context)
			var button: Button = hud.speed_button
			var transform := button.get_global_transform_with_canvas()
			var physical_size := root.get_final_transform().basis_xform(transform.basis_xform(button.size))
			check(physical_size.is_equal_approx(Vector2.ONE * VisualTokens.GAME_TOOLBAR_BUTTON_SIZE * density),
				"Toolbar button keeps its logical size: " + context)
			check(hud.root.size.is_equal_approx(Vector2(logical_size)),
				"HUD layout follows logical window bounds: " + context)
			check(is_equal_approx(hud.root.size.x - hud.build_panel.get_rect().end.x, 12),
				"Right-anchored panel keeps its logical margin: " + context)
			check(is_equal_approx(menu.buttons.settings.size.y, 42),
				"Menu button keeps its logical height: " + context)
			var panel := menu.title.get_parent().get_parent() as Control
			check(absf(panel.get_global_rect().get_center().x - logical_size.x / 2.0) <= 1.0,
				"Menu remains horizontally centered after resizing: " + context)
			check(is_equal_approx(menu.buttons.settlements.get_global_rect().position.y, 160 * VisualTokens.POINT),
				"First menu action retains its confirmed 160-point top position: " + context)
			var resource_panel: Control = hud.resource_counts.food.get_parent().get_parent().get_parent()
			check(resource_panel.get_global_rect().encloses(hud.day_icon.get_global_rect()),
				"Day/night icon sits inside the resource bar: " + context)
			check(hud.root.get_global_rect().encloses(hud.root.get_node("ResetCameraCompass").get_global_rect()),
				"Compass remains inside the window: " + context)
			check(world.size == logical_size,
				"World viewport follows the logical layout for projection and picking: " + context)
			check(root.min_size == Vector2i(Vector2(1100, 760) * density),
				"Minimum window dimensions use the same logical units: " + context)
	hud.queue_free()
	menu.queue_free()
	world_container.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d UI resize and Retina scale checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
