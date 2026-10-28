extends Node3D
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
	drop.material = material("b6d2ce")
	rain.draw_pass_1 = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emitting = false
	add_child(rain)

func sync(model) -> void:
	rain.emitting = model.weather.raining
	rain.visible = model.weather.raining
	for cell in sources.keys():
		if not model.water_sources.has(cell) or model.wells.has(cell):
			sources[cell].free()
			sources.erase(cell)
	for cell: Vector3i in model.water_sources:
		if model.wells.has(cell): continue
		var source: Dictionary = model.water_sources[cell]
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
			bed.radial_segments = 9
			var base := MeshInstance3D.new()
			base.name = "Bed"
			base.mesh = bed
			base.position.y = 0.025
			base.scale.z = 0.65
			base.material_override = material("8e987f")
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
			water.material_override = material("80b5ae")
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
		if model.soil_enabled and source.kind == "puddle":
			sources[cell].get_node("Bed").hide()
			var state := [model.soil_revision, amount]
			if sources[cell].get_meta("soil_state", []) != state:
				sources[cell].set_meta("soil_state", state)
				water_surface.mesh = pool_mesh(model, cell, float(amount) / source.inventory.capacity)
				water_surface.position = Vector3.ZERO
				water_surface.scale = Vector3.ONE
				sources[cell].get_node("Picking").position.y = model.navigation.surface_height(cell, Nav.point(cell)) - Nav.point(cell).y
		else:
			water_surface.scale.x = 0.55 + 0.45 * float(amount) / source.inventory.capacity
			if model.soil_enabled:
				sources[cell].position = model.navigation.surface_point(cell)

func material(color: String) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color)
	result.roughness = 0.7
	if preload("res://scripts/settlement/illustration_style.gd").enabled:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

# Clip each ground triangle at a horizontal waterline. The outline follows the
# actual hollow, and shrinks as buckets are collected or water evaporates.
func pool_mesh(model, cell: Vector3i, fraction: float) -> ArrayMesh:
	var heights: Array = model.soil_shapes.get(cell, [])
	if heights.size() != 5 or fraction <= 0.0: return null
	var levels: Vector2 = model.Soil.pool_levels(model, cell)
	if levels.y - levels.x < 0.005: return null
	var level := lerpf(levels.x, levels.y - 0.002, clampf(fraction, 0.0, 1.0))
	var points: Array[Vector3] = []
	for index in 5:
		var offset: Vector2 = model.Soil.OFFSETS[index]
		points.append(Vector3(offset.x, heights[index], offset.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for index in 4:
		var polygon: Array[Vector3] = [points[index], points[4], points[(index + 1) % 4]]
		var clipped: Array[Vector3] = []
		for edge in 3:
			var a := polygon[edge]
			var b := polygon[(edge + 1) % 3]
			if a.y <= level: clipped.append(a)
			if (a.y <= level) != (b.y <= level): clipped.append(a.lerp(b, (level - a.y) / (b.y - a.y)))
		for vertex in range(1, clipped.size() - 1):
			# Godot front faces use clockwise winding when viewed from above.
			for p: Vector3 in [clipped[0], clipped[vertex + 1], clipped[vertex]]:
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(p.x, level - cell.y, p.z))
				count += 1
	return st.commit() if count > 0 else null
