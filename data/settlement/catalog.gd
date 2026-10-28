extends RefCounted
## Shared asset contract. Metres, local +X stair run, +Y up.
## Access/utility markers also exist in the editable TSCN and GLB models.
const WORLD_RADIUS := preload("res://scripts/settlement/world_grid.gd").WORLD_RADIUS
const LEVEL_HEIGHT := preload("res://scripts/settlement/world_grid.gd").STOREY_HEIGHT
const WORLD_LIMIT := 16382
const MAX_LEVEL := 36
const CATEGORIES := {
	"housing": ["house", "hay_field", "windmill", "road", "well", "school"],
	"industry": ["small_warehouse", "stone_storage", "log_shed", "hay_barn", "sawmill", "mine_camp", "masonry", "workshop"],
	"structure": ["platform", "stairs", "stockpile", "soil_bed"],
	"nature": ["seed_vegetables", "seed_tree", "seed_bush", "seed_palm", "seed_vine"],
}
# New plans save their material recipe; the codec accepts legacy pile costs.
# Keep seed_grass contracts for old saves; it is no longer offered or ordered.
const SEEDS := ["seed_vegetables", "seed_tree", "seed_bush", "seed_grass", "seed_palm", "seed_vine"]
const COSTS := {"goods_rack": 4, "small_warehouse": 16, "stone_storage": 4, "seed_vine": 0, "seed_vegetables": 0, "seed_tree": 0, "seed_bush": 0, "seed_grass": 0, "seed_palm": 0,"platform": 4, "stairs": 3, "garden": 2, "soil_bed": 1, "stockpile": 1,
	"waterworks": 5, "house": 5, "hay_field": 3, "windmill": 2, "road": 1, "well": 6,
	"school": 10, "pantry": 8, "log_shed": 3, "hay_barn": 3, "sawmill": 3,
	"mine_camp": 5, "masonry": 10, "workshop": 10}
# Upper-floor attachment capability, not a requirement for a visible roof.
# Outdoor ground surfaces (roads, crops and stockpiles) are not rooms.
const ROOFS := ["small_warehouse", "stone_storage", "waterworks", "house", "school", "pantry", "log_shed", "hay_barn", "workshop", "windmill", "sawmill", "mine_camp", "masonry", "well"]
const NATURAL_ROOFS := ["waterworks", "house", "school", "pantry", "workshop"]
const PLACEMENT_MARGIN := 0.18

static func valid_placement_offset(kind: String, offset: Variant) -> bool:
	if kind in ["goods_rack", "small_warehouse"]: return offset is Vector3 and offset == Vector3.ZERO
	if kind == "seed_vine":
		return offset is Vector3 and offset.is_finite() and offset.y == 0.0 and absf(offset.x) <= 0.500001 and absf(offset.z) <= 0.500001
	if kind == "hay_field":
		return offset is Vector3 and (offset == Vector3.ZERO or offset == Vector3(0.5, 0, 0.5) or offset == Vector3(1, 0, 1))
	# Vector3 components are single precision; accept their rounded boundary value.
	return offset is Vector3 and offset.is_finite() and offset.y == 0.0 and absf(offset.x) <= PLACEMENT_MARGIN + 0.000001 and absf(offset.z) <= PLACEMENT_MARGIN + 0.000001 and (kind in ROOFS or offset == Vector3.ZERO)

const STORAGE := ["goods_rack", "small_warehouse", "stone_storage", "log_shed", "hay_barn", "pantry"]
const PASSABLE := ["road", "hay_field", "soil_bed", "garden"]
# Low plots fit between a platform's posts without supporting its deck.
const PLATFORM_COVERABLE := ["seed_grass", "seed_vegetables", "stockpile", "road", "hay_field", "soil_bed", "garden"]
const DEFINITIONS := {
	"goods_rack": {"size": Vector3(1, 0.65, 1), "offset": Vector3(0, 0.325, 0), "access": ["AccessFront"]},
	"small_warehouse": {"size": Vector3(1, 1, 1), "offset": Vector3(0, 0.5, 0), "access": ["AccessFront"]},
	"stone_storage": {"size": Vector3(3, 2, 3), "offset": Vector3(0, 1, 0), "access": ["AccessFront"]},
	"seed_vine": {"living": true, "size": Vector3(1, 0.35, 1), "offset": Vector3(0, 0.175, 0)},
	"vine_tree": {"living": true, "size": Vector3(0.65, 0.5, 0.65), "offset": Vector3(0, 0.25, 0)},
	"seed_tree": {"living": true, "size": Vector3(2, 0.35, 2), "offset": Vector3(0, 0.175, 0)},
	"seed_palm": {"living": true, "size": Vector3(2, 0.35, 2), "offset": Vector3(0, 0.175, 0)},
	"seed_bush": {"living": true, "size": Vector3(1.325, 0.825, 1.275), "offset": Vector3(0, 0.4125, 0)},
	"seed_grass": {"living": true, "size": Vector3(1, 0.35, 1), "offset": Vector3(0, 0.175, 0)},
	"seed_vegetables": {"living": true, "size": Vector3(2, 0.35, 2), "offset": Vector3(0, 0.175, 0)},
	"grass_patch": {"living": true, "size": Vector3(1, 0.65, 1), "offset": Vector3(0, 0.325, 0)},
	"berry": {"living": true, "size": Vector3(1.325, 0.825, 1.275), "offset": Vector3(0, 0.4125, 0)},
	"limestone": {"size": Vector3(2.6, 3.2, 2.6), "offset": Vector3(0, 1.6, 0)},
	"house": {"size": Vector3(1.96, LEVEL_HEIGHT, 1.96), "offset": Vector3(0, LEVEL_HEIGHT * 0.5, 0), "access": ["AccessFront"]},
	"hay_field": {"size": Vector3(4.0, 0.65, 4.0), "offset": Vector3(0, 0.325, 0), "access": ["AccessFront"]},
	"windmill": {"size": Vector3(2, 6, 2), "offset": Vector3(0, 3, 0), "access": ["AccessFront"]},
	"road": {"size": Vector3(1.96, 0.06, 1.96), "offset": Vector3(0, 0.03, 0), "access": ["AccessFront"]},
	"school": {"size": Vector3(1.96, LEVEL_HEIGHT, 1.96), "offset": Vector3(0, LEVEL_HEIGHT * 0.5, 0), "access": ["AccessFront"]},
	"pantry": {"size": Vector3(1.96, LEVEL_HEIGHT, 1.96), "offset": Vector3(0, LEVEL_HEIGHT * 0.5, 0), "access": ["AccessFront"]},
	"log_shed": {"size": Vector3(1, 1.5, 2), "offset": Vector3(0, 0.75, 0), "access": ["AccessFront"]},
	"hay_barn": {"size": Vector3(1, 1.5, 2), "offset": Vector3(0, 0.75, 0), "access": ["AccessFront"]},
	"sawmill": {"size": Vector3(1.96, LEVEL_HEIGHT, 1.96), "offset": Vector3(0, LEVEL_HEIGHT * 0.5, 0), "access": ["AccessFront"]},
	"mine_camp": {"size": Vector3(1.96, LEVEL_HEIGHT, 1.96), "offset": Vector3(0, LEVEL_HEIGHT * 0.5, 0), "access": ["AccessFront"]},
	"masonry": {"size": Vector3(1.96, LEVEL_HEIGHT, 1.96), "offset": Vector3(0, LEVEL_HEIGHT * 0.5, 0), "access": ["AccessFront"]},
	"workshop": {"size": Vector3(1.96, LEVEL_HEIGHT, 1.96), "offset": Vector3(0, LEVEL_HEIGHT * 0.5, 0), "access": ["AccessFront"]},
	"platform": {"size": Vector3(1.98, 0.12, 1.98), "offset": Vector3(0, -0.06, 0), "surface": true,
		"access": ["WalkCentre", "NorthEdge", "SouthEdge", "WestEdge", "EastEdge"]},
	"stairs": {"size": Vector3(2.0, LEVEL_HEIGHT, 2.0), "offset": Vector3(0, LEVEL_HEIGHT * 0.5, 0),
		"access": ["LowerEntrance", "UpperEntrance"]},
	"stockpile": {"size": Vector3(2.0, 0.3, 2.0), "offset": Vector3(0, 0.15, 0), "capacity": 32,
		"access": ["AccessFront"]},
	"soil_bed": {"size": Vector3(2.0, 0.10, 2.0), "offset": Vector3(0, 0.05, 0), "surface": true, "access": ["AccessFront"]},
	"garden": {"size": Vector3(1.8, 0.5, 1.8), "offset": Vector3(0, 0.25, 0),
		"access": ["AccessFront"], "ports": {"WaterIn": "water"}},
	"waterworks": {"size": Vector3(1.96, LEVEL_HEIGHT, 1.96), "offset": Vector3(0, LEVEL_HEIGHT * 0.5, 0), "access": ["AccessFront"], "ports": {"WaterOut": "water"}},
	"well": {"size": Vector3(0.95, LEVEL_HEIGHT, 0.95), "offset": Vector3(0, LEVEL_HEIGHT * 0.5, 0),
		"access": ["AccessFront"], "ports": {"WaterOut": "water"}},
	"tree": {"living": true, "size": Vector3(1.9, 3.72, 1.9), "offset": Vector3(0, 1.86, 0), "access": ["AccessFront"]},
}

static func title(kind: String) -> String:
	if kind == "seed_bush": kind = "berry"
	return TranslationServer.translate("settlement_object_" + kind + "_text")

static func description(kind: String) -> String:
	return TranslationServer.translate("settlement_description_" + kind + "_text")

static func in_bounds(cell: Vector3i) -> bool:
	return absi(cell.x) <= WORLD_LIMIT and absi(cell.z) <= WORLD_LIMIT and cell.y >= 0 and cell.y <= MAX_LEVEL

const RECIPES := {
	"goods_rack": {"log": 2, "plank": 2},
	"small_warehouse": {"plank": 10, "block": 6},
	"stockpile": {"stone": 1},
	"windmill": {"stone": 2}, "masonry": {"log": 5, "stone": 5},
	"school": {"plank": 6, "block": 4}, "workshop": {"plank": 6, "block": 4},
	"pantry": {"log": 4, "plank": 4},
}

static func recipe(kind: String) -> Dictionary:
	if kind in SEEDS: return {}
	return RECIPES.get(kind, {"log": COSTS.get(kind, 0)}).duplicate()

static func cost_text(kind: String) -> String:
	var parts: Array[String] = []
	for resource: String in recipe(kind):
		parts.append("%d %s" % [recipe(kind)[resource], TranslationServer.translate("settlement_resource_" + resource + "_text")])
	return " · ".join(parts)

static func building_height(kind: String) -> float:
	return 1.0 if kind in ["goods_rack", "small_warehouse"] else (6.0 if kind == "windmill" else LEVEL_HEIGHT)
