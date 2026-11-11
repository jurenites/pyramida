extends Node3D
## Chunk-owned terrain. All visible vegetation belongs to interactive entities.
const Assets = preload("res://scripts/settlement/asset_library.gd")
const DayCycle = preload("res://scripts/settlement/day_cycle.gd")
const Generator = preload("res://scripts/settlement/world_generator.gd")
const Terrain = preload("res://scripts/settlement/terrain_mesh.gd")
var signature := 0
var model_id := 0
var terrain_revision := -1
var soil_revision := -1
var sun: DirectionalLight3D
var settings: Environment
var chunks: Dictionary = {}
var solid_view: Node3D
var open_sea: MeshInstance3D

func update_lighting(elapsed: float) -> void:
	DayCycle.apply(sun, settings, elapsed)
	RenderingServer.global_shader_parameter_set("settlement_daylight", DayCycle.daylight_at(elapsed))
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
	Assets.Illustration.configure_sun(sun)
	add_child(sun)
	sync(model)
	update_lighting(model.time)

func sync(model, chunk_budget := -1) -> bool:
	if preload("res://scripts/settlement/solid_islands.gd").enabled(model):
		model_id=model.get_instance_id(); terrain_revision=model.terrain_revision
		for chunk in chunks.values(): chunk.free()
		chunks.clear()
		if open_sea!=null: open_sea.visible=false
		if solid_view==null:
			solid_view=preload("res://scripts/settlement/solid_island_view.gd").new(); add_child(solid_view)
		solid_view.visible=true; solid_view.sync(model)
		return true
	if solid_view!=null:
		solid_view.free(); solid_view=null
	if model_id == model.get_instance_id() and terrain_revision == model.terrain_revision and (model.streaming_enabled or signature == hash([model.ground, model.terrain_shapes])):
		return true
	if open_sea==null:
		open_sea=MeshInstance3D.new(); open_sea.name="OpenSea"
		var plane:=PlaneMesh.new(); plane.size=Vector2.ONE*60000
		open_sea.mesh=plane; open_sea.position.y=-0.1
		var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color=Color("216e87")
		open_sea.material_override=material; open_sea.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(open_sea)
	open_sea.visible=model.difficulty=="easy" and model.generator_version>=6
	if open_sea.visible and open_sea.get_meta("sea_seed",-1)!=model.world_seed:
		var depth := Image.create(129,129,false,Image.FORMAT_RF)
		for x in 129:
			for z in 129:
				depth.set_pixel(x,z,Color(preload("res://scripts/settlement/archipelago_landscape.gd").shore_distance(Vector2(x,z)*1.5-Vector2.ONE*96,model.world_seed),0,0))
		var material:=ShaderMaterial.new(); material.shader=preload("res://shaders/settlement_sea.gdshader")
		material.set_shader_parameter("islands",true); material.set_shader_parameter("depth_map",ImageTexture.create_from_image(depth))
		material.set_shader_parameter("chunk_origin",Vector2.ONE*-96); material.set_shader_parameter("depth_span",192.0)
		open_sea.material_override=material; open_sea.set_meta("sea_seed",model.world_seed)
	var switched: bool = model_id != model.get_instance_id()
	if switched: terrain_revision = -1
	var soil_changed: bool = switched or soil_revision != model.soil_revision
	soil_revision = model.soil_revision
	model_id = model.get_instance_id()
	var built := 0
	signature = 0 if model.streaming_enabled else hash([model.ground, model.terrain_shapes])
	if model.streaming_enabled:
		for chunk: Vector2i in chunks.keys():
			if switched or not model.loaded_chunks.has(chunk) or (soil_changed and chunks[chunk].get_meta("soil_signature", 0) != _soil_signature(model, chunk)):
				chunks[chunk].free()
				chunks.erase(chunk)
		for chunk: Vector2i in model.loaded_chunks:
			if chunks.has(chunk): continue
			if chunk_budget >= 0 and built >= chunk_budget: return false
			var cells := {}
			var origin := chunk * Generator.CHUNK_SIZE
			for x in range(origin.x, origin.x + Generator.CHUNK_SIZE):
				for z in range(origin.y, origin.y + Generator.CHUNK_SIZE):
					var cell: Vector3i = model.surface_at(x, z)
					if model.ground.has(cell): cells[cell] = true
			_build_chunk(model, chunk, cells)
			built += 1
		terrain_revision = model.terrain_revision
		return true
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
		if chunks.has(chunk): continue
		if chunk_budget >= 0 and built >= chunk_budget: return false
		_build_chunk(model, chunk, groups[chunk])
		built += 1
	terrain_revision = model.terrain_revision
	return true

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
	if not model.chunk_details.has(chunk):
		var generated := Generator.generate_chunk(model.world_seed, chunk, model.difficulty, model.generator_version)
		model.chunk_details[chunk] = {"grass": generated.grass, "border": generated.border, "border_shapes": generated.border_shapes}
	var details: Dictionary = model.chunk_details[chunk]
	if model.difficulty == "easy": _build_sea(node, chunk, model.world_seed, model.generator_version >= 6)
	# An ocean-only chunk must not fall back to rebuilding the entire landscape.
	if not cells.is_empty(): Terrain.build(node, model, cells, details.border if model.streaming_enabled else {}, details.get("border_shapes", {}) if model.streaming_enabled else {})

func _build_sea(parent: Node3D, chunk: Vector2i, seed_: int, archipelago := false) -> void:
	var origin := Vector2(chunk * Generator.CHUNK_SIZE) - Vector2.ONE * 0.5
	# Saltwater volumes and seabed belong to terrain_volume; this is the surface.
	if not archipelago and origin.x + Generator.CHUNK_SIZE < 17.0: return
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * Generator.CHUNK_SIZE
	sea.mesh = plane
	sea.position = Vector3(origin.x + Generator.CHUNK_SIZE * 0.5, -0.08, origin.y + Generator.CHUNK_SIZE * 0.5)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/settlement_sea.gdshader")
	material.set_shader_parameter("coast_phase", float(posmod(seed_, 97)) * 0.064)
	if archipelago:
		var depth := Image.create(33,33,false,Image.FORMAT_RF)
		for x in 33:
			for z in 33:
				var distance: float = preload("res://scripts/settlement/archipelago_landscape.gd").shore_distance(origin+Vector2(x,z)*0.5,seed_)
				depth.set_pixel(x,z,Color(distance,0,0))
		material.set_shader_parameter("islands",true)
		material.set_shader_parameter("depth_map",ImageTexture.create_from_image(depth))
		material.set_shader_parameter("chunk_origin",origin)
	sea.material_override = material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sea)
