extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Roof = preload("res://scripts/settlement/house_roofs.gd")
const Shed = preload("res://scripts/settlement/shed_roof.gd")
const Fit = preload("res://scripts/settlement/roof_timber.gd")
const Model = preload("res://scripts/settlement/world_model.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func verify(node: Node3D, ceiling: Callable) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_meta("timber_stock", "") != "log" or not mesh.is_visible_in_tree() or mesh.layers == 0: continue
		check(Fit.excess(mesh.mesh, Roof.pose_in(node, mesh), ceiling) < 0.0001, "Log fits below roof: " + str(mesh.name))
		var bounds: AABB = Roof.pose_in(node, mesh) * mesh.mesh.get_aabb()
		check(bounds.position.y >= -0.0601, "Log stays within authored 6 cm ground seating: " + str(mesh.name) + " " + str(bounds.position.y))
		if mesh.has_meta("roof_original_mesh"):
			var original: Mesh = mesh.get_meta("roof_original_mesh")
			var count: int = mesh.get_meta("timber_count")
			for surface in original.get_surface_count():
				var before: PackedVector3Array = original.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				var after: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				var size: int = before.size() / count
				for log_ in count:
					var offset := after[log_ * size] - before[log_ * size]
					for i in range(log_ * size, (log_ + 1) * size): check((after[i] - before[i]).is_equal_approx(offset), "Whole Log moves rigidly without stretching")
func run() -> void:
	var authored := Assets.Appearance.directory
	for custom in [true, false]:
		Assets.Appearance.directory = authored if custom else "/tmp/pyramida-empty-roof-appearance"
		Assets.Appearance.overrides.clear()
		for direction in 4:
			var model = Model.new(); var views := {}; var rooms: Array = []; var tiles := {}
			for cell: Vector3i in [Vector3i.ZERO, Vector3i(2, 0, 0)]:
				var turn := direction if cell == Vector3i.ZERO else 1
				model.buildings[cell] = {"kind": "house", "direction": turn}
				var node := Assets.create("house"); node.rotation.y = -turn * PI / 2; node.position = Vector3(cell)
				node.set_meta("cell", cell); node.set_meta("asset", "house"); root.add_child(node); views[cell] = node
				Assets.Variation.apply(node, "house", cell, model.world_seed)
				rooms.append({"at": Vector2(cell.x, cell.z), "axis": 1 if turn % 2 == 0 else 0})
				for x in 2:
					for z in 2: tiles[Vector2i(cell.x + x - 1, cell.z + z - 1)] = true
			preload("res://scripts/settlement/house_posts.gd").sync(model, views)
			Roof.sync(model, views)
			var shape := Roof.profile(tiles, rooms)
			for node: Node3D in views.values():
				Assets.Variation.apply(node, "house", node.get_meta("cell"), model.world_seed)
				verify(node, func(at: Vector3):
					var point := node.basis * at + node.position
					return Roof.height_at(Vector2(point.x, point.z), shape) - 0.18)
				var roof := node.get_node("JoinedRoof")
				Roof.sync(model, views)
				check(node.get_node("JoinedRoof") == roof, "Unchanged buildings retain generated roof")
			for node in views.values(): node.free()
		var shed := Assets.create("log_shed"); root.add_child(shed)
		Assets.Variation.apply(shed, "log_shed", Vector3i.ZERO, 17); Shed.sync(shed, 17)
		Assets.Variation.apply(shed, "log_shed", Vector3i.ZERO, 17)
		verify(shed, func(at: Vector3): return Shed.EAVE + 0.5 - at.x - 0.11)
		var mesh: Mesh = shed.get_node("Canopy/GeneratedRoof").mesh
		Shed.sync(shed, 17)
		check(shed.get_node("Canopy/GeneratedRoof").mesh == mesh, "Shed roof does not reshuffle on inventory updates")
		check(shed.get_node("Canopy/GeneratedRoof").get_meta("source_component") == "Canopy/RoofCourse0", "Shed reuses its authored beveled roof component")
		shed.free()
	Assets.Appearance.directory = authored; Assets.Appearance.overrides.clear()
	print("PASS: authored/default Home and Shed, rotated joins, rigid timber clearance, stable roofs" if failures.is_empty() else "FAIL: timber roof clearance")
	quit(0 if failures.is_empty() else 1)
