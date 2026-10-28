extends RefCounted
## Three removable trunk lengths with a plain, stock-width ground entry.
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const TRUNK_RADIUS := Timber.LOG_DIAMETER * 0.5
const STUMP_HEIGHT := 0.18
const LOG_HEIGHT := 0.88
const BARK := Color("986a4b")
const CUT := Color("d1a775")
const LEAVES := Color("7e985b")

static func build(kit, parent: Node3D, dead := false) -> void:
	var bark := BARK.darkened(0.12) if dead else BARK
	kit.cylinder(parent, "Stump", Vector3(0, 0.07, 0), TRUNK_RADIUS, STUMP_HEIGHT + 0.04, bark, TRUNK_RADIUS, 7)
	kit.cylinder(parent, "StumpCut", Vector3(0, STUMP_HEIGHT + 0.002, 0), TRUNK_RADIUS, 0.008, CUT, -1, 7)
	var joints := [Vector3(0, STUMP_HEIGHT, 0), Vector3(0.035, STUMP_HEIGHT + LOG_HEIGHT, 0.015),
		Vector3(-0.035, STUMP_HEIGHT + LOG_HEIGHT * 2, -0.02), Vector3(0.025, STUMP_HEIGHT + LOG_HEIGHT * 3, 0)]
	for index in 3:
		var segment := Node3D.new()
		segment.name = "Segment%d" % (index + 1)
		parent.add_child(segment)
		var radius := TRUNK_RADIUS * (1.0 - index * 0.02)
		branch(kit, segment, "Trunk", joints[index], joints[index + 1], radius, radius - TRUNK_RADIUS * 0.02, bark)
		kit.cylinder(segment, "CutFace", joints[index + 1] + Vector3.UP * 0.003, radius - TRUNK_RADIUS * 0.02, 0.012, CUT, -1, 7)
		if index == 1:
			branch(kit, segment, "BrokenBranch", Vector3(0, 1.48, 0), Vector3(-0.33, 1.71, 0.11), 0.09, 0.045, bark)
		if index == 2:
			for fork in 3:
				var angle := fork * TAU / 3.0 + 0.4
				var start := Vector3(0, 2.17 + fork * 0.12, 0)
				var elbow := Vector3(cos(angle) * 0.37, 2.55 + fork * 0.06, sin(angle) * 0.37)
				var tip := Vector3(cos(angle) * 0.56, 2.98 + fork * 0.06, sin(angle) * 0.56)
				branch(kit, segment, "Fork", start, elbow, 0.095, 0.068, bark)
				branch(kit, segment, "Twig", elbow, tip, 0.068, 0.025, bark)
			if not dead:
				var crown := Node3D.new()
				crown.name = "Crown"
				segment.add_child(crown)
				for spec in [Vector3(-0.40, 2.92, 0.12), Vector3(0.38, 3.00, 0.12), Vector3(0, 3.24, -0.23)]:
					kit.foliage(crown, "Leaves", spec, Vector3(1.1, 0.95, 1.05), LEAVES)
				for mesh in crown.get_children():
					var material := StandardMaterial3D.new()
					material.albedo_color = LEAVES
					material.roughness = 1.0
					material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					mesh.material_override = material
	var access := Marker3D.new()
	access.name = "AccessFront"
	access.position = Vector3(0, 0, 0.7)
	parent.add_child(access)

static func branch(kit, parent: Node3D, name_: String, start: Vector3, finish: Vector3, bottom: float, top: float, colour: Color) -> void:
	var mesh: MeshInstance3D = kit.cylinder(parent, name_, (start + finish) * 0.5, bottom, start.distance_to(finish), colour, top, 7)
	mesh.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
