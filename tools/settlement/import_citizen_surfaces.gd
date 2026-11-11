extends SceneTree
## Import the sculpt_citizens.py output, then use generate_assets.gd for TSCN/GLB.
const SKIN := [Color("66513a"), Color("78583f"), Color("543b2c"), Color("674938")]
const CLOTH := [Color("518e9a"), Color("cc765c"), Color("d3ad53"), Color("869c70")]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var source: String = args[0] if not args.is_empty() else "/tmp/pyramida-citizens"
	DirAccess.make_dir_recursive_absolute("res://data/settlement/citizens")
	for variant in 4:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("citizen_%d.json" % variant)))
		var mesh := ArrayMesh.new()
		for surface in 3:
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			var indices := PackedInt32Array()
			var remap := {}
			for raw in data.surfaces[surface]:
				var index := int(raw)
				if not remap.has(index):
					remap[index] = vertices.size()
					var p: Array = data.vertices[index]
					var n: Array = data.normals[index]
					vertices.append(Vector3(p[0], p[1], p[2]))
					normals.append(Vector3(n[0], n[1], n[2]))
					for bone in data.bones[index]: bones.append(int(bone))
					for weight in data.weights[index]: weights.append(float(weight))
				indices.append(remap[index])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			arrays[Mesh.ARRAY_INDEX] = indices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material := StandardMaterial3D.new()
			material.albedo_color = [SKIN[variant], CLOTH[variant], Color("211c18")][surface]
			material.roughness = 0.95
			mesh.surface_set_material(surface, material)
		assert(ResourceSaver.save(mesh, "res://data/settlement/citizens/body_%d.res" % variant) == OK)
	print("PASS: imported four joined citizen surfaces with shared body/clothing weights")
	quit()
