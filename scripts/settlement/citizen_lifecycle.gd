extends RefCounted
## Childhood uses simulation time, including pause/speed and saved progress.
const Economy = preload("res://scripts/settlement/economy.gd")

static func adulthood_seconds() -> float:
	return preload("res://scripts/settlement/balance.gd").number("childhood_seconds")

static func is_adult(citizen: Dictionary) -> bool:
	return citizen.get("life_stage", "adult") == "adult"

static func restore_defaults(citizen: Dictionary) -> void:
	# Existing saves contain three adults; do not turn an active worker into a child.
	citizen.role = citizen.get("role", "auto")
	citizen.assigned_plan_id = citizen.get("assigned_plan_id", -1)
	citizen.life_stage = citizen.get("life_stage", "adult")
	citizen.growth_seconds = float(citizen.get("growth_seconds", 0.0))
	citizen.appearance = int(citizen.get("appearance", citizen.id % 3))
	citizen.cloth_color = int(citizen.get("cloth_color", citizen.id % 5))

static func valid(citizen: Dictionary) -> bool:
	var growth: Variant = citizen.get("growth_seconds", 0.0)
	return (not citizen.has("home_cell") or citizen.home_cell is Vector3i) \
		and citizen.get("life_stage", "adult") in ["child", "adult"] \
		and (growth is int or growth is float) and is_finite(float(growth)) and growth >= 0 \
		and citizen.get("role", "auto") in Economy.ROLES \
		and citizen.get("assigned_plan_id", -1) is int and citizen.get("assigned_plan_id", -1) >= -1 \
		and citizen.get("appearance", 0) in [0, 1, 2, 3] \
		and citizen.get("cloth_color", 0) in [0, 1, 2, 3, 4]

static func tick(world, citizen: Dictionary, delta: float) -> void:
	if not is_adult(citizen):
		citizen.growth_seconds = float(citizen.get("growth_seconds", 0.0)) + delta * (2.0 if Economy.count_buildings(world, "school") > 0 else 1.0)
		if citizen.growth_seconds >= adulthood_seconds():
			citizen.life_stage = "adult"
			if citizen.job.is_empty():
				citizen.route = []
				citizen.route_index = 0
				citizen.status = "idle"
			world.revision += 1
	if world.Clearance.tick(world, citizen, delta):
		# Separation must not starve the bounded job scheduler. New assignments
		# can be selected now; their movement resumes after stepping aside.
		if citizen.job.is_empty() and is_adult(citizen): world.tick_citizen_job(citizen, delta)
		return
	if is_adult(citizen) or not citizen.job.is_empty() or citizen.hunger >= 30.0:
		world.tick_citizen_job(citizen, delta)
		if is_adult(citizen) or not citizen.job.is_empty():
			return
	# Play and quiet wandering both remain autonomous, without reserving work.
	citizen.status = "growing up"
	if citizen.route_index < citizen.route.size():
		var next: Vector3i = citizen.route[citizen.route_index]
		if not world.navigation.edges.get(citizen.cell, []).has(next):
			citizen.route = []
			citizen.route_index = 0
			return
		var old: Vector3 = citizen.position
		citizen.position = old.move_toward(world.navigation.movement_target(citizen.cell, next, old), delta * world.ChildPlay.speed(world, citizen))
		if citizen.cell.y == next.y:
			citizen.position = world.navigation.ground_position(citizen.position, citizen.cell.y)
		citizen.distance += old.distance_to(citizen.position)
		if citizen.position.distance_to(world.navigation.surface_point(next)) < 0.001:
			citizen.cell = next
			citizen.route_index += 1
	elif not world.child_players.has(citizen.id) and int(citizen.growth_seconds / 4.0) != int((citizen.growth_seconds - delta) / 4.0):
		# Solitary children stay near their current neighbourhood, not the map origin.
		var neighbours: Array = world.navigation.edges.get(citizen.cell, [])
		if neighbours.is_empty(): return
		var target: Vector3i = neighbours[(citizen.id + int(citizen.growth_seconds / 4.0)) % neighbours.size()]
		if target.y == citizen.cell.y and not world.occupied(target):
			citizen.route = [citizen.cell, target]
			citizen.route_index = 1
