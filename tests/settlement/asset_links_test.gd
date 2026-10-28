extends SceneTree
const Scene = preload("res://scenes/settlement/StructureWorkshop.tscn")
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
const Shape = preload("res://scripts/settlement/structure_blueprint.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)
func run() -> void:
	var workshop = Scene.instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	var editor = workshop.pieces
	editor.activate()
	editor.open_asset("house")
	var original: Array = editor.parts.duplicate(true)
	editor.new_asset("prefab")
	var prefab: String = editor.active_asset
	var first: Dictionary = editor.library_instance("house")
	first.at = Vector3(2, 0, -3)
	first.rotation.y = PI / 2
	editor.parts = [first, editor.library_instance("house")]
	editor.store_asset()
	editor.open_asset("house")
	editor.parts[0].at.y += 0.4
	var changed: Array = editor.parts.duplicate(true)
	editor.open_asset(prefab)
	check(editor.parts[0].children == changed and editor.parts[1].children == changed, "Existing instances follow source edits without reinserting")
	check(editor.parts[0].at == Vector3(2, 0, -3) and is_equal_approx(editor.parts[0].rotation.y, PI / 2), "Source updates preserve instance placement and rotation")
	var document: Dictionary = Shape.document(workshop.draft, workshop.instances, workshop.workspace_state())
	check(document.workspace.parts[0].linked and not document.workspace.parts[0].has("children"), "Saved instance stores a reference instead of duplicate geometry")
	check(not document.workspace.authoring.assets[prefab].parts[0].has("children"), "Stored prefab also contains only component references")
	var path := "/tmp/pyramida-links-%d.pyrstructure" % Time.get_ticks_usec()
	check(workshop._save(path) and workshop._load(path), "Linked workspace saves and reopens")
	check(editor.parts[0].children == changed, "Reopening resolves source geometry")
	editor.selected = 0
	editor.enter_selected()
	check(editor.active_asset == "house", "Editing a linked instance opens its shared source")
	editor.parts[0].at.y += 0.2
	changed = editor.parts.duplicate(true)
	editor.leave_scope()
	check(editor.parts[0].children == changed and editor.parts[1].children == changed, "Editing one linked instance updates its siblings")
	workshop.undo()
	check(editor.scopes.size() == 1, "Undo restores the source editing scope")
	workshop.redo()
	check(editor.parts[1].children == changed, "Redo restores updated references")
	# Keep explicit local groups independent; nesting must still resolve their links.
	editor.parts = [{"kind": "assembly", "at": Vector3.ZERO, "rotation": Vector3.ZERO, "children": editor.parts.duplicate(true)}]
	workshop._refresh()
	editor.store_asset()
	editor.open_asset("house")
	editor.parts = original
	editor.open_asset(prefab)
	check(editor.parts[0].children[0].children == original, "References update through ordinary nested groups")
	# Migrate an older cached House snapshot, including one with stale geometry.
	var legacy: Dictionary = editor.parts[0].children[0].duplicate(true)
	legacy.erase("linked")
	legacy.children = changed
	editor.parts = [legacy]
	editor.restore_state(editor.state())
	workshop._refresh()
	check(editor.parts[0].linked and editor.parts[0].children == original, "Older asset_ref snapshots become live component links")
	var cyclic := {"loop": {"parts": [{"kind": "assembly", "asset_ref": "loop", "linked": true, "children": []}], "contract": Workspace.Contract.make()}}
	check(not Workspace.resolve(cyclic.loop.parts.duplicate(true), cyclic), "Circular references are rejected")
	var invalid: Dictionary = Shape.document(workshop.draft, workshop.instances, workshop.workspace_state())
	invalid.workspace.parts[0].asset_ref = "missing_component"
	check(Shape.parse_document(invalid).is_empty(), "Missing references reject a document before replacing current work")
	editor.open_asset("house")
	editor.choose_library(prefab)
	editor.insert_library()
	check(editor.insertion.is_empty(), "Inserting a prefab into its own source is prevented")
	editor.refresh_library()
	check("stick" in editor.library_ids and "stick" not in editor.building_ids, "Construction Stick is available as an asset rather than a building")
	for prop in ["bed", "bench", "table", "urn", "food_crate", "water_bucket", "pottery"]:
		check(prop in editor.library_ids and prop not in editor.building_ids, prop + " is available as a reusable prop")
	var orphan: Dictionary = legacy.duplicate(true)
	orphan.asset_ref = "deleted_custom_source"
	orphan.erase("linked")
	Workspace.migrate_links([orphan])
	check(not orphan.linked and orphan.children == changed, "Legacy instances with missing custom sources retain their geometry locally")
	var invalid_cycle: Dictionary = Shape.document(workshop.draft, workshop.instances, workshop.workspace_state())
	invalid_cycle.workspace.authoring.assets[prefab].parts = [{"kind": "assembly", "at": [0, 0, 0], "rotation": [0, 0, 0], "asset_ref": prefab, "linked": true}]
	check(Shape.parse_document(invalid_cycle).is_empty(), "Cyclic saved component definitions are rejected")
	editor.open_asset("stick")
	check(not editor.parts.is_empty() and editor.source_path().ends_with("stick.glb"), "Stick opens for mesh editing and reveals its real source")
	var example := Workspace.example()
	check(example[0].linked and not Workspace.encode_parts(example)[0].has("children"), "Lower example floors also remain linked, without embedded House copies")
	check(Workspace.resolve(example, {}) and not example[0].children.any(func(p): return str(p.get("component", "")).begins_with("Roof/")), "Linked example preserves its open intermediate roofs")
	editor.new_asset("prefab")
	editor.parts = [example[0]]
	editor.selected = 0
	editor.enter_selected()
	check(editor.parts.any(func(p): return str(p.get("component", "")).begins_with("Roof/")), "Editing a lower-floor link opens its complete source, including the hidden roof")
	editor.leave_scope()
	check(not editor.parts[0].children.any(func(p): return str(p.get("component", "")).begins_with("Roof/")), "Returning retains the instance roof visibility override")
	var site := Kit.Assets.create("house")
	preload("res://scripts/settlement/construction_site_view.gd").prepare(site, "house")
	var marker: Node3D = site.get_node("ConstructionCorners/Branch2")
	check(marker.scene_file_path == "res://data/settlement/stick.tscn", "Construction uses the same shared Stick scene")
	check(Kit.meshes(marker).size() == 1, "Construction marker remains one branchless stick")
	site.free()
	DirAccess.remove_absolute(path)
	workshop.free()
	if failures.is_empty(): print("PASS: %d linked asset checks" % checks)
	quit(int(not failures.is_empty()))
