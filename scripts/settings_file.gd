extends RefCounted
## Shared CFG reader with unquoted numeric expressions for both game versions.
const Arithmetic = preload("res://scripts/settings_expression.gd")
var _config := ConfigFile.new()
var _expressions := {}
var _errors := {}
var _visiting := {}
var _resolved := {}

static func read(path: String) -> Dictionary:
	var reader = load("res://scripts/settings_file.gd").new()
	return reader._read(path)

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"config": _config, "errors": {}, "warnings": [path + ": unable to read; using defaults"]}
	var lines: Array[String] = []
	var section := ""
	for source_line in file.get_as_text().trim_prefix("\uFEFF").split("\n"):
		var line := _without_comment(source_line).strip_edges()
		if line.begins_with("["):
			section = line.substr(1, line.length() - 2).strip_edges()
		elif line.contains("="):
			var split := line.find("=")
			var key := line.left(split).strip_edges()
			var value := line.substr(split + 1).strip_edges()
			_expressions.erase(section + "." + key)
			# Preserve native dictionaries/arrays and quoted strings. Treat other
			# values as expressions so ConfigFile cannot silently truncate "360 * 2".
			if not value.begins_with("{") and not value.begins_with("[") and not value.begins_with("\""):
				_expressions[section + "." + key] = {"section": section, "key": key, "source": value}
				line = key + " = " + JSON.stringify(value)
		lines.append(line)
	if _config.parse("\n".join(lines)) != OK:
		return {"config": ConfigFile.new(), "errors": {}, "warnings": [path + ": invalid file syntax; using defaults"]}
	for id: String in _expressions:
		_resolve(id)
	return {"config": _config, "errors": _errors, "warnings": []}

func _resolve(id: String) -> Variant:
	if _resolved.has(id): return _resolved[id]
	if _errors.has(id): return null
	if _visiting.has(id) or _visiting.size() >= 64:
		_errors[id] = "circular reference or reference chain too deep"
		return null
	var entry: Dictionary = _expressions[id]
	_visiting[id] = true
	var expression := Arithmetic.new()
	var value: Variant = expression.evaluate(entry.source, _lookup.bind(entry.section),
		String(entry.key).to_lower().ends_with("_multiplier"))
	_visiting.erase(id)
	if value == null:
		_errors[id] = expression.error
	else:
		_config.set_value(entry.section, entry.key, value)
		_resolved[id] = value
	return value

func _lookup(name: String, section: String) -> Variant:
	# Local keys win, then general constants; qualified names are explicit.
	var candidates: Array = [name] if name.contains(".") else [section + "." + name, "general." + name]
	for id: String in candidates:
		if _expressions.has(id): return _resolve(id)
		var separator := id.rfind(".")
		var owner := id.left(separator)
		var key := id.substr(separator + 1)
		if _config.has_section_key(owner, key):
			var value: Variant = _config.get_value(owner, key)
			return value if value is int or value is float else null
	return null

static func _without_comment(line: String) -> String:
	var quoted := false
	var escaped := false
	for index in line.length():
		var character := line[index]
		if escaped:
			escaped = false
		elif quoted and character == "\\":
			escaped = true
		elif character == "\"":
			quoted = not quoted
		elif not quoted and character == ";":
			return line.left(index)
	return line
