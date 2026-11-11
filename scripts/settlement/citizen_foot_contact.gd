extends RefCounted
## Render-only two-bone IK. Contacts use the terrain triangles and authored rungs,
## never a physics ray that could mistake a roof above the citizen for the floor.
const Indoor = preload("res://scripts/settlement/indoor_stair_contact.gd")
var indoor: Dictionary = {}

static var rung_cache: Dictionary = {}
var planted: Dictionary = {}
var was_stance: Dictionary = {}
var context := ""
var connector: Dictionary = {}
var contacts: Dictionary = {}

func reset() -> void:
	planted.clear()
	was_stance.clear()
	contacts.clear()
	context = ""

static func ladder(nav, worker: Dictionary) -> Dictionary:
	var route: Array = worker.get("route", [])
	var index: int = worker.get("route_index", 0)
	if index >= route.size(): return {}
	var a: Vector3i = worker.cell
	var b: Vector3i = route[index]
	var cell = nav.ladder_cell(a, b)
	if cell == null: return {}
	var low: Vector3 = nav.surface_point(a if a.y < b.y else b)
	var high: Vector3 = nav.surface_point(b if a.y < b.y else a)
	var direction := Vector3(high.x-low.x, 0, high.z-low.z).normalized()
	return {"cell": cell, "direction": direction, "low": low, "high": high,
		"basis": Basis(Vector3.UP, atan2(-direction.z, direction.x)),
		"rise": roundi(high.y-low.y)}

static func rungs(rise: int) -> Array:
	if not rung_cache.has(rise):
		var scene: Node3D = load("res://data/settlement/stairs_1m.tscn" if rise == 1 else "res://data/settlement/stairs.tscn").instantiate()
		var result := []
		for part in scene.get_children():
			if part is MeshInstance3D and part.visible and str(part.name).begins_with("LadderRung"):
				var box: AABB = part.transform * part.mesh.get_aabb()
				result.append(Vector3(box.get_center().x, box.end.y, 0))
		rung_cache[rise] = result
		scene.free()
	return rung_cache[rise]

func support(nav, worker: Dictionary, point: Vector3) -> Vector3:
	if not indoor.is_empty(): return Indoor.support(indoor, point)
	if not connector.is_empty():
		var origin: Vector3 = nav.surface_point(connector.cell)
		var local: Vector3 = connector.basis.inverse() * (point-origin)
		if local.x > -1.0 and local.x < 1.0:
			var nearest := Vector3.ZERO
			var distance := INF
			for rung: Vector3 in rungs(connector.rise):
				if absf(rung.x-local.x) < distance:
					distance = absf(rung.x-local.x)
					nearest = rung
			local.x = nearest.x
			local.y = nearest.y
			local.z = clampf(local.z, -0.35, 0.35)
			return origin + connector.basis * local
		point.y = connector.low.y if local.x <= -1.0 else connector.high.y
		return point
	var cell := Vector3i(roundi(point.x/nav.CELL_SIZE), worker.get("cell", Vector3i.ZERO).y, roundi(point.z/nav.CELL_SIZE))
	if nav.surfaces.has(cell) or nav.terrain_shapes.has(cell):
		point.y = nav.surface_height(cell, point)
	else:
		# Preserve the route's floor at edges rather than snapping to another storey.
		point.y = nav.surface_height(worker.cell, point)
	return point

func apply(actor: Node3D, worker: Dictionary, nav, _delta: float, teleport: bool) -> void:
	if nav == null: return
	if teleport: reset()
	connector = ladder(nav, worker)
	indoor = Indoor.active(nav, worker)
	var stepped := not connector.is_empty() or not indoor.is_empty()
	var key := str(indoor.get("key",connector.get("cell", "ground"))) + ":" + str(worker.get("cell", Vector3i.ZERO).y) + ":" + str(nav.revision)
	if key != context:
		planted.clear(); was_stance.clear(); context = key
	var body: Node3D = actor.body
	var size: float = body.scale.x
	var gait = body.Gait
	var cycle: float = actor.phase / TAU
	contacts.clear()
	# Compute targets before changing the root. The gait lifts only the swing foot.
	for side in [-1, 1]:
		var bone := 7 if side < 0 else 9
		var phase := cycle + (0.5 if side > 0 else 0.0)
		var path: Vector2 = gait.foot_target(phase)
		var stance_fraction: float = 0.5 if stepped else gait.stance_fraction
		var stance: bool = actor.walk_blend < 0.05 or fposmod(phase, 1.0) < stance_fraction
		var hip: Vector3 = actor.skeleton.get_bone_rest(bone).origin
		var nominal: Vector3 = actor.global_position + body.basis * Vector3(hip.x, 0, -path.x * actor.walk_blend)
		var target := support(nav, worker, nominal)
		if stance:
			if actor.walk_blend < 0.05 or not was_stance.get(side, false) or not planted.has(side): planted[side] = target
			# Compressed simulation speeds can outrun a short limb. Replant within
			# reach instead of stretching the mesh or leaving it above the surface.
			var old: Vector3 = planted[side]
			if Vector2(old.x-nominal.x, old.z-nominal.z).length() > 0.16*size:
				planted[side] = target
			target = planted[side]
		else:
			# Interpolate from the last support to the next landing, clearing rungs.
			var t := clampf((fposmod(phase, 1.0)-stance_fraction)/(1.0-stance_fraction), 0, 1)
			var landing: Vector3 = actor.global_position + body.basis * Vector3(hip.x, 0, -gait.half_step)
			landing = support(nav, worker, landing)
			target = (planted.get(side, target) as Vector3).lerp(landing, smoothstep(0.0, 1.0, t))
			var ground := support(nav, worker, target)
			target.y = maxf(target.y, ground.y) + sin(PI*t) * (0.10 if stepped else gait.clearance)*size
		was_stance[side] = stance
		contacts[side] = {"point": target, "stance": stance}
	# Lower the pelvis enough for the lower leg to reach without lengthening bones.
	var root_y := INF
	for side in [-1, 1]:
		if not contacts[side].stance: continue
		var hip: Vector3 = actor.skeleton.get_bone_rest(7 if side < 0 else 9).origin
		var p: Vector3 = contacts[side].point
		var hip_world: Vector3 = actor.global_position + body.basis * hip
		var horizontal := Vector2(p.x-hip_world.x, p.z-hip_world.z).length()
		var reach := 0.300*size
		root_y = minf(root_y, p.y + 0.03*size + sqrt(maxf(0.002, reach*reach-horizontal*horizontal)) - hip.y*size)
	# Follow continuous travel while allowing a planted knee to flex. Bound the
	# crouch so a short child cannot fold its leg above the hip on a high rung.
	var lowest_root := -INF
	for side in [-1, 1]:
		if contacts[side].stance: lowest_root = maxf(lowest_root, contacts[side].point.y - 0.10*size)
	root_y = minf(root_y, maxf(lowest_root, actor.global_position.y - 0.015*size))
	body.position.y = root_y - actor.global_position.y
	for side in [-1, 1]:
		var knee := 8 if side < 0 else 10
		var target: Vector3 = body.to_local(contacts[side].point + Vector3.UP*0.03*size)
		var lift: float = contacts[side].point.y - support(nav, worker, contacts[side].point).y if not stepped else 0.0
		# Correct using the actual rounded sole, rather than an imaginary flat foot.
		for iteration in 5:
			solve_leg(body, side, target)
			var posed: Transform3D = body.bone_pose(knee) * body.get_node("Surface").skin.get_bind_pose(knee)
			var gap := INF
			for vertex: Vector3 in body.get_meta("sole_samples")[knee]:
				var world: Vector3 = body.to_global(posed * vertex)
				var floor_y: float = contacts[side].point.y
				if not stepped: floor_y = support(nav, worker, world).y + lift
				gap = minf(gap, world.y-floor_y)
			if absf(gap-0.003) < 0.00005: break
			target.y += (0.003-gap)/size
		solve_leg(body, side, target)
	actor.skeleton.force_update_all_bone_transforms()

static func solve_leg(body: Node3D, side: int, target: Vector3) -> void:
	var skeleton: Skeleton3D = body.get_node("Skeleton3D")
	var hip := 7 if side < 0 else 9
	var start := skeleton.get_bone_rest(hip).origin
	var first_rest := skeleton.get_bone_rest(hip+1).origin
	var second_rest := Vector3(0, -0.16, 0)
	var reach := target-start
	var a := first_rest.length()
	var b := second_rest.length()
	var distance := clampf(reach.length(), 0.02, a+b-0.0001)
	var direction := reach.normalized()
	var along := (a*a-b*b+distance*distance)/(2*distance)
	var forward := Vector3.FORWARD
	var pole := (forward-direction*forward.dot(direction)).normalized()
	var joint := start + direction*along + pole*sqrt(maxf(0,a*a-along*along))
	var upper := (joint-start).normalized()
	var lower := (start+direction*distance-joint).normalized()
	var rotation := Quaternion(first_rest.normalized(), upper)
	var leg: Node3D = body.get_node("LeftLeg" if side < 0 else "RightLeg")
	leg.quaternion = rotation
	leg.get_node("Knee").quaternion = Quaternion(second_rest.normalized(), rotation.inverse()*lower)
	skeleton.set_bone_pose_rotation(hip, leg.quaternion)
	skeleton.set_bone_pose_rotation(hip+1, leg.get_node("Knee").quaternion)
