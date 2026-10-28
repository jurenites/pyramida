extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 1000)
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	workshop.pieces.activate()
	workshop.pieces.open_asset("sawmill")
	workshop.pieces.contract.size = [2, 2, 2]
	workshop.pieces.contract.margin = 0.05
	workshop.pieces.selected = -1
	workshop._refresh()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pyramida-asset-workbench.png")
	workshop.pieces.contract.size[0] = 0.5
	workshop._refresh()
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pyramida-asset-overflow.png")
	workshop.pieces.assets.clear()
	workshop.pieces.active_asset = ""
	workshop.pieces.building_drafts.clear()
	workshop.pieces.building_kind = ""
	workshop.pieces.parts = []
	workshop.pieces.load_example()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pyramida-asset-prefab.png")
	assert(workshop._save("res://data/structures/asset-prefab-example.pyrstructure"))
	workshop.free()
	print("PASS: asset workbench rendered")
	quit()
