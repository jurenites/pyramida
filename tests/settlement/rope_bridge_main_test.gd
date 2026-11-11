extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Fixture = preload("res://scripts/settlement/rope_bridge_fixture.gd")
const Bridges = Fixture.Bridges
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 900)
	var game = Scene.instantiate(); game.launch_to_menu = false
	game.slot_directory = "/tmp/pyramida-bridge-main-test"
	root.add_child(game); game.set_process(false); game.speed = 0
	game.model = Fixture.create(false); game.model.streaming_enabled = false
	game.model.exploration.reveal(Fixture.END)
	game.menu.hide(); game.world.fog_enabled = false
	game.world.sync(game.model, 0, -1)
	game.rig.focus = Vector3(1, 3, 1); game.rig.zoom = 23; game.rig.pitch = 0.95; game.rig.update_camera()
	await process_frame; await physics_frame; await physics_frame
	var editor = game.bridge_editor
	var camera: Camera3D = game.rig.camera
	game.hud.update(game.model, -1, 0)
	game.hud.category_buttons.structure.pressed.emit()
	check(game.hud.buttons.rope_bridge.is_visible_in_tree(), "Bridge is in the main Structure tab")
	game.hud.buttons.rope_bridge.pressed.emit()
	check(game.tool == "rope_bridge", "Main build button activates free bridge placement")
	var start := camera.unproject_position(Fixture.START)
	var end := camera.unproject_position(Fixture.END)
	var first: Variant = editor.pick(start)
	check(first != null and first.distance_to(Fixture.START) < 0.01, "Main picker finds fractional terrace landing")
	editor.update(start, true)
	check(editor.preview.get_child_count() == 1 and editor.preview.get_child(0).get_child_count() == 4, "First preview immediately has two poles and their rope ties")
	editor.click(start); editor.update(end, true)
	check(editor.error.is_empty(), "Unequal-height diagonal preview is valid: " + editor.error)
	check(editor.preview.get_child(0).basis.z.dot(editor.preview.get_child(1).basis.z) < -0.99, "Both pairs face each other")
	editor.click(end)
	check(game.model.plans.size() == 1 and game.tool == "inspect", "Two clicks queue the whole bridge and exit placement")
	if game.model.plans.is_empty(): game.free(); quit(1); return
	var id: int = game.selected_object.bridge_id
	var record: Dictionary = game.model.plans[id].bridge
	check(record.start.distance_to(Fixture.START) < 0.01 and record.end.distance_to(Fixture.END) < 0.01, "Both endpoints retain fractional coordinates")
	game.world.sync(game.model, 0, -1)
	await physics_frame; await physics_frame
	for point: Vector3 in [record.start + Vector3.UP * 0.6, record.end + Vector3.UP * 0.6, Bridges.curve(record)[16]]:
		var target: Dictionary = editor.object_at(camera.unproject_position(point))
		check(target.get("bridge_id", -1) == id, "Either gate and the deck select the entire span")
	game.hud.update(game.model, -1, 0, game.selected_object)
	check(game.hud.move_button.visible and game.hud.removal_button.visible and not game.hud.copy_button.visible, "Bridge selection exposes only Move and Remove")
	game.hud.move_button.pressed.emit()
	check(game.tool == "rope_bridge_move", "Existing Move action enters endpoint editing")
	editor.click(camera.unproject_position(record.start + Vector3.UP * 0.55))
	check(editor.endpoint == 0, "Move picks the first endpoint independently")
	var moved := Fixture.START + Vector3(-0.1, 0, 0.2)
	editor.click(camera.unproject_position(moved))
	var next_id: int = game.selected_object.bridge_id
	check(next_id != id and game.model.plans.has(next_id), "Move replaces pending span")
	record = Bridges.get_record(game.model, next_id)
	check(record.start.distance_to(moved) < 0.01 and record.end.distance_to(Fixture.END) < 0.01, "Moving first gate keeps second fixed")
	editor.click(camera.unproject_position(record.end + Vector3.UP * 0.55))
	check(editor.endpoint == 1, "Move picks the second endpoint independently")
	var moved_end := Fixture.END + Vector3(0.1, 0, -0.15)
	editor.click(camera.unproject_position(moved_end))
	record = Bridges.get_record(game.model, game.selected_object.bridge_id)
	check(record.start.distance_to(moved) < 0.01 and record.end.distance_to(moved_end) < 0.01, "Moving second gate keeps first fixed")
	game._set_tool("inspect")
	var carried := false
	for step in 10000:
		game.model.tick(0.05)
		if game.model.workers[0].cargo == "log" and game.model.workers[0].position.x > 1 and game.model.workers[0].position.x < 2:
			carried = true; break
	check(carried and game.model.navigation.roads.is_empty(), "Normal jobs build the edited span and carry logs automatically without roads")
	for frame in 10: game.world.sync(game.model, 0.1, -1)
	var citizen_target: Dictionary = game.object_at(camera.unproject_position(game.world.actors[0].global_position + Vector3.UP * 0.55))
	check(citizen_target.get("worker_id", -1) == 0, "Citizens remain selectable while walking on a bridge")
	id = game.selected_object.bridge_id
	check(Bridges.move_end(game.model, id, 0, Fixture.START) == -1 and not Bridges.remove(game.model, id), "An occupied bridge cannot be moved or removed")
	for step in 1500:
		game.model.tick(0.05)
		if not Bridges.occupied(game.model, record): break
	game.world.sync(game.model, 0, -1)
	game.selected_object.entity_key = "bridge:%d" % id
	game.hud.update(game.model, -1, 0, game.selected_object)
	game.hud.update_selection(game.world, camera, game.selected_object, game.model)
	game.hud.update_object_tooltips(game.world, camera, game.model, game.selected_object)
	check(game.hud.selection_strokes.size() == 2, "Selection traces both edges of the whole span")
	game.hud.removal_button.pressed.emit()
	check(game.model.bridges.is_empty() and game.selected_object.is_empty(), "Remove deletes the complete span and clears selection")
	check(game.world.bridge_view.get_child_count() == 0, "Remove clears both endpoint models, deck and colliders")
	check(game.model.navigation.route(record.a, record.b).is_empty(), "Remove invalidates the automatic connection")
	var copy = Fixture.Model.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(game.model.snapshot()))), "Deletion salvage survives normal JSON saves")
	# Exercise roof picking against actual main-game house meshes and colliders.
	game.model = Fixture.create(false)
	game.model.buildings.clear(); game.model.stores.clear(); game.model.ground.clear()
	for centre: Vector3i in [Vector3i(0,0,0),Vector3i(8,1,2)]:
		for cell: Vector3i in game.model.Grid.support_cells(centre): game.model.ground[cell] = true
		game.model.buildings[centre] = {"kind": "house", "direction": 0, "house_tier": 2}
		game.model.exploration.reveal(Vector3(centre))
	game.model.rebuild_navigation(); game.world.sync(game.model,0,-1)
	game.rig.focus = Vector3(4,2,1); game.rig.pitch = 1.1; game.rig.update_camera()
	await physics_frame; await physics_frame
	game._set_tool("rope_bridge")
	var roof_start := Vector3(0.75,2,0.1); var roof_end := Vector3(7.25,3,1.9)
	for point: Vector3 in [roof_start,roof_end]:
		var screen: Vector2 = camera.unproject_position(point)
		var hit: Variant = editor.pick(screen)
		check(hit != null and hit.distance_to(point) < 0.01, "Main picker lands on the visible building roof at its own elevation")
		editor.click(screen)
	check(game.model.plans.size() == 1, "Main tool queues a roof-to-roof diagonal span")
	game.world.sync(game.model,0,-1)
	for node: Node3D in game.world.entity_views.values():
		if node.get_meta("asset", "") != "house": continue
		check(node.has_node("AssembledHome") and preload("res://scripts/settlement/building_assembly_layout.gd").build(game.model)[node.get_meta("cell")].terrace, "Attached house has a visible flat landing deck")
		check(not node.has_node("JoinedRoof"), "Pitched roofing does not clip into the bridge landing")
	if not game.model.plans.is_empty():
		var roof_plan: Dictionary = game.model.plans.values()[0]
		Bridges.complete(game.model,roof_plan); game.world.sync(game.model,0,-1)
		for node: Node3D in game.world.entity_views.values():
			if node.get_meta("asset", "") == "house": check(not node.has_node("JoinedRoof"), "Completed span keeps the flat roof landing")
		check(Bridges.remove(game.model,roof_plan.id), "Unused rooftop span can be removed")
		game.world.sync(game.model,0,-1)
		for node: Node3D in game.world.entity_views.values():
			if node.get_meta("asset", "") == "house": check(node.has_node("JoinedRoof") and not node.get_node("BridgeLandingDeck").visible, "Removing the last span restores ordinary roofing")
	game.free()
	print("PASS: main-game bridge placement, two-pole previews, picking, independent moves, hauling and whole-span deletion" if failures == 0 else "FAIL: %d main bridge checks" % failures)
	quit(1 if failures else 0)
