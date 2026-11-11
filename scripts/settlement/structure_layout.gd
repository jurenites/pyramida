extends RefCounted
## Completed metre frames share one deck/headroom rule with rendering and walking.

static func kind_at(world, cell: Vector3i) -> String:
	return world.buildings.get(cell, {}).get("kind", "")

static func has_deck(world, cell: Vector3i) -> bool:
	if kind_at(world, cell) != "support" or kind_at(world, cell + Vector3i.UP) == "stair": return false
	var cells := column(world, cell)
	var phase := posmod(cells[0].y + 1, 2)
	for member in cells:
		if world.buildings[member].has("deck_phase"):
			phase = int(world.buildings[member].deck_phase)
			return posmod(cell.y, 2) == phase
	return cells.size() == 1 or posmod(cell.y, 2) == phase

static func column(world, cell: Vector3i) -> Array[Vector3i]:
	var base := cell
	while kind_at(world, base + Vector3i.DOWN) == "support": base += Vector3i.DOWN
	var result: Array[Vector3i] = []
	while kind_at(world, base) == "support":
		result.append(base)
		base += Vector3i.UP
	return result

static func passage_open(world, cell: Vector3i) -> bool:
	# Two open frame metres give a resident headroom beneath the top deck.
	# A stair starting just one metre up is too low to walk under.
	return kind_at(world, cell) == "support" and not has_deck(world, cell) and kind_at(world, cell + Vector3i.UP) != "stair"

static func removes_lower_deck(world, plan: Dictionary) -> bool:
	var below: Vector3i = plan.cell + Vector3i.DOWN
	if plan.kind not in ["support", "stair"] or not has_deck(world, below): return false
	if plan.kind == "stair": return true
	# Only converting the first solitary Support to a column changes its floor.
	# Later modules preserve the column's existing two-metre rhythm.
	var cells := column(world, below)
	return cells.size() == 1 and not world.buildings[below].has("deck_phase")

static func restore_error(world, cell: Vector3i) -> String:
	if kind_at(world, cell) != "support": return "Support required"
	if kind_at(world, cell + Vector3i.UP) == "stair": return "Stair passage must stay open"
	if has_deck(world, cell): return "Deck already present"
	var cells := column(world, cell)
	for member in cells:
		if world.Relocation.locked(world, member): return "Finish moving first"
		for plan: Dictionary in world.plans.values():
			if plan.cell == member and not world.Deconstruction.is_salvage(plan): return "Finish construction first"
		var next_deck := posmod(member.y, 2) == posmod(cell.y, 2) and kind_at(world, member + Vector3i.UP) != "stair"
		if next_deck == has_deck(world, member): continue
		if not next_deck and world.RopeBridges.supports_bridge(world, member, "support"): return "Move or remove the attached bridge first"
		var floor_y := float(member.y + 1)
		var volume := AABB(Vector3(member.x - 0.7, floor_y - 1.4, member.z - 0.7), Vector3(1.4, 1.5, 1.4))
		for worker: Dictionary in world.workers:
			if volume.has_point(worker.position): return "Clear the changing floors first"
			var route: Array = worker.get("rescue_route", worker.get("clearance_route", worker.route))
			var index: int = worker.get("rescue_index", worker.get("clearance_index", worker.route_index))
			if index < route.size():
				var path: Array = worker.get("rescue_paths", {}).get(worker.cell, {}).get(route[index], world.navigation.room_paths.get(worker.cell, {}).get(route[index], [worker.position, world.navigation.surface_point(route[index])]))
				for i in range(1, path.size()):
					if volume.intersects_segment(path[i - 1], path[i]) != null: return "Clear the changing floors first"
	return ""

static func restore_deck(world, cell: Vector3i) -> bool:
	world.last_message = restore_error(world, cell)
	if not world.last_message.is_empty(): return false
	for member in column(world, cell): world.buildings[member].deck_phase = posmod(cell.y, 2)
	world.rebuild_navigation()
	return true

static func restoring_deck_occupied(world, cell: Vector3i) -> bool:
	if kind_at(world, cell) not in ["support", "stair"] or kind_at(world, cell + Vector3i.DOWN) != "support": return false
	# Removing this upper module restores the deck below. Wait until bodies and
	# the currently traversed edge are clear, including the lower stair flight.
	var volume := AABB(Vector3(cell) + Vector3(-0.68, -1.4, -0.68), Vector3(1.36, 1.45, 1.36))
	for worker: Dictionary in world.workers:
		if volume.has_point(worker.position): return true
		var route: Array = worker.get("rescue_route", worker.get("clearance_route", worker.route))
		var index: int = worker.get("rescue_index", worker.get("clearance_index", worker.route_index))
		if index >= route.size(): continue
		var next: Vector3i = route[index]
		var path: Array = worker.get("rescue_paths", {}).get(worker.cell, {}).get(next, world.navigation.room_paths.get(worker.cell, {}).get(next,
			[worker.position, world.navigation.surface_point(next)]))
		for i in range(1, path.size()):
			if volume.intersects_segment(path[i - 1], path[i]) != null: return true
	return false

static func configure_navigation(world, surfaces: Dictionary) -> void:
	var nav = world.navigation
	nav.support_poses.clear()
	for cell: Vector3i in world.buildings:
		if has_deck(world, cell):
			surfaces[cell + Vector3i.UP] = true
			var data: Dictionary = world.buildings[cell]
			if data.has("support_yaw") or data.has("support_group"):
				nav.support_poses[cell+Vector3i.UP]=Transform3D(Basis(Vector3.UP,float(data.get("support_yaw",0.0))),Vector3(cell+Vector3i.UP)+data.get("placement_offset",Vector3.ZERO))
				nav.support_poses[cell+Vector3i.UP].origin.y = preload("res://scripts/settlement/support_foundation.gd").deck_height(world, cell, data.get("placement_offset", Vector3.ZERO), float(data.get("support_yaw",0.0)))

static func connect_stairs(world, surfaces: Dictionary) -> void:
	var nav = world.navigation
	for cell: Vector3i in world.buildings:
		if kind_at(world, cell) != "stair": continue
		var run: Vector3i = world.DIRECTIONS[int(world.buildings[cell].direction)]
		var lower := cell - run; var upper := cell + run + Vector3i.UP
		if not surfaces.has(lower) or not surfaces.has(upper) or nav.blocked.has(lower) or nav.blocked.has(upper): continue
		var shift := preload("res://scripts/settlement/structure_elevation.gd").base_shift(world,cell,"stair")
		if absf(nav.surface_height(lower, Vector3(lower)) - float(lower.y) - shift) > 0.08 or absf(nav.surface_height(upper, Vector3(upper)) - float(upper.y) - shift) > 0.08: continue
		# Walk up the actual one-metre flight, with level approaches at both ends.
		# In a stair/support/stair column the flights retain separate endpoints.
		var center := Vector3(cell) + Vector3.UP * shift; var along := Vector3(run)
		world.RoomNavigation.add_path(nav, lower, upper, [nav.surface_point(lower),
			center - along * 0.5, center + along * 0.5 + Vector3.UP, nav.surface_point(upper)])
