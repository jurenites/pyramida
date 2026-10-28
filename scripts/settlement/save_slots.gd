extends RefCounted
## Slot persistence is independent of UI and simulation. Writes are atomic;
## the previous valid snapshot stays available if the newest file is damaged.
const Model = preload("res://scripts/settlement/world_model.gd")
const SLOT_COUNT := 3
const AUTOSAVE_SECONDS := 30.0
var directory := "user://settlements"
var last_error := ""

func path_for(slot: int) -> String:
	return directory.path_join("slot_%d.json" % (slot + 1))

func occupied(slot: int) -> bool:
	return FileAccess.file_exists(path_for(slot)) or FileAccess.file_exists(path_for(slot) + ".bak")

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var data: Variant = parser.data
	if not data is Dictionary or data.get("format") != 1 or data.get("difficulty") not in ["normal", "easy"] or not data.get("world") is Dictionary:
		return {}
	var validation = Model.new()
	if not validation.restore(data.world) or validation.difficulty != data.difficulty:
		return {}
	return data

func read_slot(slot: int) -> Dictionary:
	last_error = ""
	if slot < 0 or slot >= SLOT_COUNT:
		return {}
	var data := _read(path_for(slot))
	if not data.is_empty():
		return data
	data = _read(path_for(slot) + ".bak")
	if not data.is_empty():
		data["recovered"] = true
		return data
	if occupied(slot):
		last_error = "settlement_slot_damaged_text"
	return {}

func write_slot(slot: int, model, view: Dictionary = {}) -> bool:
	last_error = ""
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		last_error = "settlement_autosave_failed_text"
		return false
	var path := path_for(slot)
	var temporary := path + ".tmp"
	var data := {"format": 1, "difficulty": model.difficulty, "saved_at": Time.get_unix_time_from_system(),
		"elapsed": model.time, "view": view, "world": model.snapshot()}
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "settlement_autosave_failed_text"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		last_error = "settlement_autosave_failed_text"
		return false
	# Never replace a good backup with a corrupt primary file.
	if not _read(path).is_empty():
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak.tmp")) != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".bak.tmp"), ProjectSettings.globalize_path(path + ".bak")) != OK:
			last_error = "settlement_autosave_failed_text"
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
		last_error = "settlement_autosave_failed_text"
		return false
	return true

func delete_slot(slot: int) -> bool:
	last_error = ""
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	var path := path_for(slot)
	if occupied(slot) and slot == 0:
		# A deliberate deletion must not reimport the old pre-slot save on launch.
		var marker := FileAccess.open(path + ".deleted", FileAccess.WRITE)
		if marker == null:
			last_error = "settlement_slot_delete_failed_text"
			return false
		marker.close()
	# Remove recovery and in-flight snapshots before the primary save.
	for suffix in [".tmp", ".bak.tmp", ".bak", ""]:
		var target: String = path + suffix
		if FileAccess.file_exists(target) and DirAccess.remove_absolute(ProjectSettings.globalize_path(target)) != OK:
			last_error = "settlement_slot_delete_failed_text"
			return false
	return true

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in SLOT_COUNT:
		var data := read_slot(slot)
		result.append({"slot": slot, "occupied": occupied(slot), "valid": not data.is_empty(),
			"difficulty": data.get("difficulty", ""),
			"elapsed": data.get("elapsed", 0), "saved_at": data.get("saved_at", 0)})
	return result

func import_legacy(path: String) -> void:
	if occupied(0) or FileAccess.file_exists(path_for(0) + ".deleted") or not FileAccess.file_exists(path):
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var snapshot: Variant = parser.data
	var model = Model.new()
	if snapshot is Dictionary and model.restore(snapshot):
		write_slot(0, model)

func read_settings() -> Dictionary:
	var config := ConfigFile.new()
	config.load(directory.path_join("settings.cfg"))
	return {"fullscreen": bool(config.get_value("display", "fullscreen", false)),
		"debug_mode": bool(config.get_value("debug", "enabled", false)),
		"sound_effects": clampf(float(config.get_value("audio", "sound_effects", 100.0)), 0.0, 100.0),
		"routes": bool(config.get_value("display", "routes", false)),
		"hotkeys": config.get_value("input", "hotkeys", {})}

func write_settings(values: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return false
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", values.get("fullscreen", false))
	config.set_value("debug", "enabled", values.get("debug_mode", false))
	config.set_value("audio", "sound_effects", clampf(float(values.get("sound_effects", 100.0)), 0.0, 100.0))
	config.set_value("display", "routes", values.get("routes", false))
	config.set_value("input", "hotkeys", values.get("hotkeys", {}))
	var path := directory.path_join("settings.cfg")
	return config.save(path + ".tmp") == OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK
