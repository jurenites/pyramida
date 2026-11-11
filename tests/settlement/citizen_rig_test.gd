extends SceneTree
const Assets = preload("res://scripts/settlement/asset_library.gd")
const Rig = preload("res://scripts/settlement/citizen_rig.gd")
const Picker = preload("res://scripts/settlement/citizen_skin_picker.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value and message not in failures: failures.append(message)

func _initialize() -> void:
	for variant in 4:
		var body := Assets.create("citizen_%d" % variant)
		root.add_child(body)
		var visuals := body.find_children("*", "MeshInstance3D", true, false)
		check(visuals.size() == 1, "One outer body/clothing surface replaces overlapping shells")
		var part: MeshInstance3D = visuals[0]
		var rig: Skeleton3D = part.get_node(part.skeleton)
		check(rig.get_bone_count() == 11 and part.skin.get_bind_count() == 11, "Every outfit has the full shared rig")
		var skin_vertices := {}
		var shared_boundary := 0
		for surface in part.mesh.get_surface_count():
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			for vertex in vertices.size():
				var sum := 0.0
				for influence in 4:
					var index := vertex * 4 + influence
					sum += weights[index]
					check(bones[index] >= 0 and bones[index] < 11 and weights[index] >= 0, "Skin influence stays on a valid bone")
				# ArrayMesh stores influences at 16-bit precision: allow one
				# quantization step per influence, not an unnormalized binding.
				check(absf(sum - 1.0) <= 4.0 / 65535.0, "Skin weights are normalized")
				var key := vertices[vertex].snapped(Vector3.ONE * 0.000001)
				var binding := [bones.slice(vertex * 4, vertex * 4 + 4), weights.slice(vertex * 4, vertex * 4 + 4)]
				if surface == 0: skin_vertices[key] = binding
				elif surface == 1 and skin_vertices.has(key):
					shared_boundary += 1
					check(skin_vertices[key] == binding, "Cloth and skin share identical deformation along their seam")
		check(shared_boundary > 20, "Clothing joins skin along real mesh boundaries")
		var picker = Picker.for_mesh(part.mesh)
		for pose in [0.0, 0.8, 1.82]:
			rig.set_bone_pose_rotation(7, Quaternion(Vector3.RIGHT, pose))
			rig.set_bone_pose_rotation(8, Quaternion(Vector3.RIGHT, -pose * 0.9))
			rig.set_bone_pose_rotation(3, Quaternion(Vector3.FORWARD, pose * 0.5))
			rig.force_update_all_bone_transforms()
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = Rig.posed_faces(part, rig)
			var reference := ArrayMesh.new()
			reference.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var exact := reference.generate_triangle_mesh()
			var transforms: Array[Transform3D] = []
			for bind in part.skin.get_bind_count():
				transforms.append(rig.get_bone_global_pose(part.skin.get_bind_bone(bind)) * part.skin.get_bind_pose(bind))
			for yaw in [0.0, PI * 0.5, PI]:
				var turn := Basis(Vector3.UP, yaw)
				for x in [-0.5, -0.3, 0.0, 0.3, 0.5]:
					for y in [0.1, 0.3, 0.55, 0.845]:
						var origin := turn * Vector3(x, y, 3)
						var direction := turn * Vector3.FORWARD
						var hit := exact.intersect_ray(origin, direction)
						var distance: float = picker.distance(origin, direction, transforms)
						check(hit.is_empty() == not is_finite(distance), "Posed BVH matches full-mesh ray hits and misses")
						if not hit.is_empty() and is_finite(distance):
							check(absf(origin.distance_to(hit.position) - distance) < 0.0001, "Posed BVH preserves exact surface distance")
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		check(document.append_from_file("res://data/settlement/citizen_%d.glb" % variant, state) == OK, "Editable rigged GLB parses")
		var imported := document.generate_scene(state)
		check(imported.find_children("*", "Skeleton3D", true, false).size() == 1, "GLB export retains the skeleton")
		imported.free()
		body.free()
	for failure in failures: printerr("FAIL: " + failure)
	if failures.is_empty(): print("PASS: four joined surfaces, continuous clothing seams, rigged GLBs and 720 posed picking comparisons")
	quit(int(not failures.is_empty()))
