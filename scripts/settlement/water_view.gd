extends Node3D
const Palette = preload("res://scripts/game_palette.gd")
const Nav = preload("res://scripts/settlement/navigation.gd")
var sources := {}
var rain: GPUParticles3D

func _ready() -> void:
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 1200
	rain.lifetime = 2.0
	rain.position.y = 36
	rain.visibility_aabb = AABB(Vector3(-42, -40, -42), Vector3(84, 44, 84))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(40, 0, 40)
	process.direction = Vector3(0.15, -1, 0)
	process.spread = 2
	process.initial_velocity_min = 18
	process.initial_velocity_max = 22
	process.gravity = Vector3(0, -8, 0)
	rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.025, 0.65, 0.025)
	drop.material = material(Color("b6d2ce"))
	rain.draw_pass_1 = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emitting = false
	add_child(rain)

func sync(model) -> void:
	rain.emitting = model.weather.raining
	rain.visible = model.weather.raining
	for cell in sources.keys():
		if not model.water_sources.has(cell) or model.wells.has(cell) or model.buildings.get(cell, {}).get("kind") == "claypit":
			sources[cell].free()
			sources.erase(cell)
	for cell: Vector3i in model.water_sources:
		if model.wells.has(cell) or model.buildings.get(cell, {}).get("kind") == "claypit": continue
		var source: Dictionary = model.water_sources[cell]
		if source.kind in ["cistern","vase","barrel","basin"]: continue
		if sources.has(cell) and sources[cell].get_meta("kind") != source.kind:
			sources[cell].free()
			sources.erase(cell)
		if not sources.has(cell):
			var root := Node3D.new()
			root.set_meta("kind", source.kind)
			root.position = Nav.point(cell)
			add_child(root)
			var bed := CylinderMesh.new()
			bed.top_radius = 0.42
			bed.bottom_radius = 0.42
			bed.height = 0.025
			bed.radial_segments = 32
			var base := MeshInstance3D.new()
			base.name = "Bed"
			base.mesh = puddle_mesh(cell,model.world_seed) if source.kind=="puddle" else bed
			base.position.y = 0.025
			base.scale.z = 1.0 if source.kind=="puddle" else 0.65
			base.material_override = material(Palette.SAND_SURFACE.darkened(0.13) if source.kind=="puddle" else Color("8e987f"))
			base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(base)
			var water := MeshInstance3D.new()
			water.name = "Water"
			if source.kind == "stream":
				var mesh := BoxMesh.new()
				mesh.size = Vector3(0.6, 0.035, Nav.CELL_SIZE + 0.02)
				if model.water_sources.has(cell + Vector3i.RIGHT) or model.water_sources.has(cell + Vector3i.LEFT):
					mesh.size.x = Nav.CELL_SIZE + 0.02
				water.mesh = mesh
			else:
				water.mesh = bed
				water.scale = Vector3(0.9, 1, 0.55)
			water.position.y = 0.055
			water.material_override = puddle_material() if source.kind=="puddle" else material(Palette.WATER_BLUE)
			water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(water)
			var body := StaticBody3D.new()
			body.name = "Picking"
			body.set_meta("cell", cell)
			body.set_meta("kind", source.kind)
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.85, 0.16, 0.85)
			collision.shape = shape
			collision.position.y = 0.08
			body.add_child(collision)
			root.add_child(body)
			sources[cell] = root
		var water_surface: MeshInstance3D = sources[cell].get_node("Water")
		var amount: int = source.inventory.count("water")
		water_surface.visible = amount > 0
		# Solid islands deliberately have flat soil samples, so pool_mesh returns
		# null there. Keep a visible shallow pool on their actual walking surface.
		var solid_island := preload("res://scripts/settlement/solid_islands.gd").enabled(model)
		if solid_island and source.kind=="puddle":
			sources[cell].get_node("Bed").hide()
			sources[cell].position=Vector3(cell)
			water_surface.position=Vector3.ZERO; water_surface.scale=Vector3.ONE
			if sources[cell].get_meta("basin_amount",-1)!=amount:
				sources[cell].set_meta("basin_amount",amount)
				water_surface.mesh=preload("res://scripts/settlement/puddle_basin.gd").water(cell,model.world_seed,float(amount)/source.inventory.capacity)
		elif model.soil_enabled and source.kind == "puddle":
			sources[cell].get_node("Bed").hide()
			var state := [model.soil_revision, amount]
			if sources[cell].get_meta("soil_state", []) != state:
				sources[cell].set_meta("soil_state", state)
				water_surface.mesh = pool_mesh(model, cell, float(amount) / source.inventory.capacity)
				water_surface.position = Vector3.ZERO
				water_surface.scale = Vector3.ONE
				sources[cell].get_node("Picking").position.y = model.navigation.surface_height(cell, Nav.point(cell)) - Nav.point(cell).y
		else:
			if source.kind == "puddle":
				var bed: MeshInstance3D=sources[cell].get_node("Bed")
				bed.visible=amount>0; water_surface.mesh=bed.mesh
				bed.position.y=0.006
				bed.scale=Vector3.ONE
				water_surface.position=Vector3(0,0.012,0)
				var fill: float = 0.55+0.45*float(amount)/source.inventory.capacity
				water_surface.scale=Vector3(fill,1,fill)
				bed.scale=Vector3(fill*0.98,1,fill*0.98)
			else: water_surface.scale.x = 0.55 + 0.45 * float(amount) / source.inventory.capacity
			if model.soil_enabled:
				sources[cell].position = model.navigation.surface_point(cell)

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color)
	result.roughness = 0.7
	if preload("res://scripts/settlement/illustration_style.gd").enabled:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

# The rim is the waterline's intersection with the four soil triangles.
# Round convex corners inward, keeping every water vertex inside the real hollow.
func pool_mesh(model, cell: Vector3i, fraction: float) -> ArrayMesh:
	var heights: Array = model.soil_shapes.get(cell, [])
	if heights.size() != 5 or fraction <= 0.0: return null
	var levels: Vector2 = model.Soil.pool_levels(model, cell)
	if levels.y - levels.x < 0.005: return null
	var level := lerpf(levels.x, levels.y - 0.002, clampf(fraction, 0.0, 1.0))
	var outline := PackedVector2Array()
	for index in 4:
		outline.append(model.Soil.OFFSETS[4].lerp(model.Soil.OFFSETS[index],(level-heights[4])/(heights[index]-heights[4])))
	var rounded := PackedVector2Array()
	for index in outline.size():
		var previous := outline[posmod(index-1,outline.size())]
		var corner := outline[index]
		var next := outline[(index+1)%outline.size()]
		if (corner-previous).cross(next-corner)<=0.0:
			rounded.append(corner) # Preserve concave banks instead of crossing dry soil.
			continue
		var a := corner.lerp(previous,0.28)
		var b := corner.lerp(next,0.28)
		for step in 7:
			var t := float(step)/6.0
			rounded.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
	var indices := Geometry2D.triangulate_polygon(rounded)
	if indices.is_empty(): return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var point := rounded[index]
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(point.x,level-cell.y,point.y))
	return st.commit()

# A flush, asymmetric water patch: no cylindrical lip to resemble a dug Well.
static func puddle_mesh(cell: Vector3i, seed_value: int) -> ArrayMesh:
	var phase := float(posmod(hash([seed_value,cell]),10000))/10000.0*TAU
	var outline := PackedVector2Array()
	for i in 40:
		var angle := TAU*float(i)/40.0
		var radius := 1.0+0.09*sin(angle*3.0+phase)+0.05*cos(angle*5.0-phase)
		outline.append((Vector2(cos(angle)*0.40,sin(angle)*0.29)*radius).rotated(phase))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		for point in [Vector2.ZERO,outline[i],outline[(i+1)%outline.size()]]:
			st.set_normal(Vector3.UP); st.add_vertex(Vector3(point.x,0,point.y))
	return st.commit()

static func puddle_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader=preload("res://shaders/island_water.gdshader")
	result.set_shader_parameter("shallow_colour",Palette.WATER_BLUE)
	result.set_shader_parameter("puddle_surface",true)
	result.set_shader_parameter("wave_strength",0.0)
	return result
