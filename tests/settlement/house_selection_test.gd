extends SceneTree
const Selection = preload("res://scripts/settlement/house_selection.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
const Tooltip = preload("res://scripts/settlement/object_tooltip.gd")
var failures: Array[String] = []
const A := Vector3i.ZERO
const B := Vector3i(0, 0, 2)
const C := Vector3i(0, 2, 0)
const D := Vector3i(0, 2, 2)
const OTHER := Vector3i(6, 0, 0)

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); printerr("FAIL: " + message)
func hit(cell: Vector3i) -> Dictionary:
	return {"cell": cell, "kind": "house", "entity_key": "building:%s" % cell}
func houses(model) -> void:
	model.buildings.clear(); model.plans.clear(); model.trees.clear(); model.deposits.clear()
	model.stores.clear(); model.platforms.clear(); model.stairs.clear(); model.gardens.clear()
	for cell in [A, B, C, D, OTHER]:
		model.buildings[cell] = {"kind": "house", "direction": 0, "placement_offset": Vector3.ZERO, "house_tier": 3}
	model.rebuild_navigation()

func run() -> void:
	var model := Model.new(); model.setup(); houses(model)
	var selection := Selection.select(model, {}, hit(D))
	check(selection.house_scope == "structure" and selection.cell == D and Selection.members(model, selection) == [A, B, C, D], "First click selects every storey while retaining the actual hit address")
	check(model.Houses.members(model, A) == [A, B], "Same-floor shell and roof joins remain separate from inspection ownership")
	check(Tooltip.describe(model, selection).rows[0].value.ends_with("/4"), "Whole house reports one resident place per room")
	check(Tooltip.describe(model, selection).rows[1].value.ends_with("/16"), "Four rooms store sixteen food")
	selection = Selection.select(model, selection, hit(C))
	check(selection.house_scope == "floor" and Selection.members(model, selection) == [C, D], "Second click selects the clicked floor")
	check(Tooltip.describe(model, selection).title == "Floor" and Tooltip.describe(model, selection).rows[0].value.ends_with("/2"), "Floor readout follows the selected scope")
	selection = Selection.select(model, selection, hit(D))
	check(selection.house_scope == "room" and Selection.members(model, selection) == [D], "Third click selects the clicked room")
	check(Tooltip.describe(model, selection).title == "Room" and Tooltip.describe(model, selection).rows[0].value.ends_with("/1"), "Room readout follows the selected scope")
	check(Selection.select(model, selection, hit(D)).house_scope == "room", "Repeated room clicks do not wrap back to the whole house")
	check(Selection.select(model, selection, hit(C)).house_scope == "room", "Switching rooms on the same floor retains room depth")
	selection = Selection.select(model, selection, hit(B))
	check(selection.house_scope == "floor" and Selection.members(model, selection) == [A, B], "Clicking another storey starts at its floor scope")
	check(Selection.select(model, selection, hit(OTHER)).house_scope == "structure", "A different house starts from the whole structure")
	var plan := {"kind": "house", "cell": D, "entity_key": "plan:42"}
	check(Selection.select(model, selection, plan) == plan, "Construction plans remain individual selectable sites")
	var saved := Model.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(model.snapshot()))) and Selection.structure(saved, D) == [A, B, C, D], "Stacked household membership survives existing save serialization")
	model.buildings[D].placement_offset = Vector3(0.1, 0, 0)
	check(Selection.structure(model, D) == [A, B, C, D], "Supported offset upper Homes remain part of the same structure")
	model.buildings[D].placement_offset = Vector3.ZERO
	model.buildings.erase(C); model.buildings.erase(D)
	model.stores.erase(C); model.stores.erase(D)
	model.rebuild_navigation()
	selection = Selection.select(model, {}, hit(A))
	selection = Selection.select(model, selection, hit(A))
	selection = Selection.select(model, selection, hit(A))
	var removed: bool = model.Houses.remove(model, A, Selection.members(model, selection))
	check(removed and model.plans.size() == 1 and model.plans.values()[0].cell == A, "Removing a room never schedules its unselected neighbour: " + model.last_message)
	await runtime()
	print("PASS: house structure, floor and room selection" if failures.is_empty() else "FAIL: house selection")
	quit(int(not failures.is_empty()))

func runtime() -> void:
	var game := preload("res://scenes/settlement/Terraces.tscn").instantiate()
	game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-house-selection-%d" % Time.get_ticks_usec()
	root.add_child(game); game.set_process(false); game.capture = true
	houses(game.model)
	game.world.fog_enabled = false
	game.world.sync(game.model, 0, -1)
	for actor in game.world.actors: actor.hide()
	game.rig.focus = Vector3(0, 2, 1); game.rig.zoom = 14; game.rig.yaw = 0; game.rig.update_camera()
	for frame in 3: await process_frame
	await physics_frame
	var mouse: Vector2 = game.rig.camera.unproject_position(Vector3(0, 3, 2.9))
	check(game.object_at(mouse).get("cell") == D, "Physics picking preserves the upper room that was hit")
	game._clear_selection()
	var pose: Transform3D = game.rig.camera.transform
	var counts: Array[int] = []
	for scope in ["structure", "floor", "room"]:
		game._select_worker(false, mouse)
		check(game.selected_object.get("house_scope") == scope, "Live mouse selection reaches " + scope)
		game.hud.update_selection(game.world, game.rig.camera, game.selected_object, game.model)
		counts.append(game.hud.selection_strokes.size())
		game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, game.selected_object, hit(D))
		check(game.hud.world_tooltips.size() == 1 and game.hud.object_hover_strokes.is_empty(), "Hover does not duplicate selected house feedback")
		if "--capture-house-selection" in OS.get_cmdline_user_args():
			game.hud.update(game.model, -1, 1, game.selected_object)
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/pyramida-house-selection-%s.png" % scope)
	check(counts == [8, 4, 4], "Structure outlines both floor footprints, then floor and room scopes")
	check(game.rig.camera.transform == pose and not game.world.cutaway, "Selection does not jump the camera or activate interior editing")
	game._copy_selected_building()
	check(game.house_stamp.size() == 1 and game.house_stamp[0].source == D, "Live room Copy includes only the selected room")
	game._set_tool("inspect")
	game.selected_object = Selection.select(game.model, {}, hit(D))
	game._copy_selected_building()
	check(game.house_stamp.size() == 4, "Live whole-house Copy includes all levels")
	game._set_tool("inspect")
	game.hud.update(game.model, -1, 1, game.selected_object)
	check(game.hud.move_button.disabled and game.hud.removal_button.disabled, "Whole-house actions retain supporting-floor protection even when the top room was clicked")
	game._clear_selection()
	game._select_worker(false, mouse)
	check(game.selected_object.get("house_scope") == "structure", "Deselecting restarts the hierarchy")
	game.free()
