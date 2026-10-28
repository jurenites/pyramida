extends RefCounted
## Disposable batched stems/leaves: grid anchors, soft curves and sparse new tips.
const Vines = preload("res://scripts/settlement/vines.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")

static func sync(node: Node3D, model, root: Vector3i) -> void:
	var plant: Dictionary = model.vines[root]
	var stamp := [plant.nodes.duplicate(), int(float(plant.health) * 12), model.navigation.revision, plant.get("placement_offset", Vector3.ZERO)]
	if node.get_meta("vine_stamp", []) == stamp: return
	node.set_meta("vine_stamp", stamp)
	if node.has_node("Growth"): node.get_node("Growth").free()
	var growth := Node3D.new()
	growth.name = "Growth"
	node.add_child(growth)
	var faces := Vines.surfaces(model, root)
	var rng := RandomNumberGenerator.new()
	rng.seed = Vines.Random.world_coordinate_seed(root.x, root.z, model.world_seed, 917)
	var stems: Array[Transform3D] = []
	var leaves: Array = [[], [], []]
	var origin := Nav.point(root) + Vector3(plant.get("placement_offset", Vector3.ZERO))
	var health := float(stamp[1]) / 12.0
	var flow: Array[int] = []
	flow.resize(plant.nodes.size())
	flow.fill(1)
	for i in range(plant.nodes.size() - 1, -1, -1):
		if plant.parents[i] >= 0: flow[plant.parents[i]] += flow[i]
	# A planted cutting is visible before it has earned its first wall segment.
	branch(stems, leaves, Vector3(0, 0.04, 0), Vector3(0, 0.32, 0), Vector3.BACK, rng, health, 0.65)
	for i in plant.nodes.size():
		var key: Vector3i = plant.nodes[i]
		if not faces.has(key): continue
		var parent: int = plant.parents[i]
		if parent >= 0 and not faces.has(plant.nodes[parent]): continue
		var start: Vector3 = faces[plant.nodes[parent]].point - origin if parent >= 0 else Vector3(0, 0.12, 0)
		var finish: Vector3 = faces[key].point - origin
		start.y += 0.10
		finish.y += 0.10
		var thickness := clampf(0.55 + sqrt(float(flow[i])) * 0.23, 0.65, 1.9)
		branch(stems, leaves, start, finish, faces[key].normal, rng, health, 0.72 if flow[i] == 1 else 1.0, thickness)
	var wood := CylinderMesh.new()
	wood.top_radius = 0.7
	wood.bottom_radius = 1.0
	wood.height = 1.0
	wood.radial_segments = 6
	batch(growth, wood, stems, Color("826c46").lerp(Color("62704a"), health), "Stems")
	var leaf := SphereMesh.new()
	leaf.radius = 1.0
	leaf.height = 2.0
	leaf.radial_segments = 8
	leaf.rings = 4
	var palette := [Color("557650"), Color("75955e"), Color("92a66d")]
	for i in 3:
		batch(growth, leaf, leaves[i], Color("a78b58").lerp(palette[i], health), "Leaves%d" % i)

static func branch(stems: Array[Transform3D], leaves: Array, start: Vector3, finish: Vector3, normal: Vector3, rng: RandomNumberGenerator, health: float, size: float, thickness := 1.0) -> void:
	var tangent := normal.cross(Vector3.UP)
	var bend := rng.randf_range(-0.18, 0.18)
	var last := start
	for step in range(1, 7):
		var t := float(step) / 6.0
		var point := start.lerp(finish, t) + (tangent * bend + normal * 0.055) * sin(t * PI)
		var delta := point - last
		if delta.length() > 0.001:
			var radius := 0.021 * size * thickness
			var basis := Basis(Quaternion(Vector3.UP, delta.normalized())) * Basis.from_scale(Vector3(radius, delta.length(), radius))
			stems.append(Transform3D(basis, (last + point) * 0.5))
		last = point
		# Keep RNG consumption stable as leaves dry, so surviving leaves never jump.
		for side in [-1, 1]:
			var angle := rng.randf_range(-0.6, 0.6)
			var scale_: float = rng.randf_range(0.09, 0.19) * size
			var slot := rng.randi_range(0, 2)
			var retention := rng.randf()
			var centre: Vector3 = point + tangent * side * scale_ * rng.randf_range(0.5, 1.2) + normal * 0.07
			var basis := Basis.looking_at(normal, Vector3.UP).rotated(normal, angle + side * 0.5)
			basis = basis * Basis.from_scale(Vector3(scale_, scale_ * 1.35, scale_ * 0.36))
			if health > 0.05 and retention < 0.15 + health * 0.75:
				leaves[slot].append(Transform3D(basis, centre))

static func batch(parent: Node3D, mesh: Mesh, transforms: Array, colour: Color, title: String) -> void:
	if transforms.is_empty(): return
	var node := MultiMeshInstance3D.new()
	node.name = title
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size(): multi.set_instance_transform(i, transforms[i])
	node.multimesh = multi
	parent.add_child(node)
