extends Node3D
## Chunk-owned geometry and deterministic grass; simulation owns all resources.
const GrassClearance = preload("res://scripts/settlement/grass_clearance.gd")
const Navigation = preload("res://scripts/settlement/navigation.gd")
const Assets = preload("res://scripts/settlement/asset_library.gd")
const DayCycle = preload("res://scripts/settlement/day_cycle.gd")
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Random = preload("res://scripts/deterministic_random.gd")
const Greece = preload("res://scripts/settlement/greece_landscape.gd")
const Terrain = preload("res://scripts/settlement/terrain_mesh.gd")
var signature := 0
var model_id := 0
var terrain_revision := -1
var soil_revision := -1
var chunk_revision := 0
var footprint_state: Array = []
var grass_footprints: Dictionary = {}
var footprints_by_chunk: Dictionary = {}
var sun: DirectionalLight3D
var settings: Environment
var chunks: Dictionary = {}
var grass_mesh: ArrayMesh
var grass_state: Array = []

func update_lighting(elapsed: float) -> void:
	DayCycle.apply(sun, settings, elapsed)
	if Assets.Illustration.ground_material != null:
		Assets.Illustration.ground_material.set_shader_parameter("daylight", DayCycle.daylight_at(elapsed))

func setup(model) -> void:
	var environment := WorldEnvironment.new()
	settings = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("fef1cf")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d4dfdc")
	settings.ambient_light_energy = 0.45
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR if Assets.Illustration.enabled else Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	# The camera sits 85 m from its focus, before zooming out over the desert.
	# Cover the visible ground as well as the long low-sun projections.
	sun.directional_shadow_max_distance = 200
	sun.shadow_bias = 0.5
	sun.shadow_normal_bias = 2.0
	add_child(sun)
	grass_mesh = _grass_mesh()
	sync(model)
	update_lighting(model.time)

func sync(model) -> void:
	if model_id == model.get_instance_id() and terrain_revision == model.terrain_revision and (model.streaming_enabled or signature == hash([model.ground, model.terrain_shapes])):
		return
	var switched: bool = model_id != model.get_instance_id()
	var soil_changed: bool = switched or soil_revision != model.soil_revision
	soil_revision = model.soil_revision
	model_id = model.get_instance_id()
	terrain_revision = model.terrain_revision
	signature = 0 if model.streaming_enabled else hash([model.ground, model.terrain_shapes])
	if model.streaming_enabled:
		for chunk: Vector2i in chunks.keys():
			if switched or not model.loaded_chunks.has(chunk) or (soil_changed and chunks[chunk].get_meta("soil_signature", 0) != _soil_signature(model, chunk)):
				chunks[chunk].free()
				chunks.erase(chunk)
		for chunk: Vector2i in model.loaded_chunks:
			if chunks.has(chunk): continue
			var cells := {}
			var origin := chunk * Generator.CHUNK_SIZE
			for x in range(origin.x, origin.x + Generator.CHUNK_SIZE):
				for z in range(origin.y, origin.y + Generator.CHUNK_SIZE):
					var cell: Vector3i = model.surface_at(x, z)
					if model.ground.has(cell): cells[cell] = true
			_build_chunk(model, chunk, cells)
		return
	var groups := {}
	for cell: Vector3i in model.ground:
		var chunk := Generator.chunk_at(Vector2i(cell.x, cell.z))
		if not groups.has(chunk): groups[chunk] = {}
		groups[chunk][cell] = true
	for chunk: Vector2i in chunks.keys():
		if switched or not groups.has(chunk) or chunks[chunk].get_meta("signature") != hash(groups[chunk]) or (soil_changed and chunks[chunk].get_meta("soil_signature", 0) != _soil_signature(model, chunk)):
			chunks[chunk].free()
			chunks.erase(chunk)
	for chunk: Vector2i in groups:
		if not chunks.has(chunk): _build_chunk(model, chunk, groups[chunk])

func _soil_signature(model, chunk: Vector2i) -> int:
	var samples := []
	var origin := chunk * Generator.CHUNK_SIZE
	for x in range(origin.x - 1, origin.x + Generator.CHUNK_SIZE + 1):
		for z in range(origin.y - 1, origin.y + Generator.CHUNK_SIZE + 1):
			var column_cell := Vector2i(x, z)
			if model.surface_edits.has(column_cell): samples.append([column_cell, model.surface_edits[column_cell]])
			# Only permanent cuts invalidate a previously built procedural chunk.
			for offset: Vector2 in model.Soil.OFFSETS:
				var key: Vector3i = model.Soil.sample_key(model.surface_at(x, z), offset)
				if model.soil_cuts.has(key): samples.append(key)
	return hash(samples)

func _build_chunk(model, chunk: Vector2i, cells: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Terrain_%d_%d" % [chunk.x, chunk.y]
	node.set_meta("signature", hash(cells))
	node.set_meta("soil_signature", _soil_signature(model, chunk))
	add_child(node)
	chunks[chunk] = node
	chunk_revision += 1
	if not model.chunk_details.has(chunk):
		var generated := Generator.generate_chunk(model.world_seed, chunk, model.difficulty)
		model.chunk_details[chunk] = {"grass": generated.grass, "border": generated.border, "border_shapes": generated.border_shapes}
	var details: Dictionary = model.chunk_details[chunk]
	if model.difficulty == "easy": _build_sea(node, chunk, model.world_seed)
	# An ocean-only chunk must not fall back to rebuilding the entire landscape.
	if not cells.is_empty(): Terrain.build(node, model, cells, details.border if model.streaming_enabled else {}, details.get("border_shapes", {}) if model.streaming_enabled else {})
	var grass := MultiMeshInstance3D.new()
	grass.name = "Grass"
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(grass)
	grass.set_meta("signature", -1)

func sync_grass(model, fog_enabled: bool) -> void:
	# Inventory/reservation changes do not change grass. Only compare the small
	# footprint map on a general revision, then skip all cells when it is equal.
	var next_footprint_state := [model.get_instance_id(), model.revision]
	if footprint_state != next_footprint_state:
		footprint_state = next_footprint_state
		var next_footprints := GrassClearance.footprints(model)
		if grass_footprints != next_footprints:
			grass_footprints = next_footprints
			footprints_by_chunk.clear()
			for cell: Vector3i in grass_footprints:
				var chunk := Generator.chunk_at(Vector2i(cell.x, cell.z))
				if not footprints_by_chunk.has(chunk): footprints_by_chunk[chunk] = {}
				footprints_by_chunk[chunk][cell] = grass_footprints[cell]
			grass_state.clear()
	var state := [model.get_instance_id(), chunk_revision, model.terrain_revision, model.soil_revision, model.exploration.revision, fog_enabled]
	if grass_state == state: return
	grass_state = state
	for chunk: Vector2i in chunks:
		var grass: MultiMeshInstance3D = chunks[chunk].get_node("Grass")
		var footprints: Dictionary = footprints_by_chunk.get(chunk, {})
		var input_state := [fog_enabled, model.exploration.revision if fog_enabled else -1, hash(footprints), model.soil_revision]
		if grass.get_meta("input_state", []) == input_state: continue
		grass.set_meta("input_state", input_state)
		var visible_cells: Array[Vector3i] = []
		for cell: Vector3i in model.chunk_details[chunk].grass:
			if model.surface_edits.has(Vector2i(cell.x, cell.z)): continue
			if not model.ground.has(cell) or (model.difficulty != "easy" and model.terrain_shapes.has(cell)): continue
			if fog_enabled and not model.exploration.contains(Navigation.point(cell)): continue
			visible_cells.append(cell)
		var next_signature := hash([visible_cells, footprints, model.soil_revision])
		if grass.get_meta("signature") == next_signature: continue
		grass.set_meta("signature", next_signature)
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = grass_mesh
		var tuft_count := 6 if model.difficulty == "easy" else 4
		batch.instance_count = visible_cells.size() * tuft_count
		var index := 0
		for cell: Vector3i in visible_cells:
			for tuft in tuft_count:
				var offset := Vector3(Random.world_fraction(cell.x, cell.z, model.world_seed, 320 + tuft * 4) * Navigation.CELL_SIZE * 0.7 - Navigation.CELL_SIZE * 0.35, 0.012,
					Random.world_fraction(cell.x, cell.z, model.world_seed, 321 + tuft * 4) * Navigation.CELL_SIZE * 0.7 - Navigation.CELL_SIZE * 0.35)
				var scale_ := 0.7 + Random.world_fraction(cell.x, cell.z, model.world_seed, 322 + tuft * 4) * 0.6
				var tuft_basis := Basis(Vector3.UP, Random.world_fraction(cell.x, cell.z, model.world_seed, 323 + tuft * 4) * TAU).scaled(Vector3.ONE * scale_)
				var origin := Navigation.point(cell) + offset
				if GrassClearance.covered(footprints, cell, origin): continue
				origin.y = model.navigation.surface_height(cell, origin) + 0.012
				batch.set_instance_transform(index, Transform3D(tuft_basis, origin))
				batch.set_instance_color(index, Color("467b3c").lerp(Color("82ad50"), Random.world_fraction(cell.x, cell.z, model.world_seed, 340 + tuft)))
				index += 1
		batch.visible_instance_count = index
		grass.multimesh = batch
		grass.extra_cull_margin = 0.6

func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Three genuinely pointed triangles, with a midpoint to curve in the wind.
	for blade in 3:
		var x := float(blade - 1) * 0.105
		var height := 0.38 if blade == 1 else 0.27
		var lean := float(blade - 1) * 0.075
		var base_left := Vector3(x - 0.045, 0, 0)
		var base_right := Vector3(x + 0.045, 0, 0)
		var mid_left := Vector3(x + lean * 0.5 - 0.0225, height * 0.5, 0)
		var mid_right := Vector3(x + lean * 0.5 + 0.0225, height * 0.5, 0)
		var tip := Vector3(x + lean, height, 0)
		for vertex: Vector3 in [base_left, mid_left, base_right, base_right, mid_left, mid_right, mid_left, tip, mid_right]:
			st.set_normal(Vector3.FORWARD)
			st.set_uv(Vector2(0.5, vertex.y / height))
			st.add_vertex(vertex)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/settlement_grass.gdshader")
	st.set_material(material)
	st.index() # Share each blade's midpoint/root vertices within the flat cutout.
	return st.commit()

func _build_sea(parent: Node3D, chunk: Vector2i, seed_: int) -> void:
	var origin := Vector2(chunk * Generator.CHUNK_SIZE) - Vector2.ONE * 0.5
	# Saltwater volumes and seabed belong to terrain_volume; this is the surface.
	if origin.x + Generator.CHUNK_SIZE < 17.0: return
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * Generator.CHUNK_SIZE
	sea.mesh = plane
	sea.position = Vector3(origin.x + Generator.CHUNK_SIZE * 0.5, -0.08, origin.y + Generator.CHUNK_SIZE * 0.5)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/settlement_sea.gdshader")
	material.set_shader_parameter("coast_phase", float(posmod(seed_, 97)) * 0.064)
	sea.material_override = material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sea)
