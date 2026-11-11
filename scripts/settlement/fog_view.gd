extends Node3D
## World-space cloud banks made from shared smooth, merged cloud shapes.
const Shape = preload("res://scripts/settlement/cloud_shape.gd")
const Palette = preload("res://scripts/game_palette.gd")
const Ocean = preload("res://scripts/settlement/ocean_surface.gd")
const SPACING := 21.0
const COAST_CLEARANCE := 6.0
const DISSOLVE_SECONDS := 1.8
var material := ShaderMaterial.new()
var bank := MultiMeshInstance3D.new()
var fading_bank := MultiMeshInstance3D.new()
var fading_material := ShaderMaterial.new()
var banks: Array[MultiMeshInstance3D] = []
var fading_banks: Array[MultiMeshInstance3D] = []
var spheres: Array[Dictionary] = []
var model_id := 0
var revision := -1
var bounds := Rect2i()
var last_camera := Transform3D()
var last_time := 0.0

func _ready() -> void:
	name = "ExplorationClouds"
	# The owner is the camera, but cloud positions belong to the world.
	top_level = true
	global_transform = Transform3D.IDENTITY
	material.shader = preload("res://shaders/settlement_fog.gdshader")
	material.set_shader_parameter("cloud_color", Palette.CLOUD)
	material.set_shader_parameter("shade_color", Palette.MORNING_SHADOW.lerp(Palette.CLOUD, 0.55))
	fading_material.shader = preload("res://shaders/settlement_cloud_fade.gdshader")
	fading_material.render_priority = 120
	for shader_material in [material, fading_material]:
		shader_material.set_shader_parameter("cloud_color", Palette.CLOUD)
		shader_material.set_shader_parameter("shade_color", Palette.MORNING_SHADOW.lerp(Palette.CLOUD, 0.72))
		shader_material.set_shader_parameter("wind_direction", Ocean.WIND_DIRECTION.normalized())
	for kind in 4:
		var opaque := bank if kind == 0 else MultiMeshInstance3D.new()
		var transparent := fading_bank if kind == 0 else MultiMeshInstance3D.new()
		opaque.multimesh = MultiMesh.new()
		opaque.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		opaque.multimesh.use_custom_data = true
		opaque.multimesh.mesh = Shape.mesh(kind)
		opaque.material_override = material
		transparent.multimesh = opaque.multimesh
		transparent.material_override = fading_material
		for node in [opaque,transparent]:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
		banks.append(opaque); fading_banks.append(transparent)

static func sphere_mesh() -> ArrayMesh:
	# Retain the old inspection entry point; the geometry is now one smooth union.
	return Shape.mesh(0)

func visible_bounds() -> Rect2i:
	var camera := get_parent() as Camera3D
	var size := Vector2(camera.get_viewport().size)
	var low := Vector2(INF, INF); var high := Vector2(-INF, -INF)
	for screen in [Vector2.ZERO, Vector2(size.x,0), size, Vector2(0,size.y)]:
		var origin := camera.project_ray_origin(screen)
		var direction := camera.project_ray_normal(screen)
		for height in [0.0, 24.0]:
			var point: Vector3 = origin + direction * ((height-origin.y)/direction.y)
			low = low.min(Vector2(point.x,point.z)); high = high.max(Vector2(point.x,point.z))
	var first := Vector2i((low / SPACING).floor()) - Vector2i.ONE * 2
	var last := Vector2i((high / SPACING).ceil()) + Vector2i.ONE * 2
	return Rect2i(first, last-first)

func cleared(exploration, at: Vector3, radius: Vector3, margin := COAST_CLEARANCE) -> bool:
	var camera := get_parent() as Camera3D
	var ray := -camera.global_basis.z
	# Clear whole spheres whose silhouettes would cover the discovered shore.
	# No screen-space cutouts or slices through individual cloud meshes.
	var projected := at + ray * (-at.y / ray.y)
	var extent := radius + Vector3(margin,0,margin)
	for centre in [at, projected]:
		for offset in [Vector3.ZERO, Vector3(extent.x,0,0), Vector3(-extent.x,0,0), Vector3(0,0,extent.z), Vector3(0,0,-extent.z)]:
			if exploration.contains(centre + offset): return true
	return false

func edge_opacity(exploration, at: Vector3, radius: Vector3, phase: float) -> float:
	# A loose translucent fringe sits beyond the clear water, backed by denser
	# clouds. This is visual clearance, never additional resource discovery.
	if cleared(exploration, at, radius, COAST_CLEARANCE + 9.0): return 0.24 + phase * 0.16
	if cleared(exploration, at, radius, COAST_CLEARANCE + 19.0): return 0.60 + phase * 0.16
	return 1.0

func rebuild(model, next_bounds: Rect2i, fresh: bool) -> void:
	var previous := {}
	if not fresh:
		for sphere in spheres: previous[sphere.key] = sphere
	spheres.clear()
	bounds = next_bounds
	for x in range(bounds.position.x,bounds.end.x):
		for z in range(bounds.position.y,bounds.end.y):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector3i(x, z, model.world_seed))
			var centre := Vector3((x+0.5)*SPACING + posmod(z,2)*SPACING*0.5 + rng.randf_range(-4.0,4.0), rng.randf_range(6.0,8.0), (z+0.5)*SPACING + rng.randf_range(-4.0,4.0))
			var size := rng.randf_range(8.5,13.5)
			var angle := rng.randf_range(-0.9,0.9)
			var rotation := Basis(Vector3.UP,angle)
			var wind_phase := rng.randf()
			var count := rng.randi_range(2,4)
			for lobe in count:
				var kind := rng.randi_range(0,3)
				var local := Vector3.ZERO
				var radius := Vector3(size*0.75,size*0.53,size*0.80)
				if lobe > 0:
					var puff := size*rng.randf_range(0.18,0.43)
					local = Vector3((-1.0 if lobe%2 == 0 else 1.0)*size*rng.randf_range(0.65,1.0),rng.randf_range(-0.5,1.0),rng.randf_range(-0.35,0.35)*size)
					radius = Vector3(puff,puff*0.75,puff*0.8)
				var at := centre + rotation * local
				var shape_bounds := Shape.mesh(kind).get_aabb()
				var reach := shape_bounds.position.abs().max(shape_bounds.end.abs()) * radius
				var extent := Vector3(absf(rotation.x.x)*reach.x+absf(rotation.z.x)*reach.z,reach.y,absf(rotation.x.z)*reach.x+absf(rotation.z.z)*reach.z)
				var key := Vector3i(x,z,lobe)
				var phase := rng.randf()
				var target := 0.0 if cleared(model.exploration,at,extent) else 1.0
				var opacity := edge_opacity(model.exploration,at,extent,phase)
				var old: Dictionary = previous.get(key,{})
				spheres.append({"kind":kind,"key":key,"at":at,"radius":radius,"extent":extent,"rotation":rotation,"phase":phase,"wind_phase":wind_phase,"target":old.get("target",target),
					"opacity":old.get("opacity",opacity),"opacity_target":opacity,
					"remaining":old.get("remaining",target),"reveal_at":old.get("reveal_at",model.time)})
	var counts := [0,0,0,0]
	for sphere in spheres:
		sphere.draw_index = counts[sphere.kind]
		counts[sphere.kind] += 1
	for kind in 4: banks[kind].multimesh.instance_count = counts[kind]
	for index in spheres.size():
		var sphere := spheres[index]
		banks[sphere.kind].multimesh.set_instance_transform(sphere.draw_index, Transform3D(sphere.rotation * Basis.from_scale(sphere.radius),sphere.at))
		write_state(index)

func write_state(index: int) -> void:
	var sphere := spheres[index]
	banks[sphere.kind].multimesh.set_instance_custom_data(sphere.draw_index,Color(sphere.remaining,sphere.wind_phase,sphere.opacity,sphere.phase))

func sync(model, enabled: bool, _focus := Vector3.ZERO) -> void:
	visible = enabled
	if not enabled: return
	var fresh: bool = model_id != model.get_instance_id()
	var camera := get_parent() as Camera3D
	var screen_centre := Vector2(camera.get_viewport().size)*0.5
	var origin := camera.project_ray_origin(screen_centre)
	var ray := camera.project_ray_normal(screen_centre)
	var camera_focus := origin + ray * (-origin.y/ray.y)
	fading_material.set_shader_parameter("camera_focus",camera_focus)
	fading_material.set_shader_parameter("camera_reach",clampf(camera.size*0.18,7.0,16.0))
	var next_bounds := visible_bounds()
	var delta := 0.0 if fresh else maxf(0.0,model.time-last_time)
	var camera_changed := last_camera != camera.global_transform
	var discovery_changed: bool = revision != model.exploration.revision
	material.set_shader_parameter("cloud_time", model.time)
	fading_material.set_shader_parameter("cloud_time", model.time)
	if fresh or next_bounds != bounds: rebuild(model,next_bounds,fresh)
	if fresh or discovery_changed or camera_changed:
		for index in spheres.size():
			var sphere := spheres[index]
			var target := 0.0 if cleared(model.exploration,sphere.at,sphere.extent) else 1.0
			if target > 0:
				sphere.opacity_target = edge_opacity(model.exploration,sphere.at,sphere.extent,sphere.phase)
				if camera_changed:
					sphere.opacity = sphere.opacity_target
					write_state(index)
			if target != sphere.target:
				sphere.target = target
				sphere.reveal_at = model.time + sphere.phase * 0.4
				# Camera clearance is immediate, including when the game is paused.
				# Actual new discovery still plays the staggered shrinking animation.
				if camera_changed and not discovery_changed:
					sphere.remaining = target
					write_state(index)
	for index in spheres.size():
		var sphere := spheres[index]
		if sphere.opacity != sphere.opacity_target:
			sphere.opacity = move_toward(sphere.opacity,sphere.opacity_target,delta)
			write_state(index)
		if sphere.remaining == sphere.target or model.time < sphere.reveal_at: continue
		var elapsed := minf(delta, model.time - float(sphere.reveal_at))
		sphere.remaining = move_toward(sphere.remaining,sphere.target,elapsed/DISSOLVE_SECONDS)
		write_state(index)
	model_id = model.get_instance_id()
	revision = model.exploration.revision
	last_camera = camera.global_transform
	last_time = model.time
