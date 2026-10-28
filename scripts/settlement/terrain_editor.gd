extends RefCounted
## One-metre surface-column edits. Sparse heights survive chunk regeneration.
const Catalog = preload("res://data/settlement/catalog.gd")
const MIN_HEIGHT := -36
const MAX_HEIGHT := Catalog.MAX_LEVEL
const TOOL_KINDS := ["terrain_dig", "terrain_fill"]

static func valid_cell(surface_cell: Vector3i) -> bool:
	return absi(surface_cell.x) <= Catalog.WORLD_LIMIT and absi(surface_cell.z) <= Catalog.WORLD_LIMIT and surface_cell.y >= MIN_HEIGHT and surface_cell.y <= MAX_HEIGHT

static func edit_error(world, surface_cell: Vector3i, tool_kind: String, require_revealed := true) -> String:
	if tool_kind not in TOOL_KINDS or not world.ground.has(surface_cell): return "Choose exposed sand"
	if require_revealed and not world.exploration.contains(Vector3(surface_cell)): return "Choose exposed sand"
	var next_cell := surface_cell + (Vector3i.DOWN if tool_kind == "terrain_dig" else Vector3i.UP)
	if not valid_cell(next_cell): return "Terrain height limit"
	if world.rock_blocks_build("well", surface_cell): return "This space is occupied"
	if world.terrain_shapes.has(surface_cell): return "Choose level ground"
	for ramp_cell: Vector3i in world.terrain_ramps:
		if ramp_cell == surface_cell or world.terrain_ramps[ramp_cell] == surface_cell: return "This space is occupied"
	# Never undermine foundations, plants, sources or planned structures. Check
	# their horizontal footprints at every height, including elevated supports.
	var edit_rect := Rect2(Vector2(surface_cell.x, surface_cell.z) - Vector2.ONE * 0.499, Vector2.ONE * 0.998)
	for field_name in ["buildings", "platforms", "stairs", "stores", "wells", "gardens", "soil_beds", "trees", "deposits", "vines", "water_sources"]:
		for occupied_cell: Vector3i in world.get(field_name):
			if abs(occupied_cell.x - surface_cell.x) > 3 or abs(occupied_cell.z - surface_cell.z) > 3: continue
			var building_data: Dictionary = world.buildings.get(occupied_cell, {})
			var object_kind: String = building_data.get("kind", "house")
			var object_rect: Rect2 = world.Farming.footprint(object_kind, occupied_cell, building_data.get("placement_offset", Vector3.ZERO), int(building_data.get("direction", 0)))
			if edit_rect.intersects(object_rect): return "This space is occupied"
	for plan_data: Dictionary in world.plans.values():
		var plan_rect: Rect2 = world.Farming.footprint(plan_data.kind, plan_data.cell, plan_data.get("placement_offset", Vector3.ZERO), int(plan_data.direction))
		if edit_rect.intersects(plan_rect): return "This space is occupied"
	for worker_data: Dictionary in world.workers:
		var worker_point := Vector2(worker_data.position.x, worker_data.position.z)
		if edit_rect.grow(0.3).has_point(worker_point) or (worker_data.cell.x == surface_cell.x and worker_data.cell.z == surface_cell.z):
			return "Wait until the worker clears this space"
	return ""

static func apply_edit(world, surface_cell: Vector3i, tool_kind: String, require_revealed := true) -> bool:
	world.last_message = edit_error(world, surface_cell, tool_kind, require_revealed)
	if not world.last_message.is_empty(): return false
	var next_height := surface_cell.y + (-1 if tool_kind == "terrain_dig" else 1)
	var column_cell := Vector2i(surface_cell.x, surface_cell.z)
	world.surface_edits[column_cell] = next_height
	apply_column(world, column_cell, next_height)
	world.terrain_revision += 1
	world.soil_revision += 1
	world.rebuild_navigation()
	return true

static func apply_column(world, column_cell: Vector2i, next_height: int) -> void:
	var old_surface: Vector3i = world.surface_at(column_cell.x, column_cell.y)
	world.ground.erase(old_surface)
	world.soil_shapes.erase(old_surface)
	world.terrain_shapes.erase(old_surface)
	var new_surface := Vector3i(column_cell.x, next_height, column_cell.y)
	world.terrain_heights[column_cell] = next_height
	world.ground[new_surface] = true
	if world.soil_enabled: world.soil_shapes[new_surface] = [float(next_height), float(next_height), float(next_height), float(next_height)]

static func apply_chunk(world, chunk_cell: Vector2i) -> void:
	for column_cell: Vector2i in world.surface_edits:
		if world.Generator.chunk_at(column_cell) == chunk_cell:
			apply_column(world, column_cell, int(world.surface_edits[column_cell]))

static func valid_edits(world_data: Dictionary) -> bool:
	var saved_edits: Variant = world_data.get("surface_edits", {})
	if not saved_edits is Dictionary: return false
	for column_cell: Variant in saved_edits:
		if not column_cell is Vector2i or not saved_edits[column_cell] is int: return false
		if not valid_cell(Vector3i(column_cell.x, saved_edits[column_cell], column_cell.y)): return false
	return true
