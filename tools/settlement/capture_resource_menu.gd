extends SceneTree
func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1440,900)
	var game = load("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.capture = true
	root.add_child(game)
	game.set_process(false)
	game.world.fog_enabled = false
	game.fog.hide()
	for kind: String in game.model.Economy.RECIPES: game.model.unlock_production(kind)
	for kind: String in game.model.Economy.EXTRACTORS: game.model.unlock_production(kind)
	for resource: String in game.model.Economy.RESOURCES: game.model.discovered_resources[resource] = true
	game.hud.update(game.model, -1, 1)
	game.hud.build_panel.show()
	for category in ["housing", "clay", "hay", "storage"]:
		game.hud.show_category(category)
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/settlement/resource-menu-%s.png" % category)
	game.hud.show_category("housing")
	game.hud.show_building_tooltip(game.hud.buttons.house,"house")
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/settlement/resource-menu-tooltip.png")
	game.free()
	print("PASS: resource menu captures")
	quit()
