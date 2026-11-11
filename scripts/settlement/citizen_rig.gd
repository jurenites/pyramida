extends RefCounted
## Shared joints for the joined body/clothing surface. No overlapping clothing shells.
const NAMES := ["Root", "Torso", "Head", "LeftArm", "LeftElbow", "RightArm", "RightElbow", "LeftLeg", "LeftKnee", "RightLeg", "RightKnee"]
const PARENTS := [-1, 0, 1, 1, 3, 1, 5, 0, 7, 0, 9]
const CENTRES := [Vector3.ZERO, Vector3(0, 0.48, 0), Vector3(0, 0.845, 0),
	Vector3(-0.22, 0.64, 0), Vector3(-0.295, 0.515, 0), Vector3(0.22, 0.64, 0), Vector3(0.295, 0.515, 0),
	Vector3(-0.11, 0.29, 0), Vector3(-0.11, 0.185, 0), Vector3(0.11, 0.29, 0), Vector3(0.11, 0.185, 0)]
const CONTROLS := {2: "Head", 3: "LeftArm", 4: "LeftArm/Elbow", 5: "RightArm", 6: "RightArm/Elbow", 7: "LeftLeg", 8: "LeftLeg/Knee", 9: "RightLeg", 10: "RightLeg/Knee"}

static func populate(root: Node3D, variant: int) -> void:
	populate_mesh(root, load("res://data/settlement/citizens/body_%d.res" % variant), CENTRES)

static func populate_mesh(root: Node3D, mesh: Mesh, centres: Array) -> void:
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	root.add_child(skeleton)
	var skin := Skin.new()
	for index in NAMES.size():
		skeleton.add_bone(NAMES[index])
		skeleton.set_bone_parent(index, PARENTS[index])
		var centre: Vector3 = centres[index] - (centres[PARENTS[index]] if PARENTS[index] >= 0 else Vector3.ZERO)
		skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, centre))
		skeleton.reset_bone_pose(index)
		skin.add_bind(index, Transform3D(Basis.IDENTITY, -centres[index]))
	for index in CONTROLS:
		var path: String = CONTROLS[index]
		var node := Node3D.new()
		node.name = path.get_file()
		var parent := root if not path.contains("/") else root.get_node(path.get_base_dir()) as Node3D
		parent.add_child(node)
		node.position = centres[index] - (centres[PARENTS[index]] if parent != root else Vector3.ZERO)
	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	surface.mesh = mesh
	surface.skin = skin
	surface.skeleton = NodePath("../Skeleton3D")
	surface.set_meta("citizen_cloth_surface", 1)
	# Conservative animated bound for culling and the CPU picking broad phase.
	surface.custom_aabb = AABB(Vector3(-0.65, -0.2, -0.65), Vector3(1.3, 1.4, 1.3))
	root.add_child(surface)
	var cargo := Node3D.new()
	cargo.name = "CargoSocket"
	cargo.position = Vector3(0, 0.50, -0.37)
	root.add_child(cargo)

static func sync(root: Node3D, skeleton: Skeleton3D) -> bool:
	var changed := false
	for index in CONTROLS:
		var node: Node3D = root.get_node(CONTROLS[index])
		if not skeleton.get_bone_pose_rotation(index).is_equal_approx(node.quaternion):
			skeleton.set_bone_pose_rotation(index, node.quaternion)
			changed = true
	# Keep the source and the occlusion mask on the same rendered pose.
	if changed: skeleton.force_update_all_bone_transforms()
	return changed

static func posed_faces(part: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	# CPU skinning is only used after a ray enters the character's broad bounds.
	# No GPU readback or rendering stall for hover/click picking.
	var transforms: Array[Transform3D] = []
	for bind in part.skin.get_bind_count():
		transforms.append(skeleton.get_bone_global_pose(part.skin.get_bind_bone(bind)) * part.skin.get_bind_pose(bind))
	var faces := PackedVector3Array()
	for surface in part.mesh.get_surface_count():
		var arrays := part.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var posed := PackedVector3Array()
		posed.resize(vertices.size())
		for vertex in vertices.size():
			var position := Vector3.ZERO
			for influence in 4:
				var slot := vertex * 4 + influence
				if weights[slot] > 0.0:
					position += (transforms[bones[slot]] * vertices[vertex]) * weights[slot]
			posed[vertex] = position
		for index in arrays[Mesh.ARRAY_INDEX]: faces.append(posed[index])
	return faces
