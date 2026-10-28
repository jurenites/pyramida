extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 1000)
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	var editor: RefCounted = workshop.pieces
	editor.activate()
	editor.parts = [Workspace.instance("sawmill", Vector3.ZERO, Vector3(0, 0.3, 0))]
	editor.selected = 0
	editor.selecting = true
	workshop._refresh()
	editor.fit()
	for mode: String in ["move", "size"]:
		editor.gizmo.set_mode(mode)
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pyramida-blueprint-%s.png" % mode)
	workshop.free()
	print("PASS: Blueprint transform controls rendered")
	quit()
