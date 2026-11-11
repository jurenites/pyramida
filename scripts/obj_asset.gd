class_name ObjAsset
extends RefCounted

## Minimal runtime reader for Blender/Wavefront OBJ geometry. The game owns
## materials and behaviour; the OBJ owns editable vertices and named parts.
static var _object_cache: Dictionary = {}


static func load_objects(asset_path: String) -> Dictionary:
	if _object_cache.has(asset_path):
		return (_object_cache[asset_path] as Dictionary).duplicate()
	var source := FileAccess.open(asset_path, FileAccess.READ)
	if source == null:
		push_error("Unable to open OBJ asset: %s" % asset_path)
		return {}
	var vertices: Array[Vector3] = []
	var triangles_by_object := {}
	var current_object := "default"
	while not source.eof_reached():
		var line := source.get_line().strip_edges()
		if line.begins_with("o ") or line.begins_with("g "):
			current_object = line.substr(2).strip_edges()
			if current_object.is_empty():
				current_object = "default"
		elif line.begins_with("v "):
			var values := line.split(" ", false)
			if values.size() >= 4:
				vertices.append(Vector3(float(values[1]), float(values[2]), float(values[3])))
		elif line.begins_with("f "):
			var values := line.split(" ", false)
			if values.size() < 4:
				continue
			var face_indices: Array[int] = []
			for face_value_index in range(1, values.size()):
				var raw_index := int(str(values[face_value_index]).split("/")[0])
				var vertex_index := raw_index - 1 if raw_index > 0 else vertices.size() + raw_index
				if vertex_index >= 0 and vertex_index < vertices.size():
					face_indices.append(vertex_index)
			if face_indices.size() < 3:
				continue
			if not triangles_by_object.has(current_object):
				triangles_by_object[current_object] = []
			var triangles: Array = triangles_by_object[current_object]
			for triangle_index in range(1, face_indices.size() - 1):
				triangles.append(vertices[face_indices[0]])
				triangles.append(vertices[face_indices[triangle_index]])
				triangles.append(vertices[face_indices[triangle_index + 1]])

	var result := {}
	for object_name_value in triangles_by_object:
		var object_name := str(object_name_value)
		var object_vertices: Array = triangles_by_object[object_name]
		if object_vertices.is_empty():
			continue
		var surface_tool := SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex_value in object_vertices:
			surface_tool.add_vertex(vertex_value as Vector3)
		surface_tool.generate_normals()
		result[object_name] = surface_tool.commit()
	_object_cache[asset_path] = result
	return result.duplicate()


static func instantiate(
	asset_path: String,
	material_for_part: Callable = Callable(),
	cast_shadows := true
) -> Node3D:
	var root := Node3D.new()
	root.name = asset_path.get_file().get_basename().to_pascal_case()
	var object_meshes := load_objects(asset_path)
	for object_name_value in object_meshes:
		var object_name := str(object_name_value)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = object_name
		mesh_instance.mesh = object_meshes[object_name] as Mesh
		if material_for_part.is_valid():
			mesh_instance.material_override = material_for_part.call(object_name) as Material
		mesh_instance.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if cast_shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		root.add_child(mesh_instance)
	return root


static func object_centres_xz(asset_path: String, name_prefix: String) -> Array[Vector2]:
	var centres: Array[Vector2] = []
	var matching_names: Array[String] = []
	var object_meshes := load_objects(asset_path)
	for object_name_value in object_meshes:
		var object_name := str(object_name_value)
		if object_name.begins_with(name_prefix):
			matching_names.append(object_name)
	matching_names.sort()
	for object_name in matching_names:
		var mesh := object_meshes[object_name] as Mesh
		var centre := mesh.get_aabb().get_center()
		centres.append(Vector2(centre.x, centre.z))
	return centres
