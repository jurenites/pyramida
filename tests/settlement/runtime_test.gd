extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Catalog = preload("res://data/settlement/catalog.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func run() -> void:
	var game := Scene.instantiate()
	game.slot_directory = "/tmp/pyramida-runtime-%d" % Time.get_ticks_usec()
	game.launch_to_menu = false
	root.add_child(game)
	await process_frame
	await process_frame
	game._choose_slot(0, true)
	game.speed = 0.0
	check(game.model.workers.size() == 3 and game.world.actors.size() == 3, "Playable scene creates simulation and visible citizens")
	game.hud.buttons.platform.pressed.emit()
	check(game.tool == "platform" and is_instance_valid(game.preview), "Platform toolbar opens a real placement preview")
	game.hud.set_level(2)
	check(game.level == 2, "Floor selector changes cutaway elevation")
	var rotation := InputEventKey.new()
	rotation.physical_keycode = KEY_R
	rotation.pressed = true
	game._unhandled_input(rotation)
	check(game.direction == 1, "Rotation keyboard control changes stair direction")
	game.model.request_build("platform", Vector3i(0, 1, 0))
	game.model.request_build("platform", Vector3i(2, 1, 0))
	for index in 100:
		game.model.tick(0.05)
	game.world.sync(game.model, 0.05, 0)
	check(game.world.actors[0].body.get_node_or_null("CargoSocket") != null, "Citizen carries resources using an authored socket")
	game.autosave()
	check(FileAccess.file_exists(game.saves.path_for(0)), "Autosave writes an actual slot file")
	var saved_log_count: int = game.model.resource_total("log")
	game._choose_slot(1, true)
	game._choose_slot(0, false)
	check(game.model.resource_total("log") == saved_log_count and game.model.plans.size() == 2, "Slot selection restores saved construction after visiting another settlement")
	game.world.sync(game.model, 0, -1)
	var plan: Dictionary = game.model.plans.values()[0]
	var inspection := {"kind": plan.kind, "cell": plan.cell, "entity_key": "plan:%s" % plan.id}
	game.hud.update(game.model, -1, 0, inspection)
	game.hud.update_object_tooltips(game.world, game.rig.camera, game.model, inspection)
	var plan_tooltip = game.hud.world_tooltips[inspection.entity_key]
	check(plan_tooltip.title.text == game.model.Catalog.title(plan.kind) and plan_tooltip.last_rows[0].value == "%d/%d" % [plan.installed, plan.required] and not game.hud.detail_panel.visible, "Selected construction shows its name and materials only above the object")
	check(game.world.entity_views[inspection.entity_key].get_node_or_null("Progress") == null, "Construction text is absent from the pixelated world")
	game.hud.update_selection(game.world, game.rig.camera, inspection)
	check(game.hud.selection_points.size() == 4 and game.hud.selection_strokes.size() == 4, "Selected construction has four separate floor corners")
	var marker_centre := Vector2.ZERO
	for point: Vector2 in game.hud.selection_points:
		marker_centre += point / 4.0
	var screen_scale: Vector2 = game.hud.root.size / Vector2(game.rig.camera.get_viewport().size)
	var site: Node3D = game.world.entity_views[inspection.entity_key]
	var floor_centre: Vector2 = game.rig.camera.unproject_position(site.to_global(Vector3(0, 0.035, 0))) * screen_scale
	check(marker_centre.is_equal_approx(floor_centre), "Construction marker stays on its elevated floor rather than enclosing its height")
	for stroke: PackedVector2Array in game.hud.selection_strokes:
		check(stroke.size() > 3 and not stroke[0].is_equal_approx(stroke[-1]), "Footprint uses rounded open corner brackets, not a continuous rectangle")
	var tree_cell := Vector3i(-8, 0, -4)
	game.model.exploration.reveal(Navigation.point(tree_cell))
	game.world.sync(game.model, 0, -1)
	var tree_selection := {"kind": "tree", "cell": tree_cell, "entity_key": "tree:%s" % tree_cell}
	game.hud.update_selection(game.world, game.rig.camera, tree_selection)
	check(game.hud.selection_strokes.size() == 1 and game.hud.selection_points.size() > 4
		and game.hud.selection_points[0].is_equal_approx(game.hud.selection_points[-1]), "Living tree uses one closed floor circle")
	game.world.actors[0].ring.show()
	game.world.actors[1].ring.show()
	game.hud.update_selection(game.world, game.rig.camera, {})
	check(game.hud.selection_strokes.size() == 2, "Multiple citizens retain independent circles on the x-ray GUI layer")
	game.world.actors[0].ring.hide()
	game.world.actors[1].ring.hide()
	check(game.hud.get_parent() == game and game.hud.root.theme.default_font is FontFile, "Bitmap GUI renders outside the low-resolution viewport")
	game.hud.update(game.model, -1, 0, {})
	game.hud.update_selection(game.world, game.rig.camera, {})
	check(not game.hud.detail_panel.visible and game.hud.selection_points.is_empty(), "Deselection hides construction details and outline")
	game.selected_object = {"kind": "garden", "cell": Vector3i(2, 1, 2)}
	game.hud.update(game.model, -1, 0, game.selected_object)
	check(not game.hud.detail_panel.visible, "Garden inspection does not duplicate information in the top-left corner")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_WHEEL_UP
	mouse.pressed = true
	var initial_zoom: float = game.rig.zoom
	game._unhandled_input(mouse)
	check(game.rig.zoom < initial_zoom, "Mouse wheel zoom changes the active camera")
	for kind: String in Catalog.DEFINITIONS:
		var asset := Assets.create(kind)
		for anchor: String in Catalog.DEFINITIONS[kind].get("access", []):
			check(asset.has_node(anchor), "%s asset is missing access marker %s" % [kind, anchor])
		for port: String in Catalog.DEFINITIONS[kind].get("ports", {}):
			check(asset.has_node(port), "%s asset is missing utility port %s" % [kind, port])
		asset.free()
	for kind in ["citizen_0", "citizen_1", "citizen_2", "citizen_3"]:
		var asset := Assets.create(kind)
		for part in ["Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "CargoSocket"]:
			check(asset.has_node(part), "%s missing articulated part %s" % [kind, part])
		asset.free()
	var rock := Assets.create("rock")
	var arrays: Array = rock.get_child(0).mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_VERTEX][0].dot(arrays[Mesh.ARRAY_NORMAL][0]) > 0, "Bevelled mesh faces point outward rather than rendering inside-out")
	rock.free()
	game.hud.show_category("industry")
	check(game.hud.category_lists.industry.visible and not game.hud.category_lists.housing.visible, "Category tabs show one compact building list")
	var visible_buildings := 0
	for category: Array in Catalog.CATEGORIES.values(): visible_buildings += category.size()
	check(game.hud.buttons.size() == visible_buildings + 1, "Every available building and the exit control have a working menu button")
	check(game.hud.buttons.has("soil_bed") and not game.hud.buttons.has("garden"), "One-tile soil bed replaces the legacy crop garden in the menu")
	check(game.hud.category_buttons.keys() == ["housing", "industry", "structure", "nature"], "Housing, industry, structure and the requested Nature tab are available")
	check(not game.hud.buttons.has("seed_grass"), "Nature has no grass planting option")
	for seed_kind: String in ["seed_vegetables", "seed_tree", "seed_bush", "seed_palm"]:
		game.hud.buttons[seed_kind].pressed.emit()
		check(game.tool == seed_kind and game.hud.current_category == "nature" and is_instance_valid(game.preview), "Seed menu selects a working planting preview: " + seed_kind)
	for kind in ["archer_hut", "wall", "gate", "watch_tower", "brick_road"]:
		check(not game.hud.buttons.has(kind), "Removed building has no menu button: " + kind)
	game.hud.buttons.house.pressed.emit()
	check(game.tool == "house" and game.hud.current_category == "housing", "House menu selects the actual building tool")
	# This placement fixture is established, explored construction.
	game.model.exploration.reveal(Navigation.point(Vector3i(10, 0, 0)))
	game.model.buildings[Vector3i(10, 0, 0)] = {"kind": "house", "direction": 0}
	game.model.rebuild_navigation()
	game.world.sync(game.model, 0, -1)
	await physics_frame
	await physics_frame
	var roof_point := Navigation.point(Vector3i(10, 1, 0))
	var projected: Vector2 = game.rig.camera.unproject_position(roof_point)
	var placement: Dictionary = game.placement_at(projected)
	check(placement.get("cell") == Vector3i(10, 1, 0) and placement.get("support") == "house", "Actual camera ray snaps a house directly onto the hovered roof")
	game.hud.set_level(7)
	check(game.placement_at(projected).get("cell") == Vector3i(10, 1, 0), "Manual cutaway floor cannot make the preview float")
	game._set_tool("platform")
	check(game.placement_at(projected).get("cell") == Vector3i(10, 2, 0), "Ray-selected platform posts begin at the roof height")
	game._set_tool("house")
	game.world.cutaway = true
	game.world.display_level = 0
	game.model.buildings[Vector3i(10, 1, 0)] = {"kind": "house", "direction": 0}
	game.model.rebuild_navigation()
	game.world.sync(game.model, 0, -1)
	await physics_frame
	await physics_frame
	check(game.placement_at(projected).get("cell") == Vector3i(10, 1, 0), "Hidden upper building does not intercept a cutaway placement ray")
	var save_directory: String = game.slot_directory
	game.queue_free()
	await process_frame
	for file in DirAccess.get_files_at(save_directory):
		DirAccess.remove_absolute(save_directory.path_join(file))
	DirAccess.remove_absolute(save_directory)
	if failures.is_empty():
		print("PASS: %d scene, UI, persistence and 3D asset checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
