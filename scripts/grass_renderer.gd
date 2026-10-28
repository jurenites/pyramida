extends Node3D

const GRASS_SHADER := preload("res://shaders/grass.gdshader")

const DeterministicRandomScript = preload("res://scripts/deterministic_random.gd")

const Palette = preload("res://scripts/game_palette.gd")

const CHUNK_SIZE := 8
const STREAM_CHUNK_SIZE := 16
const TUFTS_PER_WORLD_UNIT := 6
const MAX_RENDER_DISTANCE := 20.0
const BILLBOARD_CULL_PADDING := 0.5

var _world_half_extent := 0.0
var _fog_cell_size := 0.5
var _tuft_mesh: ArrayMesh
var _grass_material: ShaderMaterial
var _chunk_candidates: Dictionary = {}
var _chunk_instances: Dictionary = {}
var _revealed_fog_cells: Dictionary = {}
var _excluded_world_units: Dictionary = {}


func setup(
	world_half_extent: float,
	fog_cell_size: float,
	excluded_world_units: Dictionary = {}
) -> void:
	_world_half_extent = world_half_extent
	_fog_cell_size = fog_cell_size
	_excluded_world_units = excluded_world_units.duplicate()
	_tuft_mesh = _create_tuft_mesh()
	_grass_material = _create_grass_material()
	if _world_half_extent > 0.0:
		_build_chunk_candidates()


func has_grass_in_world_unit(world_unit: Vector2i) -> bool:
	return _world_unit_has_grass(world_unit.x, world_unit.y)


func exclude_world_unit(world_unit: Vector2i) -> void:
	_excluded_world_units[world_unit] = true
	_rebuild_chunk(_chunk_coordinate(world_unit))


static func generated_grass_at(world_unit: Vector2i) -> bool:
	if abs(world_unit.x) <= 3 and abs(world_unit.y) <= 3:
		return true
	var patch_value := (
		sin(float(world_unit.x) * 0.37)
		+ cos(float(world_unit.y) * 0.31)
		+ sin(float(world_unit.x + world_unit.y) * 0.17)
	)
	return patch_value > 1.05


func load_world_chunk(stream_chunk: Vector2i, excluded_world_units: Dictionary) -> void:
	for excluded_world_unit in excluded_world_units:
		_excluded_world_units[excluded_world_unit] = true
	var stream_origin := stream_chunk * STREAM_CHUNK_SIZE
	var affected_grass_chunks: Dictionary = {}
	for local_x in STREAM_CHUNK_SIZE:
		for local_z in STREAM_CHUNK_SIZE:
			var world_unit := stream_origin + Vector2i(local_x, local_z)
			if not _world_unit_has_grass(world_unit.x, world_unit.y):
				continue
			_append_world_unit_candidates(world_unit)
			affected_grass_chunks[_chunk_coordinate(world_unit)] = true
	for grass_chunk in affected_grass_chunks:
		_rebuild_chunk(grass_chunk)


func unload_world_chunk(stream_chunk: Vector2i) -> void:
	# Stream chunks contain a whole number of grass chunks.
	@warning_ignore("integer_division")
	var grass_chunks_per_stream_chunk := int(STREAM_CHUNK_SIZE / CHUNK_SIZE)
	var first_grass_chunk := stream_chunk * grass_chunks_per_stream_chunk
	for local_x in grass_chunks_per_stream_chunk:
		for local_z in grass_chunks_per_stream_chunk:
			var grass_chunk := first_grass_chunk + Vector2i(local_x, local_z)
			_chunk_candidates.erase(grass_chunk)
			if _chunk_instances.has(grass_chunk):
				var instance := _chunk_instances[grass_chunk] as MultiMeshInstance3D
				if is_instance_valid(instance):
					instance.queue_free()
				_chunk_instances.erase(grass_chunk)
	var stream_bounds := Rect2i(stream_chunk * STREAM_CHUNK_SIZE, Vector2i(STREAM_CHUNK_SIZE, STREAM_CHUNK_SIZE))
	var exclusions_to_remove: Array[Vector2i] = []
	for world_unit_value in _excluded_world_units:
		var world_unit: Vector2i = world_unit_value
		if stream_bounds.has_point(world_unit):
			exclusions_to_remove.append(world_unit)
	for world_unit in exclusions_to_remove:
		_excluded_world_units.erase(world_unit)


func reveal_fog_cells(newly_revealed_cells: Array[Vector2i]) -> void:
	var affected_chunks: Dictionary = {}
	for fog_cell in newly_revealed_cells:
		if _revealed_fog_cells.has(fog_cell):
			continue
		_revealed_fog_cells[fog_cell] = true
		var world_unit := Vector2i(
			floori(float(fog_cell.x) * _fog_cell_size),
			floori(float(fog_cell.y) * _fog_cell_size)
		)
		affected_chunks[_chunk_coordinate(world_unit)] = true
	for chunk_coordinate in affected_chunks:
		_rebuild_chunk(chunk_coordinate)


func update_viewer_position(viewer_position: Vector3) -> void:
	var viewer_2d := Vector2(viewer_position.x, viewer_position.z)
	for chunk_coordinate in _chunk_instances:
		var grass_chunk := _chunk_instances[chunk_coordinate] as MultiMeshInstance3D
		if not is_instance_valid(grass_chunk):
			continue
		var chunk_centre := Vector2(
			(chunk_coordinate.x + 0.5) * CHUNK_SIZE,
			(chunk_coordinate.y + 0.5) * CHUNK_SIZE
		)
		var distance := viewer_2d.distance_to(chunk_centre)
		grass_chunk.visible = distance <= MAX_RENDER_DISTANCE
		grass_chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_chunk_candidates() -> void:
	for world_x in range(-int(_world_half_extent), int(_world_half_extent)):
		for world_z in range(-int(_world_half_extent), int(_world_half_extent)):
			if not _world_unit_has_grass(world_x, world_z):
				continue
			_append_world_unit_candidates(Vector2i(world_x, world_z))


func _append_world_unit_candidates(world_unit: Vector2i) -> void:
	var chunk_coordinate := _chunk_coordinate(world_unit)
	if not _chunk_candidates.has(chunk_coordinate):
		_chunk_candidates[chunk_coordinate] = []
	var candidates: Array = _chunk_candidates[chunk_coordinate]
	# A scrambled Halton set gives every occupied World Unit even coverage
	# without the rows and diagonal bands produced by independent hashes.
	var tile_seed := _coordinate_seed(world_unit.x, world_unit.y, 193)
	var sequence_offset := tile_seed % TUFTS_PER_WORLD_UNIT
	var shift_x := _seed_fraction(tile_seed + 211)
	var shift_z := _seed_fraction(tile_seed + 227)
	var swap_axes := tile_seed % 2 == 0
	var mirror_x := tile_seed % 3 == 0
	var mirror_z := tile_seed % 5 == 0
	for tuft_index in TUFTS_PER_WORLD_UNIT:
		var seed_value := _coordinate_seed(world_unit.x, world_unit.y, tuft_index)
		var sequence_index := 1 + (tuft_index + sequence_offset) % TUFTS_PER_WORLD_UNIT
		var low_discrepancy_point := Vector2(
			_radical_inverse(sequence_index, 2),
			_radical_inverse(sequence_index, 3)
		)
		if swap_axes:
			low_discrepancy_point = Vector2(low_discrepancy_point.y, low_discrepancy_point.x)
		if mirror_x:
			low_discrepancy_point.x = 1.0 - low_discrepancy_point.x
		if mirror_z:
			low_discrepancy_point.y = 1.0 - low_discrepancy_point.y
		low_discrepancy_point.x = fposmod(low_discrepancy_point.x + shift_x, 1.0)
		low_discrepancy_point.y = fposmod(low_discrepancy_point.y + shift_z, 1.0)
		var local_x := 0.07 + low_discrepancy_point.x * 0.86
		var local_z := 0.07 + low_discrepancy_point.y * 0.86
		var scale_value := 0.78 + _seed_fraction(seed_value + 131) * 0.42
		var origin := Vector3(world_unit.x + local_x, 0.012, world_unit.y + local_z)
		var tuft_basis := Basis.IDENTITY.scaled(Vector3(scale_value, scale_value, scale_value))
		candidates.append(Transform3D(tuft_basis, origin))


func _rebuild_chunk(chunk_coordinate: Vector2i) -> void:
	var candidates: Array = _chunk_candidates.get(chunk_coordinate, [])
	var visible_transforms: Array[Transform3D] = []
	for candidate: Transform3D in candidates:
		var candidate_world_unit := Vector2i(floori(candidate.origin.x), floori(candidate.origin.z))
		if _excluded_world_units.has(candidate_world_unit):
			continue
		var fog_cell := Vector2i(
			floori(candidate.origin.x / _fog_cell_size),
			floori(candidate.origin.z / _fog_cell_size)
		)
		if _revealed_fog_cells.has(fog_cell):
			visible_transforms.append(candidate)

	if visible_transforms.is_empty():
		if _chunk_instances.has(chunk_coordinate):
			var empty_chunk := _chunk_instances[chunk_coordinate] as MultiMeshInstance3D
			if is_instance_valid(empty_chunk):
				empty_chunk.visible = false
		return

	var grass_chunk: MultiMeshInstance3D
	if _chunk_instances.has(chunk_coordinate):
		grass_chunk = _chunk_instances[chunk_coordinate] as MultiMeshInstance3D
	else:
		grass_chunk = MultiMeshInstance3D.new()
		grass_chunk.name = "GrassChunk_%d_%d" % [chunk_coordinate.x, chunk_coordinate.y]
		grass_chunk.material_override = _grass_material
		grass_chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(grass_chunk)
		_chunk_instances[chunk_coordinate] = grass_chunk

	var grass_multimesh := MultiMesh.new()
	grass_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	grass_multimesh.mesh = _tuft_mesh
	grass_multimesh.instance_count = visible_transforms.size()
	grass_multimesh.custom_aabb = AABB(
		Vector3(
			chunk_coordinate.x * CHUNK_SIZE - BILLBOARD_CULL_PADDING,
			0.0,
			chunk_coordinate.y * CHUNK_SIZE - BILLBOARD_CULL_PADDING
		),
		Vector3(
			CHUNK_SIZE + BILLBOARD_CULL_PADDING * 2.0,
			1.2,
			CHUNK_SIZE + BILLBOARD_CULL_PADDING * 2.0
		)
	)
	for instance_index in visible_transforms.size():
		grass_multimesh.set_instance_transform(instance_index, visible_transforms[instance_index])
	grass_chunk.multimesh = grass_multimesh
	grass_chunk.visible = true


func _create_tuft_mesh() -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_billboard_vertex(surface_tool, Vector3(-0.3, 0.0, 0.0), Vector2(0.0, 0.0))
	_add_billboard_vertex(surface_tool, Vector3(0.3, 0.0, 0.0), Vector2(1.0, 0.0))
	_add_billboard_vertex(surface_tool, Vector3(0.3, 0.82, 0.0), Vector2(1.0, 1.0))
	_add_billboard_vertex(surface_tool, Vector3(-0.3, 0.0, 0.0), Vector2(0.0, 0.0))
	_add_billboard_vertex(surface_tool, Vector3(0.3, 0.82, 0.0), Vector2(1.0, 1.0))
	_add_billboard_vertex(surface_tool, Vector3(-0.3, 0.82, 0.0), Vector2(0.0, 1.0))
	return surface_tool.commit()


func _add_billboard_vertex(surface_tool: SurfaceTool, vertex_position: Vector3, uv: Vector2) -> void:
	surface_tool.set_uv(uv)
	surface_tool.add_vertex(vertex_position)


func _create_grass_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRASS_SHADER
	material.set_shader_parameter("grass_color", Palette.GRASS)
	return material


func _world_unit_has_grass(world_x: int, world_z: int) -> bool:
	if _excluded_world_units.has(Vector2i(world_x, world_z)):
		return false
	return generated_grass_at(Vector2i(world_x, world_z))


func _chunk_coordinate(world_unit: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(world_unit.x) / CHUNK_SIZE),
		floori(float(world_unit.y) / CHUNK_SIZE)
	)


func _coordinate_seed(x_coordinate: int, z_coordinate: int, salt: int) -> int:
	return DeterministicRandomScript.coordinate_seed(x_coordinate, z_coordinate, salt)


func _seed_fraction(seed_value: int) -> float:
	return DeterministicRandomScript.fraction(seed_value)


func _radical_inverse(sequence_index: int, base: int) -> float:
	var result := 0.0
	var inverse_base := 1.0 / float(base)
	var fraction := inverse_base
	var remaining := sequence_index
	while remaining > 0:
		result += float(remaining % base) * fraction
		remaining /= base
		fraction *= inverse_base
	return result
