extends SceneTree
## Render the actual editable tree assets in each harvest state.
const Assets = preload("res://scripts/settlement/asset_library.gd")
const TreeView = preload("res://scripts/settlement/tree_view.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1440, 980)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = 2
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 490)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("eee1bd")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_energy = 0.5
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_energy = 0.85
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.6
	viewport.add_child(camera)
	camera.position = Vector3(0, 10, 16)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.current = true
	var ui := CanvasLayer.new()
	root.add_child(ui)
	label(ui, "PYRAMIDA / THREE LOGS PER TREE", Vector2(36, 24), 28)
	label(ui, "Living and dead trunks · each cut removes the highest remaining section", Vector2(36, 66), 18)
	for row in 2:
		for column in 4:
			var amount := 3 - column
			var node := Assets.create("tree" if row == 0 else "dead_tree")
			node.position = Vector3((column - 1.5) * 2.8, 0, -4 if row == 0 else 4)
			viewport.add_child(node)
			var inventory := Inventory.new()
			inventory.store("log", amount)
			TreeView.sync(node, {"inventory": inventory, "kind": "living" if row == 0 else "dead"})
			var anchor := camera.unproject_position(node.position + Vector3(0, 0, 0.8)) * 2.0
			label(ui, ("LIVING" if row == 0 else "DEAD") + "  %d / 3" % amount if amount > 0 else "STUMP  0 / 3", anchor - Vector2(70, 0), 20)
	label(ui, "Living stumps regrow. Dead stumps remain exhausted. Each harvested log is physically carried to storage.", Vector2(36, 925), 18)
	for frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/tree-harvest-stages.png")
	print("PASS: rendered tree harvest stages" if error == OK else "FAIL: could not save tree preview")
	quit(int(error != OK))

func label(parent: Node, text_: String, position_: Vector2, font_size: int) -> void:
	var node := Label.new()
	node.text = text_
	node.position = position_
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color("493b2c"))
	parent.add_child(node)
