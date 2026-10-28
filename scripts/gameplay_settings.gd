class_name GameplaySettings
extends RefCounted

## Typed access to the text-based gameplay tuning file. Uppercase public names
## mirror its UPPER_SNAKE_CASE keys so tuning values remain easy to identify.

const SETTINGS_PATH := "res://game_settings.cfg"

static var _settings := _load_settings()

static var SUPPORT_RECIPE: Dictionary = _dictionary("CONSTRUCTION_RECIPES", "SUPPORT_RECIPE", {"log": 4})
static var PLATFORM_RECIPE: Dictionary = _dictionary("CONSTRUCTION_RECIPES", "PLATFORM_RECIPE", {"log": 4, "plank": 4})
static var SAWMILL_RECIPE: Dictionary = _dictionary("CONSTRUCTION_RECIPES", "SAWMILL_RECIPE", {"log": 10})
static var ROAD_RECIPE: Dictionary = _dictionary("CONSTRUCTION_RECIPES", "ROAD_RECIPE", {"plank": 4})
static var PILE_RECIPE: Dictionary = _dictionary("CONSTRUCTION_RECIPES", "PILE_RECIPE", {})
static var WAREHOUSE_RECIPE: Dictionary = _dictionary("CONSTRUCTION_RECIPES", "WAREHOUSE_RECIPE", {"log": 4, "plank": 4})
static var SMALL_LIVABLE_RECIPE: Dictionary = _dictionary("CONSTRUCTION_RECIPES", "SMALL_LIVABLE_RECIPE", {"log": 4, "plank": 8})
static var SMALL_LIVABLE_STANDALONE_ROOF_RECIPE: Dictionary = _dictionary("CONSTRUCTION_RECIPES", "SMALL_LIVABLE_STANDALONE_ROOF_RECIPE", {"log": 4, "hay": 4})

static var SAWMILL_PLANK_INPUT: Dictionary = _dictionary("WORKSHOP_RECIPES", "SAWMILL_PLANK_INPUT", {"log": 1})
static var SAWMILL_PLANK_OUTPUT: Dictionary = _dictionary("WORKSHOP_RECIPES", "SAWMILL_PLANK_OUTPUT", {"plank": 1})
static var SAWMILL_PLANK_LABOUR_SECONDS := _number("WORKSHOP_RECIPES", "SAWMILL_PLANK_LABOUR_SECONDS", 3.0)

static var TREE_CUT_LABOUR_SECONDS := _number("LABOUR", "TREE_CUT_LABOUR_SECONDS", 3.0)
static var EXCAVATION_LABOUR_SECONDS := _number("LABOUR", "EXCAVATION_LABOUR_SECONDS", 3.0)
static var RESOURCE_GATHER_LABOUR_SECONDS := _number("LABOUR", "RESOURCE_GATHER_LABOUR_SECONDS", 3.0)
static var STORAGE_DELIVERY_LABOUR_SECONDS := _number("LABOUR", "STORAGE_DELIVERY_LABOUR_SECONDS", 1.0)
static var CONSTRUCTION_BLOCK_LABOUR_SECONDS := _number("LABOUR", "CONSTRUCTION_BLOCK_LABOUR_SECONDS", 3.0)
static var INTERRUPTED_LABOUR_VISIBILITY_SECONDS := _number("LABOUR", "INTERRUPTED_LABOUR_VISIBILITY_SECONDS", 2.0)

static var CITIZEN_BAREFOOT_WALK_SPEED := _number("CITIZEN_MOVEMENT", "CITIZEN_BAREFOOT_WALK_SPEED", 2.25)
static var GROUND_TRAVEL_COST := _number("CITIZEN_MOVEMENT", "GROUND_TRAVEL_COST", 1.35)
static var ROAD_TRAVEL_COST := _number("CITIZEN_MOVEMENT", "ROAD_TRAVEL_COST", 1.0)
static var CACTUS_TRAVEL_COST := _number("CITIZEN_MOVEMENT", "CACTUS_TRAVEL_COST", 3.0)
static var EMERGENCY_ESCAPE_DELAY_SECONDS := _number("CITIZEN_MOVEMENT", "EMERGENCY_ESCAPE_DELAY_SECONDS", 2.0)
static var MINIMUM_DELIVERY_TRAVEL_DISTANCE := _number("CITIZEN_MOVEMENT", "MINIMUM_DELIVERY_TRAVEL_DISTANCE", 0.5)

static var SIMULATION_DAY_SECONDS := preload("res://scripts/settlement/balance.gd").number("day_seconds")
static var BUSH_REGROWTH_SECONDS := _number("WORLD_TIMING", "BUSH_REGROWTH_SECONDS", 720.0)


static func construction_recipe(building_id: String) -> Dictionary:
	match building_id:
		"support":
			return SUPPORT_RECIPE.duplicate(true)
		"platform":
			return PLATFORM_RECIPE.duplicate(true)
		"sawmill":
			return SAWMILL_RECIPE.duplicate(true)
		"road":
			return ROAD_RECIPE.duplicate(true)
		"pile":
			return PILE_RECIPE.duplicate(true)
		"warehouse":
			return WAREHOUSE_RECIPE.duplicate(true)
		"small_livable":
			return SMALL_LIVABLE_RECIPE.duplicate(true)
		_:
			return {}


static func _load_settings() -> ConfigFile:
	var parsed := preload("res://scripts/settings_file.gd").read(SETTINGS_PATH)
	for warning: String in parsed.warnings: push_warning(warning)
	return parsed.config


static func _number(section: String, key: String, fallback: float) -> float:
	var value: Variant = _settings.get_value(section, key, fallback)
	if not (value is float or value is int) or not is_finite(float(value)):
		push_warning("Invalid gameplay setting %s/%s; using default" % [section, key])
		return fallback
	return maxf(0.0, float(value))


static func _dictionary(section: String, key: String, fallback: Dictionary) -> Dictionary:
	var value: Variant = _settings.get_value(section, key, fallback)
	if not value is Dictionary:
		push_error("Gameplay setting %s/%s must be a Dictionary" % [section, key])
		return fallback.duplicate(true)
	var result := {}
	for resource_kind_value in value:
		var resource_kind := str(resource_kind_value)
		var amount := maxi(0, int(value[resource_kind_value]))
		if amount > 0:
			result[resource_kind] = amount
	return result
