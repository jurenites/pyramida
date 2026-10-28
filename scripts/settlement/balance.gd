extends RefCounted
## Text configuration for the active settlement. No dependency on world/UI state.
const SETTINGS_PATH := "res://game_settings.cfg"
const SettingsFile = preload("res://scripts/settings_file.gd")
const LEGACY_SECTIONS := ["CONSTRUCTION_RECIPES", "WORKSHOP_RECIPES", "LABOUR",
	"CITIZEN_MOVEMENT", "WORLD_TIMING"]
const MAX_ITEMS := 10000
const BUILDINGS := ["platform", "stairs", "garden", "soil_bed", "stockpile",
	"goods_rack", "small_warehouse", "stone_storage", "waterworks", "house",
	"hay_field", "windmill", "road", "well", "school", "pantry", "log_shed",
	"hay_barn", "sawmill", "mine_camp", "masonry", "workshop"]
const COLLECTIONS := ["tree", "berry", "stone", "water", "hay", "vegetables", "grass"]
const GENERAL := {
	"day_seconds": 360.0, "work_speed_multiplier": 1.0, "workshop_speed_multiplier": 1.5,
	"walk_speed": 2.25, "road_speed_multiplier": 1.35,
	"sowing_seconds": 3.0, "watering_seconds": 1.5, "eating_seconds": 2.0,
	"crop_growth_seconds": 24.0, "tree_growth_seconds": 96.0, "palm_growth_seconds": 120.0,
	"bush_seedling_seconds": 24.0, "shade_growth_multiplier": 0.1,
	"berry_regrowth_seconds": 720.0, "birth_interval_seconds": 120.0, "childhood_seconds": 1080.0,
}
static var _data: Dictionary = load_file(SETTINGS_PATH)

static func number(key: String) -> float:
	return float(_data.general[key])

static func construction_seconds(kind: String) -> float:
	return float(_data.construction.get(kind, {}).get("seconds_per_material", 2.0))

static func gathering(kind: String) -> Dictionary:
	return _data.gathering[kind].duplicate()

static func production(kind: String) -> Dictionary:
	return _data.production[kind].duplicate()

static func load_file(path: String) -> Dictionary:
	var construction := {}
	for kind in BUILDINGS:
		construction[kind] = {"seconds_per_material": 2.0}
	var collection := {}
	for kind in COLLECTIONS:
		collection[kind] = {"seconds_per_action": 3.0}
	var factories := {
		"sawmill": {"seconds_per_batch": 5.0, "output_items": 1, "automatic_stock_target": 12},
		"windmill": {"seconds_per_batch": 4.0, "output_items": 3, "automatic_stock_target": 24},
		"masonry": {"seconds_per_batch": 6.0, "output_items": 1, "automatic_stock_target": 12},
	}
	var result := {"general": GENERAL.duplicate(), "construction": construction,
		"gathering": collection, "production": factories, "warnings": []}
	var sections := {"general": result.general, "construction": {}}
	for kind in BUILDINGS:
		sections.construction[kind] = construction[kind].seconds_per_material
	for kind in COLLECTIONS:
		sections["gathering." + kind] = collection[kind]
	for kind in factories:
		sections["production." + kind] = factories[kind]
	var parsed := SettingsFile.read(path)
	var config: ConfigFile = parsed.config
	if not parsed.warnings.is_empty():
		for warning: String in parsed.warnings: _warn(result.warnings, warning)
		return result
	for section in config.get_sections():
		if section in LEGACY_SECTIONS: continue
		if not sections.has(section):
			_warn(result.warnings, "%s: unknown section [%s]" % [path, section])
			continue
		var defaults: Dictionary = sections[section]
		for key in config.get_section_keys(section):
			if not defaults.has(key):
				_warn(result.warnings, "%s: unknown setting %s/%s" % [path, section, key])
				continue
			var value: Variant = config.get_value(section, key)
			var integral: bool = defaults[key] is int
			var minimum := 0.0 if key in ["shade_growth_multiplier", "automatic_stock_target"] else (1.0 if integral else 0.001)
			var maximum := float(MAX_ITEMS) if integral else 1000000.0
			if not (value is float or value is int) or not is_finite(float(value)) or float(value) < minimum or float(value) > maximum or (integral and float(value) != floorf(float(value))):
				var reason: String = parsed.errors.get(section + "." + key, "number outside allowed range or wrong type")
				_warn(result.warnings, "%s: invalid %s/%s (%s); using default" % [path, section, key, reason])
				continue
			defaults[key] = int(value) if integral else float(value)
	for kind in BUILDINGS:
		construction[kind].seconds_per_material = sections.construction[kind]
	if not config.has_section_key("general", "berry_regrowth_seconds"):
		result.general.berry_regrowth_seconds = result.general.day_seconds * 2.0
	if not config.has_section_key("general", "childhood_seconds"):
		result.general.childhood_seconds = result.general.day_seconds * 3.0
	return result

static func _warn(warnings: Array, message: String) -> void:
	warnings.append(message)
	push_warning("Game balance: " + message)

