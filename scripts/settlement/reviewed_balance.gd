extends RefCounted
## User-reviewed Numbers data. Keep saved resource IDs stable (grain=Hay, block=Slab).
const PATH := "res://data/settlement/reviewed_balance.json"
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
static var buildings: Dictionary = _index()

static func _index() -> Dictionary:
	var result := {}
	for row: Dictionary in data.buildings: result[row.id] = row
	return result

static func has(kind: String) -> bool:
	return buildings.has(kind)

static func size(kind: String) -> Vector3:
	var s: Array = buildings[kind].size_m
	return Vector3(s[0], s[2], s[1])

static func cost(kind: String) -> Dictionary:
	var result := {}
	for resource: String in buildings[kind].cost: result[resource] = int(buildings[kind].cost[resource])
	return result

static func capacity(kind: String, fallback := 4) -> int:
	var value: Variant = buildings.get(kind, {}).get("capacity")
	return fallback if value == null else int(value)
