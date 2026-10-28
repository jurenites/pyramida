extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Variation = Assets.Variation
const Model = preload("res://scripts/settlement/world_model.gd")
const View = preload("res://scripts/settlement/world_view.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: " + message)

func geometry(node: Node3D) -> Array:
	var result: Array = []
	for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null: continue
		for surface in part.mesh.get_surface_count():
			result.append(part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	return result

func run() -> void:
	Assets.Appearance.directory = "/tmp/pyramida-variation-no-overrides"
	for kind in ["house", "road", "platform", "stairs", "well", "log_shed", "stone_storage", "sawmill"]:
		var node := Assets.create(kind)
		var source := Assets.create(kind)
		var original := geometry(source)
		Variation.apply(node, kind, Vector3i(-6, 2, 8), 9182)
		var first := geometry(node)
		check(first != original, kind + " has individual geometry")
		check(geometry(source) == original, kind + " leaves shared source meshes unchanged")
		var cached: Array = []
		var bounded := true
		var level := true
		var rigid := true
		for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if not part.has_meta("building_variation"): continue
			cached.append(part.mesh)
			var data: Dictionary = part.get_meta("building_variation")
			var pose := Variation._pose(node, part)
			for surface in part.mesh.get_surface_count():
				var before: PackedVector3Array = data.source.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				var after: PackedVector3Array = part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for index in before.size():
					var a := pose * before[index]
					var b := pose * after[index]
					bounded = bounded and absf(a.x - b.x) <= 0.10001 and absf(a.z - b.z) <= 0.10001
					level = level and absf(a.y - b.y) < 0.00001
					if part.has_meta("timber_stock"):
						rigid = rigid and absf(a.distance_to(pose * before[0]) - b.distance_to(pose * after[0])) < 0.0001
		check(bounded and level and rigid, kind + " keeps bounded corners, level floors and rigid timber")
		Variation.apply(node, kind, Vector3i(-6, 2, 8), 9182)
		check(geometry(node) == first, kind + " repeated sync does not drift")
		var current: Array = []
		for part: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			if part.has_meta("building_variation"): current.append(part.mesh)
		check(current == cached, kind + " repeated sync reuses generated meshes")
		Variation.apply(node, kind, Vector3i(-4, 2, 8), 9182)
		check(geometry(node) != first, kind + " neighbouring instances differ")
		Variation.apply(node, kind, Vector3i(-6, 2, 8), 9182)
		check(geometry(node) == first, kind + " cursor return reconstructs identical geometry")
		Variation.apply(source, kind, Vector3i(-6, 2, 8), 9182)
		check(geometry(source) == first, kind + " new instance reconstructs the same identity")
		Variation.apply(source, kind, Vector3i(-6, 3, 8), 9182)
		check(geometry(source) != first, kind + " floors have distinct identities")
		Variation.apply(source, kind, Vector3i(-6, 2, 8), 9183)
		check(geometry(source) != first, kind + " world seed affects identity")
		if kind == "platform":
			preload("res://scripts/settlement/platform_tiers.gd").sync(node, 2)
			Variation.apply(node, kind, Vector3i(-6, 2, 8), 9182)
			var upgraded := Assets.create("platform")
			preload("res://scripts/settlement/platform_tiers.gd").sync(upgraded, 2)
			Variation.apply(upgraded, kind, Vector3i(-6, 2, 8), 9182)
			check(geometry(node) == geometry(upgraded), "Tier upgrades use fresh source geometry without accumulating distortion")
			upgraded.free()
		node.free()
		source.free()
	var model := Model.new()
	model.setup()
	model.trees.clear()
	model.deposits.clear()
	check(model.request_build("house", Vector3i.ZERO), "House plan accepted")
	var plan: Dictionary = model.plans[model.next_plan_id - 1]
	var view := View.new()
	root.add_child(view)
	view.setup(model)
	var site: Node3D = view.entity_views["plan:%s" % plan.id]
	var site_wall: Mesh = site.get_node("BackWall").mesh
	var preview := Assets.create("house")
	Variation.apply(preview, "house", Vector3i.ZERO, model.world_seed)
	check(geometry(preview)[0] == geometry(site)[0], "Preview and construction use identical corners")
	model._complete_plan(plan)
	view.sync(model, 0, -1)
	var completed: Node3D = view.entity_views["building:%s" % Vector3i.ZERO]
	check(completed.get_node("BackWall").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == site_wall.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Completion retains the constructed shape")
	check(completed.get_meta("collider").get_child(0).shape.size == Assets.Appearance.Catalog.DEFINITIONS.house.size, "Collision footprint remains authored")
	check(completed.get_node("AccessFront").transform == preview.get_node("AccessFront").transform, "Entrance marker remains exact")
	var saved := Model.new()
	check(saved.restore(JSON.parse_string(JSON.stringify(model.snapshot()))), "World round trips through save codec")
	var restored := Assets.create("house")
	Variation.apply(restored, "house", Vector3i.ZERO, saved.world_seed)
	check(geometry(restored) == geometry(preview), "Saved world reconstructs identical variation")
	preview.free()
	restored.free()
	view.free()
	if failures.is_empty(): print("PASS: %d building variation checks" % checks)
	quit(0 if failures.is_empty() else 1)
