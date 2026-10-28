extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Contract = preload("res://scripts/settlement/asset_contract.gd")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(not Shape.parse_document(JSON.parse_string(FileAccess.get_file_as_string("res://data/structures/asset-prefab-example.pyrstructure"))).is_empty(), "Shipped prefab example opens as a valid workspace")
	var directory := "/tmp/pyramida-authoring-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	Kit.Appearance.mesh_directory = directory
	var volume := Contract.make(Vector3(1,2,2))
	check(Contract.box(volume).size == Vector3(1,2,2), "Half cube has an explicit 1x2x2 occupied volume")
	check(not Contract.excess(AABB(Vector3(-0.53, 0, -1), Vector3(1, 2, 2)), volume), "Small overlap is allowed")
	check(Contract.excess(AABB(Vector3(-0.56, 0, -1), Vector3(1, 2, 2)), volume), "Excess beyond allowance is detected")
	for kind in Kit.Appearance.PRIMITIVES:
		var parts := Kit.Appearance.defaults(kind)
		check(not parts.is_empty() and not Kit.decode(Kit.encode(parts)).is_empty(), kind + " is editable and serializable")
	var group := Workspace.instance("sawmill", Vector3(3,0,1), Vector3(0,PI/2,0))
	group.scale = Vector3(1.2,1,0.8)
	var node := Kit.draw(Node3D.new(), group)
	var mesh_bounds := AABB()
	var first := true
	for mesh in Kit.meshes(node, node.transform):
		var b: AABB = mesh.transform * mesh.bounds
		mesh_bounds = b if first else mesh_bounds.merge(b)
		first = false
	check(Kit.bounds(group).is_equal_approx(mesh_bounds), "Nested transforms preserve exact displayed bounds")
	node.get_parent().free()
	var serialized := Kit.encode([group])
	check(not Kit.decode(JSON.parse_string(JSON.stringify(serialized))).is_empty(), "Nested prefab survives JSON")
	serialized[0].contract.size[0] = -1
	check(Kit.decode(serialized).is_empty(), "Malformed nested bounds rejected")

	var workshop := Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	var editor = workshop.pieces
	editor.activate()
	check(workshop.overlay.origin_visible, "Blueprints marks the fixed workspace origin")
	var house := Workspace.instance("house", Vector3.ZERO)
	check(editor.placement_position(house, Vector3(0.49, 2.008, -1.12)) == Vector3(0, 2, -1), "Dragging a full building aligns its corner and ignores floor finish thickness")
	check(editor.building_socket(house, Vector3(0.4, 3.6, -0.2), Workspace.instance("windmill", Vector3.ZERO)) == Vector3(0, 6, 0), "Stacking uses the game's six-metre windmill socket rather than its visible roof")
	check(editor.building_socket(house, Vector3(0.2, 1.4, -0.3), house) == Vector3(0, 2, 0), "Stacking a full building aligns its occupied footprint with its support")
	check(editor.placement_position(Workspace.instance("log", Vector3.ZERO), Vector3(0.24, 0.36, -0.12)).is_equal_approx(Vector3(0.2, 0.4, -0.1)), "Loose assets retain fine authoring precision")
	var half_house: Dictionary = house.duplicate(true)
	half_house.contract = Contract.make(Vector3(1, 2, 2))
	var half_before: Dictionary = half_house.duplicate(true)
	var left_at: Vector3 = editor.building_socket(half_house, Vector3.ZERO)
	var right_at: Vector3 = editor.building_socket(half_house, Vector3.RIGHT)
	var left_box: AABB = Transform3D(Basis.IDENTITY, left_at) * Contract.box(half_house.contract)
	var right_box: AABB = Transform3D(Basis.IDENTITY, right_at) * Contract.box(half_house.contract)
	check(left_box.position.is_equal_approx(Vector3.ZERO), "A half-width building starts at the clicked grid corner")
	check(left_box.end.x == right_box.position.x and left_box.merge(right_box).size == Vector3(2, 2, 2), "Two half-width buildings fill one 2x2 square without gaps or overlap")
	check(editor.placement_position(half_house, left_at + Vector3(0.2, 0.008, -0.1)).is_equal_approx(left_at), "Dragging keeps the half-width building's corner on the grid")
	check(editor.placement_position(half_house, Vector3(-0.6, 2.008, -1.2)).is_equal_approx(Vector3(-0.5, 2, -1)), "Corner snapping works across negative coordinates")
	half_house.rotation.y = PI / 2
	var rotated_at: Vector3 = editor.building_socket(half_house, Vector3.ZERO)
	half_house.at = rotated_at
	var rotated_box: AABB = Kit.transform(half_house) * Contract.box(half_house.contract)
	check(rotated_box.position.is_equal_approx(Vector3.ZERO) and rotated_box.size.is_equal_approx(Vector3(2, 2, 1)), "Quarter-turn placement snaps the rotated footprint corner")
	half_house = half_before.duplicate(true)
	var support: Dictionary = house.duplicate(true)
	support.at = Vector3(1, 0, 1)
	var lower: Vector3 = editor.building_socket(half_house, Vector3(0.1, 1.9, 0.1), support)
	var upper: Vector3 = editor.building_socket(half_house, Vector3(1.1, 1.9, 0.1), support)
	check(lower.is_equal_approx(Vector3(0.5, 2, 1)) and upper.is_equal_approx(Vector3(1.5, 2, 1)), "Half-width buildings stack on either side of a supporting roof")
	var platform := Workspace.instance("platform", Vector3.ZERO)
	platform.at = editor.building_socket(platform, Vector3.ZERO)
	check((Kit.transform(platform) * Contract.box(platform.contract)).position.is_equal_approx(Vector3.ZERO), "Top-pivot platform still places its occupied lower corner on the ground")
	check(half_house == half_before, "Snapping leaves source geometry, pivots and contracts untouched")
	var grid_root := Node3D.new()
	preload("res://scripts/settlement/structure_workshop_view.gd").grid(grid_root, 0, 2, Color.WHITE, 2.0, true)
	var grid_vertices: PackedVector3Array = grid_root.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var crosses_x := false
	var crosses_z := false
	for i in range(0, grid_vertices.size(), 2):
		crosses_x = crosses_x or (is_zero_approx(grid_vertices[i].x) and is_zero_approx(grid_vertices[i + 1].x))
		crosses_z = crosses_z or (is_zero_approx(grid_vertices[i].z) and is_zero_approx(grid_vertices[i + 1].z))
	check(crosses_x and crosses_z, "Major grid lines intersect at the fixed workspace origin")
	grid_root.free()
	editor.refresh_library()
	check("log" in editor.library_ids and "raw_stone" in editor.library_ids and "utility_ac" in editor.library_ids, "Assets includes materials and equipment")
	check("school" not in editor.library_ids and "house" not in editor.library_ids, "Assets excludes buildings")
	check("school" in editor.building_ids and "house" in editor.building_ids and "log" not in editor.building_ids, "Buildings have a dedicated single selection input")
	check("roof_face" in editor.library_ids and "roof_face" not in editor.building_ids, "The existing roof face is available as a loose asset")
	var roof := Workspace.instance("roof_face", Vector3.ZERO)
	var source_roof: Dictionary = Kit.Appearance.defaults("house").filter(func(p): return p.component == "Roof/Cap")[0]
	check(Kit.bounds(roof).size.is_equal_approx(Kit.bounds(source_roof).size), "Roof face keeps the building source's exact dimensions")
	check(is_zero_approx(Kit.bounds(roof).position.y), "Reusable roof face rests on its placement plane")
	var roof_mesh := Kit.Appearance.source("roof_face", "RoofFace")
	var source_mesh := Kit.Appearance.source("house", "Roof/Cap")
	check(roof_mesh.mesh == source_mesh.mesh and roof_mesh.material_override == source_mesh.material_override, "Roof face reuses the actual building mesh and material")
	roof_mesh.free()
	source_mesh.free()
	editor.open_asset("roof_face")
	check(editor.source_path() == "res://data/settlement/house.tscn", "Roof face reveals its actual source scene")
	var open_id: String = editor.active_asset
	var open_parts: Array = editor.parts.duplicate(true)
	editor.library.item_selected.emit(editor.library_ids.find("log"))
	editor.library.item_activated.emit(editor.library_ids.find("log"))
	check(editor.active_asset == open_id and editor.parts == open_parts and editor.library_choice == "log", "Double-clicking Assets selects without opening")
	editor.building_select.item_selected.emit(editor.building_ids.find("house") + 1)
	check(editor.active_asset == open_id and editor.library_choice == "house" and not editor.can_save_variant(), "Building selection waits for Edit and cannot save the wrong asset as a variant")
	editor.edit_library()
	check(editor.active_asset == "house", "Edit opens the selected library entry")
	editor.new_asset("prefab")
	editor.parts = [roof]
	editor.store_asset()
	var prefab_id: String = editor.active_asset
	editor.open_asset("log")
	editor.prefab_library.item_selected.emit(editor.prefab_ids.find(prefab_id))
	editor.prefab_library.item_activated.emit(editor.prefab_ids.find(prefab_id))
	check(editor.active_asset == "log" and editor.library_choice == prefab_id, "Double-clicking Prefabs selects without opening")
	editor.edit_library()
	editor.select_layer(0)
	editor.layers.item_activated.emit(0)
	check(editor.scopes.is_empty() and editor.active_asset == prefab_id, "Activating a Parts row does not enter the assembly")
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	double_click.position = Vector2(10, 10)
	editor.layer_input(double_click)
	check(editor.scopes.is_empty(), "Double-clicking a Parts row keeps the current scope")
	editor.selected = -1
	workshop._refresh()
	double_click.position = workshop.camera.unproject_position(Kit.bounds(roof).get_center())
	editor.input(double_click)
	check(editor.selected == 0 and editor.scopes.is_empty(), "Double-clicking an assembly in the viewport only selects it")
	double_click.pressed = false
	editor.input(double_click)
	editor.enter_selected()
	check(editor.scopes.size() == 1 and editor.active_asset == "roof_face", "Edit instance still opens a selected linked roof face")
	editor.leave_scope()
	var roof_path := directory.path_join("roof.pyrstructure")
	check(workshop._save(roof_path) and workshop._load(roof_path) and editor.parts[0].asset_ref == "roof_face", "Reusable roof links survive workspace save and reload")
	editor.search.text = "school"
	editor.refresh_library()
	check(editor.library_ids.is_empty(), "Search does not leak buildings into Assets")
	check("school" in editor.building_ids and editor.prefab_library.visible and editor.library.visible, "Asset search leaves the other sections available")
	editor.search.text = ""
	editor.refresh_library()
	editor.open_asset("log")
	var before_drag: Array = editor.parts.duplicate(true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = workshop.camera.unproject_position(Kit.bounds(editor.parts[0]).get_center())
	editor.input(click)
	var motion := InputEventMouseMotion.new()
	motion.position = click.position + Vector2(45, 0)
	motion.relative = Vector2(45, 0)
	editor.input(motion)
	click.pressed = false
	editor.input(click)
	check(editor.parts != before_drag, "Viewport drag moves a picked primitive")
	workshop.undo()
	check(editor.parts == before_drag, "A complete drag is one undo step")
	editor.open_asset("sawmill")
	check(editor.category == "building", "Opening a building preserves its assembly classification")
	var legacy_state: Dictionary = editor.state()
	legacy_state.category = "component"
	editor.restore_state(legacy_state)
	check(editor.category == "building", "Older component-classified buildings migrate without changing their parts")
	var overflow_group := Workspace.instance("log", Vector3.ZERO)
	overflow_group.children[0].at.x += 3
	check(editor.exceeds(overflow_group, Contract.make(Vector3(20,20,20), Vector3(0,-5,0))), "Component overflow is detected even inside a roomy prefab")
	check(editor.parts.size() > 1 and editor.inspector.visible, "Standard building opens as editable original components")
	editor.volume_spins[0].value = 1.0
	check(editor.contract.size[0] == 1.0, "Occupied width changes independently of mesh")
	workshop.undo()
	check(is_equal_approx(editor.contract.size[0], Workspace.defaults("sawmill").size[0]), "Undo restores the authoring volume")
	workshop.redo()
	check(editor.contract.size[0] == 1.0, "Redo restores the changed volume")
	editor.open_asset("utility_ac")
	check(editor.contract.mount == "wall", "Wall utilities carry their own mount and occupied volume")
	editor.open_asset("sawmill")
	check(editor.contract.size[0] == 1.0, "Switching assets preserves unsaved volume edits")
	editor.new_asset("prefab")
	workshop.draft.name = "Test prefab"
	var id: String = editor.active_asset
	editor.chosen_building = "house"
	editor.choose_library("house")
	editor.insert_library()
	editor.automatic = false
	editor.plane_height = 0
	var floor_pointer: Vector2 = workshop.camera.unproject_position(Vector3(-1.26, 0, 2.34))
	editor.hover(floor_pointer)
	check(editor.candidate.at == Vector3(0, 0, 3), "Live insertion preview snaps on both sides of the origin")
	editor.click(floor_pointer)
	check(editor.parts.size() == 1 and editor.parts[0].at == Vector3(0, 0, 3), "Click commits exactly the snapped preview")
	workshop.undo()
	editor.selecting = true
	editor.insertion = {}
	editor.parts = [Workspace.instance("sawmill", Vector3.ZERO), Workspace.instance("utility_ac", Vector3(1,1,0))]
	editor.selected = 0
	workshop._refresh()
	editor.coordinates[0].value = 1.3
	check(editor.parts[0].at == Vector3(1.3, 0, 0), "Explicit numeric building positions override placement snapping")
	editor.coordinates[0].value = 1.0
	editor.gizmo.set_mode("move")
	editor.gizmo.nudge(2, -1)
	check(editor.parts[0].at == Vector3(1, 0, -1), "Building movement buttons use metre steps")
	editor.duplicate_selected()
	check(editor.parts[-1].at == Vector3(3, 0, -1), "Duplicated buildings retain grid alignment")
	workshop.undo()
	check(editor.parts.size() == 2, "Grid duplication stays undoable")
	editor.parts[0].at = Vector3.ZERO
	editor.store_asset()
	check(editor.assets.has(id) and editor.assets[id].category == "prefab", "Prefabs can be stored and reused")
	editor.refresh_library()
	check(id in editor.prefab_ids and "log" in editor.library_ids and "school" in editor.building_ids, "Prefabs, buildings and assets remain available together")
	editor.parts[0].at = Vector3(1,0,2)
	editor.selected = 0
	workshop._refresh()
	var saved_bounds: AABB = Kit.bounds(editor.parts[0])
	editor.unpack_selected()
	var unpacked := AABB()
	first = true
	for i in range(1, editor.parts.size()):
		var b := Kit.bounds(editor.parts[i])
		unpacked = b if first else unpacked.merge(b)
		first = false
	check(unpacked.is_equal_approx(saved_bounds), "Editing instance parts preserves the assembly transform")
	workshop.undo()
	check(editor.parts.size() == 2 and editor.parts[0].kind == "assembly", "Unpacking is undoable")
	editor.selected = 0
	editor.enter_selected()
	check(editor.scopes.size() == 1 and editor.parts.size() > 1, "A prefab component opens in place without losing its grouping")
	editor.selected = 0
	workshop._refresh()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	workshop._input(escape)
	check(workshop.visible and editor.scopes.size() == 1 and editor.selected == -1, "Escape deselects inside a component without leaving its editing scope")
	editor.contract.size[0] = 3.0
	editor.parts[0].at.x += 0.1
	var nested_path := directory.path_join("nested.pyrstructure")
	check(workshop._save(nested_path) and workshop._load(nested_path) and editor.scopes.size() == 1, "Saving inside a component preserves its parent prefab")
	editor.leave_scope()
	check(editor.parts[0].kind == "assembly" and editor.parts[0].contract.size[0] == 3.0, "Returning commits component edits and its occupied volume")
	workshop.undo()
	check(editor.scopes.size() == 1, "Undo returns to the nested component scope")
	workshop.redo()
	check(editor.scopes.is_empty(), "Redo returns to the prefab with edits retained")
	var path := directory.path_join("test.pyrstructure")
	check(workshop._save(path), "Full asset workspace saves")
	editor.new_asset("component")
	check(workshop._load(path) and editor.active_asset == id and editor.parts.size() == 2, "Save/load retains active prefab, reusable library and nested parts")
	check(editor.assets.sawmill.category == "building", "Building classification survives workspace save/load")
	var bad := Shape.document(workshop.draft, workshop.instances, workshop.workspace_state())
	bad.workspace.authoring.contract.margin = -1
	check(Shape.parse_document(bad).is_empty(), "Invalid authoring metadata cannot replace a document")
	var glb := directory.path_join("prefab.glb")
	var original_bounds := Kit.bounds({"kind":"assembly", "children":editor.parts, "at":Vector3.ZERO, "rotation":Vector3.ZERO})
	check(editor.export_glb(glb), "Edited prefab exports to Blender GLB")
	check(editor.import_glb(glb), "Blender GLB imports as an editable source model")
	check(Kit.bounds(editor.parts[0]).is_equal_approx(original_bounds), "Blender round trip preserves size and transforms")
	check(not Kit.decode(Kit.encode(editor.parts)).is_empty(), "Imported model references persist")
	check(workshop._save(path) and workshop._load(path), "Imported assets survive workspace reopening")
	workshop.undo()
	editor.load_example()
	check(editor.parts.size() > 10 and editor.parts.any(func(p): return p.asset_ref == "stairs"), "Multilevel example includes explicit ladders and utilities")
	check(not Shape.parse_document(Shape.document(workshop.draft, workshop.instances, workshop.workspace_state())).is_empty(), "Example and reusable library validate")
	workshop.free()
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	if failures.is_empty(): print("PASS: %d asset workbench checks" % checks)
	quit(int(not failures.is_empty()))
