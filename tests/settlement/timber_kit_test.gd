extends SceneTree
const Kit = preload("res://scripts/settlement/structure_parts.gd")
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Workspace = preload("res://scripts/settlement/asset_workspace.gd")
const Variants = preload("res://scripts/settlement/construction_variants.gd")
const Gizmo = preload("res://scripts/settlement/asset_transform_gizmo.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Assets.Appearance.directory = "/tmp/pyramida-timber-empty-%d" % Time.get_ticks_usec()
	for kind in ["log", "plank", "house", "sawmill", "platform", "stairs"]:
		var part := {"kind": kind, "at": Vector3(2, 3, 4), "rotation": Vector3(0.2, 0.4, 0.6), "scale": Vector3(3, 0.5, 2), "basis": Basis.from_scale(Vector3(2, 4, 1))}
		check(Kit.transform(part).basis.get_scale().is_equal_approx(Vector3.ONE), kind + " ignores instance stretching, including saved bases")
		var decoded := Kit.decode(Kit.encode([part]))
		check(Kit.transform(decoded.parts[0]).is_equal_approx(Kit.transform(part)), kind + " keeps scale lock after reload")
		var resized := Gizmo.transformed(part, {"kind": "face", "axis": 0, "anchor": Vector3.ZERO, "length": 1.0}, 1)
		check(resized == part, kind + " cannot be resized through face controls")
		var moved := Gizmo.transformed(part, {"kind": "move", "direction": Vector3.RIGHT}, 0.1)
		check(moved.at.is_equal_approx(part.at + Vector3.RIGHT * 0.1), kind + " can still be repositioned")
	var group := Workspace.instance("house", Vector3.ZERO)
	group.scale = Vector3.ONE * 4
	check(Kit.transform(group).basis.get_scale().is_equal_approx(Vector3.ONE), "Building prefab stays at authored size")
	var nested := {"kind": "assembly", "at": Vector3.ZERO, "rotation": Vector3.ZERO, "scale": Vector3.ONE * 5, "children": [group]}
	check(Kit.transform(nested).basis.get_scale().is_equal_approx(Vector3.ONE), "Wrapping a building in another group cannot bypass the lock")
	var plank: Dictionary = Kit.Appearance.defaults("plank")[0]
	plank.scale = Vector3(2, 3, 4)
	plank.basis = Basis.from_scale(Vector3.ONE * 7)
	check(Kit.transform(plank).basis.get_scale().is_equal_approx(Vector3.ONE), "Component editing cannot widen the reference plank")
	var edited := 0
	for kind in Kit.Appearance.buildings() + ["platform_2m", "stairs_1m"]:
		var asset := (load("res://data/settlement/%s.tscn" % kind) as PackedScene).instantiate() as Node3D
		for mesh: MeshInstance3D in asset.find_children("*", "MeshInstance3D", true, false):
			if not mesh.has_meta("timber_stock"): continue
			edited += 1
			var pose := mesh.transform
			var parent := mesh.get_parent() as Node3D
			while parent != asset:
				pose = parent.transform * pose
				parent = parent.get_parent() as Node3D
			check(pose.basis.get_scale().is_equal_approx(Vector3.ONE), kind + "/" + str(mesh.name) + " has no stock scale")
			var expected_vertices := 0
			for source: Dictionary in Timber.sources(mesh.get_meta("timber_stock")):
				for surface in source.mesh.get_surface_count():
					var arrays: Array = source.mesh.surface_get_arrays(surface)
					expected_vertices += arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()
			var actual_vertices := 0
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				actual_vertices += arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()
			check(actual_vertices == expected_vertices * int(mesh.get_meta("timber_count")), "Construction contains complete copies of stock meshes")
		asset.free()
	check(edited > 100, "Shared stock is used throughout the construction library")
	for kind in ["well", "waterworks", "sawmill"]:
		var asset := Assets.create(kind)
		for tier in [1, 2, 3, 1]:
			if kind == "sawmill": preload("res://scripts/settlement/sawmill_view.gd").sync(asset, tier)
			else: preload("res://scripts/settlement/well_view.gd").sync(asset, tier, 1, 3, kind == "waterworks")
			for mesh: MeshInstance3D in asset.find_children("*", "MeshInstance3D", true, false):
				if not mesh.has_meta("timber_stock"): continue
				var pose := mesh.transform
				var parent := mesh.get_parent() as Node3D
				while parent != asset:
					pose = parent.transform * pose
					parent = parent.get_parent() as Node3D
				check(pose.basis.get_scale().is_equal_approx(Vector3.ONE), "Production tiers retain physical timber dimensions")
		asset.free()
	for kind in ["stairs", "platform"]:
		var asset := Assets.create(kind)
		for height in [1, 2, 1]:
			if kind == "stairs": Variants.stairs(asset, height)
			else: preload("res://scripts/settlement/platform_tiers.gd").sync(asset, height)
			check(asset.scale.is_equal_approx(Vector3.ONE), "Height variant never resizes a placed " + kind)
			if kind == "stairs": check(is_equal_approx(asset.get_node("UpperEntrance").position.y, height), "Ladder socket matches the authored rise")
		asset.free()
	var world := preload("res://scripts/settlement/world_model.gd").new()
	for x in range(-4, 5):
		for z in range(-4, 5): world.ground[Vector3i(x, 0, z)] = true
	world.buildings[Vector3i.ZERO] = {"kind": "house", "direction": 1, "placement_offset": Vector3.ZERO}
	world.rebuild_navigation()
	var view := preload("res://scripts/settlement/world_view.gd").new()
	root.add_child(view)
	view.setup(world)
	var lower: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	var facade: Transform3D = lower.get_node("PlasterWall").transform
	var original_pose: Transform3D = lower.transform
	world.buildings[Vector3i(0, 2, 0)] = {"kind": "house", "direction": 0, "placement_offset": Vector3.ZERO}
	world.buildings[Vector3i(2, 0, 0)] = {"kind": "house", "direction": 1, "placement_offset": Vector3.ZERO}
	world.rebuild_navigation()
	view.sync(world, 0, -1)
	check(lower.transform.is_equal_approx(original_pose) and lower.get_node("PlasterWall").transform.is_equal_approx(facade), "Vertical and side neighbours preserve the authored shell and rotation")
	check(not lower.has_node("JoinedWalls"), "Side neighbours do not replace the placed facade")
	var visible_caps := 0
	for cap in lower.get_node("Roof").get_children(): visible_caps += int(cap.visible)
	check(visible_caps == 0, "Completed upper neighbour removes only the covered roof")
	check(view.entity_views["building:%s" % Vector3i(0, 2, 0)].get_node("Floor").visible, "Upper neighbour retains its floor finish")
	world.buildings.erase(Vector3i(0, 2, 0))
	world.rebuild_navigation()
	view.sync(world, 0, -1)
	visible_caps = 0
	for cap in lower.get_node("Roof").get_children(): visible_caps += int(cap.visible)
	check(visible_caps == 4, "Roof returns after removing the upper neighbour")
	view.free()
	var workshop := preload("res://scenes/settlement/StructureWorkshop.tscn").instantiate()
	workshop.restore_last = false
	root.add_child(workshop)
	await process_frame
	var editor = workshop.pieces
	editor.activate()
	editor.parts = [group]
	editor.selected = 0
	editor.selecting = true
	workshop._refresh()
	editor.gizmo.set_mode("size")
	check(editor.gizmo.mode == "move" and editor.gizmo.handles().all(func(handle): return handle.kind == "move"), "Building instances expose no resize handles")
	check(not editor.scale_spins[0].editable and editor.gizmo.mode_buttons[1].disabled and editor.gizmo.mode_buttons[2].disabled, "Scale, Size and Face controls are locked for buildings")
	workshop.free()
	if failures == 0: print("PASS: %d timber stock, authored variants and placement scale checks" % checks)
	quit(int(failures > 0))
