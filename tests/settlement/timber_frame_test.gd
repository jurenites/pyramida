extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Frame = preload("res://scripts/settlement/timber_frame.gd")
const Timber = preload("res://scripts/settlement/timber_kit.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for kind in ["house", "log_shed", "platform", "stairs"]:
		var node: Node3D = Assets.create(kind)
		root.add_child(node)
		var slots := Frame.slots(node)
		check(not slots.is_empty(), kind + " exposes authored full-size timber")
		for slot in slots:
			var mesh: MeshInstance3D = slot.mesh
			var source: Dictionary = Timber.sources("log")[0]
			var expected: PackedVector3Array = source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var actual: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var offset: int = maxi(0, slot.index) * expected.size()
			var identical := true
			for index in expected.size():
				var incoming: Vector3 = slot.pose * Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)) * source.pose * expected[index]
				var authored: Vector3 = Frame.relative(node, mesh) * actual[offset + index]
				if incoming.distance_to(authored) > 0.0001: identical = false
			check(identical, kind + " replacement preserves every authored bark vertex")
		var slot := slots[0]
		var original: Mesh = slot.mesh.mesh
		Frame.mask(slot)
		if slot.index == -1:
			check(slot.mesh.layers == 0, "Individual authored log is hidden beneath the arriving piece")
		else:
			var triangles: int = original.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()
			var remaining: int = slot.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()
			check(remaining == triangles - Timber.sources("log")[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size(), "Batch removes exactly one stock piece's triangles")
			check(slot.mesh.mesh.surface_get_material(0) == original.surface_get_material(0), "Unchanged frame retains its material")
		Frame.mask(slot)
		check(Frame.slots(node).size() == slots.size(), "Repeated sync keeps a stable slot map")
		node.free()
	if failures.is_empty(): print("PASS: %d authored frame geometry and replacement checks" % checks)
	else:
		for message in failures: printerr("FAIL: " + message)
	quit(int(not failures.is_empty()))
