extends RefCounted
## Seeded facade grammar: fixed room interfaces, structural/service clearance first.
const Rules = preload("res://scripts/settlement/modular_house_rules.gd")
const P = preload("res://scripts/game_palette.gd")
const ResourcePalette = preload("res://scripts/settlement/resource_palette.gd")
const SUPPORT_CLEARANCE := 0.16
const WINDOW_WIDTH := 0.90
const WINDOW_OFFSET := 0.30
const SHAFT := AABB(Vector3(-1.03, 0, -1.03), Vector3(0.76, 4.8, 0.76))

static func wall_colour(height: float) -> Color:
	# One horizontal shade per two-metre storey, shared across all rooms and seeds.
	var storey:=maxi(0,floori(height/2.0))
	return P.SAND_SURFACE.darkened(0.22*pow(0.65,storey))

static func aperture(wall: Dictionary) -> AABB:
	var size := Vector3(wall.width, 0.72, 0.22)
	var local := Vector3(wall.offset, 1.25, 0)
	var pose := Transform3D(Basis(Vector3.UP, wall.yaw), wall.center)
	return pose * AABB(local - size / 2, size)

static func clear_window(wall: Dictionary, supports: Array[Dictionary], tier: int) -> bool:
	var space := aperture(wall).grow(SUPPORT_CLEARANCE)
	if tier == 0 and space.intersects(SHAFT): return false
	for member in supports:
		if space.intersects_segment(member.a, member.b): return false
	return true

static func generate(records: Array[Dictionary], seed_: int, tier: int) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_ + 751
	var supports := Rules.supports(records)
	var reserved := supports.duplicate(true)
	for record in records:
		for x in [0.06, 1.94]:
			for z in [0.06, 1.94]:
				var foot: Vector3 = record.origin + Vector3(x, 0, z)
				reserved.append({"a": foot, "b": foot + Vector3.UP * 1.96})
	var result := {"rooms": [], "supports": supports, "seed": seed_, "tier": tier}
	for record in records:
		var walls: Array[Dictionary] = []
		var definitions := [
			[Vector3(0, 0, 1), PI / 2, "window"],
			[Vector3(2, 0, 1), PI / 2, "door" if record.id == 0 else "window"],
			[Vector3(1, 0, 0), 0.0, "window"],
			[Vector3(1, 0, 2), 0.0, "door" if record.id != 1 else "window"]]
		for side in 4:
			var normal: Vector3 = [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK][side]
			var neighbours := records.filter(func(other): return other.origin.is_equal_approx(record.origin + normal * 2))
			if not neighbours.is_empty() and neighbours[0].id < record.id: continue
			var spec: Array = definitions[side]
			if not neighbours.is_empty(): spec[2] = "door"
			elif record.id == 0 and side == 3: spec[2] = "door"
			elif record.origin.y == 2:
				var outside: Vector3 = record.origin + Vector3(1, 0, 1) + normal * 1.5
				spec[2] = "door" if Rules.terrace_tiles(records).any(func(tile): return absf(tile.x - outside.x) < 0.6 and absf(tile.z - outside.z) < 0.6) else "window"
			else: spec[2] = "window"
			var wall := {"side": side, "center": record.origin + spec[0], "yaw": spec[1], "opening": spec[2], "offset": 0.0, "width": 0.84}
			if wall.opening == "window":
				wall.opening = ""
				var candidates := [-WINDOW_OFFSET, 0.0, WINDOW_OFFSET]
				var start := rng.randi_range(0, 2)
				for i in 3:
					wall.offset = candidates[(start + i) % 3]; wall.width = WINDOW_WIDTH
					if clear_window(wall, reserved, tier): wall.opening = "window"; break
			walls.append(wall)
		# Keep existing seeded roof shapes unchanged when removing random wall paint.
		rng.randi_range(0,1)
		result.rooms.append({"record": record, "walls": walls,
			"color": wall_colour(record.origin.y),
			"roof_slope": [-0.10, -0.06, 0.06, 0.10][rng.randi_range(0, 3)],
			"roof_overhang": [0.12, 0.19, 0.26][rng.randi_range(0, 2)]})
	return result

static func brick_flue(records: Array[Dictionary]) -> Array[Vector3]:
	var through_upper := records.any(func(room): return room.origin.y == 2 and Rules.bounds(room).has_point(Vector3(-0.65, 2.1, -0.65)))
	return [Vector3(-0.65, 0.75, -0.65), Vector3(-0.65, 4.8 if through_upper else 2.8, -0.65)]
