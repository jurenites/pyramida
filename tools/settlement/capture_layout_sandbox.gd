extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var sandbox := preload("res://scripts/settlement/building_layout_sandbox.gd").new()
	sandbox.restore_last = false; sandbox.auto_save = false; root.add_child(sandbox)
	sandbox.entries = []
	for spec in [["house", Vector3(0, 0, 0)], ["house", Vector3(0, 2, 0)], ["log_shed", Vector3(-1.5, 0, 0)], ["hay_barn", Vector3(-1.5, 0, 2)], ["masonry", Vector3(4, 0, 0)], ["claypit", Vector3(4, 0, 4)], ["bakery", Vector3(0, 0, 5)], ["stone_storage", Vector3(-4, 0, 4)]]:
		sandbox.entries.append({"kind": spec[0], "tier": 1, "turn": 0, "at": spec[1]})
	sandbox._rebuild(); sandbox.focus = Vector3(0, 1, 2); sandbox.zoom = 12; sandbox._camera()
	for frame in 20: await process_frame
	root.get_texture().get_image().save_png("res://artifacts/settlement/building-arrangement.png")
	sandbox.set_pixelated(true)
	for frame in 8: await process_frame
	root.get_texture().get_image().save_png("res://artifacts/settlement/building-arrangement-pixel.png")
	print("PASS: captured arrangement in smooth and pixel modes")
	sandbox.auto_save = false; sandbox.free(); quit()
