extends SceneTree
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Appearance = Assets.Appearance
const Model = preload("res://scripts/settlement/world_model.gd")
const WorldView = preload("res://scripts/settlement/world_view.gd")
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func run() -> void:
	Appearance.directory = "/tmp/pyramida-building-looks-%d" % Time.get_ticks_usec()
	for kind: String in Appearance.buildings():
		var parts := Appearance.defaults(kind)
		check(not parts.is_empty() and parts.size() <= Kit.LIMIT, kind + " opens its actual components")
		var decoded := Kit.decode(JSON.parse_string(JSON.stringify(Kit.encode(parts))))
		check(not decoded.is_empty() and decoded.parts.size() == parts.size(), kind + " components round trip")
		var original := Appearance.original(kind)
		var actual := Kit.meshes(original)
		check(actual.size() == parts.size(), kind + " retains all visible source meshes")
		for index in parts.size():
			check(Kit.transform(parts[index]).is_equal_approx(actual[index].transform), kind + " retains exact component transform")
		original.free()
	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	workshop.pieces.activate()
	var editor = workshop.pieces
	check(editor.building_picker.item_count == Appearance.buildings().size() + 1, "Every standard building appears in the selector")
	editor.open_building("well")
	var original_count: int = editor.parts.size()
	check(editor.selecting and original_count > 1 and editor.apply_button.visible, "Well opens ready to select its components")
	editor.selected = 0
	var source_path: String = editor.parts[0].component
	var first: Dictionary = editor.parts[0].duplicate(true)
	editor.coordinates[0].value = first.at.x + 0.3
	var moved: Dictionary = editor.parts[0].duplicate(true)
	editor.copy_selected()
	check(editor.component == source_path, "Copy keeps the selected individual mesh, not the whole well")
	var copy := Kit.placement(editor.kind, editor.rotation, Vector3(3, 0, 0), Vector3.UP, editor.component, editor.piece_scale, editor.piece_basis)
	check(copy.component == source_path and absf(Kit.bounds(copy).position.y) < 0.0001, "Copied source component snaps using its own geometry")
	editor.open_building("stairs")
	editor.open_building("stockpile")
	editor.open_building("platform")
	editor.open_building("well")
	check(editor.parts[0] == moved, "Switching standard buildings retains unsaved edits")
	workshop.undo()
	check(editor.building_kind == "platform", "Undo restores the correct building target")
	workshop.redo()
	check(editor.building_kind == "well" and editor.parts[0] == moved, "Redo restores component edits and building target")
	var path := Appearance.directory + "/workshop.pyrstructure"
	check(workshop._save(path), "Standard building workspace saves")
	editor.open_building("stairs")
	check(workshop._load(path) and editor.building_kind == "well" and editor.parts[0] == moved, "Opening preserves the standard building target and edits")
	check(editor.building_drafts.has("platform"), "Other building drafts persist with the workspace")
	var removed: Dictionary = editor.parts.pop_back()
	var prior_revision := Appearance.revision
	editor.apply_building()
	check(Appearance.revision == prior_revision + 1, "Apply saves an appearance and invalidates live visuals")
	Appearance.overrides.clear()
	var game := Assets.create("well")
	check(game.get_node(source_path).transform.is_equal_approx(Kit.transform(moved)), "Game reloads edited component placement from disk")
	check(game.get_node(removed.component).layers == 0, "Removed components stay invisible even if gameplay shows the node")
	check(game.has_node("AccessFront") and game.has_node("WaterOut"), "Gameplay access and water markers remain intact")
	game.free()
	editor.restore_original()
	check(editor.parts.size() == original_count and editor.parts[0] == first, "Original restores source appearance without changing the saved game look")
	workshop.undo()
	check(editor.parts.size() == original_count - 1 and editor.parts[0] == moved, "Restoring the original is undoable")
	var bad := Kit.encode(editor.parts)
	bad[0].component = "../../Unknown"
	check(Kit.decode(bad).is_empty(), "Invalid component paths rejected")
	bad = Kit.encode(editor.parts)
	bad[0].scale = [1, 0, 1]
	check(Kit.decode(bad).is_empty(), "Singular component scales rejected before picking")
	for kind: String in Appearance.buildings():
		check(Appearance.save(kind, Appearance.defaults(kind)), kind + " appearance can be applied")
		var restored := Assets.create(kind)
		check(not Kit.meshes(restored).is_empty(), kind + " remains drawable in the game")
		restored.free()
	var model := Model.new()
	var mill_parts := Appearance.defaults("windmill")
	var sail_path := "WindTower/Rotor/Sail0/LinenSail"
	var sail: Dictionary = mill_parts.filter(func(p): return p.component == sail_path)[0]
	sail.at.x += 0.3
	sail.scale = Vector3(1.2, 0.8, 1.0)
	var duplicate := sail.duplicate(true)
	duplicate.at.y += 0.4
	mill_parts.append(duplicate)
	check(Appearance.save("windmill", mill_parts), "Edited and duplicated sails save")
	Appearance.overrides.erase("windmill")
	var mill := Assets.create("windmill")
	root.add_child(mill)
	var rotor := mill.get_node("WindTower/Rotor") as Node3D
	var sail_node := mill.get_node(sail_path) as MeshInstance3D
	var copy_node := sail_node.get_parent().get_child(sail_node.get_parent().get_child_count() - 1) as MeshInstance3D
	check(rotor.is_ancestor_of(copy_node) and copy_node != sail_node, "Duplicated sail remains attached to the animated rotor after reload")
	check(copy_node.global_transform.is_equal_approx(Kit.transform(duplicate)), "Attaching copied sail preserves its authored building-space pose")
	var local_pose := sail_node.transform
	var copy_local_pose := copy_node.transform
	var old_pose := sail_node.global_transform
	var old_copy_pose := copy_node.global_transform
	preload("res://scripts/settlement/mill_view.gd").animate(mill, 3, 1.0, true)
	check(not sail_node.global_transform.is_equal_approx(old_pose) and not copy_node.global_transform.is_equal_approx(old_copy_pose), "Edited and duplicated sails both rotate during animation")
	check(sail_node.transform.is_equal_approx(local_pose) and copy_node.transform.is_equal_approx(copy_local_pose), "Animation preserves sail edits relative to the hub")
	preload("res://scripts/settlement/mill_view.gd").sync(mill, 1)
	check(not copy_node.is_visible_in_tree(), "Duplicated sails follow windmill tier visibility")
	mill.free()
	model.setup()
	preload("res://tests/settlement/terrace_fixture.gd").add_to(model)
	var view := WorldView.new()
	root.add_child(view)
	view.setup(model)
	var key := "platform:%s" % Vector3i(2, 1, 0)
	var old_id: int = view.entity_views[key].get_instance_id()
	var deck := Appearance.defaults("platform")
	deck[0].at.x += 0.2
	check(Appearance.save("platform", deck), "Applying a platform while settlement exists succeeds")
	view.sync(model, 0, -1)
	check(view.entity_views[key].get_instance_id() != old_id, "Existing buildings refresh without changing the simulation revision")
	# Applied custom geometry stays at its authored size at either platform tier.
	var expected_position: Vector3 = deck[0].at
	check(view.entity_views[key].get_node(deck[0].component).position.is_equal_approx(expected_position), "Existing platform displays applied placement with its support tier")
	check(view.entity_views[key].get_meta("collider").get_child(0).shape.size == Kit.Catalog.DEFINITIONS.platform.size, "Visual edits retain the gameplay collision footprint")
	view.free()
	workshop.free()
	for file in DirAccess.get_files_at(Appearance.directory): DirAccess.remove_absolute(Appearance.directory.path_join(file))
	DirAccess.remove_absolute(Appearance.directory)
	Appearance.overrides.clear()
	if failures == 0: print("PASS: %d standard building appearance checks" % checks)
	quit(0 if failures == 0 else 1)
