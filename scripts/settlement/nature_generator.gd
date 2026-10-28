extends RefCounted
## Runtime geometry from bounded, seeded growth; no finite catalogue of tree shapes.
const DEFAULT_PROFILE = preload("res://data/settlement/nature_profile.tres")
const Illustration = preload("res://scripts/settlement/illustration_style.gd")
const Timber = preload("res://scripts/settlement/timber_kit.gd")
const STUMP := 0.18
const LOG_LENGTH := 0.88
const BARK := Color("986a4b")
const CUT := Color("d1a775")
const LEAVES := Color("7e985b")
static var materials: Dictionary = {}

static func skeleton(seed_value: int, palm: bool, profile: Resource = DEFAULT_PROFILE) -> PackedVector3Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var height := LOG_LENGTH * rng.randf_range(1.0 - profile.height_variation, 1.0 + profile.height_variation)
	var lean := deg_to_rad(clampf(profile.palm_lean if palm else profile.trunk_lean, 0, 40))
	var bend := deg_to_rad(clampf(profile.joint_bend, 0, 25))
	var heading := rng.randf_range(0, TAU)
	var direction := Vector3.UP
	var points := PackedVector3Array([Vector3(0, STUMP, 0)])
	# Two connected pieces per log give the trunk a gentle changing direction.
	for index in 6:
		heading += rng.randf_range(-0.65, 0.65)
		var angle := rng.randf_range(lean * 0.3, lean)
		var target := Vector3(sin(angle) * cos(heading), cos(angle), sin(angle) * sin(heading))
		var turn := direction.angle_to(target)
		direction = direction.slerp(target, minf(1, bend / maxf(turn, 0.00001))).normalized()
		points.append(points[-1] + direction * height * 0.5)
	return points

static func populate(root: Node3D, kind: String, seed_value: int, profile: Resource = DEFAULT_PROFILE) -> void:
	# Leave colliders and gameplay anchors attached to the same entity.
	for child in root.get_children():
		if child is MeshInstance3D or str(child.name).begins_with("Segment"): child.free()
	var palm := kind == "palm"
	var dead := kind == "dead"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 79
	var points := skeleton(seed_value, palm, profile)
	var radius := rng.randf_range(0.15, 0.21) * 0.75 if palm else Timber.LOG_DIAMETER * 0.5 * rng.randf_range(0.97, 1.03)
	var trunk_taper := 0.16 if palm else 0.02
	var bark := BARK.darkened(0.12) if dead else BARK
	root.set_meta("nature_skeleton", points)
	root.set_meta("nature_seed", seed_value)
	tube(root, "Stump", PackedVector3Array([Vector3(0, -0.04, 0), points[0]]), radius, radius, bark)
	cut(root, "StumpCut", points[0], radius)
	for index in 3:
		var segment := Node3D.new()
		segment.name = "Segment%d" % (index + 1)
		root.add_child(segment)
		var bottom := radius * (1.0 - index * trunk_taper)
		var top := radius * (1.0 - (index + 1) * trunk_taper)
		tube(segment, "Trunk", points.slice(index * 2, index * 2 + 3), bottom, top, bark)
		cut(segment, "CutFace", points[index * 2 + 2], top)
		if index == 1 and not palm:
			branch(segment, "BrokenBranch", points[3], points[3] + Vector3(-0.24, 0.23, 0.12), 0.075, 0.035, bark)
		if index != 2: continue
		var crown := Node3D.new()
		crown.name = "Crown"
		if not dead: segment.add_child(crown)
		if palm:
			palm_crown(crown, points[-1], rng, profile)
		else:
			var phase := rng.randf_range(0, TAU)
			for fork in 3:
				var azimuth := phase + fork * TAU / 3.0 + rng.randf_range(-0.2, 0.2)
				var low := clampf(profile.branch_angle_min, 5, 75)
				var high := clampf(profile.branch_angle_max, low, 75)
				var angle := deg_to_rad(rng.randf_range(low, high))
				var direction := Vector3(cos(azimuth) * sin(angle), cos(angle), sin(azimuth) * sin(angle))
				var start := points[5].lerp(points[6], fork * 0.2)
				var tip := start + direction * rng.randf_range(0.7, 0.95)
				branch(segment, "Fork", start, tip, 0.08, 0.025, bark)
				if not dead:
					var spread := rng.randf_range(1.0 - profile.crown_variation, 1.0 + profile.crown_variation)
					foliage(crown, tip, Vector3(1.1, 0.95, 1.05) * spread)
		if dead: crown.free()
	Illustration.apply(root)
	if root.has_meta("log_count"): root.remove_meta("log_count")

static func material(colour: Color) -> Material:
	if not materials.has(colour):
		var value := StandardMaterial3D.new()
		value.albedo_color = colour
		value.roughness = 1.0
		value.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials[colour] = value
	return materials[colour]

static func mesh(parent: Node3D, name_: String, shape: Mesh, colour: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = shape
	node.material_override = material(colour)
	parent.add_child(node, true)
	return node

static func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func tube(parent: Node3D, name_: String, points: PackedVector3Array, bottom: float, top: float, colour: Color) -> void:
	# Horizontal rings share exact vertices at log boundaries, including bent ones.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for ring in range(points.size() - 1):
		var r0 := lerpf(bottom, top, float(ring) / (points.size() - 1))
		var r1 := lerpf(bottom, top, float(ring + 1) / (points.size() - 1))
		for side in 7:
			var a := Vector3(cos(side * TAU / 7), 0, sin(side * TAU / 7))
			var b := Vector3(cos((side + 1) * TAU / 7), 0, sin((side + 1) * TAU / 7))
			triangle(st, points[ring] + a * r0, points[ring] + b * r0, points[ring + 1] + b * r1)
			triangle(st, points[ring] + a * r0, points[ring + 1] + b * r1, points[ring + 1] + a * r1)
	st.generate_normals()
	mesh(parent, name_, st.commit(), colour)

static func cut(parent: Node3D, name_: String, point: Vector3, radius: float) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = 0.008
	shape.radial_segments = 7
	mesh(parent, name_, shape, CUT).position = point + Vector3.UP * 0.003

static func branch(parent: Node3D, name_: String, start: Vector3, finish: Vector3, bottom: float, top: float, colour: Color) -> void:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = start.distance_to(finish)
	shape.radial_segments = 7
	var node := mesh(parent, name_, shape, colour)
	node.position = (start + finish) * 0.5
	node.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())

static func foliage(parent: Node3D, centre: Vector3, size: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 7
	sphere.rings = 3
	var node := mesh(parent, "Leaves", sphere, LEAVES)
	node.position = centre
	node.scale = size

static func palm_crown(parent: Node3D, centre: Vector3, rng: RandomNumberGenerator, profile: Resource) -> void:
	var count := rng.randi_range(8, 11)
	var phase := rng.randf_range(0, TAU)
	for index in count:
		var angle := phase + index * TAU / count + rng.randf_range(-0.12, 0.12)
		var length := 1.65 * rng.randf_range(1.0 - profile.crown_variation, 1.0 + profile.crown_variation)
		var droop := rng.randf_range(0.35, 0.65)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-sin(angle), 0, cos(angle))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
		for segment in 5:
			var t := segment / 5.0
			var u := (segment + 1) / 5.0
			var a := centre + direction * t * length + Vector3.UP * (sin(t * PI) * 0.38 - t * t * droop)
			var b := centre + direction * u * length + Vector3.UP * (sin(u * PI) * 0.38 - u * u * droop)
			var wa := sin(t * PI) * 0.23 + 0.015
			var wb := sin(u * PI) * 0.23
			triangle(st, a - side * wa, b - side * wb, b + side * wb)
			triangle(st, a - side * wa, b + side * wb, a + side * wa)
		st.generate_normals()
		mesh(parent, "Frond", st.commit(), LEAVES.darkened((index % 2) * 0.12))
