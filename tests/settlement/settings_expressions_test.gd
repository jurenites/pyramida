extends SceneTree
const Balance = preload("res://scripts/settlement/balance.gd")
const Citizens = preload("res://scripts/settlement/citizen_lifecycle.gd")
const Economy = preload("res://scripts/settlement/economy.gd")
const Inventory = preload("res://scripts/settlement/inventory.gd")
var failures: Array[String] = []
var path := "/tmp/pyramida-expressions-%d.cfg" % OS.get_process_id()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func write_settings(content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)

func _initialize() -> void:
	var original := Balance._data
	check(original.warnings.is_empty(), "Shipped expressions parse")
	check(original.general.berry_regrowth_seconds == 720 and original.general.childhood_seconds == 1080, "Default durations remain unchanged")
	check(original.general.work_speed_multiplier == 1.0 and original.general.workshop_speed_multiplier == 1.5
		and is_equal_approx(original.general.road_speed_multiplier, 1.35)
		and is_equal_approx(original.general.shade_growth_multiplier, 0.1), "Shipped percentage bonuses preserve game balance")
	write_settings("\uFEFF; References may precede their definitions.\r\n"
		+ "[general]\nberry_regrowth_seconds = day_seconds * 2 ; two days\n"
		+ "childhood_seconds = berry_regrowth_seconds + day_seconds\n"
		+ "day_seconds = (60 + 40) * 6\n"
		+ "tree_growth_seconds = 1e2 - -2\n"
		+ "[gathering.tree]\nseconds_per_action = general.day_seconds / 100\n"
		+ "[production.sawmill]\nseconds_per_batch = gathering.tree.seconds_per_action / 2\n"
		+ "output_items = 1 + 2 * 2\n"
		+ "automatic_stock_target = output_items * 4\n"
		+ "[construction]\nhouse = .5 + +1.5\n"
		+ "[WORLD_TIMING]\nBUSH_REGROWTH_SECONDS = day_seconds * 2\n"
		+ "[CONSTRUCTION_RECIPES]\nSUPPORT_RECIPE = {\"log\": 4}\n")
	var parsed := Balance.SettingsFile.read(path)
	check(parsed.errors.is_empty() and parsed.warnings.is_empty(), "Arithmetic and cross-section references resolve")
	check(parsed.config.get_value("CONSTRUCTION_RECIPES", "SUPPORT_RECIPE") == {"log": 4}, "Native recipes remain dictionaries")
	check(parsed.config.get_value("WORLD_TIMING", "BUSH_REGROWTH_SECONDS") == 1200, "Legacy timing uses the same constants")
	var tuned := Balance.load_file(path)
	check(tuned.warnings.is_empty(), "Resolved values pass validation")
	check(tuned.general.day_seconds == 600 and tuned.general.berry_regrowth_seconds == 1200, "Changing a constant updates dependent seconds")
	check(tuned.general.childhood_seconds == 1800 and tuned.general.tree_growth_seconds == 102, "Chained references and unary signs work")
	check(tuned.production.sawmill.seconds_per_batch == 3 and tuned.production.sawmill.output_items == 5 and tuned.production.sawmill.output_items is int, "Precedence and integer output validation work")
	check(tuned.production.sawmill.automatic_stock_target == 20 and tuned.construction.house.seconds_per_material == 2, "Local references and decimal literals work")
	Balance._data = tuned
	check(Citizens.adulthood_seconds() == 1800, "Childhood consumes seconds without multiplying by days again")
	var inventory := Inventory.new()
	inventory.capacity = 3
	var bush := {"inventory": inventory, "regrowth": 0.0}
	check(not Economy.grow_bush(bush, 1199), "Berry waits for the configured seconds")
	check(Economy.grow_bush(bush, 1) and inventory.count("food") == 1, "Berry regrows after exactly two configured days")
	Balance._data = original

	write_settings("[general]\n"
		+ "day_seconds = childhood_seconds\nchildhood_seconds = day_seconds\n"
		+ "berry_regrowth_seconds = day_seconds * 2\n"
		+ "walk_speed = missing_name * 2\n"
		+ "sowing_seconds = 1 / 0\n"
		+ "eating_seconds = (2 + 3\n"
		+ "tree_growth_seconds = 1e308 * 1e308\n"
		+ "watering_seconds = sin(1)\n"
		+ "[production.sawmill]\noutput_items = 3 / 2\n")
	var invalid := Balance.load_file(path)
	check(invalid.warnings.size() == 9, "Cycles, invalid references, arithmetic errors, calls and fractional counts warn")
	check(invalid.general.day_seconds == 360 and invalid.general.childhood_seconds == 1080 and invalid.general.berry_regrowth_seconds == 720, "Cycles and dependants fall back safely")
	check(invalid.general.walk_speed == 2.25 and invalid.general.sowing_seconds == 3 and invalid.general.eating_seconds == 2, "Bad formulas do not enter runtime settings")
	check(invalid.production.sawmill.output_items == 1, "Expressions cannot bypass whole-item constraints")

	write_settings("[general]\nday_seconds = 600\n")
	var partial := Balance.load_file(path)
	check(partial.general.berry_regrowth_seconds == 1200 and partial.general.childhood_seconds == 1800, "Omitted dependent settings retain the default day relationship")
	write_settings("[general]\nwalk_speed = 9\nwalk_speed = \"fast; still a string\"\n")
	var duplicate := Balance.SettingsFile.read(path)
	check(duplicate.config.get_value("general", "walk_speed") == "fast; still a string", "Last assignment and quoted semicolons are preserved")
	write_settings("[general]\nwork_speed_multiplier = +100%\nworkshop_speed_multiplier = +12.5% ; bonus\n"
		+ "road_speed_multiplier = workshop_speed_multiplier * 2\nshade_growth_multiplier = -100%\n"
		+ "sowing_seconds = 6.0 / work_speed_multiplier\n")
	var percentages := Balance.load_file(path)
	check(percentages.warnings.is_empty(), "Percentage bonuses and references pass validation")
	check(percentages.general.work_speed_multiplier == 2.0 and percentages.general.workshop_speed_multiplier == 1.125
		and percentages.general.road_speed_multiplier == 2.25 and percentages.general.shade_growth_multiplier == 0.0
		and percentages.general.sowing_seconds == 3.0, "Positive, fractional and negative percentages resolve before arithmetic")
	write_settings("[general]\nwork_speed_multiplier = -100%\nworkshop_speed_multiplier = +50%%\n"
		+ "road_speed_multiplier = +20% + 30%\nshade_growth_multiplier = -101%\n"
		+ "sowing_seconds = +50%\n[production.sawmill]\noutput_items = +100%\n")
	var bad_percentages := Balance.load_file(path)
	check(bad_percentages.warnings.size() == 6, "Malformed, out-of-range and non-multiplier percentages warn")
	check(bad_percentages.general.work_speed_multiplier == 1.0 and bad_percentages.general.workshop_speed_multiplier == 1.5
		and bad_percentages.general.road_speed_multiplier == 1.35 and bad_percentages.general.shade_growth_multiplier == 0.1
		and bad_percentages.general.sowing_seconds == 3.0 and bad_percentages.production.sawmill.output_items == 1,
		"Invalid percentages retain safe defaults")
	write_settings("[general]\nworkshop_speed_multiplier = 1.5\nwork_speed_multiplier = 0%\n")
	var compatible := Balance.load_file(path)
	check(compatible.warnings.is_empty() and compatible.general.workshop_speed_multiplier == 1.5
		and compatible.general.work_speed_multiplier == 1.0, "Existing numeric multipliers and zero-percent bonuses remain supported")
	DirAccess.remove_absolute(path)
	for message in failures: printerr("FAIL: " + message)
	if failures.is_empty(): print("PASS: settings arithmetic, dependency resolution, validation and seconds-based simulation")
	quit(int(not failures.is_empty()))
