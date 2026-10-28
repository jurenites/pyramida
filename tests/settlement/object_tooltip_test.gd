extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Tooltip = preload("res://scripts/settlement/object_tooltip.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	root.size = Vector2i(1440, 980)
	var game = Scene.instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.capture = true
	game.set_process(false)
	game.speed = 0
	game._clear_selection()
	game.rig.focus = Vector3.ZERO
	game.rig.zoom = 18
	game.rig.update_camera()
	game.world.sync(game.model, 0, -1)
	for frame in 4:
		await process_frame
	await physics_frame
	var cell := Vector3i(6, 0, -4)
	var target := {"cell": cell, "kind": "tree", "entity_key": "tree:%s" % cell}
	var node: Node3D = game.world.entity_views[target.entity_key]
	var info := Tooltip.describe(game.model, target)
	check(info.title == "Dead Tree" and info.rows == [{"icon": "log", "value": "3/3"}], "Tree has only name and real log inventory/capacity")
	var mouse: Vector2 = game.rig.camera.unproject_position(node.global_position + Vector3.UP)
	check(game.object_at(mouse).get("entity_key") == target.entity_key, "Ray hover hits the tree")
	game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, {}, target)
	var tip = game.hud.world_tooltips.get(target.entity_key)
	check(tip != null and tip.title.text == "Dead Tree" and not tip.rows.visible, "Hover shows name only")
	check(tip.get_theme_stylebox("panel").bg_color.a == 0, "Hover background is transparent")
	game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, target)
	tip = game.hud.world_tooltips[target.entity_key]
	check(tip.rows.visible and tip.get_theme_stylebox("panel").bg_color == Color.BLACK, "Selection persists after hover leaves, with black backing and count")
	game.model.trees[cell].inventory.amounts.log = 2
	game.world.sync(game.model, 0, -1)
	game.hud.update(game.model, -1, 1, target)
	game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, target, target)
	check(game.hud.world_tooltips.size() == 1 and tip.last_rows[0].value == "2/3", "Selected hover is deduplicated and harvest updates the count")
	check(not game.hud.detail_panel.visible and not game.hud.detail_readout.is_visible_in_tree(), "Selected object information is not duplicated in the top-left corner")
	check(tip.position.y + tip.size.y < game.rig.camera.unproject_position(node.global_position + Vector3.UP * 1.94).y, "Tooltip sits above the remaining tree")
	var previous_position: Vector2 = tip.position
	game.rig.focus += Vector3(1, 0, 0)
	game.rig.update_camera()
	game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, target)
	check(not tip.position.is_equal_approx(previous_position), "Label follows camera movement")
	check(Rect2(Vector2.ZERO, game.hud.root.size).encloses(tip.get_rect()), "Label remains within logical viewport bounds")
	game.rig.focus = Vector3.ZERO
	game.rig.update_camera()
	node.hide()
	game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, target)
	check(game.hud.world_tooltips.is_empty(), "Hidden entities have no floating tooltip")
	node.show()
	var kid := {"worker_id": 2}
	check(Tooltip.describe(game.model, kid).title == "Kid", "Child has concise Kid label")
	var kid_mouse: Vector2 = game.rig.camera.unproject_position(game.world.actors[2].global_position + Vector3.UP * 0.4)
	game._select_worker(false, kid_mouse)
	check(game.selected == -1 and game.selected_workers.is_empty() and game.selected_object == kid, "Kid can be inspected without becoming a commanded adult")
	game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, kid)
	check(game.hud.world_tooltips.has("worker:2"), "Selected Kid keeps a name")
	game._clear_selection()
	check(game.hud.world_tooltips.is_empty(), "Deselection removes persistent labels immediately")
	for deposit_cell: Vector3i in game.model.deposits:
		var deposit: Dictionary = game.model.deposits[deposit_cell]
		var description := Tooltip.describe(game.model, {"kind": deposit.kind, "cell": deposit_cell})
		check(description.title == ("Bush" if deposit.kind == "berry" else "Stone"), "Natural deposit uses a concise noun")
		check(description.rows[0].value == "%d/%d" % [deposit.inventory.total(), deposit.inventory.capacity], "Deposit shows actual stock/capacity")
		check(description.rows[0].icon == ("berry" if deposit.kind == "berry" else "stone"), "Berries and stone use matching icons")
	for deposit_cell: Vector3i in game.model.deposits:
		if game.model.deposits[deposit_cell].kind != "limestone": continue
		var stone_target := {"kind": "limestone", "cell": deposit_cell, "entity_key": "deposit:%s" % deposit_cell}
		var stone: Node3D = game.world.entity_views[stone_target.entity_key]
		check(stone.get_meta("collider").get_child(0).shape is ConcavePolygonShape3D, "Stone tooltip exercises the mesh collider")
		stone.show()
		game.rig.focus = stone.global_position
		game.rig.zoom = 22
		game.rig.update_camera()
		game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, {}, stone_target)
		var stone_tip = game.hud.world_tooltips.get(stone_target.entity_key)
		check(stone_tip != null and stone_tip.title.text == "Stone", "Concave stone supports hover labels")
		game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, stone_target)
		stone_tip = game.hud.world_tooltips.get(stone_target.entity_key)
		check(stone_tip != null and stone_tip.rows.visible, "Concave stone supports selected inventory labels")
		break
	game.rig.focus = Vector3.ZERO
	game.rig.zoom = 18
	game.rig.update_camera()
	if OS.get_cmdline_user_args().has("--capture"):
		game.hud.update(game.model, -1, 1, target)
		game.hud.update_selection(game.world, game.rig.camera, target, game.model)
		game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, target, kid)
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/pyramida-object-tooltips.png")
	game.free()
	if failures.is_empty():
		print("PASS: object hover, selection, child inspection, compact resource details and visibility")
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
	quit(int(not failures.is_empty()))
