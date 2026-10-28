extends SceneTree
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Appearance = Kit.Appearance
const Palette = Appearance.TimberPalette
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func colours(node: Node3D) -> Array:
	var result: Array = []
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count(): result.append(mesh.get_active_material(surface).albedo_color)
	return result
func run() -> void:
	Appearance.directory = "/tmp/pyramida-timber-palette-%d" % Time.get_ticks_usec()
	var holder := Node3D.new()
	root.add_child(holder)
	for kind in ["log", "plank"]:
		var part := {"kind": kind, "at": Vector3(1, 2, 3), "rotation": Vector3(0.2, 0.4, 0.6)}
		var original := Kit.draw(holder, part)
		var original_meshes := Kit.meshes(original)
		var original_colours := colours(original)
		var seen: Array = []
		for index in 3:
			Appearance.set_timber_species(part, Palette.SPECIES[index])
			var encoded := Kit.encode([part])
			var loaded := Kit.decode(JSON.parse_string(JSON.stringify(encoded))).parts[0] as Dictionary
			check(loaded.timber_species == Palette.SPECIES[index], "Timber selection survives JSON save/load")
			var node := Kit.draw(holder, loaded)
			var meshes := Kit.meshes(node)
			check(meshes == original_meshes and node.transform == original.transform, "Species changes neither geometry nor placement")
			var painted := colours(node)
			check(painted not in seen, "Each species has a distinct material")
			seen.append(painted)
			if kind == "log":
				check(painted[0].is_equal_approx(Palette.BARK[index]), "Bark matches chosen tree type")
				check(painted[1].is_equal_approx(Palette.WOOD[index]) and painted[2].is_equal_approx(Palette.WOOD[index]), "Both cut ends match the lighter plank wood")
			else: check(painted[0].is_equal_approx(Palette.WOOD[index]), "Plank uses exposed wood without bark")
			check(Palette.WOOD[index].get_luminance() > Palette.BARK[index].get_luminance(), "Sawn wood is lighter than bark")
			check(colours(original) == original_colours, "Recolouring an instance never mutates another instance")
			node.free()
		original.free()
	var house := Workspace.instance("house", Vector3.ZERO)
	var plaster: Dictionary = house.children.filter(func(p): return p.component == "PlasterWall")[0]
	Appearance.set_timber_species(house, "palm")
	check(not plaster.has("timber_species"), "Timber colour leaves plaster and other materials untouched")
	check(Appearance.timber_species(house) == "palm", "Whole assembly can receive one wood species")
	var parts := Appearance.defaults("platform")
	var beam: Dictionary = parts.filter(func(p): return p.component == "RimBeam")[0]
	Appearance.set_timber_species(beam, "dead_tree")
	check(Appearance.save("platform", parts), "Building accent saves for live gameplay")
	Appearance.overrides.clear()
	var building := Kit.Assets.create("platform")
	var accent := building.get_node("RimBeam") as MeshInstance3D
	check(accent.get_active_material(0).albedo_color.is_equal_approx(Palette.BARK[2]), "Live building retains the saved accent")
	check(building.get_node("FloorPlank_00").get_active_material(0).albedo_color.is_equal_approx(Palette.WOOD[0]), "Other timber keeps its own species")
	building.free()
	var bad := Kit.encode(parts)
	bad[0].timber_species = "invalid"
	check(Kit.decode(bad).is_empty(), "Unknown species is rejected during loading")
	var workshop := preload("res://scenes/settlement/StructureWorkshop.tscn").instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	var editor = workshop.pieces
	editor.activate()
	editor.parts = [Workspace.instance("log", Vector3.ZERO), Workspace.instance("plank", Vector3(1, 0, 0))]
	editor.selected = 0
	editor.selecting = true
	workshop._refresh()
	check(editor.timber_picker.visible, "Timber selection appears for a log assembly")
	editor.choose_timber(1)
	check(Appearance.timber_species(editor.parts[0]) == "palm" and Appearance.timber_species(editor.parts[1]) == "tree", "Selection changes only the selected timber")
	workshop.undo()
	check(Appearance.timber_species(editor.parts[0]) == "tree", "Undo restores wood choice")
	workshop.redo()
	check(Appearance.timber_species(editor.parts[0]) == "palm", "Redo restores accent")
	editor.selected = 0
	workshop._refresh()
	editor.duplicate_selected()
	check(Appearance.timber_species(editor.parts.back()) == "palm", "Duplicates retain their wood choice")
	var path := Appearance.directory + "/workspace.pyrstructure"
	check(workshop._save(path) and workshop._load(path) and Appearance.timber_species(editor.parts.back()) == "palm", "Workspace save/load preserves accents")
	editor.parts = [house]
	editor.selected = 0
	editor.enter_selected()
	check(editor.parts.all(func(p): return p.get("timber_species", "tree") == "tree"), "Editing a linked source keeps the instance palette out of the shared definition")
	editor.leave_scope()
	check(Appearance.timber_species(editor.parts[0]) == "palm", "Leaving a nested edit preserves accents")
	workshop.free()
	holder.free()
	for file in DirAccess.get_files_at(Appearance.directory): DirAccess.remove_absolute(Appearance.directory.path_join(file))
	DirAccess.remove_absolute(Appearance.directory)
	if failures == 0: print("PASS: %d timber colour, geometry, save and editor checks" % checks)
	quit(int(failures > 0))
