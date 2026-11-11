extends Node3D
const Basin=preload("res://scripts/settlement/puddle_basin.gd")
const CoastalWater = preload("res://scripts/settlement/coastal_water.gd")
const Ocean = preload("res://scripts/settlement/ocean_surface.gd")
const Islands = preload("res://scripts/settlement/solid_islands.gd")
var signature := 0
var island_nodes: Dictionary = {}
var sea: MeshInstance3D
var seabed: MeshInstance3D
var water_layout := 0
func sync(world) -> void:
	var next := hash([world.world_seed,world.difficulty,world.generator_version,world.loaded_chunks.keys(),world.terrain_excavations,Basin.cells(world)])
	if signature==next: return
	signature=next
	if sea==null:
		sea=MeshInstance3D.new(); sea.name="AegeanSea"
		var plane := PlaneMesh.new(); plane.size=Vector2.ONE*60000; sea.mesh=plane; sea.position.y=Ocean.LEVEL
		var water := ShaderMaterial.new(); water.shader=preload("res://shaders/island_water.gdshader")
		water.set_shader_parameter("shallow_colour",preload("res://scripts/game_palette.gd").WATER_BLUE)
		water.set_shader_parameter("natural_reef",true)
		water.set_shader_parameter("reef_colour",Color("109b96"))
		water.set_shader_parameter("wind_direction",Ocean.WIND_DIRECTION.normalized()); water.set_shader_parameter("wind_speed",Ocean.WIND_SPEED)
		sea.material_override=water; sea.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(sea)
	var layout := hash([world.world_seed,world.difficulty,world.generator_version,Ocean.WIND_DIRECTION])
	if water_layout!=layout:
		water_layout=layout
		var field:=CoastalWater.bake(Islands.definitions(world.world_seed,world.generator_version),Ocean.WIND_DIRECTION,world.generator_version>=17)
		var material: ShaderMaterial=sea.material_override
		material.set_shader_parameter("coast_field",ImageTexture.create_from_image(field.image))
		var bounds: Rect2=field.bounds
		material.set_shader_parameter("coast_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))
		material.set_shader_parameter("coast_enabled",true)
		if seabed!=null: seabed.free()
		seabed=MeshInstance3D.new(); seabed.name="CoastalSeabed"; seabed.mesh=CoastalWater.seabed(field)
		var sand:=ShaderMaterial.new(); sand.shader=preload("res://shaders/coastal_seabed.gdshader")
		sand.set_shader_parameter("water_level",Ocean.LEVEL)
		sand.set_shader_parameter("continuous_coast",true)
		seabed.material_override=sand; seabed.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(seabed)
		if world.generator_version>=17:
			var body:=StaticBody3D.new(); body.name="SeabedCollision"; body.collision_layer=1; body.collision_mask=0; body.set_meta("terrain",true)
			var collision:=CollisionShape3D.new(); var shape:=ConcavePolygonShape3D.new(); shape.set_faces(seabed.mesh.get_faces()); collision.shape=shape
			seabed.add_child(body); body.add_child(collision)
	var wanted := {}
	for island in Islands.definitions(world.world_seed,world.generator_version):
		var loaded := false
		for item in island.parts:
			var b: AABB=item.bounds
			for chunk: Vector2i in world.loaded_chunks:
				if Rect2(Vector2(b.position.x,b.position.z),Vector2(b.size.x,b.size.z)).intersects(Rect2(Vector2(chunk*16),Vector2.ONE*16)): loaded=true; break
			if loaded: break
		if not loaded and world.streaming_enabled: continue
		var key: int=hash([world.world_seed,world.difficulty,world.generator_version,island.coast])
		wanted[key]=true
		var cuts: Array = []
		for cut: Dictionary in world.terrain_excavations:
			for item in island.parts:
				if item.bounds.grow(1).has_point(cut.origin): cuts.append(cut); break
		var basins: Array=Basin.cells(world).filter(func(cell):return island.parts.any(func(item):return item.bounds.grow(0.5).has_point(Vector3(cell))))
		var revision := hash([cuts,basins])
		if island_nodes.has(key) and island_nodes[key].get_meta("revision")==revision: continue
		if island_nodes.has(key): island_nodes[key].free()
		var group := Node3D.new(); group.name="IslandVisual"; group.set_meta("revision",revision)
		add_child(group); island_nodes[key]=group
		var solid := CSGCombiner3D.new(); solid.name="Island"; solid.use_collision=true; solid.collision_layer=1; solid.collision_mask=0
		solid.set_meta("terrain",true); group.add_child(solid)
		var soil_field: Dictionary=preload("res://scripts/settlement/terrain_vegetation_edge.gd").field(island) if world.generator_version>=23 else {}
		for item in island.parts:
			var mesh: ArrayMesh=item.mesh.duplicate()
			for surface in mesh.get_surface_count(): mesh.surface_set_material(surface,painted(item.mesh.surface_get_material(surface),world,soil_field))
			var shape := CSGMesh3D.new(); shape.mesh=mesh; shape.transform=item.transform; solid.add_child(shape)
		for cut: Dictionary in cuts:
			var box := CSGBox3D.new(); box.size=Vector3(1.0002,1.0002,1.0002)
			box.operation=CSGShape3D.OPERATION_SUBTRACTION; box.position=cut.origin+Vector3.UP*0.5; box.rotation.y=cut.yaw
			box.material=painted(Islands.Landform.material(Color("354b46")),world); solid.add_child(box)
		for cell in basins:
			var bowl:=CSGMesh3D.new(); bowl.mesh=Basin.cutter(cell,world.world_seed)
			bowl.operation=CSGShape3D.OPERATION_SUBTRACTION; bowl.position=Vector3(cell)
			bowl.material=painted(Islands.Landform.material(preload("res://scripts/game_palette.gd").LIMESTONE_SIDE.darkened(0.18)),world)
			solid.add_child(bowl)
	for key in island_nodes.keys():
		if not wanted.has(key): island_nodes[key].free(); island_nodes.erase(key)

func painted(source: StandardMaterial3D, world, soil_field: Dictionary = {}) -> ShaderMaterial:
	var material := ShaderMaterial.new(); material.shader=preload("res://shaders/island_terrain.gdshader")
	var dry: bool=world.difficulty=="normal" and world.generator_version>=14
	var grass_surface:=source.albedo_color.is_equal_approx(Color("a8b966"))
	var colour:=source.albedo_color
	if dry and not grass_surface and not colour.is_equal_approx(Color("e5d6aa")):
		colour=Color("ac9575")*(0.65+source.albedo_color.get_luminance()*0.65)
	material.set_shader_parameter("fill_colour",colour)
	material.set_shader_parameter("grass_surface",grass_surface)
	if not soil_field.is_empty():
		material.set_shader_parameter("soil_edge_enabled",true)
		material.set_shader_parameter("soil_edge_field",soil_field.texture)
		material.set_shader_parameter("soil_edge_bounds",soil_field.bounds)
		material.set_shader_parameter("soil_levels",soil_field.levels)
	material.set_shader_parameter("folded_layers",world.generator_version>=23)
	material.set_shader_parameter("dry_island",dry)
	material.set_shader_parameter("rocky_heights",world.generator_version>=14)
	material.set_shader_parameter("shore_sand",source.albedo_color.is_equal_approx(Color("e5d6aa")))
	material.set_shader_parameter("submerged_terrain",true)
	return material
