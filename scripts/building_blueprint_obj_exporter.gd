class_name BuildingBlueprintObjExporter
extends RefCounted

const BuildingBlueprintScript = preload("res://scripts/building_blueprint.gd")
const MaterialCatalog = preload("res://scripts/building_material_catalog.gd")


static func export_to_file(blueprint: BuildingBlueprint, destination_path: String) -> Error:
	if blueprint == null:
		return ERR_INVALID_PARAMETER
	var absolute_path := ProjectSettings.globalize_path(destination_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return directory_error
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		return FileAccess.get_open_error()
	var material_path := destination_path.get_basename() + ".mtl"
	var material_error := _write_material_library(blueprint, material_path)
	if material_error != OK:
		return material_error
	destination.store_line("# Town Building Blueprint OBJ")
	destination.store_line("# id: %s" % blueprint.blueprint_id)
	destination.store_line("# display_name: %s" % blueprint.display_name)
	destination.store_line("# source_format: %s v%d" % [
		BuildingBlueprintScript.FORMAT_ID,
		blueprint.source_format_version,
	])
	destination.store_line("# units: 1 OBJ unit = 1 Town World Unit = 1 Blender metre")
	destination.store_line("mtllib %s" % material_path.get_file())
	var vertex_offset := 0
	for blueprint_part in blueprint.parts:
		var geometry: Dictionary = blueprint_part.get("geometry", {})
		var part_kind := str(blueprint_part.get("kind", "block"))
		var primitive := str(geometry.get("primitive", "log" if part_kind == "log" else "box"))
		var generated := _primitive_geometry(primitive, geometry)
		var vertices: Array[Vector3] = generated.get("vertices", [])
		var faces: Array[PackedInt32Array] = generated.get("faces", [])
		if vertices.is_empty() or faces.is_empty():
			continue
		destination.store_line("")
		destination.store_line("o %s" % str(blueprint_part.get("id", "part")))
		destination.store_line("# kind: %s" % part_kind)
		destination.store_line("# resource: %s" % str(blueprint_part.get("resource", "")))
		destination.store_line("# sub_unit: %s" % str(blueprint_part.get("sub_unit", [])))
		destination.store_line("usemtl %s" % str(blueprint_part.get("material", "wood")))
		for vertex in vertices:
			destination.store_line("v %.6f %.6f %.6f" % [vertex.x, vertex.y, vertex.z])
		for face in faces:
			var indices: Array[String] = []
			for local_index in face:
				indices.append(str(vertex_offset + local_index + 1))
			destination.store_line("f %s" % " ".join(indices))
		vertex_offset += vertices.size()
	return OK


static func _write_material_library(
	blueprint: BuildingBlueprint,
	destination_path: String
) -> Error:
	var material_file := FileAccess.open(destination_path, FileAccess.WRITE)
	if material_file == null:
		return FileAccess.get_open_error()
	material_file.store_line("# Town Building materials")
	var written_materials := {}
	for blueprint_part in blueprint.parts:
		var material_id := str(blueprint_part.get("material", "wood"))
		if written_materials.has(material_id):
			continue
		written_materials[material_id] = true
		var colour := MaterialCatalog.colour(material_id)
		material_file.store_line("")
		material_file.store_line("newmtl %s" % material_id)
		material_file.store_line("Kd %.6f %.6f %.6f" % [colour.r, colour.g, colour.b])
		material_file.store_line("d %.6f" % colour.a)
		material_file.store_line("Ns 8.000000")
	return OK


static func _primitive_geometry(primitive: String, geometry: Dictionary) -> Dictionary:
	match primitive:
		"log":
			return _log_geometry(geometry)
		"sphere":
			return _sphere_geometry(geometry)
		_:
			return _box_geometry(geometry)


static func _box_geometry(geometry: Dictionary) -> Dictionary:
	var centre := BuildingBlueprintScript.vector3_from_value(geometry.get("centre", []))
	var size := BuildingBlueprintScript.vector3_from_value(
		geometry.get("size", []),
		Vector3(0.46, 0.46, 0.46)
	)
	var rotation_degrees := BuildingBlueprintScript.vector3_from_value(
		geometry.get("rotation_degrees", [])
	)
	var rotation := Basis.from_euler(rotation_degrees * PI / 180.0)
	var half_size := size * 0.5
	var vertices: Array[Vector3] = []
	for x_side in 2:
		for y_side in 2:
			for z_side in 2:
				var local_vertex := Vector3(
					-half_size.x if x_side == 0 else half_size.x,
					-half_size.y if y_side == 0 else half_size.y,
					-half_size.z if z_side == 0 else half_size.z
				)
				vertices.append(centre + rotation * local_vertex)
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([0, 1, 3]), PackedInt32Array([0, 3, 2]),
		PackedInt32Array([4, 6, 7]), PackedInt32Array([4, 7, 5]),
		PackedInt32Array([0, 4, 5]), PackedInt32Array([0, 5, 1]),
		PackedInt32Array([2, 3, 7]), PackedInt32Array([2, 7, 6]),
		PackedInt32Array([0, 2, 6]), PackedInt32Array([0, 6, 4]),
		PackedInt32Array([1, 5, 7]), PackedInt32Array([1, 7, 3]),
	]
	return {"vertices": vertices, "faces": faces}


static func _log_geometry(geometry: Dictionary) -> Dictionary:
	var start := BuildingBlueprintScript.vector3_from_value(geometry.get("start", []))
	var end := BuildingBlueprintScript.vector3_from_value(
		geometry.get("end", []),
		Vector3.UP * 0.5
	)
	var axis := (end - start).normalized()
	if axis.is_zero_approx():
		return {}
	var reference := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var tangent := reference.cross(axis).normalized()
	var bitangent := axis.cross(tangent).normalized()
	var sides := clampi(int(geometry.get("sides", 6)), 3, 16)
	var start_radius := float(geometry.get("start_radius", 0.085))
	var end_radius := float(geometry.get("end_radius", 0.075))
	var vertices: Array[Vector3] = []
	for ring in 2:
		var ring_centre := start if ring == 0 else end
		var ring_radius := start_radius if ring == 0 else end_radius
		for side in sides:
			var angle := TAU * float(side) / float(sides)
			vertices.append(ring_centre + (tangent * cos(angle) + bitangent * sin(angle)) * ring_radius)
	vertices.append(start)
	vertices.append(end)
	var faces: Array[PackedInt32Array] = []
	for side in sides:
		var next_side := (side + 1) % sides
		faces.append(PackedInt32Array([side, sides + side, sides + next_side]))
		faces.append(PackedInt32Array([side, sides + next_side, next_side]))
		faces.append(PackedInt32Array([sides * 2, next_side, side]))
		faces.append(PackedInt32Array([sides * 2 + 1, sides + side, sides + next_side]))
	return {"vertices": vertices, "faces": faces}


static func _sphere_geometry(geometry: Dictionary) -> Dictionary:
	var centre := BuildingBlueprintScript.vector3_from_value(geometry.get("centre", []))
	var radius := float(geometry.get("radius", 0.11))
	var half_height := float(geometry.get("height", radius * 1.5)) * 0.5
	var scale := BuildingBlueprintScript.vector3_from_value(geometry.get("scale", []), Vector3.ONE)
	var vertices: Array[Vector3] = [
		centre + Vector3(0.0, half_height * scale.y, 0.0),
		centre + Vector3(radius * scale.x, 0.0, 0.0),
		centre + Vector3(0.0, 0.0, radius * scale.z),
		centre + Vector3(-radius * scale.x, 0.0, 0.0),
		centre + Vector3(0.0, 0.0, -radius * scale.z),
		centre + Vector3(0.0, -half_height * scale.y, 0.0),
	]
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([0, 1, 2]), PackedInt32Array([0, 2, 3]),
		PackedInt32Array([0, 3, 4]), PackedInt32Array([0, 4, 1]),
		PackedInt32Array([5, 2, 1]), PackedInt32Array([5, 3, 2]),
		PackedInt32Array([5, 4, 3]), PackedInt32Array([5, 1, 4]),
	]
	return {"vertices": vertices, "faces": faces}
