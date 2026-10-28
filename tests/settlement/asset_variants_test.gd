extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func run() -> void:
	# Exercise factory buildings without reading the user's applied appearances.
	var appearance_path := "/tmp/pyramida-variant-appearances-%d" % Time.get_ticks_usec()
	Kit.Appearance.directory = appearance_path
	Kit.Appearance.mesh_directory = appearance_path
	var workshop = Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	await process_frame
	var editor = workshop.pieces
	editor.activate()
	editor.building_select.item_selected.emit(editor.building_ids.find("house") + 1)
	editor.edit_library()
	check(editor.active_asset == "house" and editor.building_kind == "house" and editor.parts.size() > 1, "Edit opens the chosen building’s editable parts")
	check(workshop.name_edit.text == workshop.draft.name and editor.layers.item_count == editor.parts.size(), "Building choice refreshes the visible name and Parts list")
	editor.store_asset()
	check(editor.prefab_library.get_index() < editor.building_select.get_parent().get_index() and editor.building_select.get_parent().get_index() < editor.library.get_index(), "Prefabs, Building and Assets appear in that order")
	var original: Array = editor.parts.duplicate(true)
	editor.parts[0].at.x += 0.3
	var edited: Array = editor.parts.duplicate(true)
	editor.building_select.item_selected.emit(editor.building_ids.find("well") + 1)
	editor.edit_library()
	check(editor.active_asset == "well" and editor.parts != edited, "Editing another building replaces the editor contents")
	workshop.undo()
	check(editor.active_asset == "house" and editor.parts == edited and editor.building_ids[editor.building_select.selected - 1] == "house", "Undo restores the edited building and its selector together")
	workshop.redo()
	check(editor.active_asset == "well" and editor.building_ids[editor.building_select.selected - 1] == "well", "Redo reopens the chosen building")
	editor.building_select.item_selected.emit(editor.building_ids.find("house") + 1)
	editor.edit_library()
	check(editor.parts == edited, "Switching buildings preserves unsaved edits")
	editor.choose_library("log")
	editor.building_select.item_selected.emit(editor.building_ids.find("house") + 1)
	editor.edit_library()
	check(editor.library_choice == "house" and editor.parts == edited, "Reselecting the open building preserves edits and selects its library entry")
	editor.parts = original.duplicate(true)
	editor.store_asset()
	var history: int = workshop.undo_stack.size()
	editor.save_variant()
	var variant: String = editor.active_asset
	check(editor.assets[variant].base_asset == "house" and editor.category == "building", "A saved variant belongs to House")
	check(editor.parts == original and editor.assets.house.parts == original, "Creating a variant preserves the original geometry")
	check(variant in editor.variant_ids and variant not in editor.prefab_ids and variant not in editor.library_ids and variant not in editor.building_ids, "House variants appear only beneath the House selection")
	check(workshop.undo_stack.size() == history + 1, "Creating a variant is one history action")
	workshop.undo()
	check(editor.active_asset == "house" and not editor.assets.has(variant), "Variant creation undoes cleanly")
	workshop.redo()
	check(editor.active_asset == variant and editor.assets[variant].base_asset == "house", "Variant creation redoes")
	editor.parts = [Workspace.instance("house", Vector3.ZERO), Workspace.instance("house", Vector3(2, 0, 0))]
	workshop.draft.name = "Two rooms"
	editor.store_asset()
	var two_rooms: Array = editor.parts.duplicate(true)
	editor.parts[1].at = Vector3(0, 2, 0)
	workshop.draft.name = "Two levels"
	editor.save_variant()
	var upstairs: String = editor.active_asset
	check(editor.assets[upstairs].base_asset == "house", "Two-level layouts stay in the House family")
	editor.variant_select.item_selected.emit(editor.variant_ids.find(variant))
	editor.edit_library()
	check(editor.active_asset == variant, "Edit opens the chosen named variant")
	check(editor.parts == two_rooms, "Saving a new variant leaves the previously stored variant unchanged")
	editor.parts = two_rooms.duplicate(true)
	workshop.draft.name = "Two rooms"
	editor.store_asset()
	editor.variant_select.item_selected.emit(0)
	editor.edit_library()
	check(editor.active_asset == "house" and editor.chosen_variant == "house", "Edit opens the selected Original building")
	check(editor.parts == original, "Editing layout variants never changes Original House")
	editor.variant_select.item_selected.emit(editor.variant_ids.find(upstairs))
	editor.edit_library()
	check(editor.parts[1].at == Vector3(0, 2, 0), "Two-level variant remains independently editable")
	editor.choose_library("log")
	check(editor.chosen_variant == upstairs and editor.variant_ids[editor.variant_select.selected] == upstairs, "Browsing Assets retains the chosen House variant")
	check("log" in editor.library_ids and editor.library.visible and editor.prefab_library.visible, "Assets and Prefabs remain available during variant editing")
	var instance: Dictionary = editor.library_instance(upstairs)
	check(instance.building_family == "house" and Kit.Appearance.fixed_size(instance) and editor.grid_placed(instance), "Variant instances retain the building size lock and metre placement")
	var loaded: Dictionary = Kit.decode(Kit.encode([instance])).parts[0]
	check(loaded.building_family == "house" and Kit.Appearance.fixed_size(loaded), "Building identity survives serialization")
	var state: Dictionary = editor.state()
	check(Workspace.valid(state), "Workspace with building variants validates")
	state.assets[upstairs].base_asset = upstairs
	check(not Workspace.valid(state), "Self-referencing variant families are rejected")

	# Roof selection uses the source hierarchy without rewriting the building.
	editor.open_asset("house")
	editor.components.select_named("Roof")
	var roof_indices: Array[int] = editor.selection_indices()
	check(roof_indices.size() >= 2 and editor.parts == original, "Roof selector selects all roof members without changing geometry")
	for index in roof_indices: check(str(editor.parts[index].component).begins_with("Roof/"), "Roof selection excludes walls and furnishings")
	editor.components.name_edit.text = "Roof"
	editor.components.store_selection()
	var roof_asset: String = editor.library_choice
	check(roof_asset in editor.library_ids and editor.assets[roof_asset].category == "component", "Stored roof is a reusable Asset")
	check(editor.parts == original, "Storing a selected group leaves its source untouched")
	editor.group_selected()
	editor.components.name_edit.text = "Roof"
	editor.components.rename_selection()
	check(editor.parts[editor.selected].label == "Roof", "Grouped parts have an editable name")
	for frame in 5: await process_frame
	check(editor.layers.get_v_scroll_bar().value > 0, "Newly grouped roof stays visible in Parts")
	check(editor.layers.get_item_custom_fg_color(0).a > 0, "Normal Parts labels remain visible")
	var grouped: Array = editor.parts.duplicate(true)
	var roof_index: int = editor.selected
	var roof: Dictionary = editor.parts[editor.selected].duplicate(true)
	var roof_bounds := Kit.bounds(roof)
	editor.components.replacement.select(editor.components.replacement_ids.find(roof_asset) + 1)
	editor.components.replace_selection()
	check(Kit.bounds(editor.parts[editor.selected]).is_equal_approx(roof_bounds), "Replacing with the stored roof keeps its exact position and dimensions")
	check(editor.parts[editor.selected].label == "Roof" and editor.parts[editor.selected].asset_ref == roof_asset, "Replacement keeps the slot name and records the new asset")
	workshop.undo()
	check(editor.parts == grouped, "Replacement undoes atomically")
	workshop.redo()
	check(editor.parts[roof_index].get("asset_ref") == roof_asset, "Replacement redoes")
	# Replacement of a rotated, nonuniform source mesh uses the authored frame,
	# without carrying its old mesh scale into the replacement asset.
	editor.parts = [Workspace.instance("raw_stone", Vector3(2, 1, -3), Vector3(0, PI / 2, 0))]
	editor.parts[0].scale = Vector3(1.4, 0.8, 1.2)
	editor.select_layer(0)
	editor.components.name_edit.text = "Window wall"
	editor.components.rename_selection()
	editor.components.store_selection()
	var wall_asset: String = editor.library_choice
	var before: Dictionary = editor.parts[0].duplicate(true)
	var anchor: Transform3D = editor.components.frame()
	editor.components.replacement.select(editor.components.replacement_ids.find(wall_asset) + 1)
	editor.components.replace_selection()
	check(Kit.bounds(editor.parts[0]).is_equal_approx(Kit.bounds(before)), "Rotated component round trip preserves geometry without double scaling")
	check(editor.components.frame().is_equal_approx(anchor), "Replacement preserves the selected component's position and orientation")
	var path := "/tmp/pyramida-variants-%d.pyrstructure" % Time.get_ticks_usec()
	check(workshop._save(path) and workshop._load(path), "Variants, component assets and replacements save and reload")
	check(editor.assets[variant].base_asset == "house" and editor.assets[upstairs].base_asset == "house" and editor.assets.has(roof_asset), "Reload retains both House variants and the reusable roof")
	check(editor.parts[0].asset_ref == wall_asset, "Reload retains replacement identity")
	DirAccess.remove_absolute(path)
	workshop.free()
	if failures.is_empty(): print("PASS: %d Blueprint variant/component checks" % checks)
	quit(int(not failures.is_empty()))
