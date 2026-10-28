extends SceneTree
const Startup = preload("res://scenes/settlement/Startup.tscn")
var failures: Array[String] = []
var startup_input_checked := false

func probe_startup_input(node: Node) -> void:
	if startup_input_checked or node.get_script() == null or node.get_script().resource_path != "res://scripts/settlement/world_view.gd":
		return
	var game := node.get_parent().get_parent().get_parent()
	check(not game.setup_complete and game.menu == null, "Input probe runs before settlement UI setup")
	startup_input_checked = true
	var event := InputEventKey.new()
	event.keycode = KEY_F2
	event.physical_keycode = KEY_F2
	event.pressed = true
	game._input(event)
	game._unhandled_input(event)
	check(game.structure_workshop == null, "Startup input cannot open the workshop before setup finishes")

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	node_added.connect(probe_startup_input)
	var capture := OS.get_cmdline_user_args().has("--capture-startup")
	var startup := Startup.instantiate()
	root.add_child(startup)
	current_scene = startup
	var sand: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	check(startup.cover.color == sand and sand.a == 1, "Loading cover matches the opaque engine splash")
	check(not ProjectSettings.get_setting("application/boot_splash/show_image"), "Engine splash does not expose branding assets")
	check(not startup.loading, "First sand frame precedes loading the game assets")
	await process_frame
	if capture:
		await RenderingServer.frame_post_draw
		var first := root.get_texture().get_image()
		check(first.get_pixel(first.get_width() / 2, first.get_height() / 2).is_equal_approx(sand), "First rendered frame is plain sand")
		first.save_png("res://artifacts/startup-sand.png")
	var deadline := Time.get_ticks_msec() + 30000
	while is_instance_valid(startup) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(startup), "Loading cover exits once game setup and menu layout finish")
	check(startup_input_checked, "Input was exercised during settlement startup")
	node_added.disconnect(probe_startup_input)
	var game := current_scene
	if game != null and game.get("menu") != null:
		check(game.menu.visible and not game.hud.visible and game.menu.current_page == "home" and game.menu.title.is_visible_in_tree() and game.menu.title.text == "Pyramida", "Ready game displays the Pyramida main menu before gameplay")
		check(game.menu.root.get_child(0).color.a < 1.0 and game.menu_preview != null, "Menu reveals the generated world after the loading cover exits")
		check(game.get_node_or_null("EditorPreview") == null, "Editor asset preview never remains in the running game")
		if capture:
			await RenderingServer.frame_post_draw
			var ready := root.get_texture().get_image()
			check(not ready.is_empty(), "Generated menu background renders after loading")
			ready.save_png("res://artifacts/startup-menu.png")
		game.queue_free()
		await process_frame
	else:
		check(false, "Startup hands off to a loaded settlement")
	if failures.is_empty():
		print("PASS: sand-first startup, asynchronous game loading and generated world menu handoff")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
